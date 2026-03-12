import Foundation
import FirebaseStorage
import UIKit
import MobileCoreServices

final class FirebaseStorageManager {
    static let shared = FirebaseStorageManager()
    private let storage = Storage.storage()
    private init() {}

    // resize image if it's too large, convert as PNG to have transparency
    func uploadPNG(image: UIImage,
                   folder: String = "clothing_images",
                   maxDimension: CGFloat = 2000,
                   completion: @escaping (Result<String, Error>) -> Void) {

        // normalize and resize the image with its aspect ratio
        guard let normalized = Self.normalize(image: image, maxDimension: maxDimension) else {
            completion(.failure(FirebaseStorageError.imageConversionFailed))
            return
        }

        // convert to PNG data
        guard let data = normalized.pngData() else {
            completion(.failure(FirebaseStorageError.imageConversionFailed))
            return
        }

        // write PNG data to a temp file before uploading to firebase
        let fileName = "\(UUID().uuidString).png"
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(fileName)

        do {
            try data.write(to: tempURL, options: .atomic)
        } catch {
            return completion(.failure(error))
        }

        let storageRef = storage.reference().child("\(folder)/\(fileName)")
        let metadata = StorageMetadata()
        metadata.contentType = "image/png"

        // upload using putFile (more stable than putData for large files)
        let task = storageRef.putFile(from: tempURL, metadata: metadata) { _, error in

            // delete temp file after uploading
            try? FileManager.default.removeItem(at: tempURL)

            if let error = error {

                // print the exact Firebase Storage error code
                if let ns = error as NSError?,
                   let code = StorageErrorCode(rawValue: ns.code) {
                    print("Storage error code: \(code) | \(ns.localizedDescription)")
                } else {
                    print("Storage error: \(error.localizedDescription)")
                }
                return completion(.failure(error))
            }

            storageRef.downloadURL { url, err in
                if let err = err {
                    return completion(.failure(err))
                }
                guard let url = url else {
                    return completion(.failure(FirebaseStorageError.unknown))
                }
                completion(.success(url.absoluteString))
            }
        }
        
        task.observe(.progress) { snap in
            let sent = snap.progress?.completedUnitCount ?? 0
            let total = snap.progress?.totalUnitCount ?? 0
            print("Uploading PNG: \(sent)/\(total) bytes")
        }
    }

    // renders the image into a unified drawing context (sRGB), preserves alpha, and fixes orientation
    private static func normalize(image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        let maxSide = max(size.width, size.height)
        let scaleFactor: CGFloat = maxSide > maxDimension ? (maxDimension / maxSide) : 1.0
        let targetSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false    // for transparency
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let img = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return img
    }

    enum FirebaseStorageError: Error, LocalizedError {
        case imageConversionFailed
        case unknown
        var errorDescription: String? {
            switch self {
            case .imageConversionFailed: return "فشل تحويل الصورة إلى PNG."
            case .unknown: return "حدث خطأ غير معروف أثناء الرفع."
            }
        }
    }
}
