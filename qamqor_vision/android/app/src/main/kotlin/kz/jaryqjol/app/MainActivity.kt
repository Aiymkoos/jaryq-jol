package kz.jaryqjol.app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import com.googlecode.tesseract.android.TessBaseAPI
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jaryq_jol/ocr")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognize") { result.notImplemented(); return@setMethodCallHandler }
                val path = call.argument<String>("path")
                if (path == null) { result.error("invalid", "No image", null); return@setMethodCallHandler }
                executor.execute {
                    val tess = TessBaseAPI()
                    var bitmap: Bitmap? = null
                    try {
                        val directory = File(filesDir, "ocr/tessdata").apply { mkdirs() }
                        for (lang in listOf("rus", "kaz")) {
                            val target = File(directory, "$lang.traineddata")
                            if (!target.exists()) assets.open("tessdata/$lang.traineddata").use { input -> target.outputStream().use { input.copyTo(it) } }
                        }
                        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                        BitmapFactory.decodeFile(path, bounds)
                        val options = BitmapFactory.Options().apply { inSampleSize = maxOf(1, maxOf(bounds.outWidth, bounds.outHeight) / 2200) }
                        bitmap = BitmapFactory.decodeFile(path, options) ?: error("Invalid image")
                        val exif = ExifInterface(path)
                        val rotation = exif.rotationDegrees
                        if (rotation != 0 || exif.isFlipped) {
                            val matrix = Matrix().apply { if (exif.isFlipped) postScale(-1f, 1f); postRotate(rotation.toFloat()) }
                            val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
                            if (rotated !== bitmap) bitmap.recycle()
                            bitmap = rotated
                        }
                        var luminance=0.0; var samples=0
                        for (y in 0 until bitmap.height step maxOf(1,bitmap.height/32)) for (x in 0 until bitmap.width step maxOf(1,bitmap.width/32)) {
                            val color=bitmap.getPixel(x,y)
                            luminance += ((color shr 16) and 255)*.2126 + ((color shr 8) and 255)*.7152 + (color and 255)*.0722
                            samples++
                        }
                        if (luminance/samples < 30) error("too_dark")
                        if (!tess.init(directory.parent, "rus+kaz", TessBaseAPI.OEM_LSTM_ONLY)) error("Model unavailable")
                        tess.setImage(bitmap)
                        val text = tess.getUTF8Text()?.trim() ?: ""
                        val confidence = tess.meanConfidence()
                        val safeText = if (confidence >= 65) text else ""
                        runOnUiThread { result.success(mapOf("text" to safeText, "confidence" to confidence / 100.0)) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("ocr_failed", e.message, null) }
                    } finally { bitmap?.recycle(); tess.recycle() }
                }
            }
    }
    override fun onDestroy() { executor.shutdown(); super.onDestroy() }
}
