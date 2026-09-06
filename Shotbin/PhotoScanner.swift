import Foundation
import Photos
import SwiftUI
import UIKit

/// Отдельный разбор обычных фотографий. Запускается по желанию и ищет
/// только повторы: текст на снимке кота никому не нужен, а вот пять
/// почти одинаковых кадров одной сцены занимают место зря.
///
/// Живёт отдельно от разбора скриншотов: свой скан, свой кэш, свои серии.
@MainActor
final class PhotoScanner: ObservableObject {
    struct Frame: Codable, Identifiable, Hashable, Sendable {
        let id: String
        let createdAt: Date
        let width: Int
        let height: Int
        var phash: Fingerprint?
        /// Кадр удалён нами — карточку не воскрешаем при следующем скане.
        var isGone: Bool = false

        static func == (a: Frame, b: Frame) -> Bool { a.id == b.id }
        func hash(into h: inout Hasher) { h.combine(id) }
    }

    struct Series: Identifiable, Sendable {
        let id: String
        let keep: Frame
        let drop: [Frame]
        var all: [Frame] { [keep] + drop }
    }

    @Published private(set) var frames: [String: Frame] = [:] { didSet { version &+= 1 } }
    @Published private(set) var isScanning = false
    @Published private(set) var progress: (done: Int, total: Int) = (0, 0)
    @Published private(set) var wasInterrupted = false
    @Published private(set) var remaining = 0
    @Published private(set) var total = 0
    @Published private(set) var freedBytes: Int64 = 0
    @Published var sizes: [String: Int64] = [:]

    private var version = 0
    private var cache: (stamp: Int, series: [Series])?
    private let library = PhotoLibrary.shared
    private let store = FrameStore()
    private var task: Task<Void, Never>?

    init() {
        frames = store.load()
        freedBytes = Int64(UserDefaults.standard.integer(forKey: "photosFreedBytes"))
    }

    var scannedCount: Int { frames.values.filter { !$0.isGone }.count }
    var neverScanned: Bool { frames.isEmpty }

    // MARK: - Скан

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        wasInterrupted = false
        task = Task { [weak self] in
            guard let self else { return }
            let assets = library.photosOnly()
            total = assets.count
            let known = frames
            let todo = assets.filter { known[$0.localIdentifier] == nil }
            progress = (0, todo.count)

            // Убираем то, чего в галерее уже нет.
            let present = Set(assets.map(\.localIdentifier))
            for id in frames.keys where !present.contains(id) { frames.removeValue(forKey: id) }

            var batch: [Frame] = []
            var done = 0
            for asset in todo {
                if Task.isCancelled { break }
                let frame = await fingerprint(asset)
                batch.append(frame)
                done += 1
                if batch.count >= 16 { publish(batch, done: done, total: todo.count); batch.removeAll(keepingCapacity: true) }
            }
            publish(batch, done: done, total: todo.count)

            wasInterrupted = Task.isCancelled && done < todo.count
            remaining = max(0, todo.count - done)
            isScanning = false
        }
    }

    func cancel() { task?.cancel() }

    private func publish(_ batch: [Frame], done: Int, total: Int) {
        if !batch.isEmpty {
            for f in batch { frames[f.id] = f }
            store.save(frames)
        }
        progress = (done, total)
    }

    /// Отпечатку хватает мелкой картинки — грузим 400 px вместо полного размера.
    private func fingerprint(_ asset: PHAsset) async -> Frame {
        var frame = Frame(id: asset.localIdentifier,
                          createdAt: asset.creationDate ?? Date(),
                          width: asset.pixelWidth, height: asset.pixelHeight)
        if let image = await library.image(for: asset, maxSide: 400) {
            frame.phash = await Task.detached(priority: .utility) { Fingerprint.make(image) }.value
        }
        return frame
    }

    // MARK: - Серии

    /// Порог тот же, что для скриншотов. На проверке настоящие серии дают 0,
    /// а ближайшие разные снимки — 60, так что запас большой.
    private static let threshold = 6

    var series: [Series] {
        if let c = cache, c.stamp == version { return c.series }
        let result = compute()
        cache = (version, result)
        return result
    }

    var dropCount: Int { series.reduce(0) { $0 + $1.drop.count } }

    private func compute() -> [Series] {
        let pool = frames.values.filter { !$0.isGone && $0.phash != nil }
            .sorted { $0.createdAt > $1.createdAt }
        var used = Set<String>()
        var out: [Series] = []
        for f in pool where !used.contains(f.id) {
            guard let h = f.phash else { continue }
            var group = [f]
            for other in pool where !used.contains(other.id) && other.id != f.id {
                guard let oh = other.phash, h.distance(to: oh) <= Self.threshold else { continue }
                group.append(other)
            }
            guard group.count > 1 else { continue }
            group.forEach { used.insert($0.id) }
            // Оставляем самый крупный кадр серии, при равенстве — свежий.
            let keep = group.max {
                let pa = $0.width * $0.height, pb = $1.width * $1.height
                return pa != pb ? pa < pb : $0.createdAt < $1.createdAt
            } ?? group[0]
            out.append(Series(id: keep.id, keep: keep,
                              drop: group.filter { $0.id != keep.id }.sorted { $0.createdAt > $1.createdAt }))
        }
        return out.sorted { $0.keep.createdAt > $1.keep.createdAt }
    }

    // MARK: - Размеры и удаление

    func measure(_ list: [Frame]) async {
        let missing = list.filter { sizes[$0.id] == nil }
        guard !missing.isEmpty else { return }
        let lib = library
        let measured: [(String, Int64)] = await Task.detached(priority: .utility) {
            missing.compactMap { f in
                guard let a = lib.asset(id: f.id) else { return nil }
                return (f.id, lib.fileSize(of: a))
            }
        }.value
        for (id, size) in measured { sizes[id] = size }
    }

    func totalSize(_ list: [Frame]) -> Int64 { list.reduce(0) { $0 + (sizes[$1.id] ?? 0) } }

    @discardableResult
    func delete(_ list: [Frame]) async -> Int64 {
        guard !list.isEmpty else { return 0 }
        await measure(list)
        let ids = list.map(\.id)
        guard let ok = try? await library.delete(ids: ids), ok else { return 0 }
        var freed: Int64 = 0
        for id in ids {
            freed += sizes[id] ?? 0
            frames.removeValue(forKey: id)
        }
        freedBytes += freed
        UserDefaults.standard.set(Int(freedBytes), forKey: "photosFreedBytes")
        store.save(frames)
        return freed
    }
}

/// Кэш отпечатков фотографий — отдельный файл, чтобы не мешать карточкам скриншотов.
private final class FrameStore: @unchecked Sendable {
    private let url: URL
    private let queue = DispatchQueue(label: "shotbin.frames")

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Shotbin", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("photos.json")
    }

    func load() -> [String: PhotoScanner.Frame] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let list = (try? dec.decode([PhotoScanner.Frame].self, from: data)) ?? []
        return Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }

    func save(_ frames: [String: PhotoScanner.Frame]) {
        let list = Array(frames.values)
        queue.async { [url] in
            let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
            if let data = try? enc.encode(list) { try? data.write(to: url, options: .atomic) }
        }
    }
}
