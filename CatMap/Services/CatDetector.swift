import Vision
import UIKit

enum CatDetector {
    static func containsCat(in image: UIImage) async -> Bool {
        guard let cgImage = image.cgImage else { return true }

        return await withCheckedContinuation { continuation in
            var didResume = false
            func resumeOnce(_ value: Bool) {
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: value)
            }

            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeAnimalsRequest { req, error in
                    if let error { print("[CatDetector] error: \(error)"); resumeOnce(false); return }
                    let observations = req.results as? [VNRecognizedObjectObservation] ?? []
                    let found = observations.contains { obs in
                        obs.labels.contains { $0.identifier.lowercased() == "cat" && $0.confidence > 0.3 }
                    }
                    resumeOnce(found)
                }
                // Neural Engine은 시뮬레이터 미지원 → CPU 전용 모드로 실행
                request.usesCPUOnly = true

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    print("[CatDetector] perform error: \(error)")
                    resumeOnce(false)
                }
            }
        }
    }
}
