package pers.cyh128.hikari_novel

import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val intentChannelName = "hikari/system_intents"
    private val debugFileChannelName = "hikari/debug_files"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, intentChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openTtsSettings" -> {
                        try {
                            val candidates = arrayListOf(
                                Intent("android.speech.tts.engine.TTS_SETTINGS"),
                                Intent("com.android.settings.TTS_SETTINGS"),
                                Intent(android.provider.Settings.ACTION_SETTINGS)
                            )
                            var launched = false
                            var lastErr: Exception? = null
                            for (it in candidates) {
                                try {
                                    it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(it)
                                    launched = true
                                    break
                                } catch (e: Exception) {
                                    lastErr = e
                                }
                            }
                            if (launched) {
                                result.success(true)
                            } else {
                                result.error(
                                    "INTENT_FAILED",
                                    lastErr?.message ?: "no activity found",
                                    null
                                )
                            }
                        } catch (e: Exception) {
                            result.error("INTENT_FAILED", e.message, null)
                        }
                    }

                    "openApp" -> {
                        val pkg = call.argument<String>("package")
                        if (pkg.isNullOrBlank()) {
                            result.error("ARG_ERROR", "package is null/blank", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val pm: PackageManager = applicationContext.packageManager
                            val launchIntent = pm.getLaunchIntentForPackage(pkg)
                            if (launchIntent != null) {
                                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(launchIntent)
                                result.success(true)
                            } else {
                                result.error("NOT_FOUND", "app not found: $pkg", null)
                            }
                        } catch (e: Exception) {
                            result.error("INTENT_FAILED", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, debugFileChannelName)
            .setMethodCallHandler { call, result ->
                val name = call.argument<String>("name")
                if (name.isNullOrBlank()) {
                    result.error("ARG_ERROR", "name is null/blank", null)
                    return@setMethodCallHandler
                }

                try {
                    when (call.method) {
                        "appendDownloadTextFile" -> {
                            val text = call.argument<String>("text") ?: ""
                            appendDownloadTextFile(name, text)
                            result.success(true)
                        }

                        "writeDownloadTextFile" -> {
                            val text = call.argument<String>("text") ?: ""
                            writeDownloadTextFile(name, text)
                            result.success(true)
                        }

                        "readDownloadTextFile" -> result.success(readDownloadTextFile(name))

                        "downloadFilePath" -> result.success(downloadFilePath(name))

                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("DEBUG_FILE_ERROR", e.message, null)
                }
            }
    }

    private fun appendDownloadTextFile(name: String, text: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val uri = findOrCreateDownloadFile(name)
            contentResolver.openOutputStream(uri, "wa")?.use { it.write(text.toByteArray(Charsets.UTF_8)) }
                ?: throw IllegalStateException("openOutputStream returned null")
        } else {
            val file = legacyDownloadFile(name)
            file.parentFile?.mkdirs()
            file.appendText(text, Charsets.UTF_8)
        }
    }

    private fun writeDownloadTextFile(name: String, text: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val uri = findOrCreateDownloadFile(name)
            contentResolver.openOutputStream(uri, "w")?.use { it.write(text.toByteArray(Charsets.UTF_8)) }
                ?: throw IllegalStateException("openOutputStream returned null")
        } else {
            val file = legacyDownloadFile(name)
            file.parentFile?.mkdirs()
            file.writeText(text, Charsets.UTF_8)
        }
    }

    private fun readDownloadTextFile(name: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val uri = findDownloadFile(name) ?: return ""
            return contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""
        }
        val file = legacyDownloadFile(name)
        return if (file.exists()) file.readText(Charsets.UTF_8) else ""
    }

    private fun downloadFilePath(name: String): String = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), name).absolutePath

    private fun legacyDownloadFile(name: String): File = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), name)

    private fun findOrCreateDownloadFile(name: String): Uri {
        return findDownloadFile(name) ?: run {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, "text/plain")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                }
            }
            contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("failed to create Download file")
        }
    }

    private fun findDownloadFile(name: String): Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val projection = arrayOf(MediaStore.MediaColumns._ID)
        val selection = "${MediaStore.MediaColumns.DISPLAY_NAME}=? AND ${MediaStore.MediaColumns.RELATIVE_PATH}=?"
        val selectionArgs = arrayOf(name, "${Environment.DIRECTORY_DOWNLOADS}/")
        contentResolver.query(MediaStore.Downloads.EXTERNAL_CONTENT_URI, projection, selection, selectionArgs, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID))
                return Uri.withAppendedPath(MediaStore.Downloads.EXTERNAL_CONTENT_URI, id.toString())
            }
        }
        return null
    }
}
