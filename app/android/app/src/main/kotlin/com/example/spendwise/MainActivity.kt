package com.example.spendwise

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

class MainActivity : FlutterActivity() {
    // SupervisorJob so one failed inference call doesn't cancel sibling calls sharing this
    // scope. Cancelled in onDestroy so no coroutine outlives the activity.
    private val nanoScope = CoroutineScope(SupervisorJob())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NANO_FIELD_EXTRACTOR_CHANNEL)
            .setMethodCallHandler(NanoFieldExtractorChannel(nanoScope))
    }

    override fun onDestroy() {
        nanoScope.cancel()
        super.onDestroy()
    }
}
