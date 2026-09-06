import Foundation

/// Категория содержимого скриншота. Порядок — порядок на главном экране.
/// Значения намеренно не переводятся: они записаны в сохранённых карточках,
/// смена сломала бы кэш у тех, кто уже пользуется. Показываем `title`.
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

    /// Название на языке пользователя.
    var title: String {
        switch self {
        case .watch: return String(localized: "Посмотреть")
        case .codes: return String(localized: "Коды и пароли")
        case .payments: return String(localized: "Чеки и платежи")
        case .tickets: return String(localized: "Билеты и брони")
        case .places: return String(localized: "Адреса и места")
        case .contacts: return String(localized: "Контакты")
        case .links: return String(localized: "Ссылки")
        case .chats: return String(localized: "Переписки")
        case .recipes: return String(localized: "Рецепты")
        case .notes: return String(localized: "Прочее")
        }
    }

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
        case .code, .wifi, .orderNumber: return String(localized: "Скопировать")
        case .amount: return String(localized: "Скопировать сумму")
        case .date: return String(localized: "В календарь")
        case .phone: return String(localized: "Позвонить")
        case .link: return String(localized: "Открыть")
        case .address: return String(localized: "На карте")
        case .email: return String(localized: "Написать")
        case .title: return String(localized: "Найти")
        case .flight: return String(localized: "Скопировать рейс")
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
    /// Картинку удалили из галереи, а разобранные данные оставили. Такая карточка
    /// живёт дальше без превью и не воскресает при следующем скане.
    var isFreed: Bool = false
    var freedAt: Date? = nil
    var freedBytes: Int64 = 0
    /// Копия миниатюры в JPEG — чтобы карточка после уборки не была пустой.
    var thumbnailData: Data? = nil
    /// Отпечаток кадра: по нему находим повторяющиеся скриншоты одного экрана.
    var phash: Fingerprint? = nil

    static func == (a: Screenshot, b: Screenshot) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var age: TimeInterval { Date().timeIntervalSince(createdAt) }
    var ageDays: Int { Int(age / 86400) }
    /// Ближайшая будущая дата на скриншоте — основа напоминаний.
    var upcomingDate: Date? {
        extracted.compactMap(\.date).filter { $0 > Date() }.min()
    }

    /// Есть ли ради чего хранить карточку после удаления картинки.
    var hasValue: Bool { !extracted.isEmpty || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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
