import 'dart:convert';
import 'dart:typed_data';

class WorkoutImageSource {
  const WorkoutImageSource({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;

  static WorkoutImageSource decode(String source) {
    final dataUri = RegExp(
      r'^data:([^;,]+);base64,(.*)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(source);
    final bytes = base64Decode(dataUri?.group(2) ?? source);
    final declaredType = dataUri?.group(1)?.toLowerCase();
    return WorkoutImageSource(
      bytes: bytes,
      contentType:
          _detectedContentType(bytes) ??
          declaredType ??
          'application/octet-stream',
    );
  }

  static String fromBytes(Uint8List bytes, {String? contentType}) {
    final type = _detectedContentType(bytes) ?? contentType?.toLowerCase();
    if (type == null || !supportedContentTypes.contains(type)) {
      throw const FormatException(
        '지원하지 않는 이미지 형식입니다. JPG, PNG, WebP 또는 GIF 파일을 선택해 주세요.',
      );
    }
    return 'data:$type;base64,${base64Encode(bytes)}';
  }

  static const supportedContentTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  };

  static String? _detectedContentType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'image/webp';
    }
    if (bytes.length >= 6) {
      final signature = ascii.decode(bytes.sublist(0, 6), allowInvalid: true);
      if (signature == 'GIF87a' || signature == 'GIF89a') return 'image/gif';
    }
    return null;
  }
}
