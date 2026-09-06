import Foundation

/// Категория содержимого скриншота. Порядок — порядок на главном экране.
enum Category: String, Codable, CaseIterable, Identifiable, Sendable {
    case watch = "Посмотреть"          // фильмы, сериалы, книги, места из рилсов
    case codes = "Коды и пароли"
    case payments = "Чеки и платежи"
    case tickets = "Билеты и брони"
    case places = "Адреса и места"
    case contacts = "Контакты"
    case links = "Ссылки"
    case chats = "Переписки"
    case recipes = "Рецепты"
    case notes = "Прочее"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .watch: return "play.rectangle"
        case .codes: return "key"
        case .payments: return "creditcard"
        case .tickets: return "ticket"
        case .places: return "mappin.and.ellipse"
        case .contacts: return "person.crop.circle"
        case .links: return "link"
        case .chats: return "bubble.left.and.bubble.right"
        case .recipes: return "fork.knife"
        case .notes: return "doc.text"
        }
    }
}

/// Что удалось вытащить из текста. Каждая находка — одно действие для пользователя.
struct Extracted: Codable, Identifiable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case code, amount, date, phone, link, address, email, title, flight, orderNumber, wifi
    }
    var id: String { "\(kind.rawValue):\(value)" }
    let kind: Kind
    let value: String
    var label: String? = nil       // «Промокод», «Итого», «Вылет»
    var date: Date? = nil          // для kind == .date

    var symbol: String {
        switch kind {
        case .code, .wifi: return "doc.on.doc"
        case .amount: return "rublesign.circle"
        case .date: return "calendar.badge.plus"
        case .phone: return "phone"
        case .link: return "safari"
        case .address: return "map"
        case .email: return "envelope"
        case .title: return "play.circle"
        case .flight: return "airplane"
        case .orderNumber: return "number"
        }
    }
    var actionTitle: String {
        switch kind {
        case .code, .wifi, .orderNumber: return "Скопировать"
        case .amount: return "Скопировать сумму"
        case .date: return "В календарь"
        case .phone: return "Позвонить"
        case .link: return "Открыть"
        case .address: return "На карте"
        case .email: return "Написать"
        case .title: return "Найти"
        case .flight: return "Скопировать рейс"
        }
    }
}

/// Скриншот с распознанным текстом. Кэшируется по идентификатору ассета:
/// OCR — самая дорогая операция, повторять её при каждом запуске нельзя.
struct Screenshot: Codable, Identifiable, Hashable, Sendable {
    let id: String              // PHAsset.localIdentifier
    let createdAt: Date
    let width: Int
    let height: Int
    var text: String = ""
    var category: Category = .notes
    var confidence: Double = 0  // насколько уверены в категории, 0...1
    var extracted: [Extracted] = []
    var summary: String = ""    // одна строка для списка
    var isDone: Bool = false    // пользователь отметил «разобрался»
    var isHidden: Bool = false
    var scannedAt: Date? = nil

    static func == (a: Screenshot, b: Screenshot) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var age: TimeInterval { Date().timeIntervalSince(createdAt) }
    var ageDays: Int { Int(age / 86400) }
    /// Ближайшая будущая дата на скриншоте — основа напоминаний.
    var upcomingDate: Date? {
        extracted.compactMap(\.date).filter { $0 > Date() }.min()
    }
}

/// Напоминание, собранное из содержимого.
struct Reminder: Identifiable, Sendable {
    enum Kind: Sendable { case upcoming, expiring, forgotten, watch }
    let id: String
    let kind: Kind
    let screenshot: Screenshot
    let title: String
    let subtitle: String
    let date: Date?

    var symbol: String {
        switch kind {
        case .upcoming: return "calendar.badge.exclamationmark"
        case .expiring: return "clock.badge.exclamationmark"
        case .forgotten: return "moon.zzz"
        case .watch: return "play.rectangle"
        }
    }
}
