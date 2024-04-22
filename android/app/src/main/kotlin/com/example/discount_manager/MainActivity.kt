package com.example.discount_manager

import android.content.Context
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.camera2.params.StreamConfigurationMap
import android.util.Log



import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.graphics.ImageFormat
import android.graphics.YuvImage
import android.graphics.Rect
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream

class MainActivity: FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        checkCameraFormats()
    }

    private fun checkCameraFormats() {
        val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        try {
            val cameraIds = manager.cameraIdList
            for (cameraId in cameraIds) {
                val characteristics = manager.getCameraCharacteristics(cameraId)
                val map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                if (map != null && map.isOutputSupportedFor(ImageFormat.YUV_420_888)) {
                    // 记录支持YUV_420_888
                    Log.d("CameraCompatibility", "Camera ID $cameraId supports YUV_420_888")
                } else {
                    // 记录不支持YUV_420_888
                    Log.d("CameraCompatibility", "Camera ID $cameraId does not support YUV_420_888")
                }
            }
        } catch (e: CameraAccessException) {
            Log.e("CameraError", "Camera access exception", e)
        }
    }

    private val CHANNEL = "com.example.app/image"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call, result ->
            when (call.method) {
                "processImage" -> {
                    val data = call.argument<ByteArray>("data")!!
                    val width = call.argument<Int>("width")!!
                    val height = call.argument<Int>("height")!!

                    try {
                        val jpegData = convertYUV420ToJPEG(data, width, height)
                        saveImage(jpegData, "output.jpg")
                        result.success("Image processed successfully")
                    } catch (e: Exception) {
                        result.error("IMAGE_PROCESS_ERROR", "Failed to process image", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
}

    private fun convertYUV420ToJPEG(yuvData: ByteArray, width: Int, height: Int): ByteArray {
        val yuvImage = YuvImage(yuvData, ImageFormat.NV21, width, height, null)
        val outputStream = ByteArrayOutputStream()
        yuvImage.compressToJpeg(Rect(0, 0, width, height), 100, outputStream)
        return outputStream.toByteArray()
    }

    private fun saveImage(jpegData: ByteArray, filename: String) {
        val outputFile = File(applicationContext.filesDir, filename)
        FileOutputStream(outputFile).use {
            it.write(jpegData)
        }
    }
}
