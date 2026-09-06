import Foundation
import Photos
import SwiftUI
import UserNotifications
import EventKit
import UIKit

@MainActor
final class AppModel: ObservableObject {
    @Published var authorization: PHAuthorizationStatus = .notDetermined
    @Published var items: [String: Screenshot] = [:]
    @Published var isScanning = false
    @Published var progress: (done: Int, total: Int) = (0, 0)
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

    var categoryCounts: [(Category, Int)] {
        Category.allCases.map { ($0, items(in: $0).filter { !$0.isDone }.count) }.filter { $0.1 > 0 }
    }

    /// Напоминания: ближайшие даты, истекающее, забытое, «посмотреть».
    var reminders: [Reminder] {
        var out: [Reminder] = []
        let now = Date()
        for s in all where !s.isDone {
            if let d = s.upcomingDate, d.timeIntervalSince(now) < 7 * 86400 {
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
        scanTask = Task { [weak self] in
            guard let self else { return }
            let assets = library.fetchScreenshots(includeAllPhotos: includeAllPhotos)
            let known = items
            // Новые и изменённые — остальное из кэша.
            let todo = assets.filter { a in
                guard let k = known[a.localIdentifier], let scanned = k.scannedAt else { return true }
                return (a.modificationDate ?? a.creationDate ?? .distantPast) > scanned
            }
            progress = (0, todo.count)
            // Убираем удалённые из галереи.
            let present = Set(assets.map(\.localIdentifier))
            for id in items.keys where !present.contains(id) { items.removeValue(forKey: id) }

            for (i, asset) in todo.enumerated() {
                if Task.isCancelled { break }
                var shot = items[asset.localIdentifier] ?? Screenshot(id: asset.localIdentifier, createdAt: asset.creationDate ?? Date(), width: asset.pixelWidth, height: asset.pixelHeight)
                if let image = await library.image(for: asset) {
                    let lines = await OCR.recognize(image)
                    let r = Extractor.analyze(lines: lines)
                    shot.text = lines.joined(separator: "\n")
                    shot.category = r.category
                    shot.confidence = r.confidence
                    shot.extracted = r.extracted
                    shot.summary = r.summary
                }
                shot.scannedAt = Date()
                items[asset.localIdentifier] = shot
                progress = (i + 1, todo.count)
                if i % 10 == 0 { store.save(items) }
            }
            store.save(items)
            isScanning = false
            scheduleNotifications()
        }
    }

    func cancelScan() { scanTask?.cancel(); isScanning = false }

    // MARK: - Действия

    func update(_ s: Screenshot) { items[s.id] = s; store.save(items) }
    func markDone(_ s: Screenshot, _ done: Bool = true) { var s = s; s.isDone = done; update(s) }
    func setCategory(_ s: Screenshot, _ c: Category) { var s = s; s.category = c; s.confidence = 1; update(s) }
    func hide(_ s: Screenshot) { var s = s; s.isHidden = true; update(s) }

    func delete(_ s: Screenshot) async {
        try? await library.delete(ids: [s.id])
        items.removeValue(forKey: s.id); store.save(items)
    }

    func asset(for s: Screenshot) -> PHAsset? { library.asset(id: s.id) }
    func thumbnail(for s: Screenshot) async -> UIImage? {
        guard let a = asset(for: s) else { return nil }
        return await library.thumbnail(for: a)
    }
    func fullImage(for s: Screenshot) async -> UIImage? {
        guard let a = asset(for: s) else { return nil }
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
