
import 'facedetection_platform_interface.dart';

class Facedetection {
  Future<String?> getPlatformVersion() {
    return FacedetectionPlatform.instance.getPlatformVersion();
  }
}
