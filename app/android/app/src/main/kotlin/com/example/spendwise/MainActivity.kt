package com.example.spendwise

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val documentScannerChannel = DocumentScannerChannel(this)
    private val textRecognizerChannel = TextRecognizerChannel()

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