package com.eburon.beatrice.ocr

import android.app.Activity
import android.content.Intent
import android.graphics.BitmapFactory
import android.provider.OpenableColumns
import com.googlecode.tesseract.android.TessBaseAPI
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class OcrChannel(
    private val context: Activity,
    flutterEngine: FlutterEngine,
) {
    companion object {
        const val NAME = "com.eburon.beatrice/local_ocr_v1"
        const val PICK_ENGLISH = 8911
        const val PICK_IMAGE = 8912
    }

    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAME)
    private val dataRoot = File(context.filesDir, "tesseract")
    private val tessdata = File(dataRoot, "tessdata")
    private var pendingEnglish: MethodChannel.Result? = null
    private var pendingImage: MethodChannel.Result? = null

    fun register() {
        channel.setMethodCallHandler(::handle)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(
                mapOf(
                    "englishReady" to File(tessdata, "eng.traineddata").exists(),
                    "dataPath" to dataRoot.absolutePath,
                ),
            )
            "selectEnglishData" -> selectEnglishData(result)
            "selectImageDocument" -> selectImageDocument(result)
            "removeEnglish" -> {
                File(tessdata, "eng.traineddata").delete()
                result.success(true)
            }
            "recognizeEnglish" -> recognize(call, result)
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_ENGLISH && requestCode != PICK_IMAGE) return false
        val pending = if (requestCode == PICK_ENGLISH) pendingEnglish else pendingImage
        if (requestCode == PICK_ENGLISH) pendingEnglish = null else pendingImage = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            if (requestCode == PICK_ENGLISH) pending?.success(false) else pending?.success(null)
            return true
        }
        val uri = data.data!!
        try {
            val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: throw IllegalArgumentException("The selected file could not be read.")
            if (requestCode == PICK_ENGLISH) {
                installEnglish(bytes, displayName(uri), pending!!)
            } else {
                pending?.success(mapOf("bytes" to bytes, "name" to displayName(uri)))
            }
        } catch (error: Exception) {
            pending?.error("FILE_READ_FAILED", error.message, null)
        }
        return true
    }

    private fun selectEnglishData(result: MethodChannel.Result) {
        if (pendingEnglish != null) {
            result.error("PICKER_BUSY", "A file picker is already open.", null)
            return
        }
        pendingEnglish = result
        context.startActivityForResult(
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/octet-stream"
            },
            PICK_ENGLISH,
        )
    }

    private fun selectImageDocument(result: MethodChannel.Result) {
        if (pendingImage != null) {
            result.error("PICKER_BUSY", "A file picker is already open.", null)
            return
        }
        pendingImage = result
        context.startActivityForResult(
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "image/*"
            },
            PICK_IMAGE,
        )
    }

    private fun displayName(uri: android.net.Uri): String {
        context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) return cursor.getString(index)
        }
        return uri.lastPathSegment ?: "document"
    }

    private fun installEnglish(
        bytes: ByteArray?,
        name: String,
        result: MethodChannel.Result,
    ) {
        if (name != "eng.traineddata") {
            result.error(
                "INVALID_TESSDATA",
                "Choose the official file named eng.traineddata.",
                null,
            )
            return
        }
        if (bytes == null || bytes.size < 1_000_000) {
            result.error(
                "INVALID_TESSDATA",
                "Select the official eng.traineddata file (Tesseract 4 or newer).",
                null,
            )
            return
        }
        try {
            tessdata.mkdirs()
            val target = File(tessdata, "eng.traineddata")
            target.writeBytes(bytes)
            val tess = TessBaseAPI()
            val valid = tess.init(dataRoot.absolutePath, "eng")
            tess.recycle()
            if (!valid) {
                target.delete()
                result.error(
                    "INVALID_TESSDATA",
                    "Tesseract could not initialize the selected English data file.",
                    null,
                )
                return
            }
            result.success(true)
        } catch (error: Exception) {
            result.error("OCR_SETUP_FAILED", error.message, null)
        }
    }

    private fun recognize(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("image")
        if (bytes == null) {
            result.error("IMAGE_REQUIRED", "Choose an image first.", null)
            return
        }
        if (!File(tessdata, "eng.traineddata").exists()) {
            result.error(
                "OCR_DATA_MISSING",
                "Import eng.traineddata before using local OCR.",
                null,
            )
            return
        }
        Thread {
            val tess = TessBaseAPI()
            try {
                if (!tess.init(dataRoot.absolutePath, "eng")) {
                    throw IllegalStateException("English language data could not be loaded.")
                }
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    ?: throw IllegalArgumentException("The selected image cannot be decoded.")
                tess.setImage(bitmap)
                val text = tess.utF8Text?.trim().orEmpty()
                val confidence = tess.meanConfidence()
                bitmap.recycle()
                context.mainExecutor.execute {
                    result.success(
                        mapOf(
                            "text" to text,
                            "confidence" to confidence,
                            "language" to "eng",
                            "engine" to "Tesseract 5.5.1",
                        ),
                    )
                }
            } catch (error: Exception) {
                context.mainExecutor.execute {
                    result.error("OCR_FAILED", error.message, null)
                }
            } finally {
                tess.recycle()
            }
        }.start()
    }
}
