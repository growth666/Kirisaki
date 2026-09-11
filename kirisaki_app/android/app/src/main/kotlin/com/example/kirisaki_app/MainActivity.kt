package com.example.kirisaki_app

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * 基础实现：保存图片到下载目录。
 *
 * - 自定义目录（用户在设置页经 SAF 选择）：写入所选 tree URI；
 * - 默认：API 29+（Android 10+，含 Android 13+ 权限模型）走
 *   MediaStore.Downloads（免权限）；API < 29 直接写公共 Download 目录
 *   （需 WRITE_EXTERNAL_STORAGE，已按 maxSdkVersion=28 声明）。
 *
 * 进阶功能（保存到相册、通知栏提示等）留待后续迭代。
 */
class MainActivity : FlutterActivity() {

    private val downloadChannel = "kirisaki/download"
    private val pickTreeRequestCode = 1001
    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, downloadChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        try {
                            val bytes = call.argument<ByteArray>("bytes")
                            val fileName = call.argument<String>("fileName") ?: "image.jpg"
                            val treeUriString = call.argument<String>("treeUri")
                            if (bytes == null) {
                                result.error("INVALID_ARGUMENT", "bytes 不能为空", null)
                                return@setMethodCallHandler
                            }
                            val path = if (treeUriString != null) {
                                saveToTree(bytes, fileName, treeUriString)
                            } else {
                                saveToDownloads(bytes, fileName)
                            }
                            result.success(path)
                        } catch (e: Exception) {
                            result.error("SAVE_FAILED", e.message, null)
                        }
                    }

                    "pickDownloadDirectory" -> {
                        // SAF 目录选择：用户自选下载位置（基础实现）。
                        pendingPickResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                            )
                        }
                        startActivityForResult(intent, pickTreeRequestCode)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickTreeRequestCode) {
            return
        }
        val result = pendingPickResult ?: return
        pendingPickResult = null
        val uri = data?.data
        if (resultCode == Activity.RESULT_OK && uri != null) {
            try {
                // 持久化访问权限：App 重启后仍可写入所选目录。
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
                result.success(uri.toString())
            } catch (e: Exception) {
                result.error("PICK_FAILED", e.message, null)
            }
        } else {
            result.success(null) // 用户取消
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

    /** 写入用户经 SAF 自选的目录（DocumentsContract，基础实现）。 */
    private fun saveToTree(bytes: ByteArray, fileName: String, treeUriString: String): String {
        val treeUri = Uri.parse(treeUriString)
        val treeDocUri = DocumentsContract.buildDocumentUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri)
        )
        var targetName = fileName
        var fileUri: Uri? = null
        var attempt = 1
        while (fileUri == null && attempt <= 5) {
            try {
                fileUri = DocumentsContract.createDocument(
                    applicationContext.contentResolver,
                    treeDocUri,
                    mimeTypeOf(fileName),
                    targetName
                )
            } catch (e: Exception) {
                // 同名冲突等：加 (n) 后缀重试。
                val dot = fileName.lastIndexOf('.')
                val stem = if (dot > 0) fileName.substring(0, dot) else fileName
                val ext = if (dot > 0) fileName.substring(dot) else ""
                targetName = "$stem($attempt)$ext"
                attempt++
            }
        }
        val uri = fileUri ?: throw IllegalStateException("无法在所选目录创建文件")
        applicationContext.contentResolver.openOutputStream(uri)?.use { out ->
            out.write(bytes)
            out.flush()
        } ?: throw IllegalStateException("无法打开输出流")
        return uri.toString()
    }

    /** 按扩展名推断 MIME 类型（MediaStore/DocumentsContract 需要）。 */
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
