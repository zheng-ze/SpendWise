package com.example.spendwise

import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.generationConfig

/**
 * The only class in this app referencing `com.google.mlkit.genai.prompt` types. Callers must
 * check `Build.VERSION.SDK_INT` before calling in; nothing here checks it again.
 */
object NanoPromptSdk {
    // Mapped onto a 0-3 int the channel sends as-is, so this order must match
    // whatever reads that int on the Dart side.
    suspend fun checkFeatureStatus(): Int {
        val client = Generation.getClient(generationConfig {})
        return try {
            when (client.checkStatus()) {
                FeatureStatus.DOWNLOADABLE -> 1
                FeatureStatus.DOWNLOADING -> 2
                FeatureStatus.AVAILABLE -> 3
                else -> 0
            }
        } finally {
            client.close()
        }
    }

    // Fresh client per call - nothing confirms reusing one across calls is safe.
    suspend fun runInference(prompt: String): String {
        val client = Generation.getClient(generationConfig {})
        return try {
            val candidate =
                client.generateContent(prompt).candidates.firstOrNull()
                    ?: throw IllegalStateException("Gemini Nano returned no candidates")
            candidate.text
        } finally {
            client.close()
        }
    }
}
