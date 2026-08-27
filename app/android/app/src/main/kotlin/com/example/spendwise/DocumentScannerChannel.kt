package com.example.spendwise

import android.app.Activity
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Channel name for [DocumentScannerChannel], namespaced to this app. */
const val DOCUMENT_SCANNER_CHANNEL = "spendwise/document_scanner"
private const val METHOD_SCAN_DOCUMENT = "scanDocument"
private const val METHOD_IS_AVAILABLE = "isAvailable"

private val scannerOptions =
    GmsDocumentScannerOptions.Builder()
        .setPageLimit(1)
        .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
        .build()

/**
 * Launches ML Kit's own document-scanning UI and returns the scanned page's JPEG bytes, or
 * null if the user backs out without capturing. Returns an error result if Google Play
 * Services is missing or outdated.
 */
class DocumentScannerChannel(
    private val activity: Activity,
) : MethodChannel.MethodCallHandler {
    private var pendingResult: MethodChannel.Result? = null

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            METHOD_SCAN_DOCUMENT -> scanDocument(result)
            METHOD_IS_AVAILABLE -> isAvailable(result)
            else -> result.notImplemented()
        }
    }

    private fun isAvailable(result: MethodChannel.Result) {
        val availability = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(activity)
        result.success(availability == ConnectionResult.SUCCESS)
    }

    private fun scanDocument(result: MethodChannel.Result) {
        val availability = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(activity)
        if (availability != ConnectionResult.SUCCESS) {
            // Fails here instead of letting the scanner launch and crash mid-flow; the Dart
            // side falls back to the plain image picker on this error.
            result.error("scanDocument", "Google Play Services is not available", null)
            return
        }
        pendingResult = result
        GmsDocumentScanning.getClient(scannerOptions)
            .getStartScanIntent(activity)
            .addOnSuccessListener { intentSender ->
                activity.startIntentSenderForResult(intentSender, SCAN_REQUEST_CODE, null, 0, 0, 0)
            }
            .addOnFailureListener { e ->
                pendingResult?.error("scanDocument", e.message, null)
                pendingResult = null
            }
    }

    /** Called from [MainActivity.onActivityResult] when [requestCode] matches [SCAN_REQUEST_CODE]. */
    fun handleActivityResult(
        resultCode: Int,
        data: android.content.Intent?,
    ) {
        val result = pendingResult ?: return
        pendingResult = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(null)
            return
        }
        val scanResult = GmsDocumentScanningResult.fromActivityResultIntent(data)
        val pageUri = scanResult?.pages?.firstOrNull()?.imageUri
        if (pageUri == null) {
            result.success(null)
            return
        }
        val bytes = activity.contentResolver.openInputStream(pageUri)?.use { it.readBytes() }
        result.success(bytes)
    }

    companion object {
        const val SCAN_REQUEST_CODE = 5301
    }
}
