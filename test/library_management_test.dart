import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_catalog_page.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_actions.dart';
import 'package:firebase_core/firebase_core.dart';

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
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';

import 'support/workout_catalog_fixture.dart';

void main() {
  testWidgets(
    'delayed first page is loading, not an empty library; failure retries',
    (tester) async {
      final pages = _ControlledCatalog()
        ..firstGate = Completer<void>()
        ..failFirst = true;
      await _mountCatalog(tester, pages);
      await tester.tap(find.text('워크아웃').last);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('워크아웃 목록을 불러오고 있습니다…'), findsOneWidget);
      expect(find.textContaining('+ 버튼으로'), findsNothing);
      pages.firstGate!.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('인터넷 연결'), findsOneWidget);
      expect(find.textContaining('+ 버튼으로'), findsNothing);
      pages.failFirst = false;
      await tester.tap(find.widgetWithText(TextButton, '다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('첫 수업'), findsOneWidget);
      expect(find.text('나중 수업'), findsOneWidget);
      expect(find.textContaining('인터넷 연결'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'later page failure keeps rows and partial folder counts; retry completes',
    (tester) async {
      final pages = _ControlledCatalog()..failLater = true;
      await _mountCatalog(tester, pages);
      await tester.pumpAndSettle();
      await tester.tap(find.text('워크아웃').last);
      await tester.pumpAndSettle();
      expect(find.text('첫 수업'), findsOneWidget);
      expect(find.textContaining('인터넷 연결'), findsOneWidget);
      await tester.tap(find.text('폴더').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('집계 미완료'), findsOneWidget);
      pages.failLater = false;
      await tester.tap(find.widgetWithText(TextButton, '다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('워크아웃 2개 · 슬라이드 0개'), findsOneWidget);
      expect(find.textContaining('집계 미완료'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'refresh failure retains selection and data; search misses are distinct',
    (tester) async {
      final pages = _ControlledCatalog();
      await _mountCatalog(tester, pages);
      await tester.pumpAndSettle();
      await tester.tap(find.text('워크아웃').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '하체'));
      await tester.enterText(find.widgetWithText(TextField, '워크아웃 검색'), '첫');
      await tester.pumpAndSettle();
      pages.failFirst = true;
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      await refresh;
      expect(find.text('첫 수업'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '하체'))
            .selected,
        isTrue,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '첫',
      );
      expect(find.textContaining('인터넷 연결'), findsOneWidget);
      pages.failFirst = false;
      await tester.tap(find.widgetWithText(TextButton, '다시 시도'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, '워크아웃 검색'),
        '없는 검색어',
      );
      await tester.pumpAndSettle();
      expect(find.text('검색 조건에 맞는 워크아웃 자료가 없습니다.'), findsOneWidget);
      expect(find.textContaining('+ 버튼으로'), findsNothing);
      await tester.tap(find.text('폴더').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '폴더 검색'), '없는 검색어');
      await tester.pumpAndSettle();
      expect(find.text('검색 조건에 맞는 폴더 자료가 없습니다.'), findsOneWidget);
      expect(find.text('폴더를 만들어 자료를 정리해 보세요.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'folder metadata failure offers retry without pretending no folders exist',
    (tester) async {
      final pages = _ControlledCatalog();
      var failFolders = true;
      await _mountCatalog(
        tester,
        pages,
        folderStream: () => failFolders
            ? Stream.error(
                FirebaseException(
                  plugin: 'cloud_firestore',
                  code: 'unavailable',
                ),
              )
            : Stream.value(['하체']),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('폴더').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('인터넷 연결'), findsOneWidget);
      expect(find.text('폴더를 만들어 자료를 정리해 보세요.'), findsNothing);
      failFolders = false;
      await tester.tap(find.widgetWithText(TextButton, '다시 시도'));
      await tester.pumpAndSettle();
      expect(find.textContaining('인터넷 연결'), findsNothing);
      expect(find.text('워크아웃 2개 · 슬라이드 0개'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a large library builds only visible previews and still searches every slide',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => Stream.value(
                const AuthUser(
                  id: 'owner',
                  email: '',
                  displayName: '',
                  photoUrl: null,
                ),
              ),
            ),
            slideTemplatesControllerProvider('owner')
                .overrideWith(_ManyTemplates.new),
            activePlaybackSessionProvider.overrideWith(
              (ref) => Stream.value(null),
            ),
          ],
          child: MaterialApp(
            theme: XonTheme.light,
            home: SlideLibraryScreen(onSelect: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(WorkoutSlidePreview).evaluate().length,
        inExclusiveRange(0, 20),
      );
      await tester.enterText(
        find.widgetWithText(TextField, '슬라이드 검색'),
        'Slide 199',
      );
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutSlidePreview), findsOneWidget);
      expect(
        tester
            .widget<WorkoutSlidePreview>(find.byType(WorkoutSlidePreview))
            .module
            .name,
        'Slide 199',
      );
      expect(tester.takeException(), isNull);
    },
  );
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

class _ManyTemplates extends SlideTemplatesController {
  @override
  Stream<List<WorkoutModule>> build(String scope) => Stream.value(
    List.generate(
      200,
      (i) => WorkoutModule.empty('s$i').copyWith(name: 'Slide $i'),
    ),
  );
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

Future<void> _mountCatalog(
  WidgetTester tester,
  _ControlledCatalog repository, {
  Stream<List<String>> Function()? folderStream,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            const AuthUser(
              id: 'owner',
              email: '',
              displayName: '',
              photoUrl: null,
            ),
          ),
        ),
        activePlaybackSessionProvider.overrideWith((ref) => Stream.value(null)),
        loadWorkoutsProvider.overrideWith(
          (ref) async => LoadWorkouts(repository),
        ),
        libraryFoldersProvider.overrideWith(
          (ref) => folderStream?.call() ?? Stream.value(['하체']),
        ),
        slideTemplatesControllerProvider('owner')
            .overrideWith(_EmptyTemplates.new),
      ],
      child: MaterialApp(
        theme: XonTheme.light,
        home: const SlideLibraryScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

class _EmptyTemplates extends SlideTemplatesController {
  @override
  Stream<List<WorkoutModule>> build(String scope) => Stream.value([]);
}

class _ControlledCatalog extends Fake
    implements WorkoutRepository, PagedWorkoutCatalog {
  Completer<void>? firstGate;
  bool failFirst = false;
  bool failLater = false;
  final first = Workout.empty(
    'first',
    const WorkoutAuthor(id: 'owner', displayName: '', photoUrl: null),
  ).copyWith(name: '첫 수업', folder: '하체');
  final second = Workout.empty(
    'second',
    const WorkoutAuthor(id: 'owner', displayName: '', photoUrl: null),
  ).copyWith(name: '나중 수업', folder: '하체');
  @override
  Stream<WorkoutCatalogPage> watchCatalog({bool requireServer = false}) async* {
    await firstGate?.future;
    if (failFirst) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    yield WorkoutCatalogPage([summarizeWorkout(first)]);
    if (failLater) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    yield WorkoutCatalogPage([
      summarizeWorkout(first),
      summarizeWorkout(second),
    ], complete: true);
  }
}
