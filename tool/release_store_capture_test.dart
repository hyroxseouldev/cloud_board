// Review-only Android-styled production widgets. These are NOT installed APK
// screenshots. The release asset pack remains blocked until native captures
// and their candidate/device evidence replace these inputs.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:cloud_board/src/app/core/router/app_router.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/views/explore_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_rehearsal_screen.dart';

import '../test/support/main_navigation_fixture.dart';
import '../test/slide_editor_features_test.dart' show scrollSettingsTo;
import '../test/timer_editor_test.dart' as timer_actions;
import 'timer_ux_preview.dart';

const _directory = 'docs/release/1.1.0/google-play/source-review';

void main() {
  testWidgets('capture 1.1.0 Android store review sources', (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final font in [
      ('Pretendard', 'assets/fonts/pretendard/Pretendard-Regular.otf'),
      (
        'RacingSansOne',
        'assets/fonts/racing_sans_one/RacingSansOne-Regular.ttf',
      ),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (_) async => const StandardMessageCodec().encodeMessage([null]),
        );
    final captured = <Map<String, Object>>[];
    Future<void> save(GlobalKey boundary, String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: name);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$_directory/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        captured.add({
          'file': '$name.png',
          'width': image.width,
          'height': image.height,
          'kind': 'flutter-widget-review',
        });
        image.dispose();
      });
    }

    final data = NavigationPreviewData();
    // Neutral local fixtures: no real customer data or third-party branding.
    final demo = data.repository.items.first.copyWith(
      name: '전신 서킷',
      folder: '그룹 수업',
      brandL: 'CloudBoard',
      brandR: 'MOVE TOGETHER',
      modules: [
        _module.copyWith(
          id: 'warmup',
          name: '워밍업',
          workSeconds: 180,
          sets: 1,
          restSeconds: 0,
        ),
        _module,
        _module.copyWith(id: 'core', name: '코어 트레이닝', workSeconds: 60, sets: 3),
        _module.copyWith(
          id: 'cooldown',
          name: '쿨다운',
          workSeconds: 120,
          sets: 1,
          restSeconds: 0,
        ),
      ],
    );
    data.repository.items
      ..clear()
      ..addAll([
        demo,
        demo.copyWith(id: 'next', name: '토요일 그룹 수업', folder: '팀 수업'),
        demo.copyWith(id: 'recovery', name: '회복 스트레칭', folder: '회복'),
      ]);
    data.session = navigationSession(demo).copyWith(remainingMs: 120000);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: UncontrolledProviderScope(
          container: data.container,
          child: const MainNavigationPreview(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final router = data.container.read(appRouterProvider);
    router.go('/player/${demo.id}?session=preview-session');
    await save(boundary, '01-control');
    router.go('/');
    await tester.pumpAndSettle();
    data.setSession(null);
    await tester.pumpAndSettle();
    router.go('/editor/${demo.id}');
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutEditorScreen), findsOneWidget);
    await save(boundary, '02-compose');
    router.go('/slides');
    await tester.pumpAndSettle();
    await tester.tap(find.text('워크아웃').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('복제'), findsOneWidget);
    await save(boundary, '03-reuse');
    await tester.tapAt(const Offset(20, 200));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '서킷');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    expect(find.text('전신 서킷'), findsOneWidget);
    await save(boundary, '07-library');
    await tester.pumpWidget(const SizedBox.shrink());

    for (final name in ['04-timer', '05-style']) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: TimerUxPreview(module: _module),
        ),
      );
      await tester.pumpAndSettle();
      if (name == '04-timer') {
        await timer_actions.tap(tester, 'slide-timer-summary');
      } else {
        await scrollSettingsTo(
          tester,
          find.byKey(const ValueKey('timer-color-scroll')),
        );
      }
      await save(key, name);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
    for (final (name, screen) in <(String, Widget)>[
      ('06-rehearsal', WorkoutRehearsalScreen(workout: demo)),
      ('08-explore', const ExploreScreen()),
    ]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              authStateProvider.overrideWith((_) => Stream.value(null)),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: XonTheme.light.copyWith(platform: TargetPlatform.android),
              home: screen,
            ),
          ),
        ),
      );
      await save(key, name);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
    tester.view.physicalSize = const Size(960, 540);
    data.setSession(navigationSession(demo).copyWith(remainingMs: 120000));
    final tvKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: tvKey,
        child: UncontrolledProviderScope(
          container: data.container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: XonTheme.light,
            home: WorkoutPlayerScreen(
              workoutId: demo.id,
              startModule: 0,
              sessionId: 'preview-session',
              displayMode: true,
            ),
          ),
        ),
      ),
    );
    await save(tvKey, 'tv-player');
    await tester.pumpWidget(const SizedBox.shrink());
    data.dispose();
    await tester.pumpAndSettle();
    File('$_directory/capture-manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 1,
        'status': 'review-only',
        'sourceKind': 'flutter-widget-review',
        'capturedAt': DateTime.now().toUtc().toIso8601String(),
        'sourceSha': Platform.environment['CAPTURE_SOURCE_SHA'] ?? 'unrecorded',
        'version': '1.1.0',
        'build': null,
        'device': null,
        'flavor': null,
        'note': 'Production widgets with local fixtures and Android styling. Not an installed release candidate; no Firebase writes or TV pairing were executed.',
        'captures': captured,
      }),
    );
    debugDefaultTargetPlatformOverride = null;
  });
}

final _module = WorkoutModule.empty('main').copyWith(
  name: '전신 서킷',
  workSeconds: 45,
  restSeconds: 15,
  sets: 4,
  beep: false,
  text: '스쿼트 12회\n푸시업 10회\n덤벨 로우 12회\n플랭크 30초',
  designTemplate: 'stationd-v2-numbered',
  designAccentColor: 0xFF8874A4,
  designBackgroundColor: 0xFFFFFFFF,
  designTextColor: 0xFF302637,
  workGaugeColor: '#8874A4',
  workTextColor: '#302637',
  restGaugeColor: '#BEB5C9',
);
