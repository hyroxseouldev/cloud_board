import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/image_color_sampling.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/slide_timer_color_edit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'contain mapping excludes letterbox and respects zoom/pan and pixel edges',
    () {
      Offset? pixel(
        Offset p, {
        Matrix4? matrix,
        Size viewport = const Size(400, 400),
      }) => imagePixelAt(
        position: p,
        viewport: viewport,
        image: const Size(4, 2),
        transform: matrix ?? Matrix4.identity(),
      );
      expect(pixel(const Offset(50, 99)), isNull);
      expect(pixel(const Offset(50, 100)), const Offset(0, 0));
      expect(pixel(const Offset(399.9, 299.9)), const Offset(3, 1));
      expect(pixel(const Offset(50, 300)), isNull);
      expect(pixel(const Offset(400, 200)), isNull);
      final zoomPan = Matrix4.diagonal3Values(2, 2, 1)
        ..setTranslationRaw(-100, -150, 0);
      expect(
        pixel(const Offset(200, 350), matrix: zoomPan),
        const Offset(1, 1),
      );
      expect(pixel(const Offset(50, 40), matrix: zoomPan), isNull);
      expect(
        pixel(const Offset(300, 100), viewport: const Size(800, 200)),
        const Offset(1, 1),
      );
      expect(
        pixel(const Offset(199, 100), viewport: const Size(800, 200)),
        isNull,
      );
      expect(pixel(const Offset(10, 10), matrix: Matrix4.zero()), isNull);
    },
  );

  test('original PNG channels and transparent pixels are read without background blending', () async {
    final fixture = img.Image(width: 3, height: 1, numChannels: 4)
      ..setPixelRgba(0, 0, 246, 90, 19, 255)
      ..setPixelRgba(1, 0, 100, 150, 200, 128)
      ..setPixelRgba(2, 0, 0, 0, 0, 0);
    final read = ImageColorRead(
      MemoryImage(Uint8List.fromList(img.encodePng(fixture))),
      ImageConfiguration.empty,
    );
    final pixels = await read.future;
    expect(pixels.size, const Size(3, 1));
    expect(pixels.colorAt(Offset.zero), const Color(0xFFF65A13));
    // PNG decoding can round a partially transparent channel by one unit.
    final partial = pixels.colorAt(const Offset(1, 0))!;
    expect((partial.r * 255).round(), closeTo(100, 1));
    expect((partial.g * 255).round(), closeTo(150, 1));
    expect((partial.b * 255).round(), closeTo(200, 1));
    expect(pixels.colorAt(const Offset(2, 0)), isNull);
    expect(pixels.colorAt(const Offset(-1, 0)), isNull);
    pixels.dispose();
    expect(pixels.image.debugDisposed, isTrue);
  });

  testWidgets('cancel/timeout/failure remove the image listener', (
    tester,
  ) async {
    for (final reason in ['cancel', 'timeout', 'error']) {
      final provider = _PendingImage();
      final read = ImageColorRead(provider, ImageConfiguration.empty);
      final failure = expectLater(
        read.future,
        throwsA(anyOf(isA<Exception>(), isA<StateError>())),
      );
      expect(provider.completer.listening, isTrue);
      if (reason == 'cancel') {
        read.cancel();
      } else if (reason == 'timeout') {
        await tester.pump(const Duration(seconds: 21));
      } else {
        provider.completer.fail();
      }
      await failure;
      expect(provider.completer.listening, isFalse);
      read.cancel(); // Safe after completion.
    }
  });

  test('only the selected field and explicit same-phase pair change', () {
    final original = WorkoutModule.empty('one').copyWith(
      name: 'latest name',
      imageSource: 'original bytes',
      text: 'preserved',
      workGaugeColor: '#111111',
      restGaugeColor: '#222222',
      workTextColor: '#333333',
      restTextColor: '#444444',
    );
    expect(
      editSlideTimerColor(original, SlideTimerColorTarget.workGauge, '#F65A13'),
      original.copyWith(workGaugeColor: '#F65A13'),
    );
    expect(
      editSlideTimerColor(
        original,
        SlideTimerColorTarget.workGauge,
        '#F65A13',
        pair: true,
      ),
      original.copyWith(workGaugeColor: '#F65A13', workTextColor: '#F65A13'),
    );
    expect(
      editSlideTimerColor(
        original,
        SlideTimerColorTarget.restGauge,
        '#F65A13',
        pair: true,
      ),
      original.copyWith(restGaugeColor: '#F65A13', restTextColor: '#F65A13'),
    );
    expect(
      editSlideTimerColor(
        original,
        SlideTimerColorTarget.workText,
        '#F65A13',
        pair: true,
      ),
      original.copyWith(workTextColor: '#F65A13'),
    );
    expect(
      editSlideTimerColor(original, SlideTimerColorTarget.restText, '#F65A13'),
      original.copyWith(restTextColor: '#F65A13'),
    );
    expect(
      editSlideTimerColor(
        original,
        SlideTimerColorTarget.sets,
        '#F65A13',
        pair: true,
      ),
      original.copyWith(
        appearance: original.appearance.copyWith(setsColor: 0xFFF65A13),
      ),
    );
  });
}

class _PendingImage extends ImageProvider<Object> {
  final completer = _PendingCompleter();
  @override
  Future<Object> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  void resolveStreamForKey(
    ImageConfiguration configuration,
    ImageStream stream,
    Object key,
    ImageErrorListener handleError,
  ) => stream.setCompleter(completer);
}

class _PendingCompleter extends ImageStreamCompleter {
  bool get listening => hasListeners;
  void fail() => reportError(
    exception: const FormatException('unreadable pixels'),
    silent: true,
  );
}
