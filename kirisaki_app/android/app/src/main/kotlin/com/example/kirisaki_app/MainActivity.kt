package com.example.kirisaki_app

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * 基础实现：保存图片到公共下载目录。
 *
 * - API 29+（Android 10+，含 Android 13+ 权限模型）：走 MediaStore.Downloads，
 *   无需存储权限；
 * - API < 29 兜底：直接写公共 Download 目录（需 WRITE_EXTERNAL_STORAGE，
 *   已在 Manifest 中按 maxSdkVersion=28 声明）。
 *
 * 进阶功能（保存到相册、通知栏提示等）留待后续迭代。
 */
class MainActivity : FlutterActivity() {

    private val downloadChannel = "kirisaki/download"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, downloadChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "saveToDownloads") {
                    try {
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName") ?: "image.jpg"
                        if (bytes == null) {
                            result.error("INVALID_ARGUMENT", "bytes 不能为空", null)
                            return@setMethodCallHandler
                        }
                        val path = saveToDownloads(bytes, fileName)
                        result.success(path)
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    /** 保存字节到公共下载目录，返回保存位置描述。 */
    private fun saveToDownloads(bytes: ByteArray, fileName: String): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveViaMediaStore(bytes, fileName)
        } else {
            saveLegacy(bytes, fileName)
        }
    }

    /** Android 10+：MediaStore.Downloads（免权限，13+ 权限模型适配）。 */
    private fun saveViaMediaStore(bytes: ByteArray, fileName: String): String {
        val resolver = applicationContext.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, mimeTypeOf(fileName))
            put(MediaStore.Downloads.RELATIVE_PATH, "Download/Kirisaki")
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("无法创建下载记录")
        resolver.openOutputStream(uri)?.use { stream ->
            stream.write(bytes)
            stream.flush()
        } ?: throw IllegalStateException("无法打开下载输出流")
        return uri.toString()
    }

    /** Android 9 及以下：直接写公共 Download 目录。 */
    private fun saveLegacy(bytes: ByteArray, fileName: String): String {
        val dir = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS
        ) ?: throw IllegalStateException("无法获取公共下载目录")
        val target = File(dir, "Kirisaki")
        if (!target.exists()) {
            target.mkdirs()
        }
        val file = File(target, fileName)
        FileOutputStream(file).use { stream ->
            stream.write(bytes)
            stream.flush()
        }
        return file.absolutePath
    }

    /** 按扩展名推断 MIME 类型（MediaStore 需要）。 */
    private fun mimeTypeOf(fileName: String): String {
        val ext = fileName.substringAfterLast('.', "").lowercase()
        return when (ext) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "webp" -> "image/webp"
            "gif" -> "image/gif"
            else -> "application/octet-stream"
        }
    }
}
