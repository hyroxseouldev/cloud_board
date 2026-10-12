import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/widgets/soft_rhythm_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as raster;

/// Mechanical density/mask exports from the approved raster master. No redraw.
class BrandAssetExporter {
  BrandAssetExporter._(this.mark, this.visibleBounds);
  final ui.Image mark;
  final Rect visibleBounds;

  static Future<BrandAssetExporter> load() async {
    final bytes = await File(SoftRhythmMark.asset).readAsBytes();
    final decoded = raster.decodePng(bytes)!;
    var left = decoded.width, top = decoded.height, right = 0, bottom = 0;
    for (final pixel in decoded) {
      // Ignore almost-transparent generation residue when optically centering.
      if (pixel.a < 128) continue;
      if (pixel.x < left) left = pixel.x;
      if (pixel.y < top) top = pixel.y;
      if (pixel.x > right) right = pixel.x;
      if (pixel.y > bottom) bottom = pixel.y;
    }
    if (right <= left || bottom <= top) throw StateError('Empty brand master');
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return BrandAssetExporter._(
      frame.image,
      Rect.fromLTRB(
        left.toDouble(),
        top.toDouble(),
        (right + 1).toDouble(),
        (bottom + 1).toDouble(),
      ),
    );
  }

  Future<Uint8List> _render({
    required int width,
    required int height,
    required Rect destination,
    bool opaque = false,
    bool crop = true,
    void Function(Canvas)? decorate,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (opaque) canvas.drawColor(AppColors.canvas, BlendMode.src);
    canvas.drawImageRect(
      mark,
      crop
          ? visibleBounds
          : Rect.fromLTWH(0, 0, mark.width.toDouble(), mark.height.toDouble()),
      destination,
      Paint()..filterQuality = FilterQuality.high,
    );
    decorate?.call(canvas);
    final picture = recorder.endRecording();
    final output = await picture.toImage(width, height);
    final data = await output.toByteData(format: ui.ImageByteFormat.png);
    output.dispose();
    picture.dispose();
    final bytes = data!.buffer.asUint8List();
    // Store icons have no alpha channel, even when every pixel is opaque.
    return opaque
        ? raster.encodePng(raster.decodePng(bytes)!.convert(numChannels: 3))
        : bytes;
  }

  Future<Uint8List> icon(
    int dimension, {
    bool transparent = false,
    double fraction = .68,
  }) {
    final width = dimension * fraction;
    return _render(
      width: dimension,
      height: dimension,
      opaque: !transparent,
      destination: Rect.fromCenter(
        center: Offset(dimension / 2, dimension / 2),
        width: width,
        height: width * visibleBounds.height / visibleBounds.width,
      ),
    );
  }

  Future<void> _save(String path, List<int> bytes) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  Future<void> exportLaunchers() async {
    for (final (density, pixels, foreground) in [
      ('mdpi', 48, 108),
      ('hdpi', 72, 162),
      ('xhdpi', 96, 216),
      ('xxhdpi', 144, 324),
      ('xxxhdpi', 192, 432),
    ]) {
      await _save(
        'android/app/src/main/res/mipmap-$density/ic_launcher.png',
        await icon(pixels),
      );
      await _save(
        'android/app/src/main/res/drawable-$density/ic_launcher_foreground.png',
        await icon(foreground, transparent: true, fraction: .44),
      );
    }
    for (final platform in ['ios', 'macos']) {
      final folder = '$platform/Runner/Assets.xcassets/AppIcon.appiconset';
      final contents = jsonDecode(
        await File('$folder/Contents.json').readAsString(),
      ) as Map<String, dynamic>;
      for (final entry in contents['images'] as List) {
        final name = entry['filename'] as String?;
        if (name == null) continue;
        final size = double.parse((entry['size'] as String).split('x').first);
        final scale = double.parse(
          (entry['scale'] as String).replaceAll('x', ''),
        );
        await _save('$folder/$name', await icon((size * scale).round()));
      }
    }
    await _save('web/favicon.png', await icon(32));
    for (final size in [192, 512]) {
      await _save('web/icons/Icon-$size.png', await icon(size));
      await _save(
        'web/icons/Icon-maskable-$size.png',
        await icon(size, fraction: .6),
      );
    }
    final frames = <raster.Image>[];
    for (final size in [16, 32, 48, 256]) {
      frames.add(raster.decodePng(await icon(size))!);
    }
    await _save(
      'windows/runner/resources/app_icon.ico',
      raster.IcoEncoder().encodeImages(frames),
    );
    await _save('assets/branding/app_icon.png', await icon(1024));
    await _save(
      'android/app/src/main/res/drawable-xhdpi/tv_icon.png',
      await icon(160),
    );
    final loader = FontLoader('Pretendard')
      ..addFont(
        File('assets/fonts/pretendard/Pretendard-SemiBold.otf')
            .readAsBytes()
            .then(ByteData.sublistView),
      );
    await loader.load();
    await _save(
      'android/app/src/main/res/drawable-xhdpi/tv_banner.png',
      await _render(
        width: 320,
        height: 180,
        opaque: true,
        destination: Rect.fromCenter(
          center: const Offset(160, 65),
          width: 66,
          height: 66 * visibleBounds.height / visibleBounds.width,
        ),
        decorate: (canvas) {
          final text = TextPainter(
            text: const TextSpan(
              text: 'CloudBoard',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          text.paint(canvas, Offset((320 - text.width) / 2, 115));
          text.dispose();
        },
      ),
    );
  }

  Future<void> exportSplashSources() async {
    for (final (name, dimension) in [
      ('mark.png', 512),
      ('mark_android12.png', 1152),
    ]) {
      await _save(
        'assets/splash/$name',
        await _render(
          width: dimension,
          height: dimension,
          crop: false,
          destination: Rect.fromCenter(
            center: Offset(dimension / 2, dimension / 2),
            width: 512,
            height: 512,
          ),
        ),
      );
    }
  }

  void dispose() => mark.dispose();
}
