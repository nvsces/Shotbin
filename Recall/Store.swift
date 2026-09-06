import Foundation

/// Кэш результатов в Application Support. JSON — потому что данных немного
/// (тысяча скриншотов = сотни килобайт), а читать его может кто угодно.
final class Store: @unchecked Sendable {
    private let url: URL
    private let queue = DispatchQueue(label: "recall.store")

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Recall", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("screenshots.json")
    }

    func load() -> [String: Screenshot] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let list = (try? dec.decode([Screenshot].self, from: data)) ?? []
        return Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }

    func save(_ items: [String: Screenshot]) {
        let list = Array(items.values)
        queue.async { [url] in
            let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
            if let data = try? enc.encode(list) { try? data.write(to: url, options: .atomic) }
        }
    }
}
