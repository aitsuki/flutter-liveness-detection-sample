import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'facedetection_method_channel.dart';

abstract class FacedetectionPlatform extends PlatformInterface {
  /// Constructs a FacedetectionPlatform.
  FacedetectionPlatform() : super(token: _token);

  static final Object _token = Object();

  static FacedetectionPlatform _instance = MethodChannelFacedetection();

  /// The default instance of [FacedetectionPlatform] to use.
  ///
  /// Defaults to [MethodChannelFacedetection].
  static FacedetectionPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FacedetectionPlatform] when
  /// they register themselves.
  static set instance(FacedetectionPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
