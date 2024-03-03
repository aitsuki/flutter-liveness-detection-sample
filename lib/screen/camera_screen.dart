import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:native_exif/native_exif.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? controller;
  XFile? imageFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestCameraPermission();
  }

  @override
  void dispose() {
    controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
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
      _initializeCameraController();
    }
  }

  Future<void> _initializeCameraController() async {
    final cameras = await availableCameras();
    int cameraIndex = 0;
    for (var i = 0; i < cameras.length; i++) {
      if (cameras[i].lensDirection == CameraLensDirection.back) {
        cameraIndex = i;
        break;
      }
    }
    final CameraController cameraController = CameraController(
      cameras[cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    controller = cameraController;

    // If the controller is updated then update the UI.
    cameraController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    try {
      await cameraController.initialize();
    } on CameraException catch (e) {
      log("_initializeCameraController", error: e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isDenied) {
      pop();
    } else if (status.isPermanentlyDenied) {
      showPermissionSettingDialog();
    } else if (status.isGranted) {
      setState(() {
        _initializeCameraController();
      });
    }
  }

  void onTakePictureButtonPressed() {
    takePicture().then((XFile? file) {
      if (mounted) {
        setState(() {
          imageFile = file;
        });
        if (file != null) {
          log('Picture saved to ${file.path}');
        }
      }
    });
  }

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      log('Error: select a camera first.');
      return null;
    }

    if (cameraController.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      final XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      log("takePicture error: ", error: e);
      return null;
    }
  }

  /// 由于是强制竖屏拍摄，所以要手动旋转-90度。
  /// 有些手机摄像头角度是已经旋转过的，会给图片写入旋转角度，
  /// 例如 Rotate 90 CW 表示照片需要顺时针旋转90度后才能正常显示，
  /// 同时也证明改照片是-90的，顺时针旋转90度后才是0度。
  ///
  /// - ORIENTATION_UNDEFINED = 0;
  /// - ORIENTATION_NORMAL = 1;
  /// - ORIENTATION_FLIP_HORIZONTAL = 2; // 左右翻转
  /// - ORIENTATION_ROTATE_180 = 3;
  /// - ORIENTATION_FLIP_VERTICAL = 4;  // 上下翻转
  /// - ORIENTATION_TRANSPOSE = 5; // 左上到右下 对角翻转
  /// - ORIENTATION_ROTATE_90 = 6;
  /// - ORIENTATION_TRANSVERSE = 7; // 右上到左下 对角翻转
  /// - ORIENTATION_ROTATE_270 = 8;
  Future<void> useCurrentImage() async {
    final path = imageFile?.path;
    if (path == null) {
      return;
    }
    final exif = await Exif.fromPath(path);
    var orientation = await exif.getAttribute("Orientation");
    orientation = int.tryParse(orientation);

    // 下面方法来自 AndroidX ExifInterface getRotationDegrees()
    int degress;
    switch (orientation) {
      case 6:
      case 7:
        degress = 90;
      case 3:
      case 4:
        degress = 180;
      case 8:
      case 5:
        degress = 270;
      default:
        degress = 0;
    }

    final bytes = await FlutterImageCompress.compressWithFile(
      path,
      quality: 75,
      autoCorrectionAngle: false,
      rotate: degress - 90, // 强制竖屏拍摄，所以要手动旋转-90度
    );

    if (bytes != null) {
      pop(bytes: bytes);
    }
  }

  void pop({Uint8List? bytes}) {
    Navigator.pop(context, bytes);
  }

  Future<bool?> showPermissionSettingDialog() {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Permission"),
          content: const Text("Required camera permission to open camera."),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Open Settings"),
              onPressed: () async {
                await openAppSettings();
                pop();
              },
            )
          ],
        );
      },
    );
  }

  Widget _cameraPreview() {
    if (imageFile != null) {
      return Image.file(
        File(imageFile!.path),
        fit: BoxFit.cover,
      );
    }

    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return SizedBox();
    } else {
      Widget? loadingView;
      if (cameraController.value.isTakingPicture) {
        loadingView = Center(
          child: Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Color(0x80000000)),
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(),
            ),
          ),
        );
      }

      return CameraPreview(
        controller!,
        child: loadingView,
      );
    }
  }

  Widget _cameraControllButtonGroup() {
    if (imageFile == null) {
      return Row(
        children: [
          _actionButton(
            onPressed: () => pop(),
            icon: Image.asset(
              "assets/images/camera_back.png",
              width: 48,
              height: 48,
            ),
          ),
          _actionButton(
            onPressed: onTakePictureButtonPressed,
            icon: RotatedBox(
              quarterTurns: 3,
              child: Image.asset(
                "assets/images/camera_take.png",
                width: 66,
                height: 66,
              ),
            ),
          ),
          _actionButton(
            onPressed: () {},
            icon: Image.asset(
              "assets/images/camera_flash_on.png",
              width: 48,
              height: 48,
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          _actionButton(
            onPressed: () {
              setState(() {
                imageFile = null;
              });
            },
            icon: Image.asset(
              "assets/images/camera_preview_close.png",
              width: 48,
              height: 48,
            ),
          ),
          _actionButton(
            onPressed: useCurrentImage,
            icon: RotatedBox(
              quarterTurns: 3,
              child: Image.asset(
                "assets/images/camera_preview_use.png",
                width: 66,
                height: 66,
              ),
            ),
          ),
          _actionButton(
            onPressed: () {},
            icon: Image.asset(
              "assets/images/camera_flash_on.png",
              width: 48,
              height: 48,
            ),
          ),
        ],
      );
    }
  }

  Widget _actionButton(
      {required VoidCallback onPressed, required Widget icon}) {
    return Expanded(
      child: Center(
        child: IconButton(onPressed: onPressed, icon: icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 18),
                    child: Container(
                      foregroundDecoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(
                            "assets/images/camera_mask_idcard.png",
                          ),
                        ),
                      ),
                      padding: EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(18)),
                        child: AspectRatio(
                          aspectRatio: 0.628,
                          child: _cameraPreview(),
                        ),
                      ),
                    ),
                  ),
                ),
                RotatedBox(
                  quarterTurns: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                        "Certifique-se de que seu ID esteja dentro da caixa antes de tirar a foto.",
                        style: TextStyle(
                          color: Color(0xFFF1F53D),
                        )),
                  ),
                )
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 8, bottom: 20),
            child: _cameraControllButtonGroup(),
          )
        ],
      ),
    );
  }
}
