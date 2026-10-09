import 'dart:io';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_editing.dart';

import 'timer_ux_preview.dart';
import '../test/timer_editor_test.dart' as actions;

class _CaptureStorage extends SlideEditorLocalDataSource {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async {
    value == null ? values.remove(key) : values[key] = value;
  }
}

void main() {
  testWidgets('capture real timer editor and summary states', (tester) async {
    await (FontLoader('Pretendard')..addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/design/timer-ux-2026-10-09/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final entry in [
      ('interval-implemented', timerPreviewModule()),
      (
        'emom-implemented',
        editEmom(timerPreviewModule(), (
          seconds: 120,
          intervals: 3,
          rounds: 6,
          restSeconds: 30,
          includeFinalRest: true,
        )),
      ),
      (
        'summary-implemented',
        timerPreviewModule().copyWith(
          workSeconds: 420,
          restSeconds: 120,
          sets: 3,
        ),
      ),
    ]) {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: TimerUxPreview(
            key: ValueKey(entry.$1),
            module: entry.$2,
            localSource: _CaptureStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('임시저장을 사용할 수 없습니다'), findsNothing);
      if (entry.$1 == 'summary-implemented') {
        await capture(entry.$1);
      } else {
        await actions.tap(tester, 'slide-timer-summary');
        await capture(entry.$1);
        await actions.reveal(tester, 'timer-editor-total');
        await capture('${entry.$1}-result');
        if (entry.$1 == 'emom-implemented') {
          await actions.tap(tester, 'open-timer-builder');
          await actions.tap(tester, 'timer-mode-amrap');
          await capture('mode-change-implemented');
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
}
