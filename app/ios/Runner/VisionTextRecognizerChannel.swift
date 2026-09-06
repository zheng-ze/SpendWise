import Flutter
import Vision
import UIKit

/// Channel name for `VisionTextRecognizerChannel`, namespaced to this app.
let visionTextRecognizerChannel = "spendwise/vision_text_recognizer"
private let methodRecognizeText = "recognizeText"

/// Recognizes text in a decoded image using Apple's Vision framework and
/// returns each line's bounds in pixel space with a top-left origin.
final class VisionTextRecognizerChannel: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: visionTextRecognizerChannel,
            binaryMessenger: registrar.messenger()
        )
        let instance = VisionTextRecognizerChannel()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case methodRecognizeText:
            guard let bytes = call.arguments as? FlutterStandardTypedData else {
                result(FlutterError(code: "recognizeText", message: "Expected image bytes as the sole argument", details: nil))
                return
            }
            recognizeText(bytes: bytes.data, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func recognizeText(bytes: Data, result: @escaping FlutterResult) {
        // Off the main thread: decoding and .accurate mode (~2s) must not block the platform channel.
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgImage = UIImage(data: bytes)?.cgImage else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "recognizeText", message: "Could not decode image bytes", details: nil))
                }
                return
            }

            let width = Double(cgImage.width)
            let height = Double(cgImage.height)

            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "recognizeText", message: "\(error)", details: nil))
                    }
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { observation -> [String: Any]? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    let box = observation.boundingBox
                    // box is normalized 0-1 with a bottom-left origin; flip Y and scale by the
                    // image size to get pixel-space, top-left bounds.
                    return [
                        "text": candidate.string,
                        "confidence": Double(candidate.confidence),
                        "left": box.minX * width,
                        "top": (1 - box.maxY) * height,
                        "right": box.maxX * width,
                        "bottom": (1 - box.minY) * height,
                    ]
                }

                DispatchQueue.main.async {
                    result(lines)
                }
            }
            request.recognitionLevel = .accurate

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "recognizeText", message: "\(error)", details: nil))
                }
            }
        }
    }
}
