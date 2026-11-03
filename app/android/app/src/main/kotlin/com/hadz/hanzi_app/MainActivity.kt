package com.hadz.hanzi_app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
import android.os.Bundle
import android.provider.MediaStore
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val speechChannelName = "com.hadz.hanzi_app/speech"
    private val ocrChannelName = "com.hadz.hanzi_app/ocr"
    private var recognizer: SpeechRecognizer? = null
    private var pendingSpeechResult: MethodChannel.Result? = null
    private var pendingOcrResult: MethodChannel.Result? = null

    companion object {
        private const val REQ_AUDIO = 1001
        private const val REQ_CAMERA = 1002
        private const val REQ_GALLERY = 1003
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, speechChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> {
                        result.success(SpeechRecognizer.isRecognitionAvailable(this))
                    }
                    "listen" -> {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
                            != PackageManager.PERMISSION_GRANTED
                        ) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.RECORD_AUDIO),
                                REQ_AUDIO
                            )
                            result.error("PERMISSION", "Vui lòng cấp quyền Micro rồi thử lại", null)
                            return@setMethodCallHandler
                        }
                        startListening(result)
                    }
                    "stop" -> {
                        recognizer?.stopListening()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ocrChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanCamera" -> {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
                            != PackageManager.PERMISSION_GRANTED
                        ) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.CAMERA),
                                REQ_CAMERA
                            )
                            result.error("PERMISSION", "Vui lòng cấp quyền Camera rồi thử lại", null)
                            return@setMethodCallHandler
                        }
                        pendingOcrResult = result
                        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
                        startActivityForResult(intent, REQ_CAMERA)
                    }
                    "scanGallery" -> {
                        pendingOcrResult = result
                        val intent = Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
                        startActivityForResult(intent, REQ_GALLERY)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val res = pendingOcrResult ?: return
        if (resultCode != Activity.RESULT_OK || data == null) {
            pendingOcrResult = null
            res.error("CANCELLED", "Đã huỷ chọn ảnh", null)
            return
        }

        try {
            if (requestCode == REQ_CAMERA) {
                val bmp = data.extras?.get("data") as? Bitmap
                if (bmp == null) {
                    pendingOcrResult = null
                    res.error("NO_IMAGE", "Không lấy được ảnh từ Camera", null)
                    return
                }
                runMlKitOcr(InputImage.fromBitmap(bmp, 0), bmpToBytes(bmp), res)
            } else if (requestCode == REQ_GALLERY) {
                val uri: Uri? = data.data
                if (uri == null) {
                    pendingOcrResult = null
                    res.error("NO_IMAGE", "Không lấy được ảnh", null)
                    return
                }
                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                runMlKitOcr(InputImage.fromFilePath(this, uri), bytes, res)
            }
        } catch (e: Exception) {
            pendingOcrResult = null
            res.error("OCR_ERROR", e.localizedMessage, null)
        }
    }

    private fun bmpToBytes(bmp: Bitmap): ByteArray {
        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.JPEG, 85, out)
        return out.toByteArray()
    }

    private fun runMlKitOcr(image: InputImage, rawBytes: ByteArray?, res: MethodChannel.Result) {
        val client = TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
        client.process(image)
            .addOnSuccessListener { visionText ->
                pendingOcrResult = null
                res.success(
                    mapOf(
                        "text" to visionText.text,
                        "image" to rawBytes
                    )
                )
            }
            .addOnFailureListener { e ->
                pendingOcrResult = null
                res.error("OCR_FAILED", e.localizedMessage, null)
            }
    }

    private fun startListening(result: MethodChannel.Result) {
        pendingSpeechResult?.error("CANCELLED", "New session started", null)
        pendingSpeechResult = result
        recognizer?.destroy()
        recognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
            setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onPartialResults(partialResults: Bundle?) {}
                override fun onEvent(eventType: Int, params: Bundle?) {}

                override fun onError(error: Int) {
                    val r = pendingSpeechResult
                    pendingSpeechResult = null
                    r?.error("STT_ERROR_$error", "Không nhận diện được giọng nói (mã $error)", null)
                }

                override fun onResults(results: Bundle?) {
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val text = matches?.firstOrNull() ?: ""
                    val r = pendingSpeechResult
                    pendingSpeechResult = null
                    r?.success(text)
                }
            })
        }
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        }
        recognizer?.startListening(intent)
    }

    override fun onDestroy() {
        recognizer?.destroy()
        super.onDestroy()
    }
}
