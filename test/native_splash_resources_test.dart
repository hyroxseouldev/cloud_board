import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('all Apple launcher catalog entries have opaque matching exports', () {
    for (final platform in ['ios', 'macos']) {
      final folder = '$platform/Runner/Assets.xcassets/AppIcon.appiconset';
      final catalog = jsonDecode(
        File('$folder/Contents.json').readAsStringSync(),
      );
      for (final entry in catalog['images'] as List) {
        final filename = entry['filename'] as String?;
        if (filename == null) continue;
        final png = image.decodePng(
          File('$folder/$filename').readAsBytesSync(),
        )!;
        final size = double.parse((entry['size'] as String).split('x').first);
        final scale = double.parse(
          (entry['scale'] as String).replaceAll('x', ''),
        );
        expect(png.width, (size * scale).round(), reason: filename);
        expect(png.height, png.width, reason: filename);
        expect(
          png.numChannels,
          3,
          reason: 'Store icons must not contain alpha',
        );
      }
    }
  });

  test('adaptive launcher artwork stays inside the 66dp safe circle', () {
    for (final (density, scale) in [
      ('mdpi', 1.0),
      ('hdpi', 1.5),
      ('xhdpi', 2.0),
      ('xxhdpi', 3.0),
      ('xxxhdpi', 4.0),
    ]) {
      final png = image.decodePng(
        File(
          'android/app/src/main/res/drawable-$density/ic_launcher_foreground.png',
        ).readAsBytesSync(),
      )!;
      expect(png.width, (108 * scale).round());
      expect(png.height, png.width);
      var visible = 0;
      for (final pixel in png) {
        if (pixel.a < 128) continue;
        visible++;
        final dx = (pixel.x + .5) / scale - 54;
        final dy = (pixel.y + .5) / scale - 54;
        expect(math.sqrt(dx * dx + dy * dy), lessThan(33));
      }
      expect(visible, greaterThan(100));
    }
  });

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
    expect(visiblePixels, greaterThan(20000));
    expect(visiblePixels, lessThan(512 * 512));
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
