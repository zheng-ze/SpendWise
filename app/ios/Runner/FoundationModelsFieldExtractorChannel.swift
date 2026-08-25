import Flutter

/// Channel name for `FoundationModelsFieldExtractorChannel`, namespaced to
/// this app.
let foundationModelsFieldExtractorChannel = "spendwise/foundation_models_field_extractor"
private let methodCheckFeatureStatus = "checkFeatureStatus"
private let methodRunInference = "runInference"
private let featureStatusUnavailable = 0

/// Apple's Foundation Models framework requires iOS 26, above this app's
/// own deployment target, so every call site guards with
/// `#available(iOS 26, *)` before reaching `FoundationModelsSdk`.
final class FoundationModelsFieldExtractorChannel: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: foundationModelsFieldExtractorChannel,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(FoundationModelsFieldExtractorChannel(), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case methodCheckFeatureStatus:
            checkFeatureStatus(result: result)
        case methodRunInference:
            runInference(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func checkFeatureStatus(result: @escaping FlutterResult) {
        guard #available(iOS 26.0, *) else {
            result(featureStatusUnavailable)
            return
        }
        result(FoundationModelsSdk.checkFeatureStatus())
    }

    private func runInference(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any], let prompt = args["prompt"] as? String else {
            result(FlutterError(code: "runInference", message: "Missing prompt argument", details: nil))
            return
        }
        guard #available(iOS 26.0, *) else {
            result(FlutterError(
                code: "runInference",
                message: "Foundation Models requires iOS 26 or higher",
                details: nil
            ))
            return
        }
        Task {
            do {
                let response = try await FoundationModelsSdk.runInference(prompt)
                await MainActor.run { result(response) }
            } catch {
                await MainActor.run {
                    result(FlutterError(code: "runInference", message: "\(error)", details: nil))
                }
            }
        }
    }
}
