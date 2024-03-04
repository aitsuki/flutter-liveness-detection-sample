import 'dart:developer';

import 'package:camera/camera.dart';
import 'package:facedetection/face_detector.dart';
import 'package:facedetection/input_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:wakelock/wakelock.dart';

class FaceScreen extends StatefulWidget {
  const FaceScreen({super.key});

  @override
  State<FaceScreen> createState() => _FaceScreenState();
}

class _FaceScreenState extends State<FaceScreen> with WidgetsBindingObserver {
  CameraController? controller;
  CameraDescription? camera;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
      minFaceSize: 0.5,
      enableTracking: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
    Wakelock.enable();
  }

  @override
  void dispose() {
    controller?.dispose();
    _faceDetector.close();
    WidgetsBinding.instance.removeObserver(this);
    Wakelock.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    final cameras = await availableCameras();
    CameraDescription? camera;
    for (var i = 0; i < cameras.length; i++) {
      if (cameras[i].lensDirection == CameraLensDirection.front) {
        camera = cameras[i];
        break;
      }
    }

    if (camera == null) {
      log("No front camera found");
      return;
    }

    final CameraController controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    this.controller = controller;
    this.camera = camera;

    // If the controller is updated then update the UI.
    controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    try {
      await controller.initialize();
      controller.startImageStream((image) {
        _processImage(image);
      });
    } on CameraException catch (e) {
      log("_initializeCameraController", error: e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final controller = this.controller;
    final camera = this.camera;
    if (controller == null ||
        !controller.value.isInitialized ||
        camera == null) {
      return null;
    }

    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/android/src/main/java/com/google_mlkit_commons/InputImageConverter.java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/ios/Classes/MLKVisionImage%2BFlutterPlugin.m
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/example/lib/vision_detector_views/painters/coordinates_translator.dart
    final sensorOrientation = camera.sensorOrientation;
    // print(
    //     'lensDirection: ${camera.lensDirection}, sensorOrientation: $sensorOrientation, ${_controller?.value.deviceOrientation} ${_controller?.value.lockedCaptureOrientation} ${_controller?.value.isCaptureOrientationLocked}');
    var rotationCompensation =
        _orientations[controller.value.deviceOrientation];
    if (rotationCompensation == null) return null;
    if (camera.lensDirection == CameraLensDirection.front) {
      // front-facing
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      // back-facing
      rotationCompensation =
          (sensorOrientation - rotationCompensation + 360) % 360;
    }
    InputImageRotation? rotation =
        InputImageRotationValue.fromRawValue(rotationCompensation);
    if (rotation == null) return null;

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null || format != InputImageFormat.nv21) return null;

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  bool _isBusy = false;
  final _errorText = ValueNotifier("");
  final _guideText = ValueNotifier("Please facing the camera");
  var _detectState = DetectState.facing;
  var _startTime = 0;
  final List<XFile> _pictures = [];

  /// CameraImage
  void _processImage(CameraImage image) async {
    if (_detectState == DetectState.end) return;
    if (_isBusy) return;
    _isBusy = true;
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      _isBusy = false;
      return;
    }

    Size imageSize = inputImage.metadata.size;
    final rotatiton = inputImage.metadata.rotation;
    final double imageWidth;
    final double imageHeight;
    switch (rotatiton) {
      case InputImageRotation.rotation180deg:
      case InputImageRotation.rotation0deg:
        imageWidth = imageSize.width;
        imageHeight = imageSize.height;
        break;
      case InputImageRotation.rotation270deg:
      case InputImageRotation.rotation90deg:
        imageWidth = imageSize.height;
        imageHeight = imageSize.width;
        break;
    }

    final faces = await _faceDetector.processImage(inputImage);
    if (faces.isEmpty || !_isWholeFace(faces.first, imageWidth, imageHeight)) {
      _errorText.value = "Please keep your face in the camera";
      _detectState = DetectState.start;
    } else if (faces.length > 1) {
      _errorText.value = "Please keep only one face in the camera";
      _detectState = DetectState.start;
    }
    final face = faces.firstOrNull;
    switch (_detectState) {
      case DetectState.start:
        _pictures.clear();
        _startTime = 0;
        _detectState = DetectState.facing;
        _guideText.value = "Please facing the camera";
      case DetectState.facing:
        if (_startTime == 0) {
          _errorText.value = "";
          _startTime = DateTime.now().millisecondsSinceEpoch;
        }
        final keepTimes = DateTime.now().millisecondsSinceEpoch - _startTime;
        if (_isFrontFace(face) && keepTimes > 1000) {
          await _takePicture(DetectState.sideFace);
        }
      case DetectState.sideFace:
        _guideText.value = "Please show your side face";
        final keepTimes = DateTime.now().millisecondsSinceEpoch - _startTime;
        if (_isSideFace(face) && keepTimes > 1000) {
          await _takePicture(DetectState.smiling);
        }
      case DetectState.smiling:
        _guideText.value = "Please keep smiling";
        final keepTimes = DateTime.now().millisecondsSinceEpoch - _startTime;
        if (_isSmiling(face) && keepTimes > 1000) {
          await _takePicture(DetectState.end);
          List<Uint8List> facePictures = [];
          for (var picture in _pictures) {
            final imageBytes = await FlutterImageCompress.compressWithFile(
                picture.path,
                quality: 75,
                autoCorrectionAngle: true);
            if (imageBytes == null) {
              pop();
              log("Comporess image error");
              return;
            } else {
              facePictures.add(imageBytes);
              log("Compress image success: ${imageBytes.length / 1024}");
            }
          }
          pop(facePictures: facePictures);
        }
      case DetectState.end:
        break;
    }
    _isBusy = false;
  }

  void pop({List<Uint8List>? facePictures}) {
    Navigator.pop(context, facePictures);
  }

  Future<void> _takePicture(DetectState nextState) async {
    final controller = this.controller;
    if (controller == null) {
      _detectState = DetectState.start;
      return;
    }
    if (controller.value.isTakingPicture) {
      return;
    }
    try {
      final file = await controller.takePicture();
      _pictures.add(file);
      _startTime = DateTime.now().millisecondsSinceEpoch;
      _detectState = nextState;
    } on CameraException catch (e) {
      _errorText.value = e.description ?? "";
      _detectState = DetectState.start;
    }
  }

  bool _isWholeFace(Face face, double imageWidth, double imageHeight) {
    final boundingBox = face.boundingBox;
    final coutours = face.contours[FaceContourType.face];
    if (coutours == null) return false;
    final top = boundingBox.top;
    final bottom = boundingBox.bottom;
    final left = coutours.points[27].x;
    final right = coutours.points[9].x;
    return top > 0 && bottom < imageHeight && left > 0 && right < imageHeight;
  }

  bool _isFrontFace(Face? face) {
    if (face == null) return false;
    final yaw = face.headEulerAngleY;
    final pitch = face.headEulerAngleX;
    final roll = face.headEulerAngleZ;
    if (yaw == null || pitch == null || roll == null) return false;
    return yaw > -12 &&
        yaw < 12 &&
        pitch > -12 &&
        pitch < 12 &&
        roll > -8 &&
        roll < 8;
  }

  bool _isSideFace(Face? face) {
    if (face == null) return false;
    final yaw = face.headEulerAngleY;
    if (yaw == null) return false;
    return yaw < -20 || yaw > 20;
  }

  bool _isSmiling(Face? face) {
    if (face == null) return false;
    final smile = face.smilingProbability;
    if (smile == null) return false;
    return smile > 0.6;
  }

  Widget _faceGuide(String text, double scale) {
    return Row(
      children: [
        Image.asset(
          "assets/images/face_warning.png",
          width: 32 * scale,
          height: 32 * scale,
        ),
        SizedBox(width: 4 * scale),
        Text(
          text,
          style: TextStyle(
            fontSize: 12 * scale,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        )
      ],
    );
  }

  Widget _cameraPreview() {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return SizedBox();
    } else {
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Color(0xFF21F6B8),
                Color(0xFFF1F53D),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: ClipOval(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: cameraController.value.previewSize?.height,
                height: cameraController.value.previewSize?.width,
                child: CameraPreview(cameraController),
              ),
            ),
          ),
        ),
      );
      // return CameraPreview(cameraController);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.of(context).size.width / 375.0;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.white,
      ),
      body: Column(children: [
        Expanded(
          child: Column(
            children: [
              Expanded(flex: 1, child: SizedBox.shrink()),
              ValueListenableBuilder(
                valueListenable: _errorText,
                builder: (context, value, child) {
                  return Text(
                    value,
                    style: TextStyle(
                        color: Color(0xFFFF2424),
                        fontSize: 18,
                        fontWeight: FontWeight.w500),
                  );
                },
              ),
              SizedBox(height: 12),
              ValueListenableBuilder(
                valueListenable: _guideText,
                builder: (context, value, child) {
                  return Text(
                    value,
                    style: TextStyle(
                        color: Color(0xFF17191C),
                        fontSize: 18,
                        fontWeight: FontWeight.w500),
                  );
                },
              ),
              SizedBox(height: 40),
              FractionallySizedBox(widthFactor: 0.72, child: _cameraPreview()),
              Expanded(flex: 3, child: SizedBox.shrink()),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 19),
          decoration: BoxDecoration(
            color: Color(0xFF17191C),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _faceGuide("Não está claro", ratio),
              _faceGuide("Incompleto", ratio),
              _faceGuide("Lente distante", ratio),
            ],
          ),
        )
      ]),
    );
  }
}

enum DetectState {
  start,
  facing,
  sideFace,
  smiling,
  end,
}
