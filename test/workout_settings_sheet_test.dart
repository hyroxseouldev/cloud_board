import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(834, 1194)]) {
    testWidgets('settings preserve every sound control and draft at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final draft = ValueNotifier(
        Workout.empty(
          'workout',
          const WorkoutAuthor(
            id: 'coach',
            displayName: 'Coach',
            photoUrl: null,
          ),
        ),
      );
      final left = TextEditingController();
      final right = TextEditingController();
      final audio = _RecordingPlayer();
      addTearDown(draft.dispose);
      addTearDown(left.dispose);
      addTearDown(right.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [beepPlayerProvider.overrideWithValue(audio)],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    constraints: const BoxConstraints(maxWidth: 800),
                    builder: (_) => WorkoutSettingsSheet(
                      draft: draft,
                      brandL: left,
                      brandR: right,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'CloudBoard');
      await tester.enterText(find.byType(TextField).last, '오늘도 함께');

      Future<void> tapVisible(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      for (final theme in WorkoutSoundTheme.values.where(
        (value) => value != WorkoutSoundTheme.custom,
      )) {
        await tapVisible(find.widgetWithText(ChoiceChip, theme.label));
        final sounds = soundsForTheme(theme);
        expect(draft.value.soundTheme, theme);
        expect(draft.value.countdownSound, sounds.countdown);
        expect(draft.value.workStartSound, sounds.workStart);
        expect(draft.value.restStartSound, sounds.restStart);
        expect(draft.value.workoutEndSound, sounds.workoutEnd);
        expect(audio.calls.last.$1, sounds.workStart);
      }
      final slider = find.byType(Slider);
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(slider));
      await tester.pumpAndSettle();
      final volume = draft.value.soundVolume;
      expect(volume, closeTo(.5, .1));

      final selections = [
        ('카운트다운', WorkoutSound.silent),
        ('운동 시작', WorkoutSound.boxingBell),
        ('휴식 시작', WorkoutSound.classicBeep),
        ('수업 종료', WorkoutSound.sharpBeep),
      ];
      for (var index = 0; index < selections.length; index++) {
        final (label, sound) = selections[index];
        await tapVisible(
          find.byType(DropdownButtonFormField<WorkoutSound>).at(index),
        );
        await tester.tap(find.text(sound.label).last);
        await tester.pumpAndSettle();
        expect(draft.value.soundTheme, WorkoutSoundTheme.custom);
        expect(audio.calls.last, (sound, volume));
        final before = audio.calls.length;
        await tapVisible(find.byTooltip('$label 미리 듣기'));
        expect(audio.calls.length, before + 1);
        expect(audio.calls.last, (sound, volume));
      }
      await tapVisible(find.byTooltip('현재 운동 시작음 미리 듣기'));
      expect(audio.calls.last, (WorkoutSound.boxingBell, volume));
      expect(draft.value.countdownSound, WorkoutSound.silent);
      expect(draft.value.workStartSound, WorkoutSound.boxingBell);
      expect(draft.value.restStartSound, WorkoutSound.classicBeep);
      expect(draft.value.workoutEndSound, WorkoutSound.sharpBeep);
      final edited = draft.value;
      await tester.tap(find.text('설정 완료'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(left.text, 'CloudBoard');
      expect(right.text, '오늘도 함께');
      expect(draft.value, edited);
      expect(find.text('직접 설정'), findsOneWidget);
      expect(tester.widget<Slider>(slider).value, volume);

      // The keyboard must leave the second field and the close action reachable.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tapVisible(find.byType(TextField).last);
      expect(find.byType(TextField).last.hitTestable(), findsOneWidget);
      expect(find.byTooltip('설정 닫기').hitTestable(), findsOneWidget);
      expect(find.text('설정 완료').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('설정 닫기'));
      await tester.pumpAndSettle();
      expect(draft.value, edited);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    });
  }
}

class _RecordingPlayer implements BeepPlayer {
  final calls = <(WorkoutSound, double)>[];

  @override
  Future<void> play([
    WorkoutSound sound = WorkoutSound.classicBeep,
    double volume = 1,
  ]) async => calls.add((sound, volume));

  @override
  Future<void> dispose() async {}
}
