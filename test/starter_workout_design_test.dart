import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/starter_exercise_artwork.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/starter_workouts.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const author = WorkoutAuthor(id: 'test', displayName: '', photoUrl: null);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Pretendard')
          ..addFont(
            rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
          )
          ..addFont(
            rootBundle.load('assets/fonts/pretendard/Pretendard-Bold.otf'),
          ))
        .load();
  });

  test('new examples keep real timings and match each listed movement', () {
    final movements = <StarterExercise>{};
    for (final starter in StarterWorkout.values) {
      final workout = starter.create(author);
      expect(workout.modules, hasLength(3));
      expect(workout.modules.map((m) => m.workSeconds), [
        180,
        starter == StarterWorkout.interval ? 40 : 480,
        120,
      ]);
      expect(
        workout.modules.map(workoutModuleDuration).reduce((a, b) => a + b),
        starter == StarterWorkout.interval ? 640 : 780,
      );
      expect(
        starter
            .createDemo()
            .modules
            .map(workoutModuleDuration)
            .reduce((a, b) => a + b),
        60,
      );
      for (final module in workout.modules) {
        expect(isIllustratedStarterDesign(module), isTrue);
        expect(slideDesignError(module), isNull);
        expect(module.designBackgroundColor, 0xFFFFFDF8);
        expect(module.designAccentColor, 0xFF526B60);
        expect(slideDesignOptions(module), contains(module.designTemplate));
        for (final line in slideDesignLines(module.text)) {
          expect(starterExerciseForLine(line), isNotNull, reason: line);
          movements.add(starterExerciseForLine(line)!);
        }
        final metrics = measureSlideDesign(module);
        expect(
          metrics.readable,
          isTrue,
          reason: '${starter.key}/${module.name}: ${metrics.warning}',
        );
        expect(
          metrics.textRuns.where((r) => r.role == 'body').map((r) => r.value),
          slideDesignLines(module.text),
        );
        for (final run in metrics.textRuns) {
          expect(
            run.rect.overlaps(metrics.timerExclusion!),
            isFalse,
            reason: run.value,
          );
        }
      }
    }
    expect(movements, StarterExercise.values.toSet());
    expect(starterExerciseForLine('스쿼트 대신 버피'), isNull);
    expect(starterExerciseForLine('코치가 바꾼 운동'), isNull);
  });

  test('saved starter IDs do not opt into the new artwork and edits survive serialization', () {
    final legacy = StarterWorkout.basics
        .create(author)
        .modules
        .first
        .copyWith(
          designTemplate: 'studio-v1-numbered',
          name: '수정한 웜업',
          text: '코치가 저장한 운동',
          designAccentColor: 0xFF2563EB,
          workSeconds: 123,
        );
    final restored = WorkoutModuleModel.fromJson(
      WorkoutModuleModel.fromEntity(legacy).toJson(),
    ).toEntity();
    expect(restored, legacy);
    expect(isIllustratedStarterDesign(restored), isFalse);
    final fresh = StarterWorkout.basics.createOwned(author).modules[1];
    expect(
      WorkoutModuleModel.fromJson(WorkoutModuleModel.fromEntity(fresh).toJson())
          .toEntity(),
      fresh,
    );
    final expanded = fresh.copyWith(text: '버피\n런지\n달리기\n걷기\n플랭크');
    expect(
      measureSlideDesign(expanded).sections.expand((s) => s.lines),
      slideDesignLines(expanded.text),
    );
    expect(slideDesignError(expanded), isNull);
  });

  testWidgets('PNG fallback keeps editable content and never bakes the timer', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final module = StarterWorkout.basics.createOwned(author).modules.first;
      final prepared = await prepareSlideDesign(module);
      expect(prepared.name, module.name);
      expect(prepared.text, module.text);
      expect(prepared.workSeconds, 180);
      expect(prepared.designTemplate, starterIllustratedDesign);
      expect(prepared.imageSource, startsWith('data:image/png;base64,'));
      final pixels = img.decodePng(
        base64Decode(prepared.imageSource.split(',').last),
      )!;
      final center = slideTimerGeometry(
        module,
        const Size(1920, 1080),
      ).timer!.center;
      final pixel = pixels.getPixel(center.dx.round(), center.dy.round());
      expect(
        [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()],
        [255, 253, 248],
      );
      expect(
        await renderSlideDesign(module.copyWith(workSeconds: 8)),
        prepared.imageSource,
      );
      final edited = module.copyWith(text: '플랭크\n걷기\n호흡 정리');
      expect(await renderSlideDesign(edited), isNot(prepared.imageSource));
      expect(
        starterExerciseForLine(edited.text.split('\n').first),
        StarterExercise.plank,
      );
      final unknown = prepared.copyWith(designTemplate: 'future-v99-design');
      expect(hasSlideDesign(unknown), isFalse);
      expect(await renderSlideDesign(unknown), prepared.imageSource);
    });
  });

  for (final width in [320.0, 1280.0]) {
    testWidgets('preview renders all examples at width $width', (tester) async {
      tester.view.physicalSize = Size(width, width * 9 / 16);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      for (final starter in StarterWorkout.values) {
        final workout = starter.create(author);
        for (var index = 0; index < workout.modules.length; index++) {
          final module = workout.modules[index];
          await tester.pumpWidget(
            MaterialApp(
              theme: XonTheme.light,
              home: Scaffold(
                body: RepaintBoundary(
                  key: boundary,
                  child: WorkoutSlidePreview(module: module, isRest: false),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(durationLabel(module.workSeconds)), findsOneWidget);
          expect(tester.takeException(), isNull);
          final canvas = tester.widget<WorkoutSlideCanvas>(
            find.byType(WorkoutSlideCanvas),
          );
          expect(canvas.module, module);
          if (const bool.fromEnvironment('STARTER_CAPTURE')) {
            await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/sta-186/${starter.key}-$index-${width.toInt()}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
      }
    });
  }

  testWidgets('live example changes remaining time and makes rest explicit', (
    tester,
  ) async {
    final module = StarterWorkout.basics.createDemo().modules.first;
    Widget frame(int seconds, bool rest) => MaterialApp(
      theme: XonTheme.light,
      home: SizedBox(
        width: 800,
        height: 450,
        child: WorkoutSlideCanvas(
          module: module,
          isRest: rest,
          secondsLeft: seconds,
          remainingMs: seconds * 1000,
          durationMs: (rest ? 4 : 8) * 1000,
          set: 1,
          totalSets: 2,
          isPaused: true,
          brandL: '',
          brandR: '',
          scale: .625,
        ),
      ),
    );
    await tester.pumpWidget(frame(8, false));
    expect(find.text(durationLabel(8)), findsOneWidget);
    await tester.pumpWidget(frame(5, false));
    expect(find.text(durationLabel(5)), findsOneWidget);
    expect(find.text(durationLabel(8)), findsNothing);
    await tester.pumpWidget(frame(4, true));
    expect(find.text('휴식 · 1/2세트'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'imported example keeps class, instruction and exercise text editable',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final module = StarterWorkout.basics.createOwned(author).modules[1];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slideEditorRepositoryProvider.overrideWithValue(
              LocalSlideEditorRepository(SlideEditorLocalDataSource()),
            ),
          ],
          child: MaterialApp(
            theme: XonTheme.light,
            builder: XonTheme.responsiveBuilder,
            home: SlideEditorScreen(
              workoutId: 'starter-editor',
              moduleId: module.id,
              guard: ExitGuard(),
              request: SlideEditRequest(
                module: module,
                onSave: (_) async => false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('slide-editor-tabs')),
          matching: find.text('배경'),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = find
          .descendant(
            of: find.byKey(const ValueKey('slide-editor-settings')),
            matching: find.byType(Scrollable),
          )
          .first;
      for (final (key, value) in [
        ('studio-class-label', '내 첫 수업'),
        ('studio-subtitle', '내 속도로 진행해요'),
        ('slide-section-0-lines', '걷기\n스쿼트\n플랭크'),
      ]) {
        final field = find.byKey(ValueKey(key));
        await tester.scrollUntilVisible(
          field.hitTestable(),
          160,
          scrollable: scroll,
        );
        await tester.pumpAndSettle();
        await tester.enterText(field, value);
        await tester.pumpAndSettle();
      }
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SlideEditorScreen)),
      );
      final edited = container
          .read(
            slideEditorControllerProvider('starter-editor', module, 'local'),
          )
          .module;
      expect(edited.designTemplate, starterIllustratedDesign);
      expect(edited.designHeaderLabel, '내 첫 수업');
      expect(edited.designSubtitle, '내 속도로 진행해요');
      expect(edited.text, '걷기\n스쿼트\n플랭크');
      expect(edited.workSeconds, 480);
      expect(
        measureSlideDesign(edited).textRuns
            .where((r) => r.role == 'body')
            .map((r) => r.value),
        ['걷기', '스쿼트', '플랭크'],
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
