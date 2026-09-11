import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_rehearsal.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/slide_editor_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_rehearsal_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_rehearsal_screen.dart';

final original = WorkoutModule.empty('slide')
    .copyWith(name: '테스트 슬라이드', workSeconds: 5, restSeconds: 2, sets: 2);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'appearance survives storage JSON and legacy defaults stay compatible',
    () {
      final value = original.copyWith(
        appearance: const SlideAppearance(
          timerX: .22,
          timerY: .65,
          timerSize: 1.25,
          ringWidth: 18,
          showTitle: false,
          showBody: false,
          showBrand: false,
          titleColor: 0xFF123456,
          bodyColor: 0xFF234567,
          setsColor: 0xFF345678,
          brandColor: 0xFF456789,
        ),
      );
      final json = jsonDecode(
        jsonEncode(WorkoutModuleModel.fromEntity(value).toJson()),
      ) as Map<String, dynamic>;
      expect(WorkoutModuleModel.fromJson(json).toEntity(), value);
      json.remove('appearance');
      expect(
        WorkoutModuleModel.fromJson(json).toEntity().appearance,
        const SlideAppearance(),
      );
      expect(
        const SlideAppearanceModel(
          timerSize: 50,
          timerX: -1,
          ringWidth: 200,
        ).toEntity().timerSize,
        1.6,
      );
    },
  );

  test('style import preserves content, timing, identity and images', () {
    final target = original.copyWith(
      imageSource: 'existing-image',
      text: 'existing-text',
    );
    final style = WorkoutModule.empty('style').copyWith(
      appearance: const SlideAppearance(showTitle: false, timerY: .7),
      workGaugeColor: '#00FF00',
    );
    final applied = applySlideStyle(target, style);
    expect(applied.id, target.id);
    expect(applied.name, target.name);
    expect(applied.text, target.text);
    expect(applied.imageSource, target.imageSource);
    expect(workoutModuleDuration(applied), workoutModuleDuration(target));
    expect(applied.appearance, style.appearance);
  });

  test(
    'rehearsal follows actual work/rest boundaries and omits final rest',
    () {
      expect(workoutModuleDuration(original), 12);
      expect(rehearsalFrame(original, 4999).secondsLeft, 1);
      expect(rehearsalFrame(original, 5000).isRest, isTrue);
      expect(rehearsalFrame(original, 7000).set, 2);
      expect(rehearsalFrame(original, 7000).isRest, isFalse);
      expect(rehearsalFrame(original, 12000).remainingMs, 0);
      final multiple = original.copyWith(
        intervalBlocks: const [
          WorkoutIntervalBlock(
            id: 'one',
            workSeconds: 5,
            restSeconds: 2,
            sets: 2,
          ),
          WorkoutIntervalBlock(
            id: 'two',
            workSeconds: 3,
            restSeconds: 0,
            sets: 1,
          ),
        ],
      );
      expect(rehearsalFrame(multiple, 12000).blockIndex, 1);
      expect(rehearsalFrame(multiple, 15000).remainingMs, 0);
    },
  );

  test(
    'draft writes and clear are ordered, styles are scoped and omit image',
    () async {
      final repository = LocalSlideEditorRepository(
        SlideEditorLocalDataSource(),
      );
      final write = repository.saveDraft('owner/slide', original);
      final clear = repository.clearDraft('owner/slide');
      await Future.wait([write, clear]);
      expect(await repository.loadDraft('owner/slide'), isNull);
      await repository.saveDraft('owner-a/slide', original);
      expect(await repository.loadDraft('owner-b/slide'), isNull);
      await repository.saveStyles('owner-a', [original]);
      expect(await repository.loadStyles('owner-b'), isEmpty);
    },
  );

  test('undo redo, recovery across controllers and successful save clears draft', () async {
    final repository = LocalSlideEditorRepository(SlideEditorLocalDataSource());
    ProviderContainer container() => ProviderContainer(
      overrides: [slideEditorRepositoryProvider.overrideWithValue(repository)],
    );
    final first = container();
    final provider = slideEditorControllerProvider(
      'workout',
      original,
      'owner',
    );
    final subscription = first.listen(provider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    final actions = first.read(provider.notifier);
    final edited = original.copyWith(
      appearance: const SlideAppearance(timerY: .6),
    );
    actions.update(edited);
    actions.undo();
    expect(first.read(provider).module, original);
    actions.redo();
    expect(first.read(provider).module, edited);
    await actions.flush();
    await actions.saveStyle('saved');
    expect(first.read(provider).styles.single.imageSource, isEmpty);
    subscription.close();
    first.dispose();
    final second = container();
    addTearDown(second.dispose);
    second.listen(provider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(second.read(provider).recovery, edited);
    final recovered = second.read(provider.notifier);
    await recovered.flush();
    final draftKey = base64Url.encode(utf8.encode('owner/workout/slide'));
    expect(
      await repository.loadDraft(draftKey),
      edited,
      reason:
          'Backgrounding while recovery is pending must preserve the old draft',
    );
    recovered.restore();
    expect(second.read(provider).module, edited);
    await recovered.markSaved(edited);
    expect(second.read(provider).dirty, isFalse);
    final third = container();
    addTearDown(third.dispose);
    final savedProvider = slideEditorControllerProvider(
      'workout',
      edited,
      'owner',
    );
    third.listen(savedProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(third.read(savedProvider).recovery, isNull);
  });

  for (final size in [
    const Size(390, 844),
    const Size(834, 1210),
    const Size(1194, 834),
  ]) {
    testWidgets(
      'editor full-width preview and save fit $size and title visibility can undo',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: SlideEditorScreen(
                workoutId: 'w',
                moduleId: original.id,
                guard: ExitGuard(),
                request: SlideEditRequest(
                  module: original,
                  onSave: (_) async => false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(WorkoutSlidePreview), findsOneWidget);
        expect(
          tester.getSize(find.byType(WorkoutSlidePreview)).width,
          closeTo(size.width - 80, 1),
        );
        expect(find.byTooltip('전체 화면 · 시험 재생'), findsOneWidget);
        expect(find.text('시험 재생'), findsNothing);
        expect(find.text('슬라이드 설정'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('slide-preview-toggle')));
        await tester.pumpAndSettle();
        expect(find.byType(WorkoutSlidePreview), findsNothing);
        await tester.tap(find.byKey(const ValueKey('slide-preview-toggle')));
        await tester.pumpAndSettle();
        expect(find.byType(WorkoutSlidePreview), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, '저장').hitTestable(),
          findsOneWidget,
        );
        await scrollSettingsTo(tester, find.text('화면'));
        await tester.tap(find.text('화면'));
        await tester.pumpAndSettle();
        final title = find.widgetWithText(SwitchListTile, '화면 제목 표시');
        final scroll = find
            .descendant(
              of: find.byKey(const ValueKey('slide-editor-settings')),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          title.hitTestable(),
          250,
          scrollable: scroll,
        );
        await tester.pumpAndSettle();
        await tester.tap(title);
        await tester.pumpAndSettle();
        await scrollSettingsToTop(tester);
        expect(
          tester
              .widget<WorkoutSlidePreview>(find.byType(WorkoutSlidePreview))
              .module
              .appearance
              .showTitle,
          isFalse,
        );
        expect(find.byType(WorkoutSlidePreview).hitTestable(), findsOneWidget);
        await tester.tap(find.byTooltip('실행 취소'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<WorkoutSlidePreview>(find.byType(WorkoutSlidePreview))
              .module
              .appearance
              .showTitle,
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'local draft can be restored through the editor after reopening',
    (tester) async {
      Future<void> open() async {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            child: MaterialApp(
              home: SlideEditorScreen(
                workoutId: 'recovery-workout',
                moduleId: original.id,
                guard: ExitGuard(),
                request: SlideEditRequest(
                  module: original,
                  onSave: (_) async => false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await open();
      await tester.enterText(
        find.widgetWithText(TextFormField, '슬라이드 제목'),
        '복구할 제목',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('저장 필요 · 이 기기에 임시저장됨'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await open();
      expect(find.text('이 기기에 저장하지 않은 편집 내용이 있습니다.'), findsOneWidget);
      await tester.tap(find.text('복원'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, '슬라이드 제목'),
            )
            .controller!
            .text,
        '복구할 제목',
      );
      await tester.tap(find.byTooltip('실행 취소'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, '슬라이드 제목'),
            )
            .controller!
            .text,
        original.name,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved style can be selected without changing the slide duration',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SlideEditorScreen(
              workoutId: 'styles-workout',
              moduleId: original.id,
              guard: ExitGuard(),
              request: SlideEditRequest(
                module: original,
                onSave: (_) async => false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await scrollSettingsTo(tester, find.text('화면'));
      await tester.tap(find.text('화면'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('스타일 저장'));
      await tester.tap(find.text('스타일 저장'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, '스타일 이름'),
        '테스트 스타일',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '스타일 저장'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('스타일 불러오기'));
      await tester.tap(find.text('스타일 불러오기'));
      await tester.pumpAndSettle();
      expect(find.text('테스트 스타일'), findsOneWidget);
      await tester.tap(find.text('초록 링 · 검정 숫자'));
      await tester.pumpAndSettle();
      await scrollSettingsToTop(tester);
      final applied = tester
          .widget<WorkoutSlidePreview>(find.byType(WorkoutSlidePreview))
          .module;
      expect(applied.workTextColor, '#000000');
      expect(workoutModuleDuration(applied), 12);
      expect(applied.name, original.name);
      await tester.tap(find.byTooltip('실행 취소'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WorkoutSlidePreview>(find.byType(WorkoutSlidePreview))
            .module
            .workTextColor,
        original.workTextColor,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rehearsal seeking and closing never writes a production session',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SlideRehearsalScreen(
              module: original.copyWith(beep: false),
              brandL: '',
              brandR: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('마지막 3초'));
      await tester.pump();
      expect(find.byKey(const ValueKey('slide-time-text')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('slide-time-text'))).data,
        '0:03',
      );
      await tester.tap(find.text('휴식으로'));
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('slide-time-text'))).data,
        '0:02',
      );
      await tester.tap(find.text('재생'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('일시정지'), findsOneWidget);
      await tester.tap(find.text('일시정지'));
      await tester.pump();
      final context = tester.element(find.byType(SlideRehearsalScreen));
      final container = ProviderScope.containerOf(context);
      expect(
        container
            .read(
              slideRehearsalControllerProvider(original.copyWith(beep: false)),
            )
            .playing,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> scrollSettingsTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('slide-editor-settings')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> scrollSettingsToTop(WidgetTester tester) async {
  tester
      .widget<ListView>(find.byKey(const ValueKey('slide-editor-settings')))
      .controller!
      .jumpTo(0);
  await tester.pumpAndSettle();
}
