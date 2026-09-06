import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PNG 바이트를 data URI로 만들고 다시 읽는다', () {
    final bytes = Uint8List.fromList([
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
    ]);

    final source = WorkoutImageSource.fromBytes(bytes);
    final decoded = WorkoutImageSource.decode(source);

    expect(source, startsWith('data:image/png;base64,'));
    expect(decoded.contentType, 'image/png');
    expect(decoded.bytes, bytes);
  });

  test('기존 raw base64 이미지도 계속 읽는다', () {
    final bytes = Uint8List.fromList([0xff, 0xd8, 0xff, 0x00]);

    final decoded = WorkoutImageSource.decode(base64Encode(bytes));

    expect(decoded.contentType, 'image/jpeg');
    expect(decoded.bytes, bytes);
  });

  test('지원하지 않는 형식은 선택 단계에서 거부한다', () {
    expect(
      () => WorkoutImageSource.fromBytes(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });
}
