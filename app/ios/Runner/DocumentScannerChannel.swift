import Flutter
import VisionKit

/// Channel name for `DocumentScannerChannel`, namespaced to this app.
let documentScannerChannel = "spendwise/document_scanner"
private let methodScanDocument = "scanDocument"

/// Presents Apple's own document-scanning UI and returns the first scanned
/// page as JPEG bytes, or nil if the user backs out without capturing.
final class DocumentScannerChannel: NSObject, FlutterPlugin, VNDocumentCameraViewControllerDelegate {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: documentScannerChannel,
            binaryMessenger: registrar.messenger()
        )
        let instance = DocumentScannerChannel()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private var pendingResult: FlutterResult?

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case methodScanDocument:
            scanDocument(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func scanDocument(result: @escaping FlutterResult) {
        guard VNDocumentCameraViewController.isSupported else {
            result(FlutterError(code: "scanDocument", message: "Document scanning is not supported on this device", details: nil))
            return
        }
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController
        else {
            result(FlutterError(code: "scanDocument", message: "No root view controller to present from", details: nil))
            return
        }
        pendingResult = result
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = self
        rootViewController.present(scannerViewController, animated: true)
    }

    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFinishWith scan: VNDocumentCameraScan
    ) {
        controller.dismiss(animated: true)
        guard scan.pageCount > 0, let jpegData = scan.imageOfPage(at: 0).jpegData(compressionQuality: 0.9) else {
            pendingResult?(FlutterError(code: "scanDocument", message: "Scan finished with no usable page", details: nil))
            pendingResult = nil
            return
        }
        pendingResult?(FlutterStandardTypedData(bytes: jpegData))
        pendingResult = nil
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
        pendingResult?(nil)
        pendingResult = nil
    }

    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFailWithError error: Error
    ) {
        controller.dismiss(animated: true)
        pendingResult?(FlutterError(code: "scanDocument", message: "\(error)", details: nil))
        pendingResult = nil
    }
}
