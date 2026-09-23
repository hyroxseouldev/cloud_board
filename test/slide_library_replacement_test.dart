import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_library_picker.dart';

import 'support/workout_preferences_fixture.dart';

import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_preferences_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_preferences_controller.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _MemorySource extends SlideEditorLocalDataSource {
  final values = <String, String>{};
  bool failReads = false;
  @override
  Future<String?> read(String key) async {
    if (failReads) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    return values[key];
  }

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

void main() {
  testWidgets(
    'library distinguishes loading failure, empty results and favorite search',
    (tester) async {
      final source = _MemorySource();
      final repository = LocalSlideEditorRepository(source);
      await repository.saveTemplates('coach', [
        WorkoutModule.empty('favorite')
            .copyWith(name: '스쿼트', category: '하체', favorite: true),
        WorkoutModule.empty('regular').copyWith(name: '푸시업', category: '상체'),
      ]);
      source.failReads = true;
      WorkoutModule? selected;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slideEditorRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: XonTheme.light,
            home: Scaffold(
              body: SlideLibraryPicker(
                scope: 'coach',
                onSelect: (item) => selected = item,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('라이브러리를 불러오지 못했습니다.'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('저장한 슬라이드가 없습니다.'), findsNothing);
      source.failReads = false;
      await tester.tap(find.text('다시 불러오기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('즐겨찾기'));
      await tester.pumpAndSettle();
      expect(find.text('푸시업'), findsNothing);
      final search = find.widgetWithText(TextField, '슬라이드 검색');
      await tester.enterText(search, '상체');
      await tester.pumpAndSettle();
      expect(find.text('조건에 맞는 슬라이드가 없습니다.'), findsOneWidget);
      await tester.enterText(search, '하체');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('library-slide-favorite')));
      expect(selected?.name, '스쿼트');
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(390, 844),
    const Size(834, 1194),
    const Size(844, 390),
  ]) {
    testWidgets(
      'library previews before atomic replacement, preserves scope, identity and undo at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final source = _MemorySource();
        final repository = LocalSlideEditorRepository(source);
        final target = WorkoutModule.empty('current')
            .copyWith(name: '현재 수업', text: '편집 중 본문');
        final template = WorkoutModule.empty('template').copyWith(
          name: '즐겨 쓰는 인터벌',
          text: '교체 본문',
          category: '하체',
          favorite: true,
          workSeconds: 120,
          restSeconds: 30,
          sets: 3,
          showTimer: false,
          showTimerGauge: false,
          showSets: false,
          beep: false,
          coverImage: true,
          imageSource: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aMioAAAAASUVORK5CYII=',
          workGaugeColor: '#112233',
          restGaugeColor: '#445566',
          workTextColor: '#778899',
          restTextColor: '#AABBCC',
          timerColorValue: 0xFF123456,
          appearance: const SlideAppearance(
            timerX: .3,
            timerY: .6,
            timerSize: .8,
            showTitle: false,
            showBody: false,
            showBrand: false,
          ),
          intervalBlocks: const [
            WorkoutIntervalBlock(
              id: 'library-block',
              workSeconds: 120,
              restSeconds: 30,
              sets: 3,
            ),
          ],
        );
        await repository.saveTemplates('coach', [template]);
        await repository.saveTemplates('other', [
          template.copyWith(id: 'private', name: '다른 계정'),
        ]);
        final workout = Workout.empty(
          'workout',
          const WorkoutAuthor(
            id: 'coach',
            displayName: 'Coach',
            photoUrl: null,
          ),
        ).copyWith(soundVolume: .35, modules: [target]);
        final saved = <WorkoutModule>[];
        final preferences = FixtureWorkoutPreferences(
          ownerId: 'coach',
          value: const WorkoutPreferences(
            brandL: 'Account brand',
            soundVolume: .8,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            slideEditorRepositoryProvider.overrideWithValue(repository),
            workoutPreferencesRepositoryProvider.overrideWithValue(preferences),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: XonTheme.light,
              builder: XonTheme.responsiveBuilder,
              home: SlideEditorScreen(
                workoutId: workout.id,
                moduleId: target.id,
                guard: ExitGuard(),
                request: SlideEditRequest(
                  module: target,
                  workout: workout,
                  onSave: (value) async {
                    saved.add(value);
                    return false;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final provider = slideEditorControllerProvider(
          workout.id,
          target,
          'coach',
        );
        final bar = find.byKey(const ValueKey('slide-editor-tabs'));
        Future<void> library() async {
          await tester.tap(
            find.descendant(of: bar, matching: find.text('라이브러리')),
          );
          await tester.pumpAndSettle();
        }

        Future<void> openCard() async {
          final card = find.byKey(const ValueKey('library-slide-template'));
          await tester.scrollUntilVisible(
            card,
            120,
            scrollable: find
                .descendant(
                  of: find.byKey(const ValueKey('slide-library-picker')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          // In landscape the tall thumbnail can extend below the viewport;
          // tap its visible leading edge after scrolling it into view.
          await tester.tapAt(tester.getTopLeft(card) + const Offset(20, 20));
          await tester.pumpAndSettle();
        }

        await library();
        expect(find.text('다른 계정'), findsNothing);
        // Saving from the library tab must also work with the settings form hidden.
        await tester.tap(find.byKey(const ValueKey('slide-save-button')));
        await tester.pumpAndSettle();
        expect(saved.single, target);
        await openCard();
        expect(container.read(provider).module, target);
        expect(find.text('현재 슬라이드를 교체할까요?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, '취소'));
        await tester.pumpAndSettle();
        expect(container.read(provider).module, target);
        expect(container.read(provider).undo, isEmpty);
        await openCard();
        await tester.tap(find.widgetWithText(FilledButton, '현재 슬라이드 교체'));
        await tester.pumpAndSettle();
        final replaced = container.read(provider).module;
        expect(replaced.id, target.id);
        expect(
          replaced.intervalBlocks.single.id,
          isNot(template.intervalBlocks.single.id),
        );
        expect(
          replaced.copyWith(
            id: template.id,
            intervalBlocks: template.intervalBlocks,
          ),
          template,
        );
        expect(container.read(provider).undo, [target]);
        expect(container.read(provider).dirty, isTrue);
        expect(saved, [target], reason: 'Replacement only updates the draft');
        expect(workout.soundVolume, .35);
        expect(preferences.loadedOwners, ['coach']);
        final preview = container
            .read(workoutPreviewProvider(workout))
            .requireValue;
        expect(preview.brandL, 'Account brand');
        expect(preview.soundVolume, .8);
        expect(await repository.loadTemplates('coach'), [template]);
        await tester.tap(find.byTooltip('실행 취소'));
        await tester.pumpAndSettle();
        expect(container.read(provider).module, target);
        await tester.tap(find.byTooltip('다시 실행'));
        await tester.pumpAndSettle();
        expect(container.read(provider).module, replaced);
        await tester.tap(find.byKey(const ValueKey('slide-save-button')));
        await tester.pumpAndSettle();
        expect(saved.last, replaced);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
