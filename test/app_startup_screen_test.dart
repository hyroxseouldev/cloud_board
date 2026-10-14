import 'dart:async';
import 'dart:convert';

import 'package:cloud_board/src/app/core/widgets/app_startup_screen.dart';
import 'package:cloud_board/src/app/core/widgets/soft_rhythm_mark.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cold start holds native frame until the mark is decoded', (
    tester,
  ) async {
    // Keep both asset resolution and native decoding outside FakeAsync.
    await tester.runAsync(() async {
      final bundle = _DelayedMarkBundle();
      tester.binding.resetFirstFrameSent();
      await tester.pumpWidget(_startupWithBundle(bundle));
      await bundle.requested.future.timeout(const Duration(seconds: 5));

      expect(tester.binding.sendFramesToEngine, isFalse);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.sendFramesToEngine, isFalse);

      final decoded = _markDecoded(tester);
      bundle.complete();
      await decoded.timeout(const Duration(seconds: 5));
      await tester.pump();

      expect(tester.binding.sendFramesToEngine, isTrue);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      // The startup precache and visible Image must share the same cache key.
      expect(bundle.markLoads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.resetFirstFrameSent();
      expect(tester.binding.sendFramesToEngine, isTrue);
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('fast bootstrap releases native frame before a late decode', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final bundle = _DelayedMarkBundle();
      tester.binding.resetFirstFrameSent();
      await tester.pumpWidget(_startupWithBundle(bundle));
      await bundle.requested.future.timeout(const Duration(seconds: 5));
      expect(tester.binding.sendFramesToEngine, isFalse);
      final decoded = _markDecoded(tester);

      await tester.pumpWidget(const MaterialApp(home: Text('Ready')));
      tester.binding.resetFirstFrameSent();
      expect(tester.binding.sendFramesToEngine, isTrue);
      expect(find.text('Ready'), findsOneWidget);

      // A late completion must not call allowFirstFrame a second time.
      bundle.complete();
      await decoded.timeout(const Duration(seconds: 5));
      await tester.pump();
      tester.binding.resetFirstFrameSent();
      expect(tester.binding.sendFramesToEngine, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable mark releases native frame and preserves retry', (
    tester,
  ) async {
    final failure = StateError('Fixture startup mark is unavailable');
    await tester.runAsync(() async {
      final bundle = _DelayedMarkBundle();
      tester.binding.resetFirstFrameSent();
      await tester.pumpWidget(_startupWithBundle(bundle, onRetry: () {}));
      await bundle.requested.future.timeout(const Duration(seconds: 5));
      expect(tester.binding.sendFramesToEngine, isFalse);

      Object? reportedFailure;
      final decoded = _markDecoded(
        tester,
        onError: (error, stackTrace) => reportedFailure = error,
      );
      bundle.fail(failure);
      await decoded.timeout(const Duration(seconds: 5));
      await tester.pump();

      expect(reportedFailure, same(failure));
      expect(tester.binding.sendFramesToEngine, isTrue);
      expect(find.text('다시 시도'), findsOneWidget);
      // The precache error listener handles the failure; the hold still ends.
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.resetFirstFrameSent();
      expect(tester.binding.sendFramesToEngine, isTrue);
    });
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(402, 874),
    const Size(1024, 1366),
    const Size(1920, 1080),
    const Size(568, 320),
  ]) {
    testWidgets('startup mark stays centered and bounded at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: AppStartupScreen()));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == '앱 준비 중',
        ),
        findsOneWidget,
      );
      final mark = find.byType(SoftRhythmMark);
      expect(tester.getSize(mark), const Size.square(128));
      expect(tester.getCenter(mark), Offset(size.width / 2, size.height / 2));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'retry is accessible with large text and does not move the mark',
    (tester) async {
      tester.view.physicalSize = const Size(568, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: AppStartupScreen(onRetry: () => retries++),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final mark = find.byType(SoftRhythmMark);
      expect(tester.getCenter(mark), const Offset(284, 160));
      await tester.ensureVisible(find.text('다시 시도'));
      await tester.tap(find.text('다시 시도'));
      expect(retries, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _startupWithBundle(_DelayedMarkBundle bundle, {VoidCallback? onRetry}) =>
    DefaultAssetBundle(
      bundle: bundle,
      child: MaterialApp(home: AppStartupScreen(onRetry: onRetry)),
    );

Future<void> _markDecoded(WidgetTester tester, {ImageErrorListener? onError}) {
  final element = find.byType(Image).evaluate().single;
  return precacheImage(
    (element.widget as Image).image,
    element,
    onError: onError,
  );
}

class _DelayedMarkBundle extends CachingAssetBundle {
  final requested = Completer<void>();
  final _mark = Completer<ByteData>();
  var markLoads = 0;

  static final _manifest = const StandardMessageCodec().encodeMessage(
    <String, Object?>{},
  )!;

  @override
  Future<ByteData> load(String key) {
    if (key == SoftRhythmMark.asset) {
      markLoads++;
      if (!requested.isCompleted) requested.complete();
      return _mark.future;
    }
    if (key == 'AssetManifest.bin') return SynchronousFuture(_manifest);
    if (key == 'AssetManifest.bin.json') {
      return SynchronousFuture(
        ByteData.sublistView(
          Uint8List.fromList(
            utf8.encode(
              jsonEncode(base64Encode(Uint8List.sublistView(_manifest))),
            ),
          ),
        ),
      );
    }
    return rootBundle.load(key);
  }

  void complete() => _mark.complete(
    ByteData.sublistView(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    ),
  );

  void fail(Object error) => _mark.completeError(error, StackTrace.current);
}
