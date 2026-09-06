import Foundation
import Photos
import UIKit

/// Доступ к галерее. Только скриншоты — PHAssetMediaSubtype это умеет
/// без перебора всей библиотеки.
final class PhotoLibrary: @unchecked Sendable {
    static let shared = PhotoLibrary()
    private let manager = PHImageManager.default()

    var status: PHAuthorizationStatus { PHPhotoLibrary.authorizationStatus(for: .readWrite) }

    func requestAccess() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    /// Сколько в галерее всего картинок и сколько из них помечены как скриншоты.
    /// Пересланный или скачанный скриншот метку теряет, поэтому числа расходятся.
    func counts() -> (all: Int, screenshots: Int) {
        let all = PHAsset.fetchAssets(with: .image, options: nil).count
        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "(mediaSubtype & %d) != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        return (all, PHAsset.fetchAssets(with: .image, options: opts).count)
    }

    /// Все скриншоты, новые первыми.
    func fetchScreenshots() -> [PHAsset] { fetch(screenshots: true) }

    /// Всё, что не помечено как снимок экрана: обычные фотографии.
    /// Их разбирает отдельный раздел и только на повторы.
    func photosOnly() -> [PHAsset] { fetch(screenshots: false) }

    /// В симуляторе системная метка «снимок экрана» не проставляется ни одному
    /// кадру, поэтому там разделяем по пропорциям: телефонный скриншот заметно
    /// вытянут. На устройстве работает штатный признак.
    private func fetch(screenshots: Bool) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        #if !targetEnvironment(simulator)
        options.predicate = NSPredicate(format: "(mediaSubtype & %d) \(screenshots ? "!=" : "==") 0",
                                        PHAssetMediaSubtype.photoScreenshot.rawValue)
        #endif
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            #if targetEnvironment(simulator)
            guard Self.looksLikeScreenshot(asset) == screenshots else { return }
            #endif
            assets.append(asset)
        }
        return assets
    }

    #if targetEnvironment(simulator)
    /// Признак скриншота для симулятора: вытянутый кадр телефонных пропорций.
    private static func looksLikeScreenshot(_ a: PHAsset) -> Bool {
        guard a.pixelWidth > 0, a.pixelHeight > 0 else { return false }
        let ratio = Double(a.pixelHeight) / Double(a.pixelWidth)
        return ratio > 1.7 && ratio < 2.4
    }
    #endif

    func asset(id: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }

    /// Картинка для OCR: ограничиваем сторону, чтобы Vision не жевал 12-мегапиксельные
    /// скриншоты — текст с экрана телефона читается и на 1500 px.
    func image(for asset: PHAsset, maxSide: CGFloat = 1600) async -> UIImage? {
        await withCheckedContinuation { cont in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true   // iCloud-оптимизированные фото
            options.isSynchronous = false
            let scale = min(1, maxSide / CGFloat(max(asset.pixelWidth, asset.pixelHeight)))
            let size = CGSize(width: CGFloat(asset.pixelWidth) * scale, height: CGFloat(asset.pixelHeight) * scale)
            var resumed = false
            manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: options) { image, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !degraded, !resumed else { return }
                resumed = true
                cont.resume(returning: image)
            }
        }
    }

    func thumbnail(for asset: PHAsset, side: CGFloat = 300) async -> UIImage? {
        await withCheckedContinuation { cont in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            var resumed = false
            manager.requestImage(for: asset, targetSize: CGSize(width: side, height: side), contentMode: .aspectFill, options: options) { image, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if resumed { return }
                if !degraded || image != nil { resumed = !degraded; if !degraded { cont.resume(returning: image) } }
            }
        }
    }

    /// Сколько занимает файл на диске. PHAssetResource знает точный размер,
    /// иначе оцениваем по пикселям (скриншот PNG/HEIC — примерно 0.4 байта на пиксель).
    func fileSize(of asset: PHAsset) -> Int64 {
        for r in PHAssetResource.assetResources(for: asset) {
            if let size = r.value(forKey: "fileSize") as? CLong { return Int64(size) }
        }
        return Int64(Double(asset.pixelWidth * asset.pixelHeight) * 0.4)
    }

    /// Удаление пачкой: один системный запрос подтверждения на всю выборку.
    /// Файлы уходят в «Недавно удалённые» и лежат там 30 дней — откат бесплатный.
    /// Возвращает false, если пользователь отменил.
    @discardableResult
    func delete(ids: [String]) async throws -> Bool {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        guard assets.count > 0 else { return true }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets)
            }
            return true
        } catch let e as NSError where e.domain == "PHPhotosErrorDomain" && e.code == 3072 {
            return false   // отменено пользователем
        }
    }
}
