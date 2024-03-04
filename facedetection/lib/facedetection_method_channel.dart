import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'facedetection_platform_interface.dart';

/// An implementation of [FacedetectionPlatform] that uses method channels.
class MethodChannelFacedetection extends FacedetectionPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('facedetection');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
