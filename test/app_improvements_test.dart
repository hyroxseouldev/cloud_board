import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/core/widgets/hex_color_field.dart';
import 'package:cloud_board/src/app/core/utils/hex_color.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/views/standby_settings_screen.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/folder_selector.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/standby_rotation.dart';
import 'package:cloud_board/src/app/feature/operations/data/models/store_operations_models.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/standby_slideshow.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/store_welcome_board.dart';

final module = WorkoutModule.empty('m')
    .copyWith(name: '새 운동 1', workSeconds: 90, restSeconds: 45, sets: 5);
final workout = Workout.empty(
  'w',
  const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
).copyWith(name: '수업', modules: [module]);
const pixel =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

void main() {
  testWidgets('system back asks before discarding the slide draft', (
    tester,
  ) async {
    final guard = ExitGuard();
    var saves = 0;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('목록으로 복귀')),
        ),
        GoRoute(
          path: '/edit',
          builder: (_, _) => SlideEditorScreen(
            workoutId: 'w',
            moduleId: 'm',
            guard: guard,
            request: SlideEditRequest(
              module: module,
              onSave: (_) async {
                saves++;
                return true;
              },
            ),
          ),
          onExit: (_, _) => guard.confirm(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    router.push('/edit');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '슬라이드 제목'),
      '저장하지 않은 제목',
    );
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('저장하지 않고 나갈까요?'), findsOneWidget);
    await tester.tap(find.text('계속 편집'));
    await tester.pumpAndSettle();
    expect(find.text('저장하지 않은 제목'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장 안 하고 나가기'));
    await tester.pumpAndSettle();
    expect(find.text('목록으로 복귀'), findsOneWidget);
    expect(saves, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'malformed standby images actually skip to next image or fallback',
    (tester) async {
      for (final sources in [
        ['#bad', pixel],
        ['#bad', '#also-bad'],
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: StandbySlideshow(
              brand: BrandTemplate.initial().copyWith(
                promotionImageUrls: sources,
                standbyTransition: StandbyTransition.none,
              ),
              now: DateTime.fromMillisecondsSinceEpoch(0),
              fallback: const Text('기본 대기 화면'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (sources.last == pixel) {
          expect(find.byKey(const ValueKey(1)), findsOneWidget);
        } else {
          expect(find.text('기본 대기 화면'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
  test('mm:ss accepts only complete valid values and round trips seconds', () {
    for (final entry in {
      '01:30': 90,
      '00:45': 45,
      '10:00': 600,
      '00:00': 0,
    }.entries) {
      expect(parseSlideTime(entry.key), entry.value);
      expect(formatSlideTime(entry.value), entry.key);
    }
    for (final invalid in [
      '',
      '1:30',
      '01:',
      '01:3',
      '00:60',
      '01:99',
      '-01:00',
      '01:00x',
      '1000:00',
    ]) {
      expect(parseSlideTime(invalid), isNull, reason: invalid);
    }
  });
  test('legacy slides default to visible timer and existing colors', () {
    final json = WorkoutModuleModel.fromEntity(module).toJson()
      ..remove('workGaugeColor')
      ..remove('restGaugeColor')
      ..remove('workTextColor')
      ..remove('restTextColor')
      ..remove('showTimer');
    final restored = WorkoutModuleModel.fromJson(json).toEntity();
    expect(restored.showTimer, isTrue);
    expect(slideColor(restored, rest: false, text: false), 0xFFFFFFFF);
    expect(slideColor(restored, rest: true, text: true), 0xFF0047FF);
    expect(
      slideColor(
        restored.copyWith(timerColorValue: 0xFF112233),
        rest: true,
        text: false,
      ),
      0xFF112233,
    );
    expect(
      slideColor(restored, rest: false, text: false, secondsLeft: 3),
      0xFFFF3B30,
    );
  });
  test('four styles survive JSON and playback snapshot serialization', () {
    final styled = module.copyWith(
      workGaugeColor: '#112233',
      restGaugeColor: '#445566',
      workTextColor: '#778899',
      restTextColor: '#AABBCC',
      showTimer: false,
    );
    final model = PlaybackSessionModel.fromWorkout(
      id: 's',
      ownerId: 'u',
      zoneId: 'main',
      targetDeviceIds: [],
      workout: workout.copyWith(modules: [styled]),
      stepIndex: 0,
      durationMs: 90000,
      deviceId: 'd',
    );
    final restored = PlaybackSessionModel.fromJson(
      jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>,
    ).toEntity().workout.modules.single;
    expect(restored, styled);
    expect(slideColor(restored, rest: false, text: false), 0xFF112233);
    expect(slideColor(restored, rest: true, text: false), 0xFF445566);
    expect(slideColor(restored, rest: false, text: true), 0xFF778899);
    expect(slideColor(restored, rest: true, text: true), 0xFFAABBCC);
    expect(isHexColor('#aAbB00'), isTrue);
    for (final bad in ['red', '#123', '#GGGGGG', '#12345678', ' #123456']) {
      expect(isHexColor(bad), isFalse);
    }
  });
  test('hidden timer progresses on server time and remaining sets recover', () {
    final hidden = workout.copyWith(
      modules: [module.copyWith(showTimer: false)],
    );
    final steps = buildPlayerSteps(hidden);
    final session = PlaybackSessionModel.fromWorkout(
      id: 's',
      ownerId: 'u',
      zoneId: 'main',
      targetDeviceIds: [],
      workout: hidden,
      stepIndex: 0,
      durationMs: 90000,
      deviceId: 'd',
    ).toEntity().copyWith(anchorServerMs: 0);
    for (final entry in {
      0: 5,
      90000: 4,
      135000: 4,
      225000: 3,
      540000: 1,
    }.entries) {
      final position = resolvePlaybackPosition(session, steps, entry.key);
      final step = steps[position.index];
      expect(
        remainingSets(
          set: step.set,
          total: step.totalSets,
          isRest: step.isRest,
        ),
        entry.value,
      );
    }
  });
  test('new slide titles do not collide', () {
    expect(nextSlideName([]), '새 운동 1');
    expect(nextSlideName([module, module.copyWith(name: '새 운동 2')]), '새 운동 3');
  });
  test(
    'standby timings loop, skip broken images and preserve legacy defaults',
    () {
      final brand = BrandTemplate.initial().copyWith(
        promotionImageUrls: ['a', 'b', 'c'],
        promotionDurationMinutes: [1, 2, 3],
        standbyTransition: StandbyTransition.slide,
      );
      int? at(int minute, {Set<int> failed = const {}}) => standbyImageIndex(
        brand,
        DateTime.fromMillisecondsSinceEpoch(minute * 60000),
        failed: failed,
      );
      expect(at(0), 0);
      expect(at(1), 1);
      expect(at(2), 1);
      expect(at(3), 2);
      expect(at(6), 0);
      expect(at(0, failed: {0}), 1);
      expect(at(0, failed: {0, 1, 2}), isNull);
      final model = BrandTemplateModel.fromEntity(brand);
      expect(BrandTemplateModel.fromJson(model.toJson()).toEntity(), brand);
      final legacy = model.toJson()
        ..remove('promotionDurationMinutes')
        ..remove('standbyTransition');
      final restored = BrandTemplateModel.fromJson(legacy).toEntity();
      expect(standbyMinutes(restored, 0), 1);
      expect(restored.standbyTransition, StandbyTransition.fade);
      expect(
        standbyImageIndex(BrandTemplate.initial(), DateTime.now()),
        isNull,
      );
      expect(
        standbyImageIndex(
          brand.copyWith(promotionImageUrls: ['a']),
          DateTime.now(),
        ),
        0,
      );
    },
  );

  for (final effect in StandbyTransition.values) {
    testWidgets('standby $effect renders, advances and skips image failure', (
      tester,
    ) async {
      final brand = BrandTemplate.initial().copyWith(
        promotionImageUrls: [pixel, pixel],
        promotionDurationMinutes: [1, 2],
        standbyTransition: effect,
      );
      Future<void> show(int minute) async {
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 400,
              height: 300,
              child: StandbySlideshow(
                brand: brand,
                now: DateTime.fromMillisecondsSinceEpoch(minute * 60000),
                fallback: const Text('기본 화면'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(0);
      expect(find.byKey(const ValueKey(0)), findsOneWidget);
      await show(1);
      expect(find.byKey(const ValueKey(1)), findsOneWidget);
      tester.widget<WorkoutImage>(find.byType(WorkoutImage)).onError!();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey(0)), findsOneWidget);
      tester.widget<WorkoutImage>(find.byType(WorkoutImage)).onError!();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('기본 화면'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final size in [
    const Size(390, 844),
    const Size(800, 1280),
    const Size(1280, 720),
    const Size(1920, 1080),
  ]) {
    testWidgets('welcome fits $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: StoreWelcomeBoard(
            brand: BrandTemplate.initial(),
            now: DateTime(2026),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('HEX picker and input synchronize and reject invalid input', (
    tester,
  ) async {
    String? changed;
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: key,
            child: HexColorField(
              label: '색상',
              initialValue: '#112233',
              onChanged: (v) => changed = v,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), '#AABBCC');
    await tester.tap(find.byTooltip('색상 컬러 피커'));
    await tester.pumpAndSettle();
    expect(find.text('#AABBCC'), findsWidgets);
    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();
    expect(changed, '#AABBCC');
    await tester.enterText(find.byType(TextFormField), '#xyz');
    expect(key.currentState!.validate(), isFalse);
  });
  testWidgets('slide local draft, failed save, retry and successful return', (
    tester,
  ) async {
    final saved = <WorkoutModule>[];
    final guard = ExitGuard();
    final request = SlideEditRequest(
      module: module,
      onSave: (value) async {
        saved.add(value);
        return saved.length > 1;
      },
    );
    final router = GoRouter(
      initialLocation: '/edit',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('목록')),
        ),
        GoRoute(
          path: '/editor/w',
          builder: (_, _) => const Scaffold(body: Text('목록')),
        ),
        GoRoute(
          path: '/edit',
          builder: (_, _) => SlideEditorScreen(
            workoutId: 'w',
            moduleId: 'm',
            guard: guard,
            request: request,
          ),
          onExit: (_, _) => guard.confirm(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    final title = find.widgetWithText(TextFormField, '슬라이드 제목');
    await tester.enterText(title, '수정 제목');
    await tester.pump();
    expect(saved, isEmpty);
    router.go('/');
    await tester.pumpAndSettle();
    expect(find.text('저장하지 않고 나갈까요?'), findsOneWidget);
    await tester.tap(find.text('계속 편집'));
    await tester.pumpAndSettle();
    expect(find.text('수정 제목'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, '저장');
    await tester.scrollUntilVisible(
      save,
      400,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saved.single.name, '수정 제목');
    expect(saved.single.workSeconds, 90);
    expect(saved.single.restSeconds, 45);
    expect(find.textContaining('편집 내용은 유지됩니다'), findsOneWidget);
    final retry = find.widgetWithText(FilledButton, '다시 저장');
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(saved.length, 2);
    expect(find.text('목록'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('folder cancel preserves selection and validates new names', (
    tester,
  ) async {
    var value = '기존';
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: FolderSelector(
              value: value,
              folders: const {'기존'},
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );
    Future<void> add() async {
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ 새 폴더 추가').last);
      await tester.pumpAndSettle();
    }

    await add();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(value, '기존');
    await add();
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    expect(find.text('폴더 이름을 입력해 주세요.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), ' 기존 ');
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    expect(find.text('같은 이름의 폴더가 있습니다.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), ' 신규 ');
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    expect(value, '신규');
    expect(tester.takeException(), isNull);
  });

  for (final id in ['w', 'new']) {
    testWidgets(
      '$id workout child route saves once and refreshes parent draft',
      (tester) async {
        final saved = <Workout>[];
        final parentGuard = ExitGuard(), childGuard = ExitGuard();
        final router = GoRouter(
          initialLocation: '/editor/$id',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('홈')),
            ),
            GoRoute(
              path: '/editor/:id',
              builder: (_, state) => WorkoutEditorScreen(
                workoutId: state.pathParameters['id']!,
                guard: parentGuard,
              ),
              onExit: (_, _) => parentGuard.confirm(),
              routes: [
                GoRoute(
                  path: 'slides/:moduleId',
                  builder: (_, state) => SlideEditorScreen(
                    workoutId: id,
                    moduleId: state.pathParameters['moduleId']!,
                    guard: childGuard,
                    request: state.extra as SlideEditRequest,
                  ),
                  onExit: (_, _) => childGuard.confirm(),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith(
                (ref) => Stream.value(
                  const AuthUser(
                    id: 'u',
                    email: 'coach@example.com',
                    displayName: 'Coach',
                    photoUrl: null,
                  ),
                ),
              ),
              workoutControllerProvider.overrideWith(_TestWorkouts.new),
              workoutActionControllerProvider.overrideWith(
                () => _SaveWorkouts(saved),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        if (id == 'new') {
          await scrollTo(tester, find.text('슬라이드 추가'));
          await tester.tap(find.text('슬라이드 추가'));
          await tester.pumpAndSettle();
        }
        await scrollTo(tester, find.text('새 운동 1'));
        await tester.tap(find.text('새 운동 1'));
        await tester.pumpAndSettle();
        expect(find.text('슬라이드 편집'), findsOneWidget);
        expect(find.text('저장하지 않고 나갈까요?'), findsNothing);
        await tester.enterText(
          find.widgetWithText(TextFormField, '슬라이드 제목'),
          '하위 페이지에서 수정',
        );
        await tester.pump();
        expect(saved, isEmpty);
        final save = find.widgetWithText(FilledButton, '저장');
        await tester.scrollUntilVisible(
          save,
          400,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pump(const Duration(milliseconds: 400));
        if (id == 'new') {
          expect(find.text('워크아웃 이름이 필요합니다'), findsOneWidget);
          await tester.enterText(
            find.widgetWithText(TextFormField, '저장할 워크아웃 이름'),
            '새 수업',
          );
          await tester.tap(find.text('계속 저장'));
          await tester.pumpAndSettle();
        }
        await tester.pumpAndSettle();
        expect(saved.length, 1);
        expect(saved.single.modules.single.name, '하위 페이지에서 수정');
        expect(find.text('슬라이드 편집'), findsNothing);
        await tester.ensureVisible(find.text('하위 페이지에서 수정'));
        await tester.pumpAndSettle();
        expect(find.text('하위 페이지에서 수정'), findsOneWidget);
        expect(find.text('저장됨'), findsOneWidget);
        if (id == 'w') {
          await tester.tap(find.byTooltip('슬라이드 메뉴').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('복제'));
          await tester.pumpAndSettle();
          expect(find.text('새 운동 1'), findsOneWidget);
          expect(saved.length, 1);
          Future<void> deleteFirst() async {
            await tester.tap(find.byTooltip('슬라이드 메뉴').first);
            await tester.pumpAndSettle();
            await tester.tap(find.text('삭제'));
            await tester.pumpAndSettle();
          }

          await deleteFirst();
          expect(find.text('슬라이드를 삭제할까요?'), findsOneWidget);
          await tester.tap(find.text('취소'));
          await tester.pumpAndSettle();
          expect(find.text('하위 페이지에서 수정'), findsOneWidget);
          await deleteFirst();
          await tester.tap(find.widgetWithText(FilledButton, '삭제'));
          await tester.pumpAndSettle();
          expect(find.text('하위 페이지에서 수정'), findsNothing);
          expect(find.text('새 운동 1'), findsOneWidget);
          expect(saved.length, 1);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'standby draft preserves image duration through reorder, failure and retry',
    (tester) async {
      final saved = <BrandTemplate>[];
      final guard = ExitGuard();
      final initial = BrandTemplate.initial().copyWith(
        promotionImageUrls: [pixel, pixel],
        promotionDurationMinutes: [1, 3],
      );
      final router = GoRouter(
        initialLocation: '/standby',
        routes: [
          GoRoute(
            path: '/operations',
            builder: (_, _) => const Scaffold(body: Text('운영 목록')),
          ),
          GoRoute(
            path: '/standby',
            builder: (_, _) => StandbySettingsScreen(guard: guard),
            onExit: (_, _) => guard.confirm(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            brandTemplateProvider.overrideWith((ref) => Stream.value(initial)),
            storeOperationsActionControllerProvider.overrideWith(
              () => _SaveBrand(saved),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!(0, 1);
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
      final save = find.widgetWithText(FilledButton, '저장');
      await tester.scrollUntilVisible(
        save,
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved.single.promotionDurationMinutes, [3, 1]);
      expect(find.textContaining('변경사항은 유지됩니다'), findsOneWidget);
      final retry = find.widgetWithText(FilledButton, '다시 저장');
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(saved.length, 2);
      expect(find.text('운영 목록'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

class _TestWorkouts extends WorkoutController {
  @override
  Future<List<Workout>> build() async => [workout];
}

class _SaveWorkouts extends WorkoutActionController {
  _SaveWorkouts(this.saved);
  final List<Workout> saved;
  @override
  Future<Workout?> save(Workout value) async {
    saved.add(value);
    ref.read(workoutControllerProvider.notifier).upsert(value);
    return value;
  }
}

class _SaveBrand extends StoreOperationsActionController {
  _SaveBrand(this.saved);
  final List<BrandTemplate> saved;
  @override
  Future<bool> saveBrandTemplate(BrandTemplate value) async {
    saved.add(value);
    return saved.length > 1;
  }
}
