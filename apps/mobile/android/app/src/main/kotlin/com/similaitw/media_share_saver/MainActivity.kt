package com.similaitw.media_share_saver

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
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
				when (call.method) {
					"getSharedText" -> result.success(sharedText)
					"saveMediaStore" -> saveMediaStore(call, result)
					else -> result.notImplemented()
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

	private fun saveMediaStore(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
		val path = call.argument<String>("path")
		val name = call.argument<String>("name")
		val mimeType = call.argument<String>("mimeType")
		if (path == null || name == null || mimeType == null) {
			result.error("invalid_arguments", "Missing media save arguments.", null)
			return
		}

		val values = ContentValues().apply {
			put(MediaStore.MediaColumns.DISPLAY_NAME, name)
			put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Media Share Saver")
				put(MediaStore.MediaColumns.IS_PENDING, 1)
			}
		}
		val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			MediaStore.Downloads.EXTERNAL_CONTENT_URI
		} else {
			MediaStore.Files.getContentUri("external")
		}
		val uri = contentResolver.insert(collection, values)
		if (uri == null) {
			result.error("media_store_insert_failed", "Could not create a MediaStore item.", null)
			return
		}
		try {
			contentResolver.openOutputStream(uri)?.use { output ->
				File(path).inputStream().use { input -> input.copyTo(output) }
			} ?: throw IllegalStateException("Could not open MediaStore output.")
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				contentResolver.update(uri, ContentValues().apply {
					put(MediaStore.MediaColumns.IS_PENDING, 0)
				}, null, null)
			}
			result.success(uri.toString())
		} catch (error: Exception) {
			contentResolver.delete(uri, null, null)
			result.error("media_store_write_failed", error.message, null)
		}
	}
}
