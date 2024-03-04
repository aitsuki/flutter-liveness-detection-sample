package com.example.facedetection

import android.content.Context
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceContour
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetector
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.face.FaceLandmark
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result


private const val START = "vision#startFaceDetector"
private const val CLOSE = "vision#closeFaceDetector"

/** FacedetectionPlugin */
class FacedetectionPlugin : FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val instances = hashMapOf<String, FaceDetector>()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "facedetection")
        channel.setMethodCallHandler(this)
    }


    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            START -> handleDetection(call, result)
            CLOSE -> closeDetector(call)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun handleDetection(call: MethodCall, result: Result) {
        val imageData = call.argument<Map<String, Any>>("imageData") ?: return
        val inputImage = getInputImageFromData(imageData) ?: return
        val id = call.argument<String>("id") ?: return
        var detector = instances[id]
        if (detector == null) {
            val options = call.argument<Map<String, Any>>("options")
            if (options == null) {
                result.error("FaceDetectorError", "Invalid options", null)
                return
            }
            val detectorOptions = parseOptions(options)
            detector = FaceDetection.getClient(detectorOptions)
            instances[id] = detector
        }

        detector.process(inputImage).addOnSuccessListener { visionFaces ->
            val faces = ArrayList<Map<String, Any>>(visionFaces.size)
            for (face in visionFaces) {
                val faceData = hashMapOf<String, Any>()
                val frame = hashMapOf<String, Int>()
                val rect = face.boundingBox
                frame["left"] = rect.left
                frame["top"] = rect.top
                frame["right"] = rect.right
                frame["bottom"] = rect.bottom
                faceData["rect"] = frame
                faceData["headEulerAngleX"] = face.headEulerAngleX
                faceData["headEulerAngleY"] = face.headEulerAngleY
                faceData["headEulerAngleZ"] = face.headEulerAngleZ
                face.smilingProbability?.let {
                    faceData["smilingProbability"] = it
                }
                face.leftEyeOpenProbability?.let {
                    faceData["leftEyeOpenProbability"] = it
                }
                face.rightEyeOpenProbability?.let {
                    faceData["rightEyeOpenProbability"] = it
                }
                face.trackingId?.let {
                    faceData["trackingId"] = it
                }
                faceData["landmarks"] = getLandmarkData(face)
                faceData["contours"] = getContourData(face)
                faces.add(faceData)
            }
            result.success(faces)
        }.addOnFailureListener { e ->
            result.error("FaceDetectorError", e.toString(), null)
        }
    }

    private fun closeDetector(call: MethodCall) {
        val id = call.argument<String>("id")
        val detector = instances[id] ?: return
        detector.close()
        instances.remove(id)
    }

    private fun parseOptions(options: Map<String, Any>): FaceDetectorOptions {
        val classification =
            if (options["enableClassification"] as Boolean) FaceDetectorOptions.CLASSIFICATION_MODE_ALL else FaceDetectorOptions.CLASSIFICATION_MODE_NONE
        val landmark =
            if (options["enableLandmarks"] as Boolean) FaceDetectorOptions.LANDMARK_MODE_ALL else FaceDetectorOptions.LANDMARK_MODE_NONE
        val contours =
            if (options["enableContours"] as Boolean) FaceDetectorOptions.CONTOUR_MODE_ALL else FaceDetectorOptions.CONTOUR_MODE_NONE
        val mode = when (options["mode"] as String?) {
            "accurate" -> FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE
            "fast" -> FaceDetectorOptions.PERFORMANCE_MODE_FAST
            else -> throw IllegalArgumentException("Not a mode:" + options["mode"])
        }
        val builder = FaceDetectorOptions.Builder()
            .setClassificationMode(classification)
            .setLandmarkMode(landmark)
            .setContourMode(contours)
            .setMinFaceSize((options["minFaceSize"] as Double).toFloat())
            .setPerformanceMode(mode)
        if (options["enableTracking"] as Boolean) {
            builder.enableTracking()
        }
        return builder.build()
    }

    private fun getLandmarkData(face: Face): Map<String, DoubleArray?> {
        val landmarks: MutableMap<String, DoubleArray?> = HashMap()
        landmarks["bottomMouth"] = landmarkPosition(face, FaceLandmark.MOUTH_BOTTOM)
        landmarks["rightMouth"] = landmarkPosition(face, FaceLandmark.MOUTH_RIGHT)
        landmarks["leftMouth"] = landmarkPosition(face, FaceLandmark.MOUTH_LEFT)
        landmarks["rightEye"] = landmarkPosition(face, FaceLandmark.RIGHT_EYE)
        landmarks["leftEye"] = landmarkPosition(face, FaceLandmark.LEFT_EYE)
        landmarks["rightEar"] = landmarkPosition(face, FaceLandmark.RIGHT_EAR)
        landmarks["leftEar"] = landmarkPosition(face, FaceLandmark.LEFT_EAR)
        landmarks["rightCheek"] = landmarkPosition(face, FaceLandmark.RIGHT_CHEEK)
        landmarks["leftCheek"] = landmarkPosition(face, FaceLandmark.LEFT_CHEEK)
        landmarks["noseBase"] = landmarkPosition(face, FaceLandmark.NOSE_BASE)
        return landmarks
    }

    private fun getContourData(face: Face): Map<String, List<DoubleArray>?> {
        val contours: MutableMap<String, List<DoubleArray>?> = HashMap()
        contours["face"] = contourPosition(face, FaceContour.FACE)
        contours["leftEyebrowTop"] = contourPosition(face, FaceContour.LEFT_EYEBROW_TOP)
        contours["leftEyebrowBottom"] = contourPosition(face, FaceContour.LEFT_EYEBROW_BOTTOM)
        contours["rightEyebrowTop"] = contourPosition(face, FaceContour.RIGHT_EYEBROW_TOP)
        contours["rightEyebrowBottom"] = contourPosition(face, FaceContour.RIGHT_EYEBROW_BOTTOM)
        contours["leftEye"] = contourPosition(face, FaceContour.LEFT_EYE)
        contours["rightEye"] = contourPosition(face, FaceContour.RIGHT_EYE)
        contours["upperLipTop"] = contourPosition(face, FaceContour.UPPER_LIP_TOP)
        contours["upperLipBottom"] = contourPosition(face, FaceContour.UPPER_LIP_BOTTOM)
        contours["lowerLipTop"] = contourPosition(face, FaceContour.LOWER_LIP_TOP)
        contours["lowerLipBottom"] = contourPosition(face, FaceContour.LOWER_LIP_BOTTOM)
        contours["noseBridge"] = contourPosition(face, FaceContour.NOSE_BRIDGE)
        contours["noseBottom"] = contourPosition(face, FaceContour.NOSE_BOTTOM)
        contours["leftCheek"] = contourPosition(face, FaceContour.LEFT_CHEEK)
        contours["rightCheek"] = contourPosition(face, FaceContour.RIGHT_CHEEK)
        return contours
    }

    private fun landmarkPosition(face: Face, landmarkInt: Int): DoubleArray? {
        val landmark = face.getLandmark(landmarkInt)
        return if (landmark != null) {
            doubleArrayOf(landmark.position.x.toDouble(), landmark.position.y.toDouble())
        } else null
    }

    private fun contourPosition(face: Face, contourInt: Int): List<DoubleArray>? {
        val contour = face.getContour(contourInt)
        if (contour != null) {
            val contourPoints = contour.points
            val result: MutableList<DoubleArray> = ArrayList()
            for (i in contourPoints.indices) {
                result.add(
                    doubleArrayOf(
                        contourPoints[i].x.toDouble(),
                        contourPoints[i].y.toDouble()
                    )
                )
            }
            return result
        }
        return null
    }
}

fun getInputImageFromData(imageData: Map<String, Any>): InputImage? {
    val bytes = imageData["bytes"] as? ByteArray ?: return null
    val metadata = imageData["metadata"] as? Map<*, *> ?: return null
    val width = metadata["width"] as? Double ?: return null
    val height = metadata["height"] as? Double ?: return null
    val rotation = metadata["rotation"] as? Int ?: return null

    return InputImage.fromByteArray(
        bytes,
        width.toInt(),
        height.toInt(),
        rotation,
        InputImage.IMAGE_FORMAT_NV21,
    )
}
