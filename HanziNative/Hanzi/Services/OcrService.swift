import UIKit
import Vision

final class OcrService {
    static let shared = OcrService()
    
    private init() {}
    
    func recognizeChinese(image: UIImage, completion: @escaping (String) -> Void) {
        guard let cgImage = image.cgImage else {
            completion("")
            return
        }
        
        let request = VNRecognizeTextRequest { req, _ in
            guard let observations = req.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async { completion("") }
                return
            }
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            let text = lines.joined(separator: "\n")
            DispatchQueue.main.async {
                completion(text)
            }
        }
        
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { completion("") }
            }
        }
    }
}
