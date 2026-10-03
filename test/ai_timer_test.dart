import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_editor_style.dart';

import 'package:cloud_board/src/app/feature/ai_timer/data/datasources/ai_timer_data_source.dart';
import 'package:cloud_board/src/app/feature/ai_timer/data/repositories/ai_timer_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_timer/domain/entities/ai_timer_result.dart';
import 'package:cloud_board/src/app/feature/ai_timer/domain/repositories/ai_timer_repository.dart';
import 'package:cloud_board/src/app/feature/ai_timer/domain/usecases/ai_timer_actions.dart';
import 'package:cloud_board/src/app/feature/ai_timer/presentation/widgets/ai_timer_button.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image/image.dart' as img;

class FakeAiTimerRepository implements AiTimerRepository {
  bool premium = true;
  int calls = 0;
  Completer<AiTimerSuggestion>? pending;
  AiTimerSuggestion suggestion = const AiTimerSuggestion(
    workSeconds: 30,
    restSeconds: 15,
    sets: 4,
    name: '스쿼트',
    remaining: 99,
  );
  @override
  Future<AiTimerAccess> access() async => AiTimerAccess(
    premium: premium,
    enabled: true,
    remaining: 100,
    limit: 100,
    resetsAt: DateTime(2026, 11),
  );
  @override
  Future<AiTimerSuggestion> recognize(String imageSource) async {
    calls++;
    return pending != null ? pending!.future : suggestion;
  }
}

void main() {
  final original = WorkoutModule.empty('slide').copyWith(
    name: '기존 제목',
    imageSource: 'test-image',
    restSeconds: 10,
    workTextColor: '#123456',
  );
  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(834, 1194),
  ]) {
    testWidgets('AI review stays editable and scrollable at $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (const bool.fromEnvironment('AI_TIMER_CAPTURE')) {
        await (FontLoader('Pretendard')..addFont(
              rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
            ))
            .load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      }
      final repository = FakeAiTimerRepository();
      WorkoutModule? applied;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [aiTimerRepositoryProvider.overrideWithValue(repository)],
          child: RepaintBoundary(
            key: const ValueKey('ai-capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: SlideEditorStyle.theme(XonTheme.light),
              home: Scaffold(
                body: AiTimerButton(
                  module: original,
                  onApply: (value) {
                    applied = value;
                    return true;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ai-timer-button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('ai-timer-analyze')),
      );
      await tester.tap(find.byKey(const ValueKey('ai-timer-analyze')));
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('AI_TIMER_CAPTURE')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('ai-capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/cloudboard-ai-review-${size.width.toInt()}.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.ensureVisible(find.byKey(const ValueKey('ai-timer-apply')));
      await tester.tap(find.byKey(const ValueKey('ai-timer-apply')));
      await tester.pumpAndSettle();
      expect(applied?.sets, 4);
      expect(tester.takeException(), isNull);
    });
  }
  test(
    'apply changes only selected timing/title fields and guards stale edits',
    () {
      final result = applyAiTimer(
        original,
        workSeconds: 30,
        restSeconds: 15,
        sets: 4,
      );
      expect(result.imageSource, original.imageSource);
      expect(result.name, original.name);
      expect(result.appearance, original.appearance);
      expect(result.workTextColor, '#123456');
      expect(result.workSeconds, 30);
      expect(result.restSeconds, 15);
      expect(result.sets, 4);
      expect(
        canApplyAiTimer(original, original.copyWith(workSeconds: 31)),
        false,
      );
      expect(
        canApplyAiTimer(original, original.copyWith(imageSource: 'new-image')),
        false,
      );
      expect(
        canApplyAiTimer(original, original.copyWith(text: 'changed body')),
        true,
      );
      expect(
        () => applyAiTimer(original, workSeconds: 0, restSeconds: 0, sets: 1),
        throwsA(isA<AiTimerFailure>()),
      );
    },
  );
  test('non-premium cannot initiate recognition through use case', () async {
    final repository = FakeAiTimerRepository()..premium = false;
    await expectLater(
      AiTimerActions(repository).recognize('image'),
      throwsA(isA<AiTimerFailure>()),
    );
    expect(repository.calls, 0);
  });
  test('analysis image gets bounded dimensions; original bytes unchanged', () {
    final source = img.Image(width: 3000, height: 1000);
    img.fill(source, color: img.ColorRgb8(255, 255, 255));
    final bytes = Uint8List.fromList(img.encodePng(source));
    final before = Uint8List.fromList(bytes);
    final output = img.decodeJpg(prepareAiTimerImage(bytes))!;
    expect(output.width, 2048);
    expect(output.height, lessThanOrEqualTo(2048));
    expect(bytes, before);
  });
  Future<void> mount(
    WidgetTester tester,
    FakeAiTimerRepository repository,
    bool Function(WorkoutModule) onApply,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [aiTimerRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: Scaffold(
            body: AiTimerButton(module: original, onApply: onApply),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opening editor/sheet never analyzes; free users cannot run AI', (
    tester,
  ) async {
    final repository = FakeAiTimerRepository()..premium = false;
    await mount(tester, repository, (_) => true);
    expect(repository.calls, 0);
    await tester.tap(find.byKey(const ValueKey('ai-timer-button')));
    await tester.pumpAndSettle();
    expect(find.text('프리미엄 전용 기능이에요.'), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-timer-analyze')), findsNothing);
    expect(repository.calls, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'premium reviews and edits result; missing values block apply and cancel preserves slide',
    (tester) async {
      final repository = FakeAiTimerRepository()
        ..suggestion = const AiTimerSuggestion(
          workSeconds: 30,
          sets: 4,
          remaining: 99,
          warnings: ['휴식 시간을 확인해 주세요.'],
        );
      WorkoutModule? applied;
      await mount(tester, repository, (m) {
        applied = m;
        return true;
      });
      await tester.tap(find.byKey(const ValueKey('ai-timer-button')));
      await tester.pumpAndSettle();
      expect(repository.calls, 0);
      await tester.tap(find.byKey(const ValueKey('ai-timer-analyze')));
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(applied, isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('ai-timer-apply')));
      await tester.tap(find.byKey(const ValueKey('ai-timer-apply')));
      await tester.pumpAndSettle();
      expect(applied, isNull);
      await tester.enterText(find.byKey(const ValueKey('ai-timer-rest')), '20');
      await tester.ensureVisible(find.byKey(const ValueKey('ai-timer-apply')));
      await tester.tap(find.byKey(const ValueKey('ai-timer-apply')));
      await tester.pumpAndSettle();
      expect(applied?.workSeconds, 30);
      expect(applied?.restSeconds, 20);
      expect(applied?.sets, 4);
      expect(applied?.name, original.name);
      expect(applied?.imageSource, original.imageSource);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'closing a recognized result leaves original unchanged; pending work cannot double submit',
    (tester) async {
      final repository = FakeAiTimerRepository()
        ..pending = Completer<AiTimerSuggestion>();
      WorkoutModule? applied;
      await mount(tester, repository, (m) {
        applied = m;
        return true;
      });
      await tester.tap(find.byKey(const ValueKey('ai-timer-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ai-timer-analyze')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('ai-timer-analyze')), findsNothing);
      expect(repository.calls, 1);
      repository.pending!.complete(repository.suggestion);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(applied, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
