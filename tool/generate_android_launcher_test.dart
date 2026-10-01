// Run: fvm flutter test tool/generate_android_launcher_test.dart
// Export the existing splash/brand painter at Android launcher densities.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/widgets/app_startup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('export CloudBoard launcher resources', () async {
    for (final (density, dimension) in [
      ('mdpi', 48),
      ('hdpi', 72),
      ('xhdpi', 96),
      ('xxhdpi', 144),
      ('xxxhdpi', 192),
    ]) {
      final recorder = ui.PictureRecorder();
      const StartupMarkPainter().paint(
        Canvas(recorder),
        Size.square(dimension.toDouble()),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(dimension, dimension);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('android/app/src/main/res/mipmap-$density/ic_launcher.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }
  });
}
