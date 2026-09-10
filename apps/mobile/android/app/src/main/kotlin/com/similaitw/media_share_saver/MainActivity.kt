package com.similaitw.media_share_saver

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "com.similaitw/media_share"
	private var sharedText: String? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		sharedText = extractSharedText(intent)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				if (call.method == "getSharedText") {
					result.success(sharedText)
				} else {
					result.notImplemented()
				}
			}
		sharedText?.let { text ->
			MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
				.invokeMethod("sharedText", text)
		}
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
		extractSharedText(intent)?.let { text ->
			sharedText = text
			flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
				MethodChannel(messenger, channelName).invokeMethod("sharedText", text)
			}
		}
	}

	private fun extractSharedText(intent: Intent?): String? {
		if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") {
			return null
		}
		return intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()?.takeIf { it.isNotEmpty() }
	}
}
