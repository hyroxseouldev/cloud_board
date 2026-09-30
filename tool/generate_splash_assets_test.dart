// Run: fvm flutter test tool/generate_splash_assets_test.dart
// Export existing vector artwork; do not resize or replace launcher/TV icons.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/widgets/app_startup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'export native splash artwork from the Flutter first-frame painter',
    () async {
      final directory = Directory('assets/splash')..createSync(recursive: true);
      for (final (filename, dimension) in [
        ('mark.png', 512),
        ('mark_android12.png', 1152),
      ]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final padding = (dimension - 512) / 2;
        canvas.translate(padding, padding);
        const StartupMarkPainter().paint(canvas, const Size.square(512));
        final picture = recorder.endRecording();
        final image = await picture.toImage(dimension, dimension);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${directory.path}/$filename')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      }
    },
  );
}
