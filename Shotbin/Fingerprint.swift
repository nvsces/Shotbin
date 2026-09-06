import Foundation
import UIKit
import CoreImage

/// Отпечаток картинки для поиска повторов.
///
/// Скриншоты — это почти белые страницы с текстом, и обычный dHash на сетке 8×8
/// их не различает: у всех получается почти один и тот же код. Поэтому берём
/// сетку 16×16 (256 бит) и сравниваем каждую ячейку со средней яркостью кадра,
/// а не с соседом: так в отпечатке остаётся раскладка текстовых блоков по странице.
struct Fingerprint: Codable, Hashable, Sendable {
    static let side = 16
    /// 256 бит в четырёх словах.
    var words: [UInt64]

    /// nil, если картинку не удалось разобрать.
    static func make(_ image: UIImage) -> Fingerprint? {
        guard let cg = image.cgImage else { return nil }
        let n = side
        var pixels = [UInt8](repeating: 0, count: n * n)
        guard let space = CGColorSpace(name: CGColorSpace.linearGray),
              let ctx = CGContext(data: &pixels, width: n, height: n, bitsPerComponent: 8,
                                  bytesPerRow: n, space: space,
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))

        let mean = pixels.reduce(0) { $0 + Int($1) } / max(1, pixels.count)
        var words = [UInt64](repeating: 0, count: 4)
        for (i, p) in pixels.enumerated() where Int(p) > mean {
            words[i / 64] |= (1 << UInt64(i % 64))
        }
        return Fingerprint(words: words)
    }

    /// Сколько ячеек из 256 различается. 0 — кадры совпадают.
    func distance(to other: Fingerprint) -> Int {
        zip(words, other.words).reduce(0) { $0 + ($1.0 ^ $1.1).nonzeroBitCount }
    }
}
