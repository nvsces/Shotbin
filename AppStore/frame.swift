import AppKit

// App Store для 6.9" (iPhone 17 Pro Max и аналоги) ждёт 1320×2868.
// Кадр из симулятора 1206×2622 вписываем в макет с заголовком.
let outW = 1320.0, outH = 2868.0

struct Slide { let file: String, title: String, subtitle: String }

func make(_ slide: Slide, out: String, accent: NSColor) {
    guard let shot = NSImage(contentsOfFile: slide.file) else { print("нет \(slide.file)"); return }
    let img = NSImage(size: NSSize(width: outW, height: outH))
    img.lockFocus()

    // фон — мягкий градиент в цвет приложения
    let grad = NSGradient(colors: [accent.blended(withFraction: 0.82, of: .white)!,
                                   accent.blended(withFraction: 0.93, of: .white)!])!
    grad.draw(in: NSRect(x: 0, y: 0, width: outW, height: outH), angle: -90)

    // заголовок
    let pad = 84.0
    let para = NSMutableParagraphStyle(); para.alignment = .center; para.lineSpacing = 4
    let tAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 76, weight: .bold),
        .foregroundColor: NSColor(white: 0.08, alpha: 1), .paragraphStyle: para]
    (slide.title as NSString).draw(in: NSRect(x: pad, y: outH - 300, width: outW - pad*2, height: 190),
                                   withAttributes: tAttrs)
    let sAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 42, weight: .regular),
        .foregroundColor: NSColor(white: 0.35, alpha: 1), .paragraphStyle: para]
    (slide.subtitle as NSString).draw(in: NSRect(x: pad, y: outH - 386, width: outW - pad*2, height: 80),
                                      withAttributes: sAttrs)

    // сам экран: масштабируем по ширине, скругляем углы, кладём тень
    // Высота под экран: от низа заголовка до нижнего поля.
    let top = outH - 440.0, bottom = 90.0
    let maxH = top - bottom
    let byWidth = (outW - pad * 2) / shot.size.width
    let scale = min(byWidth, maxH / shot.size.height)
    let shotW = shot.size.width * scale, shotH = shot.size.height * scale
    let rect = NSRect(x: (outW - shotW) / 2, y: top - shotH, width: shotW, height: shotH)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 40; shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.set()
    let path = NSBezierPath(roundedRect: rect, xRadius: 56, yRadius: 56)
    NSColor.white.setFill(); path.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    shot.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()

    img.unlockFocus()
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
    print("✓ \(out)")
}

let args = CommandLine.arguments
let dir = args[1], lang = args[2], outDir = args[3]
let accent = NSColor(red: 0.35, green: 0.38, blue: 0.97, alpha: 1)

let ru: [Slide] = [
  Slide(file: "\(dir)/shotbin-ru-1-home.png", title: "Скриншоты сами\nразложены по полкам", subtitle: "Коды, чеки, билеты, адреса, фильмы"),
  Slide(file: "\(dir)/shotbin-ru-2-shelf.png", title: "Всё нужное —\nна своей полке", subtitle: "Не листать галерею в поисках кода"),
  Slide(file: "\(dir)/shotbin-ru-3-detail.png", title: "Код, пароль, дата —\nодним нажатием", subtitle: "Скопировать, позвонить, добавить в календарь"),
  Slide(file: "\(dir)/shotbin-ru-6-search.png", title: "Поиск по тексту\nвнутри картинок", subtitle: "Ищите словом, которое видели на экране"),
]
let en: [Slide] = [
  Slide(file: "\(dir)/shotbin-en-1-home.png", title: "Your screenshots,\nsorted onto shelves", subtitle: "Codes, receipts, tickets, addresses, films"),
  Slide(file: "\(dir)/shotbin-en-2-shelf.png", title: "Everything useful\non its own shelf", subtitle: "No more scrolling to find that one code"),
  Slide(file: "\(dir)/shotbin-en-3-detail.png", title: "Codes and dates,\none tap away", subtitle: "Copy, call, add to your calendar"),
  Slide(file: "\(dir)/shotbin-en-5-cleanup.png", title: "Free up space\nwhen you're done", subtitle: "Delete screenshots, keep what they contained"),
  Slide(file: "\(dir)/shotbin-en-6-search.png", title: "Search the text\ninside your images", subtitle: "Find it by a word you saw on screen"),
]
for (i, s) in (lang == "en" ? en : ru).enumerated() {
    make(s, out: "\(outDir)/\(lang)-\(i+1).png", accent: accent)
}
