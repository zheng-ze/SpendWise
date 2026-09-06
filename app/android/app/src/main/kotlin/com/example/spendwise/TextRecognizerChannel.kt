package com.example.spendwise

import android.os.Handler
import android.os.Looper
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Channel name for [TextRecognizerChannel], namespaced to this app. */
const val TEXT_RECOGNIZER_CHANNEL = "spendwise/android_text_recognizer"
private const val METHOD_RECOGNIZE_TEXT = "recognizeText"

/**
 * Recognizes text in an image using ML Kit's on-device text recognizer and
 * returns one map per recognized line with the line text and pixel-space,
 * top-left-origin bounds.
 *
 * Processing takes one to two seconds, so it runs on a background executor and
 * replies exactly once when it finishes, never blocking the platform channel
 * thread.
 */
class TextRecognizerChannel : MethodChannel.MethodCallHandler {
    private val recognizer: TextRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    private val executor = Executors.newSingleThreadExecutor()

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            METHOD_RECOGNIZE_TEXT -> recognizeText(call, result)
            else -> result.notImplemented()
        }
    }

    private fun recognizeText(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val bytes = call.arguments as? ByteArray ?: run {
            result.error(
                METHOD_RECOGNIZE_TEXT,
                "Expected image bytes as the sole argument",
                null,
            )
            return
        }

        executor.execute {
            val bitmap = decodeBitmap(bytes)
            if (bitmap == null) {
                replyMain(result) { error(METHOD_RECOGNIZE_TEXT, "Could not decode image bytes", null) }
                return@execute
            }

            val image = InputImage.fromBitmap(bitmap, 0)
            recognizer.process(image)
                .addOnSuccessListener { text -> replyMain(result) { success(buildLines(text)) } }
                .addOnFailureListener { e -> replyMain(result) { error(METHOD_RECOGNIZE_TEXT, e.message, null) } }
        }
    }

    /** Runs [action] on the main thread, where MethodChannel results must run. [result] is passed as the action's receiver. */
    private fun replyMain(result: MethodChannel.Result, action: MethodChannel.Result.() -> Unit) {
        Handler(Looper.getMainLooper()).post { action(result) }
    }

    private fun decodeBitmap(bytes: ByteArray): Bitmap? {
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    }

    /** One map per recognized line across all blocks, in ML Kit's output order. */
    private fun buildLines(text: Text): List<Map<Any?, Any?>> {
        return text.textBlocks.flatMap { block ->
            block.lines.mapNotNull { line ->
                val bounds = line.boundingBox ?: return@mapNotNull null
                val map = HashMap<Any?, Any?>()
                map["text"] = line.text
                // ML Kit confidence may be null for a line, so only put the key
                // when one is present. The Dart side treats a missing key as null.
                line.confidence?.let { map["confidence"] = it.toDouble() }
                map["left"] = bounds.left.toDouble()
                map["top"] = bounds.top.toDouble()
                map["right"] = bounds.right.toDouble()
                map["bottom"] = bounds.bottom.toDouble()
                // ML Kit reports "und" when it cannot determine a language; treat
                // that the same as no language rather than passing it through.
                line.recognizedLanguage.takeIf { it.isNotEmpty() && it != "und" }?.let {
                    map["language"] = it
                }
                map
            }
        }
    }

    /** Releases the recognizer and stops the background executor. Called once, from [MainActivity.onDestroy]. */
    fun close() {
        recognizer.close()
        executor.shutdown()
    }
}
