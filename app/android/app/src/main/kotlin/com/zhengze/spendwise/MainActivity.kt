package com.zhengze.spendwise

import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val TABLET_MIN_SMALLEST_WIDTH_DP = 600

class MainActivity : FlutterActivity() {
    private val documentScannerChannel = DocumentScannerChannel(this)
    private val textRecognizerChannel = TextRecognizerChannel()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyOrientationPolicy()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        applyOrientationPolicy()
    }

    private fun applyOrientationPolicy() {
        requestedOrientation =
            if (resources.configuration.smallestScreenWidthDp < TABLET_MIN_SMALLEST_WIDTH_DP) {
                ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            } else {
                ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOCUMENT_SCANNER_CHANNEL)
            .setMethodCallHandler(documentScannerChannel)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TEXT_RECOGNIZER_CHANNEL)
            .setMethodCallHandler(textRecognizerChannel)
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        if (requestCode == DocumentScannerChannel.SCAN_REQUEST_CODE) {
            documentScannerChannel.handleActivityResult(resultCode, data)
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        textRecognizerChannel.close()
        super.onDestroy()
    }
}