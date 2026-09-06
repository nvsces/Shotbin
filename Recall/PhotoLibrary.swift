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

    /// Все скриншоты, новые первыми. В симуляторе скриншотов нет —
    /// там подхватываем любые фото, чтобы можно было отлаживать.
    func fetchScreenshots(includeAllPhotos: Bool = false) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if !includeAllPhotos {
            options.predicate = NSPredicate(format: "(mediaSubtype & %d) != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        }
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

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
