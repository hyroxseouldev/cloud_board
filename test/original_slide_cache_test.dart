import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/feature/workouts/data/datasources/original_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/visible_slide_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> image(int size, {int? height}) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.red, BlendMode.src);
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(size, height ?? size);
  } finally {
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('LRU byte budget evicts handles while active clones remain valid', () async {
    final cache = OriginalSlideImageCache(maximumBytes: 2 * 8 * 8 * 4);
    var decodes = 0;
    Future<ui.Image> decode() {
      decodes++;
      return image(8);
    }

    final first = await cache.load('a', decode);
    final second = await cache.load('b', decode);
    final hit = await cache.load('a', decode);
    expect(first.isCloneOf(hit), isTrue);
    final third = await cache.load('c', decode);
    expect(cache.retainedBytes, 512);
    expect(cache.length, 2);
    final reloaded = await cache.load('b', decode);
    expect(decodes, 4);
    cache.clear();
    expect(cache.retainedBytes, 0);
    // Neither budget eviction nor full clearing invalidates an active painter.
    for (final owned in [first, second, hit, third, reloaded]) {
      expect((await owned.toByteData())!.lengthInBytes, 256);
      owned.dispose();
    }
  });
  test(
    'pending deduplication and eviction do not dispose waiting readers',
    () async {
      final cache = OriginalSlideImageCache(maximumBytes: 0);
      final pending = Completer<ui.Image>();
      var calls = 0;
      Future<ui.Image> decode() {
        calls++;
        return pending.future;
      }

      final first = cache.load('a', decode);
      final second = cache.load('a', decode);
      cache.clear();
      pending.complete(await image(8));
      final handles = await Future.wait([first, second]);
      expect(calls, 1);
      expect(cache.retainedBytes, 0);
      expect(handles[0].isCloneOf(handles[1]), isTrue);
      for (final owned in handles) {
        expect(await owned.toByteData(), isNotNull);
        owned.dispose();
      }
    },
  );
  test('failed decode is evicted and a later request retries', () async {
    final cache = OriginalSlideImageCache(maximumBytes: 1024);
    await expectLater(
      cache.load('a', () async => throw StateError('decode')),
      throwsStateError,
    );
    expect(cache.length, 0);
    final retried = await cache.load('a', () => image(8));
    expect(retried.width, 8);
    retried.dispose();
    cache.clear();
  });
  test('all seven template IDs decode at thumbnail size (bundled native, fixture web)', () async {
    originalSlidePreviewCache.clear();
    originalSlideExportCache.clear();
    expect(originalSlideTemplates.length, 7);
    if (kIsWeb) {
      // Flutter's browser test engine intentionally ignores platform messages,
      // including flutter/assets. Supply encoded fixtures at the actual two
      // source dimensions; production cache + image codec still run on Chrome.
      // Native tests load all seven real assets, with separate pixel-fidelity
      // comparisons in original_slide_renderer/stationd_original_templates.
      final encoded = <Size, ByteData>{};
      final assets = <String, ByteData>{};
      for (final template in originalSlideTemplates) {
        final size = template.sourceSize;
        if (!encoded.containsKey(size)) {
          final source = await image(
            size.width.toInt(),
            height: size.height.toInt(),
          );
          try {
            encoded[size] = (await source.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
          } finally {
            source.dispose();
          }
        }
        assets[template.asset] = encoded[size]!;
      }
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler(
        'flutter/assets',
        (message) async =>
            assets[utf8.decode(
              message!.buffer.asUint8List(
                message.offsetInBytes,
                message.lengthInBytes,
              ),
            )],
      );
      addTearDown(
        () => messenger.setMockMessageHandler('flutter/assets', null),
      );
    }
    for (final template in originalSlideTemplates) {
      final thumbnail = await loadOriginalSlideImage(
        template.id,
        targetWidth: 320,
      );
      expect(thumbnail.width, 320);
      expect(thumbnail.height, lessThanOrEqualTo(180));
      thumbnail.dispose();
    }
    expect(originalSlideExportCache.length, 0);
    expect(originalSlidePreviewCache.retainedBytes, lessThan(2 * 1024 * 1024));
    originalSlidePreviewCache.clear();
  });
  testWidgets(
    'offscreen gallery artwork is not built and is released on scroll',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            height: 400,
            child: ListView(
              controller: controller,
              children: List.generate(
                7,
                (i) => SizedBox(
                  height: 300,
                  child: VisibleSlidePreview(builder: (_) => Text('art-$i')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('art-0'), findsOneWidget);
      expect(find.text('art-6'), findsNothing);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      await tester.pump();
      expect(find.text('art-0'), findsNothing);
      expect(find.text('art-6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
