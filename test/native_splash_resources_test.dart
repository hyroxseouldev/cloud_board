import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('Android 12 artwork fits completely within the circular safe area', () {
    final mark = image.decodePng(
      File('assets/splash/mark_android12.png').readAsBytesSync(),
    )!;
    expect(mark.width, 1152);
    expect(mark.height, 1152);
    var visiblePixels = 0;
    for (final pixel in mark) {
      if (pixel.a == 0) continue;
      visiblePixels++;
      final distance = math.sqrt(
        math.pow(pixel.x + .5 - 576, 2) + math.pow(pixel.y + .5 - 576, 2),
      );
      expect(
        distance,
        lessThan(384),
        reason: 'Android 12 would clip this pixel',
      );
    }
    expect(visiblePixels, 512 * 512);
  });

  test('native exports keep a 128 point mark at every pixel density', () {
    for (var density = 1; density <= 3; density++) {
      final suffix = density == 1 ? '' : '@${density}x';
      final file = File(
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png',
      );
      final mark = image.decodePng(file.readAsBytesSync())!;
      expect(mark.width / density, 128);
      expect(mark.height / density, 128);
    }
    for (final (qualifier, density) in [
      ('mdpi', 1.0),
      ('hdpi', 1.5),
      ('xhdpi', 2.0),
      ('xxhdpi', 3.0),
      ('xxxhdpi', 4.0),
    ]) {
      final mark = image.decodePng(
        File('android/app/src/main/res/drawable-$qualifier/splash.png')
            .readAsBytesSync(),
      )!;
      expect(mark.width / density, 128);
      expect(mark.height / density, 128);
    }
  });
}
