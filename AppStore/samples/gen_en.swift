import AppKit

func render(_ name: String, bg: NSColor, blocks: [(String, CGFloat, NSColor, Bool)]) {
    let w = 1170.0, h = 2532.0
    let img = NSImage(size: NSSize(width: w, height: h))
    img.lockFocus()
    bg.setFill(); NSRect(x: 0, y: 0, width: w, height: h).fill()
    var y = h - 200
    for (text, size, color, bold) in blocks {
        let font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        let para = NSMutableParagraphStyle(); para.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: para]
        (text as NSString).draw(in: NSRect(x: 80, y: y - size * 3, width: w - 160, height: size * 3), withAttributes: attrs)
        y -= size * 2.2 + 20
    }
    img.unlockFocus()
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(name).png"))
    print("✓ \(name)")
}
let dark = NSColor(white: 0.08, alpha: 1), white = NSColor.white, gray = NSColor(white: 0.55, alpha: 1)
let light = NSColor(white: 0.97, alpha: 1), black = NSColor(white: 0.1, alpha: 1)

render("01_reel_movie", bg: dark, blocks: [
    ("@film_picks", 40, gray, false),
    ("5 films you have to watch this autumn", 52, white, true),
    ("\"Oppenheimer\" (2023)", 64, white, true),
    ("Christopher Nolan. Three hours that fly by. IMDb 8.4", 44, white, false),
    ("a must-watch 🎬", 44, gray, false),
    ("♡ 48 210    ⃝ 1 204    ➦ 9 872", 40, gray, false),
])
render("02_receipt", bg: light, blocks: [
    ("Botanica Coffee", 56, black, true),
    ("12 Market Street", 40, gray, false),
    ("Cappuccino 350 ml          $4.90", 44, black, false),
    ("Almond croissant           $3.60", 44, black, false),
    ("Total: $8.50", 60, black, true),
    ("Paid by card *4471", 40, gray, false),
    ("06.09.2026 09:41   Receipt No. 001842", 36, gray, false),
])
render("03_sms_code", bg: light, blocks: [
    ("Your bank", 48, black, true),
    ("Confirmation code: 482913", 52, black, false),
    ("Never share this code. Transfer $150 to card *2210", 40, gray, false),
    ("today, 14:02", 36, gray, false),
])
render("04_ticket", bg: light, blocks: [
    ("Boarding pass", 48, black, true),
    ("BA 1234   LHR → BCN", 72, black, true),
    ("Departure 21 September 2026, 08:15", 48, black, false),
    ("Passenger: DMITRII SHANYGIN", 44, black, false),
    ("Seat 14A · Gate 32 · Terminal B", 44, black, false),
    ("Booking: PNR X7K2LM", 44, gray, false),
])
render("05_wifi", bg: light, blocks: [
    ("Guest Wi-Fi", 56, black, true),
    ("Network: Botanica_Guest", 48, black, false),
    ("Password: coffee2026", 48, black, false),
    ("Opening hours: 08:00 – 22:00", 40, gray, false),
])
render("06_chat_place", bg: light, blocks: [
    ("Anna                               12:31", 40, gray, false),
    ("Found a great place, shall we go on Friday?", 44, black, false),
    ("The Creamery, 1 Riverside Walk", 44, black, false),
    ("Me                                 12:33", 40, gray, false),
    ("Yes! Booked for 19:30, phone +44 20 7946 0958", 44, black, false),
    ("Anna                               12:34", 40, gray, false),
    ("Great, see you Friday 🙌", 44, black, false),
])
render("07_recipe", bg: light, blocks: [
    ("Shakshuka in 20 minutes", 48, black, true),
    ("Ingredients: 4 eggs, 400 g tomatoes, 1 onion, pepper, cumin, a pinch of salt", 40, black, false),
    ("Chop the onion, fry for 5 minutes, add tomatoes, simmer 10 minutes", 40, black, false),
    ("Crack the eggs in, cover, cook 5 minutes", 40, black, false),
    ("2 servings · 320 kcal", 36, gray, false),
])
