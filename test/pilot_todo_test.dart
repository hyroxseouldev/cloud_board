import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/device/data/datasources/device_pairing_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preferences.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/display_refresh_button.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_countdown.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_control_panel.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/data/models/store_operations_models.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/store_welcome_board.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_templates_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_library_screen.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';

const pixel =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
final workout = Workout.empty(
  'w',
  const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
).copyWith(name: '수업');
void main() {
  test(
    'countdown and library metadata survive snapshots with legacy defaults',
    () {
      final edited = workout.copyWith(
        countdownSeconds: 17,
        countdownBackgroundColor: 0xFFEEDDEE,
        countdownImageSource: pixel,
        modules: [
          WorkoutModule.empty('m').copyWith(favorite: true, category: '워밍업'),
        ],
      );
      final json = WorkoutModel.fromEntity(edited).toJson();
      expect(WorkoutModel.fromJson(json).toEntity(), edited);
      json.remove('countdownSeconds');
      json.remove('countdownBackgroundColor');
      json.remove('countdownImageSource');
      final old = WorkoutModel.fromJson(json).toEntity();
      expect(old.countdownSeconds, 3);
      expect(old.countdownImageSource, isEmpty);
      json['countdownSeconds'] = 999;
      expect(WorkoutModel.fromJson(json).toEntity().countdownSeconds, 60);
      final brand = BrandTemplate.initial().copyWith(
        standbyFullscreen: true,
        standbyShowText: false,
        standbyTextColor: 0xFF000000,
        standbyTextPosition: 'center',
        standbyBackgroundColor: 0xFFFF0000,
      );
      expect(
        BrandTemplateModel.fromJson(
          BrandTemplateModel.fromEntity(brand).toJson(),
        ).toEntity(),
        brand,
      );
    },
  );
  test('calibration sanitizes bad values and image selection retains original bytes', () {
    final p = decodeDisplayPreferences({
      'enabled': true,
      'zoom': 99,
      'offsetX': double.nan,
      'safeInset': 1,
    });
    expect(p.zoom, 1.3);
    expect(p.offsetX, 0);
    expect(p.safeInset, .15);
    expect(decodeDisplayPreferences(null), const DisplayPreferences());
    final bytes = WorkoutImageSource.decode(pixel).bytes;
    expect(
      WorkoutImageSource.decode(WorkoutImageSource.fromBytes(bytes)).bytes,
      bytes,
    );
    expect(
      () => WorkoutImageSource.fromBytes(
        Uint8List(10 * 1024 * 1024),
        contentType: 'image/png',
      ),
      throwsFormatException,
    );
  });
  testWidgets(
    'refresh accepts mouse and keyboard, blocks duplicates and retries failure',
    (tester) async {
      var calls = 0;
      var pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DisplayRefreshButton(
              autofocus: true,
              onRefresh: () {
                calls++;
                return pending.future;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('새로고침'));
      await tester.pump();
      expect(calls, 1);
      expect(find.text('새로고침 중…'), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      expect(calls, 1);
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('연결 확인 후 다시 시도'), findsOneWidget);
      pending = Completer<void>();
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls, 2);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('새로고침'), findsOneWidget);
    },
  );
  testWidgets(
    'touch lock disables controls, page selection and swipe until long press',
    (tester) async {
      var locked = false;
      var actions = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: XonTheme.light,
          home: StatefulBuilder(
            builder: (context, setState) => WorkoutControlPanel(
              title: '수업',
              moduleCount: 2,
              currentModule: 0,
              paused: false,
              busy: false,
              locked: locked,
              onLockChanged: (v) => setState(() => locked = v),
              onPrevious: () => actions++,
              onNext: () => actions++,
              onToggle: () => actions++,
              onExit: () => actions++,
              onSelectModule: (_) async {
                actions++;
              },
              previewBuilder: (_, _) => const ColoredBox(color: Colors.black),
              timeline: const SizedBox(height: 36),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('터치 잠금'));
      await tester.pumpAndSettle();
      expect(locked, isTrue);
      await tester.tap(find.byTooltip('일시정지'));
      await tester.tap(find.text('종료하기'));
      final carousel = find.byKey(const ValueKey('workout-control-carousel'));
      await tester.ensureVisible(carousel);
      await tester.pumpAndSettle();
      await tester.drag(carousel, const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(actions, 0);
      final unlock = find.byKey(const ValueKey('unlock-controls'));
      await tester.ensureVisible(unlock);
      await tester.pumpAndSettle();
      await tester.tap(unlock);
      await tester.pump();
      expect(locked, isTrue);
      await tester.longPress(unlock);
      await tester.pumpAndSettle();
      expect(locked, isFalse);
      await tester.tap(find.byTooltip('일시정지'));
      expect(actions, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('full standby uses whole image bounds and can hide overlay', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final brand = BrandTemplate.initial().copyWith(
      promotionImageUrls: [pixel],
      standbyTransition: StandbyTransition.none,
      standbyImageFit: StandbyImageFit.cover,
      standbyShowText: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StoreWelcomeBoard(brand: brand, now: DateTime(2026, 9, 15)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(WorkoutImage)), const Size(1280, 720));
    expect(
      tester.widget<WorkoutImage>(find.byType(WorkoutImage)).fit,
      BoxFit.cover,
    );
    expect(find.text(brand.standbyMessage), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: StoreWelcomeBoard(
          brand: brand.copyWith(standbyShowText: true),
          now: DateTime(2026, 9, 15),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(brand.standbyMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'calibrated timer and text stay in safe bounds and countdown remains legible',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final module = WorkoutModule.empty('m').copyWith(
        name: '운동',
        appearance: const SlideAppearance(timerX: 1, timerY: 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutSlideCanvas(
            module: module,
            isRest: false,
            secondsLeft: 60,
            remainingMs: 60000,
            durationMs: 60000,
            set: 1,
            totalSets: 1,
            isPaused: true,
            brandL: '',
            brandR: '',
            scale: 1,
            displayPreferences: const DisplayPreferences(
              enabled: true,
              cover: true,
              safeInset: .15,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final timer = tester.getRect(find.byType(WorkoutSlideTimer));
      expect(timer.right, lessThanOrEqualTo(1280 * .85 + .1));
      expect(timer.bottom, lessThanOrEqualTo(720 * .85 + .1));
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutCountdown(
            workout: workout.copyWith(countdownBackgroundColor: 0xFFFFFFFF),
            seconds: 17,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final text = tester.element(find.text('17'));
      expect(DefaultTextStyle.of(text).style.color, Colors.black);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'library searches, favorites, renames, duplicates and inserts account templates',
    (tester) async {
      final source = _MemorySource();
      final repo = LocalSlideEditorRepository(source);
      await repo.saveTemplates('u', [
        WorkoutModule.empty('a').copyWith(name: '스쿼트', category: '하체'),
        WorkoutModule.empty('b').copyWith(name: '푸시업', category: '상체'),
      ]);
      WorkoutModule? inserted;
      final container = ProviderContainer(
        overrides: [
          slideEditorRepositoryProvider.overrideWithValue(repo),
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
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: XonTheme.light,
            home: SlideLibraryScreen(onSelect: (m) => inserted = m),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '슬라이드 검색'), '스쿼트');
      await tester.pumpAndSettle();
      expect(find.text('푸시업'), findsNothing);
      await tester.tap(find.byTooltip('즐겨찾기 추가'));
      await tester.pumpAndSettle();
      expect((await repo.loadTemplates('u')).first.favorite, isTrue);
      await tester.tap(find.text('삽입'));
      expect(inserted?.id, 'a');
      await tester.tap(find.byTooltip('슬라이드 관리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이름·분류 수정'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, '이름'),
        '스쿼트 준비',
      );
      await tester.tap(find.text('수정'));
      await tester.pumpAndSettle();
      expect((await repo.loadTemplates('u')).first.name, '스쿼트 준비');
      await tester.tap(find.byTooltip('슬라이드 관리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('복제'));
      await tester.pumpAndSettle();
      expect((await repo.loadTemplates('u')).length, 3);
      expect(await repo.loadTemplates('different-account'), isEmpty);
      source.fail = true;
      final controller = container.read(
        slideTemplatesControllerProvider('u').notifier,
      );
      final before = container
          .read(slideTemplatesControllerProvider('u'))
          .requireValue;
      expect(
        await controller.updateTemplate(before.first.copyWith(name: '실패')),
        isFalse,
      );
      expect(
        container.read(slideTemplatesControllerProvider('u')).requireValue,
        before,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}

class _MemorySource extends SlideEditorLocalDataSource {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async {
    if (fail) throw StateError('failed');
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}
