import Foundation
import Vision
import UIKit

/// Распознавание текста на устройстве. Возвращаем строки сверху вниз —
/// порядок важен: заголовок чека или название фильма обычно первые.
enum OCR {
    /// Vision занимает поток целиком, поэтому уводим работу с главного:
    /// иначе список дёргается на каждом кадре.
    static func recognize(_ image: UIImage) async -> [String] {
        guard let cg = image.cgImage else { return [] }
        return await Task.detached(priority: .utility) { recognizeSync(cg) }.value
    }

    /// perform() возвращает управление, когда запрос уже отработал,
    /// так что результат читаем прямо из request.results — без семафоров.
    private static func recognizeSync(_ cg: CGImage) -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ru-RU", "en-US"]
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
        do { try handler.perform([request]) } catch { return [] }
        let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
        // Сортируем по вертикали: Vision отдаёт в произвольном порядке.
        return observations
            .sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            .compactMap { $0.topCandidates(1).first?.string }
    }
}
