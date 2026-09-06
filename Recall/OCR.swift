import Foundation
import Vision
import UIKit

/// Распознавание текста на устройстве. Возвращаем строки сверху вниз —
/// порядок важен: заголовок чека или название фильма обычно первые.
enum OCR {
    static func recognize(_ image: UIImage) async -> [String] {
        guard let cg = image.cgImage else { return [] }
        return await withCheckedContinuation { cont in
            let request = VNRecognizeTextRequest { req, _ in
                let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
                // Сортируем по вертикали: Vision отдаёт в произвольном порядке.
                let lines = observations
                    .sorted { $0.boundingBox.midY > $1.boundingBox.midY }
                    .compactMap { $0.topCandidates(1).first?.string }
                cont.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ru-RU", "en-US"]
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
            do { try handler.perform([request]) } catch { cont.resume(returning: []) }
        }
    }
}
