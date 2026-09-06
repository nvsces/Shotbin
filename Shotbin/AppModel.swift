import Foundation
import Photos
import SwiftUI
import UserNotifications
import EventKit
import UIKit

@MainActor
final class AppModel: ObservableObject {
    @Published var authorization: PHAuthorizationStatus = .notDetermined
    @Published var items: [String: Screenshot] = [:] { didSet { itemsVersion &+= 1 } }
    /// Растёт при любой правке карточек — по нему сбрасываем тяжёлые вычисления.
    private var itemsVersion = 0
    @Published var isScanning = false
    @Published var progress: (done: Int, total: Int) = (0, 0)
    /// Скан прервали, не дойдя до конца: показываем «Продолжить».
    @Published var wasInterrupted = false
    /// Сколько кадров осталось на момент остановки.
    @Published var remaining = 0
    @Published var search = ""
    @Published var includeAllPhotos = false

    private let store = Store()
    private let library = PhotoLibrary.shared
    private var scanTask: Task<Void, Never>?

    init() {
        authorization = library.status
        items = store.load()
        #if targetEnvironment(simulator)
        includeAllPhotos = true
        #endif
    }

    // MARK: - Выборки

    var all: [Screenshot] { items.values.filter { !$0.isHidden }.sorted { $0.createdAt > $1.createdAt } }

    func items(in category: Category) -> [Screenshot] { all.filter { $0.category == category } }

    var searchResults: [Screenshot] {
        let q = search.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return all.filter { $0.text.lowercased().contains(q) || $0.summary.lowercased().contains(q) }
    }

    /// Подпись над полками: сколько ещё не разобрано и сколько карточек живёт
    /// без картинки — иначе после уборки счётчик выглядит так, будто ничего не удалили.
    var shelfSummary: String {
        let pending = all.filter { !$0.isDone }.count
        let freed = freedCount
        var parts = ["\(pending) скриншотов"]
        if freed > 0 { parts.append("\(freed) без картинки") }
        return parts.joined(separator: " · ")
    }

    var categoryCounts: [(Category, Int)] {
        Category.allCases.map { ($0, items(in: $0).filter { !$0.isDone }.count) }.filter { $0.1 > 0 }
    }

    /// Напоминания: ближайшие даты, истекающее, забытое, «посмотреть».
    var reminders: [Reminder] {
        var out: [Reminder] = []
        let now = Date()
        // Из серии повторов напоминание даёт только один кадр: об одном и том же
        // рейсе не нужно напоминать столько раз, сколько его успели переснять.
        let shadowed = Set(duplicateGroups.flatMap { $0.drop.map(\.id) })
        for s in all where !s.isDone && !shadowed.contains(s.id) {
            if let d = s.upcomingDate, d.timeIntervalSince(now) < 30 * 86400 {
                let f = RelativeDateTimeFormatter(); f.locale = Locale(identifier: "ru_RU"); f.unitsStyle = .full
                out.append(Reminder(id: "up-\(s.id)", kind: .upcoming, screenshot: s, title: s.summary,
                                    subtitle: "Дата на скриншоте — \(f.localizedString(for: d, relativeTo: now))", date: d))
            } else if s.category == .watch, s.ageDays >= 3 {
                out.append(Reminder(id: "w-\(s.id)", kind: .watch, screenshot: s, title: s.summary,
                                    subtitle: "Сохранили \(s.ageDays) дн. назад и не отметили", date: nil))
            } else if s.category == .codes, s.ageDays >= 30 {
                out.append(Reminder(id: "x-\(s.id)", kind: .expiring, screenshot: s, title: s.summary,
                                    subtitle: "Код лежит месяц — ещё нужен?", date: nil))
            } else if [.tickets, .places].contains(s.category), s.ageDays >= 14, s.ageDays <= 90 {
                out.append(Reminder(id: "f-\(s.id)", kind: .forgotten, screenshot: s, title: s.summary,
                                    subtitle: "Сохранили \(s.ageDays) дн. назад", date: nil))
            }
        }
        return out.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }.prefix(20).map { $0 }
    }

    // MARK: - Доступ и скан

    func requestAccess() async {
        authorization = await library.requestAccess()
        if authorization == .authorized || authorization == .limited { scan() }
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        wasInterrupted = false
        scanTask = Task { [weak self] in
            guard let self else { return }
            let assets = library.fetchScreenshots(includeAllPhotos: includeAllPhotos)
            let known = items

            // Новые и изменённые — остальное из кэша. Разобранные раньше кадры
            // сюда не попадают, поэтому прерванный скан продолжается с того же места.
            let todo = assets.filter { a in
                guard let k = known[a.localIdentifier], let scanned = k.scannedAt else { return true }
                if k.isFreed { return false }
                return (a.modificationDate ?? a.creationDate ?? .distantPast) > scanned
            }
            progress = (0, todo.count)

            // Убираем удалённые из галереи.
            // Карточки, которые мы сами освободили, остаются: картинки уже нет,
            // а вытащенные из неё данные — это всё, ради чего скриншот и хранили.
            let present = Set(assets.map(\.localIdentifier))
            for (id, s) in items where !present.contains(id) {
                if s.isFreed { continue }
                if s.isDone && s.hasValue { items[id]?.isFreed = true; items[id]?.freedAt = Date() }
                else { items.removeValue(forKey: id) }
            }

            // Публикуем результаты пачками: каждая запись в items пересобирает
            // полки, напоминания и повторы, и на каждом кадре это заметно тормозит.
            var batch: [Screenshot] = []
            var doneCount = 0

            for asset in todo {
                if Task.isCancelled { break }
                let cached = items[asset.localIdentifier]
                let shot = await analyze(asset, cached: cached)
                batch.append(shot)
                doneCount += 1
                if batch.count >= Self.batchSize {
                    publish(batch, done: doneCount, total: todo.count)
                    batch.removeAll(keepingCapacity: true)
                }
            }
            publish(batch, done: doneCount, total: todo.count)

            wasInterrupted = Task.isCancelled && doneCount < todo.count
            remaining = max(0, todo.count - doneCount)
            isScanning = false
            if !wasInterrupted { scheduleNotifications() }
        }
    }

    /// Сколько кадров публикуем за раз. Больше — меньше перерисовок,
    /// но реже видно движение полосы.
    private static let batchSize = 8

    /// Публикация пачки: одна перерисовка вместо восьми.
    private func publish(_ batch: [Screenshot], done: Int, total: Int) {
        if !batch.isEmpty {
            for shot in batch { items[shot.id] = shot }
            store.save(items)
        }
        progress = (done, total)
    }

    /// Разбор одного кадра целиком вне главного потока.
    private func analyze(_ asset: PHAsset, cached: Screenshot?) async -> Screenshot {
        var shot = cached ?? Screenshot(id: asset.localIdentifier,
                                        createdAt: asset.creationDate ?? Date(),
                                        width: asset.pixelWidth, height: asset.pixelHeight)
        if let image = await library.image(for: asset) {
            let lines = await OCR.recognize(image)
            let hashed = await Task.detached(priority: .utility) { Fingerprint.make(image) }.value
            let r = await Task.detached(priority: .utility) { Extractor.analyze(lines: lines) }.value
            shot.phash = hashed
            shot.text = lines.joined(separator: "\n")
            shot.category = r.category
            shot.confidence = r.confidence
            shot.extracted = r.extracted
            shot.summary = r.summary
        }
        shot.scannedAt = Date()
        return shot
    }

    /// Останавливаем скан. Разобранные кадры уже сохранены, поэтому
    /// следующий запуск продолжит с того места, где остановились.
    func cancelScan() { scanTask?.cancel() }

    // MARK: - Действия

    func update(_ s: Screenshot) { items[s.id] = s; store.save(items) }
    func markDone(_ s: Screenshot, _ done: Bool = true) { var s = s; s.isDone = done; update(s) }
    func setCategory(_ s: Screenshot, _ c: Category) { var s = s; s.category = c; s.confidence = 1; update(s) }
    func hide(_ s: Screenshot) { var s = s; s.isHidden = true; update(s) }

    func delete(_ s: Screenshot) async {
        guard let ok = try? await library.delete(ids: [s.id]), ok else { return }
        items.removeValue(forKey: s.id); store.save(items)
    }

    // MARK: - Уборка галереи

    /// Скриншот отработал: данные вытащены, картинка в галерее больше не нужна.
    /// Считаем его кандидатом на освобождение места.
    enum FreeReason: String, CaseIterable, Identifiable, Sendable {
        case done = "Разобранные"
        case oldCode = "Коды старше месяца"
        case pastDate = "Прошедшие даты"
        case empty = "Без текста"
        var id: String { rawValue }
        var hint: String {
            switch self {
            case .done: return "Вы отметили «разобрался» — данные уже в карточке"
            case .oldCode: return "Код или пароль лежит больше месяца"
            case .pastDate: return "Билет или бронь на дату, которая прошла"
            case .empty: return "Vision не нашёл текста — разбирать нечего"
            }
        }
    }

    func freeReason(for s: Screenshot) -> FreeReason? {
        guard !s.isFreed else { return nil }
        if !s.hasValue, s.scannedAt != nil { return .empty }
        if s.isDone { return .done }
        if s.category == .codes, s.ageDays >= 30 { return .oldCode }
        if [.tickets, .places].contains(s.category),
           let d = s.extracted.compactMap(\.date).max(), d < Date(), s.upcomingDate == nil { return .pastDate }
        return nil
    }

    /// Кандидаты на уборку, сгруппированные по причине.
    var cleanupGroups: [(FreeReason, [Screenshot])] {
        var byReason: [FreeReason: [Screenshot]] = [:]
        for s in all where !s.isFreed {
            if let r = freeReason(for: s) { byReason[r, default: []].append(s) }
        }
        return FreeReason.allCases.compactMap { r in
            guard let list = byReason[r], !list.isEmpty else { return nil }
            return (r, list.sorted { $0.createdAt > $1.createdAt })
        }
    }

    /// Занимаемое место — считаем один раз и держим в памяти, PHAssetResource небыстрый.
    @Published private(set) var sizes: [String: Int64] = [:]

    func measure(_ list: [Screenshot]) async {
        let missing = list.filter { sizes[$0.id] == nil }
        guard !missing.isEmpty else { return }
        let lib = library
        let measured: [(String, Int64)] = await Task.detached(priority: .utility) {
            missing.compactMap { s in
                guard let a = lib.asset(id: s.id) else { return nil }
                return (s.id, lib.fileSize(of: a))
            }
        }.value
        for (id, size) in measured { sizes[id] = size }
    }

    func totalSize(_ list: [Screenshot]) -> Int64 { list.reduce(0) { $0 + (sizes[$1.id] ?? 0) } }

    /// Освобождает место: сохраняет миниатюру и данные, удаляет картинки одной пачкой.
    /// Возвращает, сколько байт ушло (0 — пользователь отменил системный запрос).
    ///
    /// `keepCards` = false для повторов: там кадр дублирует другой, оставшийся
    /// в галерее, и карточка-двойник в списках только мешает.
    @discardableResult
    func free(_ list: [Screenshot], keepCards: Bool = true) async -> Int64 {
        guard !list.isEmpty else { return 0 }
        await measure(list)
        if keepCards {
            // Миниатюры снимаем до удаления, иначе карточка останется без превью.
            for s in list where s.thumbnailData == nil {
                if let img = await thumbnail(for: s), let data = img.jpegData(compressionQuality: 0.7) {
                    items[s.id]?.thumbnailData = data
                }
            }
        }
        let ids = list.map(\.id)
        guard let ok = try? await library.delete(ids: ids), ok else { return 0 }
        var freed: Int64 = 0
        for id in ids {
            let size = sizes[id] ?? 0
            freed += size
            if keepCards {
                items[id]?.isFreed = true
                items[id]?.freedAt = Date()
                items[id]?.freedBytes = size
                items[id]?.isDone = true
            } else {
                items.removeValue(forKey: id)
                duplicatesFreedBytes += size
                duplicatesRemoved += 1
            }
        }
        store.save(items)
        return freed
    }

    /// Итог по повторам держим отдельно: карточек этих кадров уже нет,
    /// поэтому суммы живут в UserDefaults, а не в самих карточках.
    var duplicatesFreedBytes: Int64 {
        get { Int64(UserDefaults.standard.integer(forKey: "duplicatesFreedBytes")) }
        set { UserDefaults.standard.set(Int(newValue), forKey: "duplicatesFreedBytes") }
    }
    var duplicatesRemoved: Int {
        get { UserDefaults.standard.integer(forKey: "duplicatesRemoved") }
        set { UserDefaults.standard.set(newValue, forKey: "duplicatesRemoved") }
    }

    // MARK: - Повторы

    /// Группа почти одинаковых скриншотов: серия кадров одного экрана.
    struct DuplicateGroup: Identifiable, Sendable {
        let id: String
        /// Лучший кадр серии — его предлагаем оставить.
        let keep: Screenshot
        /// Остальные — кандидаты на удаление.
        let drop: [Screenshot]
        var all: [Screenshot] { [keep] + drop }
    }

    /// Насколько кадры должны совпадать, чтобы считаться повтором:
    /// 6 ячеек из 256. На наборе проверки настоящие повторы дают 0–1,
    /// а ближайшие непохожие экраны — 12, так что зазор безопасный.
    private static let duplicateThreshold = 6

    /// Вторая проверка — по распознанному тексту. Картинка может совпасть
    /// раскладкой, но если на ней другие слова, это разные экраны.
    private func textMatches(_ a: Screenshot, _ b: Screenshot) -> Bool {
        let x = a.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let y = b.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if x.isEmpty && y.isEmpty { return true }          // обои и фото без текста
        if x.isEmpty != y.isEmpty { return false }
        if x == y { return true }
        let wa = Set(x.lowercased().split(separator: " "))
        let wb = Set(y.lowercased().split(separator: " "))
        guard !wa.isEmpty, !wb.isEmpty else { return false }
        let common = Double(wa.intersection(wb).count)
        return common / Double(min(wa.count, wb.count)) >= 0.8
    }

    /// Сравнение всех пар — это O(n²), на тысяче скриншотов миллион сравнений.
    /// Держим готовый ответ и пересчитываем, только когда карточки изменились.
    private var duplicateCache: (stamp: Int, groups: [DuplicateGroup])?

    /// Серии повторов: у кадра есть отпечаток, картинка ещё в галерее,
    /// раскладка совпадает и текст на кадрах один и тот же.
    var duplicateGroups: [DuplicateGroup] {
        if let c = duplicateCache, c.stamp == itemsVersion { return c.groups }
        let groups = computeDuplicateGroups()
        duplicateCache = (itemsVersion, groups)
        return groups
    }

    private func computeDuplicateGroups() -> [DuplicateGroup] {
        let pool = all.filter { !$0.isFreed && $0.phash != nil }
            .sorted { $0.createdAt > $1.createdAt }
        var used = Set<String>()
        var groups: [DuplicateGroup] = []

        for s in pool where !used.contains(s.id) {
            guard let h = s.phash else { continue }
            var series = [s]
            for other in pool where !used.contains(other.id) && other.id != s.id {
                guard let oh = other.phash else { continue }
                guard h.distance(to: oh) <= Self.duplicateThreshold else { continue }
                guard textMatches(s, other) else { continue }
                series.append(other)
            }
            guard series.count > 1 else { continue }
            series.forEach { used.insert($0.id) }
            let keep = bestOfSeries(series)
            groups.append(DuplicateGroup(id: keep.id,
                                         keep: keep,
                                         drop: series.filter { $0.id != keep.id }
                                                     .sorted { $0.createdAt > $1.createdAt }))
        }
        return groups.sorted { $0.keep.createdAt > $1.keep.createdAt }
    }

    /// Лучший кадр серии: сначала тот, где больше распознанного текста и находок,
    /// при равенстве — крупнее по пикселям, затем более свежий.
    private func bestOfSeries(_ series: [Screenshot]) -> Screenshot {
        series.max { a, b in
            if a.extracted.count != b.extracted.count { return a.extracted.count < b.extracted.count }
            if a.text.count != b.text.count { return a.text.count < b.text.count }
            let pa = a.width * a.height, pb = b.width * b.height
            if pa != pb { return pa < pb }
            return a.createdAt < b.createdAt
        } ?? series[0]
    }

    var duplicateDropCount: Int { duplicateGroups.reduce(0) { $0 + $1.drop.count } }

    /// Сколько всего освободили за всё время.
    var freedTotal: Int64 { items.values.reduce(0) { $0 + $1.freedBytes } + duplicatesFreedBytes }
    var freedCount: Int { items.values.filter(\.isFreed).count }

    func asset(for s: Screenshot) -> PHAsset? { library.asset(id: s.id) }
    func thumbnail(for s: Screenshot) async -> UIImage? {
        if let data = s.thumbnailData ?? items[s.id]?.thumbnailData { return UIImage(data: data) }
        guard let a = asset(for: s) else { return nil }
        return await library.thumbnail(for: a)
    }
    func fullImage(for s: Screenshot) async -> UIImage? {
        guard let a = asset(for: s) else {
            if let data = items[s.id]?.thumbnailData { return UIImage(data: data) }
            return nil
        }
        return await library.image(for: a, maxSide: 2400)
    }

    func perform(_ e: Extracted, from s: Screenshot) {
        switch e.kind {
        case .code, .wifi, .orderNumber, .amount, .flight:
            UIPasteboard.general.string = e.value
        case .phone:
            if let u = URL(string: "tel:" + e.value.filter { $0.isNumber || $0 == "+" }) { UIApplication.shared.open(u) }
        case .link:
            if let u = URL(string: e.value) { UIApplication.shared.open(u) }
        case .email:
            if let u = URL(string: "mailto:" + e.value) { UIApplication.shared.open(u) }
        case .address:
            let q = e.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let u = URL(string: "maps://?q=" + q) { UIApplication.shared.open(u) }
        case .title:
            let q = e.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let u = URL(string: "https://www.kinopoisk.ru/index.php?kp_query=" + q) { UIApplication.shared.open(u) }
        case .date:
            addToCalendar(e, from: s)
        }
    }

    private func addToCalendar(_ e: Extracted, from s: Screenshot) {
        guard let date = e.date else { return }
        let storeEK = EKEventStore()
        storeEK.requestWriteOnlyAccessToEvents { granted, _ in
            guard granted else { return }
            let event = EKEvent(eventStore: storeEK)
            event.title = s.summary.isEmpty ? "Из скриншота" : s.summary
            event.startDate = date
            event.endDate = date.addingTimeInterval(3600)
            event.notes = s.text
            event.calendar = storeEK.defaultCalendarForNewEvents
            try? storeEK.save(event, span: .thisEvent)
        }
    }

    // MARK: - Уведомления

    func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    /// Локальные уведомления по датам со скриншотов — за день до события.
    private func scheduleNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for r in reminders where r.kind == .upcoming {
            guard let d = r.date else { continue }
            let fire = d.addingTimeInterval(-86400)
            guard fire > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Завтра: \(r.title)"
            content.body = "Вы сохраняли это скриншотом. Открыть?"
            content.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            center.add(UNNotificationRequest(identifier: r.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }
}
