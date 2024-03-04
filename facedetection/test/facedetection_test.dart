import 'package:flutter_test/flutter_test.dart';
import 'package:facedetection/facedetection.dart';
import 'package:facedetection/facedetection_platform_interface.dart';
import 'package:facedetection/facedetection_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFacedetectionPlatform
    with MockPlatformInterfaceMixin
    implements FacedetectionPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FacedetectionPlatform initialPlatform = FacedetectionPlatform.instance;

  test('$MethodChannelFacedetection is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFacedetection>());
  });

  test('getPlatformVersion', () async {
    Facedetection facedetectionPlugin = Facedetection();
    MockFacedetectionPlatform fakePlatform = MockFacedetectionPlatform();
    FacedetectionPlatform.instance = fakePlatform;

    expect(await facedetectionPlugin.getPlatformVersion(), '42');
  });
}
