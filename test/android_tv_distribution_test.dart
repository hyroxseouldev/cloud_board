import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android TV distribution', () {
    test('Play uploads explicitly target the private internal track', () {
      final workflow = File('.github/workflows/google-play-main.yml')
          .readAsStringSync();
      expect(workflow, contains('track: internal'));
      expect(workflow, isNot(contains('tracks:')));
    });
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    test('declares TV compatibility and a Leanback launcher', () {
      expect(
        manifest,
        contains(
          '<uses-feature android:name="android.hardware.touchscreen" '
          'android:required="false"/>',
        ),
      );
      expect(
        manifest,
        contains(
          '<uses-feature android:name="android.software.leanback" '
          'android:required="false"/>',
        ),
      );
      expect(manifest, contains('android.intent.category.LEANBACK_LAUNCHER'));
      expect(manifest, contains('android:banner="@drawable/tv_banner"'));
      expect(manifest, contains('android:icon="@drawable/tv_icon"'));
    });

    test('ships full-size xhdpi TV launcher artwork', () {
      expect(
        _pngSize(File('android/app/src/main/res/drawable-xhdpi/tv_banner.png')),
        (width: 320, height: 180),
      );
      expect(
        _pngSize(File('android/app/src/main/res/drawable-xhdpi/tv_icon.png')),
        (width: 160, height: 160),
      );
    });
  });
}

({int width, int height}) _pngSize(File file) {
  final bytes = file.readAsBytesSync();
  expect(bytes.length, greaterThanOrEqualTo(24), reason: file.path);
  expect(
    bytes.take(8),
    orderedEquals(const [137, 80, 78, 71, 13, 10, 26, 10]),
    reason: file.path,
  );
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  return (
    width: data.getUint32(16, Endian.big),
    height: data.getUint32(20, Endian.big),
  );
}
