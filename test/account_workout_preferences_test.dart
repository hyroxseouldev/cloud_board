import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/account_workout_settings_tab.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/countdown_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_preferences_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_preferences_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_preferences_controller.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';

class _Preferences implements WorkoutPreferencesRepository {
  WorkoutPreferences? value;
  bool fail = false;
  bool freshRequested = false;
  Completer<void>? pending;
  @override
  Future<WorkoutPreferences?> load(String ownerId, {bool fresh = false}) async {
    freshRequested = fresh;
    if (fail) throw StateError('offline');
    return value;
  }

  @override
  Future<void> save(String ownerId, WorkoutPreferences settings) async {
    if (pending != null) await pending!.future;
    if (fail) throw StateError('offline');
    value = settings;
  }
}

void main() {
  final legacy =
      Workout.empty(
        'old',
        const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
      ).copyWith(
        brandL: 'old brand',
        countdownSeconds: 7,
        soundVolume: .3,
        modules: [WorkoutModule.empty('a').copyWith(workSeconds: 60)],
      );
  test('common settings round-trip, preserve slides, and freeze in session snapshot', () async {
    final repository = _Preferences();
    final actions = WorkoutPreferencesActions(repository);
    expect(await actions.apply(legacy), legacy);
    final settings = WorkoutPreferences(
      brandL: 'Center',
      soundVolume: .7,
      workStartSound: WorkoutSound.classicBeep,
      countdown: const CountdownPreferences(
        seconds: 12,
        appearance: CountdownAppearance(
          showReady: false,
          numberFormat: CountdownNumberFormat.clock,
        ),
      ),
    );
    repository.value = WorkoutPreferences.fromJson(settings.toJson());
    final applied = await actions.apply(legacy, fresh: true);
    expect(repository.freshRequested, isTrue);
    expect(applied.modules, legacy.modules);
    expect(applied.id, legacy.id);
    expect(applied.updatedAt, legacy.updatedAt);
    expect(applied.brandL, 'Center');
    expect(applied.countdownSeconds, 12);
    expect(applied.workStartSound, WorkoutSound.classicBeep);
    final session = PlaybackSessionModel.fromWorkout(
      id: 's',
      ownerId: 'u',
      zoneId: 'main',
      targetDeviceIds: ['tv'],
      workout: applied,
      stepIndex: 0,
      durationMs: 60000,
      deviceId: 'c',
    ).toEntity();
    repository.value = settings.copyWith(
      brandL: 'Later',
      countdown: const CountdownPreferences(seconds: 0),
    );
    expect((await actions.apply(legacy)).brandL, 'Later');
    expect(session.workout.brandL, 'Center');
    expect(session.workout.countdownSeconds, 12);
    repository.fail = true;
    await expectLater(actions.apply(legacy, fresh: true), throwsStateError);
  });

  testWidgets(
    'account tab keeps draft on failed save, blocks double save and retries',
    (tester) async {
      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Preferences()
        ..pending = Completer<void>()
        ..fail = true;
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
            accountWorkoutPreferencesProvider('u')
                .overrideWith((ref) async => const WorkoutPreferences()),
            workoutPreferencesActionsProvider.overrideWithValue(
              WorkoutPreferencesActions(repository),
            ),
          ],
          child: MaterialApp(
            theme: XonTheme.light,
            home: const Scaffold(body: AccountWorkoutSettingsTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('계정 공통 워크아웃 설정'), findsOneWidget);
      expect(find.text('내 기본값으로 저장'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('brand-left')),
        'All classes',
      );
      await tester.enterText(
        find.byKey(const ValueKey('countdown-seconds')),
        '15',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(find.text('공통 설정 저장'));
      await tester.tap(find.text('공통 설정 저장'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull,
      );
      repository.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('저장하지 못했습니다'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('brand-left')))
            .controller!
            .text,
        'All classes',
      );
      repository.fail = false;
      repository.pending = null;
      await tester.ensureVisible(find.text('공통 설정 저장'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('공통 설정 저장'));
      await tester.pumpAndSettle();
      expect(repository.value?.brandL, 'All classes');
      expect(repository.value?.countdown.seconds, 15);
      expect(tester.takeException(), isNull);
    },
  );
}
