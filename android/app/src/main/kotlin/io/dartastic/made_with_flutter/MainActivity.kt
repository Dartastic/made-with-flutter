package io.dartastic.made_with_flutter

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val inspector = FlutterAppInspector(applicationContext)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.dartastic.made_with_flutter/scanner",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "listFlutterApps" -> runOffMain(result) {
                    inspector.listFlutterApps()
                }
                "inspectApp" -> {
                    val appId = call.argument<String>("appId")
                    if (appId == null) {
                        result.error("bad_args", "appId is required", null)
                    } else {
                        runOffMain(result) { inspector.inspectApp(appId) }
                    }
                }
                "getAppIcon" -> {
                    val appId = call.argument<String>("appId")
                    if (appId == null) {
                        result.error("bad_args", "appId is required", null)
                    } else {
                        runOffMain(result) { inspector.appIcon(appId) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** APK scanning does heavy I/O; keep it off the platform thread. */
    private fun runOffMain(result: MethodChannel.Result, body: () -> Any?) {
        executor.execute {
            try {
                val value = body()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("scan_failed", e.toString(), null)
                }
            }
        }
    }

    override fun onDestroy() {
        executor.shutdownNow()
        super.onDestroy()
    }
}
