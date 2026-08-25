import FoundationModels

/// The only file in this app referencing `FoundationModels` types directly.
/// Callers must guard with `#available(iOS 26, *)` before calling in.
/// Nothing here checks that again.
@available(iOS 26.0, *)
enum FoundationModelsSdk {
    // Sent to Dart as a raw int (0 or 1), so this mapping must match
    // whatever reads that int on the Dart side.
    static func checkFeatureStatus() -> Int {
        switch SystemLanguageModel.default.availability {
        case .available:
            return 1
        case .unavailable:
            return 0
        }
    }

    // Fresh session per call - nothing confirms reusing one across calls is
    // safe here either, same conservative default as Android's Nano session.
    static func runInference(_ prompt: String) async throws -> String {
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
