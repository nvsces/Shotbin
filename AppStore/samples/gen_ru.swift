import AppKit

// Рисуем «скриншоты телефона» 1170×2532 с текстом — как настоящие, чтобы Vision их читал.
func render(_ name: String, bg: NSColor, blocks: [(String, CGFloat, NSColor, Bool)]) {
    let w = 1170.0, h = 2532.0
    let img = NSImage(size: NSSize(width: w, height: h))
    img.lockFocus()
    bg.setFill(); NSRect(x: 0, y: 0, width: w, height: h).fill()
    var y = h - 200
    for (text, size, color, bold) in blocks {
        let font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let para = NSMutableParagraphStyle(); para.lineBreakMode = .byWordWrapping
        let rect = NSRect(x: 80, y: y - size * 3, width: w - 160, height: size * 3)
        (text as NSString).draw(in: rect, withAttributes: attrs.merging([.paragraphStyle: para]) { $1 })
        y -= size * 2.2 + 20
    }
    img.unlockFocus()
    let tiff = img.tiffRepresentation!, rep = NSBitmapImageRep(data: tiff)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(name).png"))
    print("✓ \(name).png")
}
let dark = NSColor(white: 0.08, alpha: 1), white = NSColor.white, gray = NSColor(white: 0.55, alpha: 1)
let light = NSColor(white: 0.97, alpha: 1), black = NSColor(white: 0.1, alpha: 1)

render("01_reel_movie", bg: dark, blocks: [
    ("@kino_recommend", 40, gray, false),
    ("Топ-5 фильмов, которые надо посмотреть этой осенью", 52, white, true),
    ("«Оппенгеймер» (2023)", 64, white, true),
    ("Кристофер Нолан. 3 часа, которые пролетают за минуту. Кинопоиск 8.4", 44, white, false),
    ("смотреть обязательно 🎬", 44, gray, false),
    ("♡ 48 210    ⃝ 1 204    ➦ 9 872", 40, gray, false),
])
render("02_receipt", bg: light, blocks: [
    ("Кофейня «Ботаника»", 56, black, true),
    ("ул. Большая Покровская, 12", 40, gray, false),
    ("Капучино 350 мл          290 ₽", 44, black, false),
    ("Круассан миндальный      240 ₽", 44, black, false),
    ("Итого: 530 ₽", 60, black, true),
    ("Оплачено картой *4471", 40, gray, false),
    ("06.09.2026 09:41   Чек № 001842", 36, gray, false),
])
render("03_sms_code", bg: light, blocks: [
    ("Сбербанк", 48, black, true),
    ("Код для подтверждения: 482913", 52, black, false),
    ("Никому не сообщайте код. Перевод 15 000 ₽ на карту *2210", 40, gray, false),
    ("сегодня, 14:02", 36, gray, false),
])
render("04_ticket", bg: light, blocks: [
    ("Аэрофлот · Посадочный талон", 48, black, true),
    ("SU 1234   MOW → AER", 72, black, true),
    ("Вылет 21 сентября 2026, 08:15", 48, black, false),
    ("Пассажир: SHANYGIN DMITRII", 44, black, false),
    ("Место 14A · Gate 32 · Терминал B", 44, black, false),
    ("Бронь: PNR X7K2LM", 44, gray, false),
])
render("05_wifi", bg: light, blocks: [
    ("Гостевой Wi-Fi", 56, black, true),
    ("Сеть: Botanika_Guest", 48, black, false),
    ("Пароль: coffee2026", 48, black, false),
    ("Часы работы: 08:00 – 22:00", 40, gray, false),
])
render("06_chat_place", bg: light, blocks: [
    ("Аня                                12:31", 40, gray, false),
    ("Смотри, нашла классное место, пошли в пятницу?", 44, black, false),
    ("Ресторан «Сыроварня», Кремлёвская наб., 1", 44, black, false),
    ("Я                                  12:33", 40, gray, false),
    ("Давай! Бронь на 19:30, телефон +7 (831) 423-11-90", 44, black, false),
    ("Аня                                12:34", 40, gray, false),
    ("Отлично, до пятницы 🙌", 44, black, false),
])
render("07_recipe", bg: light, blocks: [
    ("Шакшука за 20 минут", 56, black, true),
    ("Ингредиенты: 4 яйца, 400 г томатов, 1 луковица, перец, зира, щепотка соли", 42, black, false),
    ("Нарезать лук, обжарить 5 минут, добавить томаты, тушить 10 минут", 42, black, false),
    ("Разбить яйца, накрыть, готовить 5 минут", 42, black, false),
    ("2 порции · 320 ккал", 40, gray, false),
])
