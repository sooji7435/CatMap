import Vision
import UIKit

enum CatDetector {
    /// 이미지에 고양이가 있으면 true. Vision 오류 시 true(허용)로 fallback.
    static func containsCat(in image: UIImage) async -> Bool {
        guard let cgImage = image.cgImage else { return true }

        return await withCheckedContinuation { continuation in
            var didResume = false
            func resumeOnce(_ value: Bool) {
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: value)
            }

            let request = VNRecognizeAnimalsRequest { req, error in
                if error != nil { resumeOnce(true); return }
                let found = (req.results as? [VNRecognizedObjectObservation] ?? [])
                    .contains { $0.labels.contains { $0.identifier == "Cat" && $0.confidence > 0.5 } }
                resumeOnce(found)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                // perform이 throw한 경우 completion이 이미 호출됐을 수 있으므로 resumeOnce 사용
                resumeOnce(true)
            }
        }
    }
}
