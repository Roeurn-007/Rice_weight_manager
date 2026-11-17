package com.example.rice_weight_manager

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.rice_weight_manager/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "shareApp") {
                try {
                    val appPath = applicationContext.applicationInfo.sourceDir
                    val apkFile = File(appPath)
                    val sendIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "application/vnd.android.package-archive"
                        val uri = FileProvider.getUriForFile(
                            applicationContext,
                            "${applicationContext.packageName}.fileprovider",
                            apkFile
                        )
                        putExtra(Intent.EXTRA_STREAM, uri)
                        putExtra(Intent.EXTRA_SUBJECT, "Rice Weight Manager APK")
                        putExtra(Intent.EXTRA_TEXT, "Rice Weight Manager App - Offline Rice Weight Recording. Developed by Roeurn Rors.")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(Intent.createChooser(sendIntent, "Share Rice Weight Manager APK via"))
                    result.success(true)
                } catch (e: Exception) {
                    try {
                        val textIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_SUBJECT, "Rice Weight Manager")
                            putExtra(Intent.EXTRA_TEXT, "Rice Weight Manager App - 100% Offline Rice Harvest & Sack Weighing. Developed by Roeurn Rors.")
                        }
                        startActivity(Intent.createChooser(textIntent, "Share App"))
                        result.success(true)
                    } catch (ex: Exception) {
                        result.error("SHARE_ERROR", ex.message, null)
                    }
                }
            } else if (call.method == "shareText") {
                try {
                    val text = call.argument<String>("text") ?: ""
                    val subject = call.argument<String>("subject") ?: "Rice Harvest Receipt"
                    val sendIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_SUBJECT, subject)
                        putExtra(Intent.EXTRA_TEXT, text)
                    }
                    startActivity(Intent.createChooser(sendIntent, "Share Receipt via"))
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SHARE_ERROR", e.message, null)
                }
            } else if (call.method == "openUrl") {
                try {
                    val url = call.argument<String>("url") ?: ""
                    val browserIntent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url)).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(browserIntent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("OPEN_URL_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
