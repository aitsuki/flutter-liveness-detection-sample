import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

/// Image format that ML Kit takes to process the image.
class InputImage {
  /// The bytes of the image.
  final Uint8List bytes;

  /// The image data when creating an image of type = [InputImageType.bytes].
  final InputImageMetadata metadata;

  InputImage({required this.bytes, required this.metadata});

  /// Returns a json representation of an instance of [InputImage].
  Map<String, dynamic> toJson() =>
      {'bytes': bytes, 'metadata': metadata.toJson()};
}

/// Data of image required when creating image from bytes.
class InputImageMetadata {
  /// Size of image.
  final Size size;

  /// Image rotation degree.
  ///
  /// Not used on iOS.
  final InputImageRotation rotation;

  /// Format of the input image.
  ///
  /// Not used on Android.
  final InputImageFormat format;

  /// The row stride for color plane, in bytes.
  ///
  /// Not used on Android.
  final int bytesPerRow;

  /// Constructor to create an instance of [InputImageMetadata].
  InputImageMetadata({
    required this.size,
    required this.rotation,
    required this.format,
    required this.bytesPerRow,
  });

  /// Returns a json representation of an instance of [InputImageMetadata].
  Map<String, dynamic> toJson() => {
        'width': size.width,
        'height': size.height,
        'rotation': rotation.rawValue,
        'image_format': format.rawValue,
        'bytes_per_row': bytesPerRow,
      };
}

/// The camera rotation angle to be specified
enum InputImageRotation {
  rotation0deg,
  rotation90deg,
  rotation180deg,
  rotation270deg
}

extension InputImageRotationValue on InputImageRotation {
  int get rawValue {
    switch (this) {
      case InputImageRotation.rotation0deg:
        return 0;
      case InputImageRotation.rotation90deg:
        return 90;
      case InputImageRotation.rotation180deg:
        return 180;
      case InputImageRotation.rotation270deg:
        return 270;
    }
  }

  static InputImageRotation? fromRawValue(int rawValue) {
    try {
      return InputImageRotation.values
          .firstWhere((element) => element.rawValue == rawValue);
    } catch (_) {
      return null;
    }
  }
}

/// To indicate the format of image while creating input image from bytes
enum InputImageFormat {
  nv21,
  yv12,
  yuv_420_888,
  yuv420,
  bgra8888,
}

extension InputImageFormatValue on InputImageFormat {
  // source: https://developers.google.com/android/reference/com/google/mlkit/vision/common/InputImage#constants
  int get rawValue {
    switch (this) {
      case InputImageFormat.nv21:
        return 17;
      case InputImageFormat.yv12:
        return 842094169;
      case InputImageFormat.yuv_420_888:
        return 35;
      case InputImageFormat.yuv420:
        return 875704438;
      case InputImageFormat.bgra8888:
        return 1111970369;
    }
  }

  static InputImageFormat? fromRawValue(int rawValue) {
    try {
      return InputImageFormat.values
          .firstWhere((element) => element.rawValue == rawValue);
    } catch (_) {
      return null;
    }
  }
}
