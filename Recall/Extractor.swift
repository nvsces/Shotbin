import Foundation

/// Правила извлечения и классификации. Без сети и без моделей: регулярки,
/// NSDataDetector и словари признаков. Предсказуемо и мгновенно.
enum Extractor {

    struct Result {
        var category: Category
        var confidence: Double
        var extracted: [Extracted]
        var summary: String
    }

    static func analyze(lines: [String]) -> Result {
        let text = lines.joined(separator: "\n")
        let lower = text.lowercased()
        var found: [Extracted] = []

        // --- Детектор Apple: даты, телефоны, ссылки, адреса, почта ---
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue
                                              | NSTextCheckingResult.CheckingType.phoneNumber.rawValue
                                              | NSTextCheckingResult.CheckingType.link.rawValue
                                              | NSTextCheckingResult.CheckingType.address.rawValue) {
            for m in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let r = Range(m.range, in: text) else { continue }
                let s = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                switch m.resultType {
                case .date:
                    if let d = m.date, abs(d.timeIntervalSinceNow) < 400 * 86400, looksLikeRealDate(s) {
                        found.append(Extracted(kind: .date, value: s, label: nil, date: d))
                    }
                case .phoneNumber:
                    // Берём текст как на скриншоте: детектор иногда отрезает код страны.
                    if s.filter(\.isNumber).count >= 7 { found.append(Extracted(kind: .phone, value: s)) }
                case .link:
                    if let u = m.url {
                        if u.scheme == "mailto" { found.append(Extracted(kind: .email, value: u.absoluteString.replacingOccurrences(of: "mailto:", with: ""))) }
                        else { found.append(Extracted(kind: .link, value: u.absoluteString)) }
                    }
                case .address:
                    if s.count > 8 { found.append(Extracted(kind: .address, value: s)) }
                default: break
                }
            }
        }

        // --- Телефоны целиком: детектор Apple режет российский код страны ---
        for m in matches(#"(?:\+7|8)[\s(]*\d{3}[\s)]*\d{3}[\s-]*\d{2}[\s-]*\d{2}"#, text) {
            // OCR рвёт номер на строки — склеиваем в одну.
            let full = m[0].split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
            found.removeAll { $0.kind == .phone && full.contains($0.value) }
            found.append(Extracted(kind: .phone, value: full))
        }

        // --- Коды: OTP, промокоды, пароли Wi-Fi ---
        for m in matches(#"(?i)(код|code|промокод|promo|пароль|password|pin|otp)[^\n:：]{0,32}[:：\-]?\s*([A-Za-z0-9][A-Za-z0-9\-]{3,19})\b"#, text) {
            let value = m[2]
            // Слово после «код» — не код: «Код для…» → «для» отсекается требованием цифры или капса.
            guard value.rangeOfCharacter(from: .decimalDigits) != nil || value == value.uppercased() else { continue }
            found.append(Extracted(kind: .code, value: value, label: m[1].capitalized))
        }
        for m in matches(#"(?i)(?:сеть|ssid|network)\s*[:：]\s*(\S+)[\s\S]{0,60}?(?:пароль|password|pass)\s*[:：]\s*(\S+)"#, text) {
            found.removeAll { $0.kind == .code && $0.value == m[2] }
            found.append(Extracted(kind: .wifi, value: m[2], label: "Wi-Fi \(m[1])"))
        }
        // Одинокие 4–8-значные коды в строке из одного числа — типично для SMS-кодов.
        for line in lines where line.trimmingCharacters(in: .whitespaces).range(of: #"^\d{4,8}$"#, options: .regularExpression) != nil {
            if lower.contains("код") || lower.contains("code") { found.append(Extracted(kind: .code, value: line.trimmingCharacters(in: .whitespaces), label: "Код")) }
        }

        // --- Суммы ---
        for m in matches(#"(?i)(итого|всего|total|к оплате|сумма|amount|оплачено)\s*[:：]?\s*(\d[\d\s]{0,8}(?:[.,]\d{2})?)\s*(₽|руб|rub|\$|€|usd|eur)?"#, text) {
            let v = (m[2] + " " + (m[3].isEmpty ? "₽" : m[3])).replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
            found.append(Extracted(kind: .amount, value: v, label: m[1].capitalized))
        }
        if !found.contains(where: { $0.kind == .amount }) {
            for m in matches(#"(\d[\d\s]{2,8}(?:[.,]\d{2})?)\s*(₽|руб\.?|rub|\$|€)"#, text).prefix(2) {
                found.append(Extracted(kind: .amount, value: m[1].trimmingCharacters(in: .whitespaces) + " " + m[2]))
            }
        }

        // --- Номера заказов и рейсов ---
        for m in matches(#"(?i)(?:заказ|order|бронь|booking|№|номер)\s*[:：#№]?\s*([A-Z0-9]{5,14})"#, text) {
            found.append(Extracted(kind: .orderNumber, value: m[1], label: "Заказ"))
        }
        for m in matches(#"\b([A-Z]{2}\s?\d{3,4})\b[\s\S]{0,60}?\b([A-Z]{3})\b[\s\S]{0,20}?\b([A-Z]{3})\b"#, text).prefix(1) {
            found.append(Extracted(kind: .flight, value: "\(m[1]) \(m[2])→\(m[3])", label: "Рейс"))
        }

        // --- Фильмы, сериалы, книги ---
        let watchMarkers = ["смотреть", "фильм", "сериал", "кино", "imdb", "кинопоиск", "netflix", "трейлер", "серия", "сезон", "рекомендую посмотреть", "must watch", "movie", "книга", "читать", "автор:", "прочитать"]
        let watchScore = watchMarkers.filter { lower.contains($0) }.count
        if watchScore > 0 {
            // Название — строка с годом в скобках или самая «заголовочная» короткая строка.
            if let titled = lines.first(where: { $0.range(of: #"[«"“]?[А-ЯA-Z][^\n]{2,60}[»"”]?\s*\(?(19|20)\d{2}\)?"#, options: .regularExpression) != nil }) {
                found.append(Extracted(kind: .title, value: titled.trimmingCharacters(in: .whitespaces), label: "Название"))
            } else if let quoted = matches(#"[«"“]([^»"”\n]{2,60})[»"”]"#, text).first {
                found.append(Extracted(kind: .title, value: quoted[1], label: "Название"))
            }
        }

        // --- Классификация: считаем признаки ---
        var scores: [Category: Double] = [:]
        func add(_ c: Category, _ v: Double) { scores[c, default: 0] += v }

        add(.watch, Double(watchScore) * 1.5 + (found.contains { $0.kind == .title } ? 2 : 0))
        add(.codes, Double(found.filter { $0.kind == .code || $0.kind == .wifi }.count) * 3 + count(lower, ["код для", "код подтверждения", "никому не сообщайте", "verification code", "одноразовый"]))
        add(.payments, Double(found.filter { $0.kind == .amount }.count) * 1.5 + count(lower, ["чек", "оплата", "платёж", "перевод", "receipt", "кассовый", "ндс", "карта *", "операция", "purchase", "оплачено", "списание"]))
        add(.tickets, Double(found.filter { $0.kind == .flight || $0.kind == .orderNumber }.count) * 1.5 + count(lower, ["билет", "рейс", "посадочн", "boarding", "бронь", "booking", "заезд", "выезд", "check-in", "место ", "ряд", "вагон", "поезд", "gate", "терминал", "отель", "hotel"]))
        add(.places, Double(found.filter { $0.kind == .address }.count) * 2 + count(lower, ["ул.", "улица", "проспект", "дом ", "кафе", "ресторан", "бар ", "как добраться", "метро", "открыто до", "часы работы", "адрес"]))
        add(.contacts, Double(found.filter { $0.kind == .phone || $0.kind == .email }.count) * 1.5 + count(lower, ["телефон", "контакт", "звонить", "@", "написать", "менеджер"]))
        add(.links, Double(found.filter { $0.kind == .link }.count) * 1.2)
        add(.chats, count(lower, ["написал", "печатает", "онлайн", "был(а)", "в сети", "прочитано", "ответить", "переслать", "typing", "сообщение", "чат"]) + (isChatLike(lines) ? 3.5 : 0))
        add(.recipes, count(lower, ["рецепт", "ингредиент", "г муки", "ст. ложк", "ч. ложк", "духовк", "варить", "жарить", "нарезать", "щепотк", "порци", "минут при", "градус"]))

        let best = scores.max { $0.value < $1.value }
        var category: Category = .notes
        var confidence = 0.0
        if let best, best.value >= 2 {
            category = best.key
            confidence = min(1, best.value / 8)
        }

        // Дедупликация находок с сохранением порядка.
        var seen = Set<String>()
        found = found.filter { seen.insert($0.id).inserted }

        return Result(category: category, confidence: confidence, extracted: found, summary: summary(lines: lines, category: category, found: found))
    }

    /// Одна строка для списка: название, сумма, первая осмысленная строка.
    private static func summary(lines: [String], category: Category, found: [Extracted]) -> String {
        if let t = found.first(where: { $0.kind == .title }) { return t.value }
        if category == .payments, let a = found.first(where: { $0.kind == .amount }) {
            let where_ = lines.first { $0.count > 3 && $0.count < 40 && $0.rangeOfCharacter(from: .letters) != nil } ?? ""
            return where_.isEmpty ? a.value : "\(where_) · \(a.value)"
        }
        if category == .tickets, let f = found.first(where: { $0.kind == .flight }) { return f.value }
        if let c = found.first(where: { $0.kind == .code || $0.kind == .wifi }) { return "\(c.label ?? "Код") \(c.value)" }
        let meaningful = lines.map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 6 && $0.rangeOfCharacter(from: .letters) != nil && !$0.contains("%") }
        return meaningful.first.map { String($0.prefix(80)) } ?? lines.first.map { String($0.prefix(80)) } ?? ""
    }

    /// «12:31» и «в пятницу» — не даты для календаря. Нужен день с месяцем,
    /// dd.mm, или «сегодня/завтра» — иначе переписка превращается в список событий.
    private static func looksLikeRealDate(_ s: String) -> Bool {
        let l = s.lowercased()
        if l.range(of: #"\d{1,2}[./]\d{1,2}"#, options: .regularExpression) != nil { return true }
        let months = ["янв", "фев", "мар", "апр", "мая", "май", "июн", "июл", "авг", "сен", "окт", "ноя", "дек",
                      "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        if months.contains(where: { l.contains($0) }), l.rangeOfCharacter(from: .decimalDigits) != nil { return true }
        return l.contains("завтра") || l.contains("tomorrow") || l.contains("послезавтра")
    }

    private static func isChatLike(_ lines: [String]) -> Bool {
        // Много коротких строк со временем «12:34» в конце — переписка.
        let stamped = lines.filter { $0.range(of: #"\b\d{1,2}:\d{2}\s*$"#, options: .regularExpression) != nil }.count
        return stamped >= 3
    }

    private static func count(_ text: String, _ words: [String]) -> Double {
        Double(words.filter { text.contains($0) }.count)
    }

    private static func matches(_ pattern: String, _ text: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        return re.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { m in
            (0..<m.numberOfRanges).map { i in
                guard let r = Range(m.range(at: i), in: text) else { return "" }
                return String(text[r])
            }
        }
    }
}
