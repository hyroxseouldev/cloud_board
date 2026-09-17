import 'dart:async';
import 'dart:convert';

import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/countdown_defaults_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/countdown_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/countdown_defaults_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/countdown_defaults_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final base =
    Workout.empty(
      'w',
      const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
    ).copyWith(
      name: '수업',
      modules: [WorkoutModule.empty('m').copyWith(name: '스쿼트')],
    );
const customized = CountdownPreferences(
  seconds: 17,
  backgroundColor: 0xFF223344,
  appearance: CountdownAppearance(
    showReady: false,
    showTitle: false,
    numberScale: 1.4,
    numberFormat: CountdownNumberFormat.clock,
    numberColor: 0xFFFFDD00,
    numberShadow: true,
    overlayEnabled: false,
    overlayOpacity: .3,
  ),
);

void main() {
  test('legacy workout preserves countdown and defaults new appearance', () {
    final json = WorkoutModel.fromEntity(
      base.copyWith(countdownSeconds: 9, countdownBackgroundColor: 0xFFEEEEEE),
    ).toJson()..remove('countdownAppearance');
    final restored = WorkoutModel.fromJson(json).toEntity();
    expect(restored.countdownSeconds, 9);
    expect(restored.countdownBackgroundColor, 0xFFEEEEEE);
    expect(restored.countdownAppearance, const CountdownAppearance());
  });

  test(
    'preferences survive JSON and active session snapshot independently',
    () {
      final settings = CountdownPreferences.fromJson(
        jsonDecode(jsonEncode(customized.toJson())) as Map<String, dynamic>,
      );
      expect(settings, customized);
      final workout = settings.applyTo(base);
      final session = PlaybackSessionModel.fromWorkout(
        id: 's',
        ownerId: 'u',
        zoneId: 'main',
        targetDeviceIds: ['tv'],
        workout: workout,
        stepIndex: 0,
        durationMs: 60000,
        deviceId: 'controller',
      );
      final restored = PlaybackSessionModel.fromJson(
        jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>,
      ).toEntity();
      expect(CountdownPreferences.fromWorkout(restored.workout), customized);
      final other = const CountdownPreferences(seconds: 0).applyTo(base);
      expect(other.countdownSeconds, 0);
      expect(restored.workout.countdownSeconds, 17);
      expect(base.countdownSeconds, 3);
      expect(workout.modules, base.modules);
      expect(workout.soundTheme, base.soundTheme);
    },
  );

  test(
    'account defaults are isolated and an open new draft retains its snapshot',
    () async {
      final repo = _Defaults()..values['u'] = customized;
      final container = ProviderContainer(
        overrides: [
          countdownDefaultsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        newWorkoutCountdownDefaultsProvider('u'),
        (_, _) {},
      );
      addTearDown(subscription.close);
      final initial = await container.read(
        newWorkoutCountdownDefaultsProvider('u').future,
      );
      await container
          .read(countdownDefaultsControllerProvider('u').notifier)
          .save(const CountdownPreferences(seconds: 25));
      expect(
        await container.read(newWorkoutCountdownDefaultsProvider('u').future),
        initial,
      );
      expect(
        await container.read(
          newWorkoutCountdownDefaultsProvider('other').future,
        ),
        const CountdownPreferences(),
      );
      expect(repo.values['u']!.seconds, 25);
    },
  );

  testWidgets(
    'visibility, clock format and overlay apply without changing duration',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutCountdown(
              workout: customized.applyTo(base),
              seconds: 17,
            ),
          ),
        ),
      );
      expect(find.text('준비하세요'), findsNothing);
      expect(find.text('스쿼트'), findsNothing);
      expect(find.text('00:17'), findsOneWidget);
      expect(find.byKey(const ValueKey('countdown-overlay')), findsNothing);
      final number = tester.widget<Text>(
        find.byKey(const ValueKey('countdown-number')),
      );
      expect(number.style!.fontSize, closeTo(600 * .4 * 1.4, .001));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WorkoutCountdown(workout: base, seconds: 3)),
        ),
      );
      expect(find.text('준비하세요'), findsOneWidget);
      expect(find.text('스쿼트'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(
        tester
            .widget<ColoredBox>(find.byKey(const ValueKey('countdown-overlay')))
            .color,
        Colors.black,
      );
    },
  );

  testWidgets(
    'legacy image keeps black overlay until an explicit color override',
    (tester) async {
      final legacy = base.copyWith(
        countdownImageSource: 'invalid-image',
        countdownBackgroundColor: 0xFFFFFFFF,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WorkoutCountdown(workout: legacy, seconds: 3)),
        ),
      );
      expect(
        tester
            .widget<ColoredBox>(find.byKey(const ValueKey('countdown-overlay')))
            .color,
        Colors.black.withValues(alpha: .54),
      );
      final edited = legacy.copyWith(
        countdownAppearance: const CountdownAppearance(
          overlayColor: 0xFF123456,
          overlayOpacity: .7,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WorkoutCountdown(workout: edited, seconds: 3)),
        ),
      );
      expect(
        tester
            .widget<ColoredBox>(find.byKey(const ValueKey('countdown-overlay')))
            .color,
        const Color(0xFF123456).withValues(alpha: .7),
      );
      expect(
        WorkoutModel.fromJson(WorkoutModel.fromEntity(edited).toJson())
            .toEntity()
            .countdownAppearance
            .overlayColor,
        0xFF123456,
      );
    },
  );

  for (final width in [390.0, 834.0]) {
    testWidgets(
      'numeric input validates range and preview cleans up at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1194);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var draft = base;
        await _mount(tester, _Defaults(), () => draft, (v) => draft = v);
        final seconds = find.byKey(const ValueKey('countdown-seconds'));
        await tester.enterText(seconds, '60');
        await tester.pump();
        expect(draft.countdownSeconds, 60);
        await tester.enterText(seconds, '61');
        await tester.pump();
        expect(draft.countdownSeconds, 60);
        await tester.enterText(seconds, '8');
        await tester.pump();
        FocusManager.instance.primaryFocus?.unfocus();
        await _tap(tester, find.byKey(const ValueKey('countdown-preview')));
        expect(find.text('미리보기 중지'), findsOneWidget);
        await tester.enterText(seconds, '0');
        await tester.pump();
        expect(find.text('바로 시작 (카운트다운 없음)'), findsOneWidget);
        expect(find.text('미리보기 중지'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
      },
    );
  }

  testWidgets(
    'import and undo change only countdown; late load cannot overwrite edits',
    (tester) async {
      final repo = _Defaults()..values['u'] = customized;
      var draft = base;
      await _mount(tester, repo, () => draft, (v) => draft = v);
      await _tap(tester, find.text('내 기본값 가져오기'));
      expect(CountdownPreferences.fromWorkout(draft), customized);
      expect(draft.modules, base.modules);
      await _tap(tester, find.text('가져오기 되돌리기'));
      expect(draft, base);
      repo.pending = Completer();
      await _tap(tester, find.text('내 기본값 가져오기'), settle: false);
      final seconds = find.byKey(const ValueKey('countdown-seconds'));
      await tester.ensureVisible(seconds);
      await tester.enterText(seconds, '12');
      await tester.pump();
      repo.pending!.complete(customized);
      await tester.pumpAndSettle();
      expect(draft.countdownSeconds, 12);
      expect(draft.countdownAppearance, base.countdownAppearance);
      expect(find.text('설정이 변경되어 기본값을 적용하지 않았습니다. 다시 눌러 주세요.'), findsOneWidget);
    },
  );

  testWidgets('failed import keeps draft and displays error', (tester) async {
    final repo = _Defaults()..fail = true;
    var draft = base;
    await _mount(tester, repo, () => draft, (v) => draft = v);
    await _tap(tester, find.text('내 기본값 가져오기'));
    expect(draft, base);
    expect(
      find.text('기본값 작업을 완료하지 못했습니다. 연결과 로그인 상태를 확인해 주세요.'),
      findsOneWidget,
    );
    expect(find.text('가져오기 되돌리기'), findsNothing);
  });
}

Future<void> _mount(
  WidgetTester tester,
  _Defaults repo,
  Workout Function() get,
  void Function(Workout) set,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        countdownDefaultsRepositoryProvider.overrideWithValue(repo),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            const AuthUser(
              id: 'u',
              email: 'test@example.com',
              displayName: 'Coach',
              photoUrl: null,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => SingleChildScrollView(
              child: CountdownSettings(
                workout: get(),
                onChanged: (v) => update(() => set(v)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
}) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

class _Defaults implements CountdownDefaultsRepository {
  final values = <String, CountdownPreferences>{};
  Completer<CountdownPreferences>? pending;
  bool fail = false;
  @override
  Future<CountdownPreferences> load(String ownerId) async {
    if (fail) throw StateError('offline');
    return pending?.future ?? values[ownerId] ?? const CountdownPreferences();
  }

  @override
  Future<void> save(String ownerId, CountdownPreferences value) async =>
      values[ownerId] = value;
}
