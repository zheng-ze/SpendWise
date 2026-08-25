package com.example.spendwise

import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Channel name for [NanoFieldExtractorChannel], namespaced to this app. */
const val NANO_FIELD_EXTRACTOR_CHANNEL = "spendwise/nano_field_extractor"
private const val METHOD_CHECK_FEATURE_STATUS = "checkFeatureStatus"
private const val METHOD_RUN_INFERENCE = "runInference"

// Sent and read on the Dart side as a raw int, so its 0-3 ordering must stay in step with
// whatever enum the Dart channel wrapper declares to represent this same status.
private const val FEATURE_STATUS_UNAVAILABLE = 0

// ML Kit's GenAI Prompt SDK requires API 26, below this app's own minSdk, so every call
// site guards with Build.VERSION.SDK_INT before reaching NanoPromptSdk.
class NanoFieldExtractorChannel(
    private val scope: CoroutineScope,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            METHOD_CHECK_FEATURE_STATUS -> checkFeatureStatus(result)
            METHOD_RUN_INFERENCE -> runInference(call, result)
            else -> result.notImplemented()
        }
    }

    private fun checkFeatureStatus(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.success(FEATURE_STATUS_UNAVAILABLE)
            return
        }
        scope.launch(Dispatchers.Default) {
            try {
                val status = NanoPromptSdk.checkFeatureStatus()
                withContext(Dispatchers.Main) { result.success(status) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("checkFeatureStatus", e.message, null)
                }
            }
        }
    }

    private fun runInference(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val prompt = call.argument<String>("prompt")
        if (prompt == null) {
            result.error("runInference", "Missing prompt argument", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error("runInference", "Gemini Nano requires Android 8.0 (API 26) or higher", null)
            return
        }
        scope.launch(Dispatchers.Default) {
            try {
                val response = NanoPromptSdk.runInference(prompt)
                withContext(Dispatchers.Main) { result.success(response) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) { result.error("runInference", e.message, null) }
            }
        }
    }
}
