import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/library_folder_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/library_folder_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_templates_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_library_screen.dart';

import 'support/workout_catalog_fixture.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(834, 1194),
    const Size(1200, 800),
  ]) {
    testWidgets(
      'saved slides, workouts and persistent empty folders at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final folders = _Folders();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith(
                (ref) => Stream.value(
                  const AuthUser(
                    id: 'owner',
                    email: 'test@example.invalid',
                    displayName: 'Test',
                    photoUrl: null,
                  ),
                ),
              ),
              activePlaybackSessionProvider.overrideWith(
                (ref) => Stream.value(null),
              ),
              workoutControllerProvider.overrideWith(_Workouts.new),
              libraryFoldersProvider.overrideWith(
                (ref) => folders.watch('owner'),
              ),
              libraryFolderActionsProvider.overrideWithValue(folders),
              slideTemplatesControllerProvider('owner')
                  .overrideWith(_Templates.new),
            ],
            child: MaterialApp(
              theme: XonTheme.light,
              home: const SlideLibraryScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('즐겨찾기'), findsNothing);
        expect(find.text('운동 A'), findsWidgets);
        await tester.enterText(
          find.widgetWithText(TextField, '슬라이드 검색'),
          '운동 B',
        );
        await tester.pumpAndSettle();
        expect(
          find.text('운동 B'),
          findsWidgets,
          reason: 'Non-favorite legacy records are visible too',
        );
        expect(find.text('운동 A'), findsNothing);
        await tester.tap(find.text('워크아웃').last);
        await tester.pumpAndSettle();
        expect(find.text('센터 수업'), findsOneWidget);
        await tester.tap(find.text('폴더').last);
        await tester.pumpAndSettle();
        expect(find.text('빈 폴더'), findsOneWidget);
        await tester.tap(find.byTooltip('폴더 만들기'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, '이름'),
          '새 폴더',
        );
        await tester.tap(find.widgetWithText(FilledButton, '저장'));
        await tester.pumpAndSettle();
        expect(folders.names, contains('새 폴더'));
        expect(find.text('새 폴더'), findsOneWidget);
        final row = find.widgetWithText(ListTile, '새 폴더');
        await tester.tap(
          find.descendant(
            of: row,
            matching: find.byType(PopupMenuButton<String>),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('이름 수정'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, '이름'),
          '다음 수업',
        );
        await tester.tap(find.widgetWithText(FilledButton, '저장'));
        await tester.pumpAndSettle();
        expect(folders.names, contains('다음 수업'));
        expect(folders.names, isNot(contains('새 폴더')));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await folders.changes.close();
      },
    );
  }
}

class _Workouts extends FixtureWorkoutController {
  @override
  Stream<List<Workout>> fullBuild() => Stream.value([
    Workout.empty(
      'w',
      const WorkoutAuthor(id: 'owner', displayName: 'Test', photoUrl: null),
    ).copyWith(name: '센터 수업', folder: '하체'),
  ]);
}

class _Templates extends SlideTemplatesController {
  @override
  Stream<List<WorkoutModule>> build(String scope) => Stream.value([
    WorkoutModule.empty('a')
        .copyWith(name: '운동 A', favorite: true, category: '하체'),
    WorkoutModule.empty('b').copyWith(name: '운동 B', favorite: false),
  ]);
}

class _Folders extends Fake implements LibraryFolderActions {
  final names = <String>['빈 폴더'];
  final changes = StreamController<List<String>>.broadcast();
  @override
  Stream<List<String>> watch(String owner) async* {
    yield [...names];
    yield* changes.stream;
  }

  @override
  Future<void> create(String name) async {
    names.add(name);
    changes.add([...names]);
  }

  @override
  Future<void> rename(String name, String newName) async {
    names[names.indexOf(name)] = newName;
    changes.add([...names]);
  }
}
