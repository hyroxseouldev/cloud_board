import 'package:cloud_board/src/app/app.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_details.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';
import 'package:cloud_board/src/app/core/router/app_router.dart';
import 'package:cloud_board/src/app/core/services/android_class_notifications.dart';
import 'package:cloud_board/src/app/core/services/ios_class_controls.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/app_update/domain/entities/app_release.dart';
import 'package:cloud_board/src/app/feature/app_update/presentation/controllers/app_update_controller.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/billing/domain/entities/billing_status.dart';
import 'package:cloud_board/src/app/feature/billing/presentation/controllers/billing_controller.dart';
import 'package:cloud_board/src/app/feature/entitlement/presentation/controllers/entitlement_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/library_folder_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_templates_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_library_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_list_card.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/workout_catalog_fixture.dart';
import 'support/workout_recovery_fixture.dart';

final _module = WorkoutModule.empty('m')
    .copyWith(name: '스트레칭', text: '원래 내용', workSeconds: 180, beep: false);
final _workout = Workout.empty(
  'w',
  const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
).copyWith(name: '수업', modules: [_module]);
final _slide = slideEditorControllerProvider('w', _module, 'u');
final _save = find.byKey(const ValueKey('slide-save-button'));
const _networkMessage = '서버에 연결하지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.';
const _inlineMessage = '저장하지 못했습니다. 편집 내용은 유지됩니다. 연결을 확인하고 다시 저장해 주세요.';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'workout failure has one Snackbar, keeps name and retries at ${scale}x',
      (tester) async {
        final actions = _Saves();
        await _mount(tester, actions: actions, scale: scale);
        await _rename(tester, 'workout-name-button', '워크아웃 이름', '편집한 수업');
        final cards = find.byType(WorkoutSlideListCard);
        final before = tester.getRect(cards.first);
        final save = find.byKey(const ValueKey('workout-save-button'));
        await tester.tap(save);
        await tester.pumpAndSettle();
        _expectSingleNotice(tester);
        expect(find.byType(ErrorDetailsButton), findsNothing);
        expect(find.text('저장하지 못했습니다. 변경사항은 유지됩니다. 다시 저장해 주세요.'), findsNothing);
        expect(find.text('저장 실패 · 변경사항 유지됨'), findsOneWidget);
        expect(find.text('다시 저장'), findsOneWidget);
        expect(tester.getRect(cards.first), before);
        expect(actions.attempts.single.name, '편집한 수업');
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('workout-name-button')),
              )
              .controller!
              .text,
          '편집한 수업',
        );
        await _expectNoReplay(tester);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(actions.attempts, hasLength(2));
        expect(actions.attempts.last.name, '편집한 수업');
        expect(find.text('저장됨'), findsOneWidget);
        expect(tester.widget<TextButton>(save).onPressed, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'workout child failure is single across tabs and retry preserves draft at ${scale}x',
      (tester) async {
        final actions = _Saves();
        final container = await _mount(tester, actions: actions, scale: scale);
        await _openSlide(tester);
        await _rename(tester, 'slide-title-button', '슬라이드 제목', '편집한 운동');
        final editor = container.read(_slide.notifier);
        editor.update(
          container.read(_slide).module.copyWith(text: '유지할 편집 내용'),
        );
        await tester.pumpAndSettle();
        final settings = find.byKey(const ValueKey('slide-editor-settings'));
        final before = tester.getRect(settings);
        await tester.tap(_save);
        await tester.pumpAndSettle();
        _expectSingleNotice(tester);
        expect(find.text(_inlineMessage), findsNothing);
        expect(
          find.byKey(const ValueKey('slide-editor-notices')),
          findsNothing,
        );
        expect(tester.getRect(settings), before);
        expect(find.text('저장 실패 · 편집 내용 유지됨'), findsOneWidget);
        expect(find.text('다시 저장'), findsOneWidget);
        expect(container.read(_slide).dirty, isTrue);
        expect(container.read(_slide).module.text, '유지할 편집 내용');
        await _expectNoReplay(tester);
        for (final label in ['배경', '소리', '라이브러리', '타이머']) {
          await tester.tap(
            find.descendant(
              of: find.byKey(const ValueKey('slide-editor-tabs')),
              matching: find.text(label),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(_inlineMessage), findsNothing);
          expect(
            find.byKey(const ValueKey('slide-editor-notices')),
            findsNothing,
          );
          expect(find.byType(SnackBar), findsNothing);
        }
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('저장하지 않고 나갈까요?'), findsOneWidget);
        await tester.tap(find.text('계속 편집'));
        await tester.pumpAndSettle();
        await tester.tap(_save);
        await tester.pumpAndSettle();
        expect(actions.attempts, hasLength(2));
        expect(actions.attempts.last.modules.single.name, '편집한 운동');
        expect(actions.attempts.last.modules.single.text, '유지할 편집 내용');
        expect(container.read(_slide).dirty, isFalse);
        expect(find.text('저장됨'), findsOneWidget);
        expect(tester.widget<TextButton>(_save).onPressed, isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('저장하지 않고 나갈까요?'), findsNothing);
        expect(find.text('수업 구성'), findsOneWidget);
        expect(find.text('편집한 운동'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'library direct edit retains inline failure and retry at ${scale}x',
      (tester) async {
        final templates = _Templates();
        final actions = _Saves();
        final container = await _mount(
          tester,
          actions: actions,
          templates: templates,
          library: true,
          scale: scale,
        );
        await _rename(tester, 'slide-title-button', '슬라이드 제목', '보관함 수정');
        await tester.tap(_save);
        await tester.pumpAndSettle();
        expect(find.text(_inlineMessage), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.text('다시 저장'), findsOneWidget);
        final provider = slideEditorControllerProvider(
          'library-m',
          _module,
          'u',
        );
        expect(container.read(provider).dirty, isTrue);
        expect(container.read(provider).module.name, '보관함 수정');
        expect(actions.attempts, isEmpty);
        await tester.tap(_save);
        await tester.pumpAndSettle();
        expect(templates.attempts.map((m) => m.name), ['보관함 수정', '보관함 수정']);
        expect(find.text(_inlineMessage), findsNothing);
        expect(container.read(provider).dirty, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('workout child keeps plan-limit dialog without a generic error', (
    tester,
  ) async {
    final actions = _Saves(
      failure: FirebaseFunctionsException(
        code: 'resource-exhausted',
        message: 'fixture quota',
        details: {
          'reason': 'plan-limit',
          'resource': 'workouts',
          'limit': 7,
          'used': 7,
        },
      ),
    );
    final container = await _mount(tester, actions: actions);
    await _openSlide(tester);
    await _rename(tester, 'slide-title-button', '슬라이드 제목', '한도 초과 후 유지');
    await tester.tap(_save);
    // Saving remains busy while the invoking parent awaits this dialog.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('수업 7개를 모두 저장했어요.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.tap(find.text('계속 편집'));
    await tester.pumpAndSettle();
    expect(find.text(_inlineMessage), findsNothing);
    expect(find.text('다시 저장'), findsOneWidget);
    expect(container.read(_slide).module.name, '한도 초과 후 유지');
    expect(container.read(_slide).dirty, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'workout child retains validation and local cleanup notices at ${scale}x',
      (tester) async {
        final actions = _Saves(failFirst: false);
        final container = await _mount(
          tester,
          actions: actions,
          scale: scale,
          repository: _CleanupFailure(),
        );
        await _openSlide(tester);
        final editor = container.read(_slide.notifier);
        for (final invalid in [
          (module: _module.copyWith(name: ''), message: '슬라이드 제목을 입력해 주세요.'),
          (
            module: _module.copyWith(rounds: 0),
            message: '라운드 반복은 1~999회로 설정해 주세요.',
          ),
          (
            module: _module.copyWith(workGaugeColor: 'invalid'),
            message: '색상을 #RRGGBB 형식으로 입력해 주세요.',
          ),
        ]) {
          editor.update(invalid.module);
          await tester.pumpAndSettle();
          await tester.tap(_save);
          await tester.pumpAndSettle();
          expect(find.text(invalid.message), findsOneWidget);
          expect(actions.attempts, isEmpty);
        }
        editor.update(_module.copyWith(text: '정상 저장할 내용'));
        await tester.pumpAndSettle();
        await tester.tap(_save);
        await tester.pumpAndSettle();
        expect(actions.attempts, hasLength(1));
        expect(container.read(_slide).dirty, isFalse);
        expect(
          find.text('저장은 완료했지만 이 기기의 이전 임시저장을 지우지 못했습니다.'),
          findsOneWidget,
        );
        expect(find.text(_inlineMessage), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

void _expectSingleNotice(WidgetTester tester) {
  expect(find.byType(SnackBar), findsOneWidget);
  expect(find.text(_networkMessage), findsOneWidget);
  expect(
    find.descendant(
      of: find.byType(SnackBar),
      matching: find.text(_networkMessage),
    ),
    findsOneWidget,
  );
  expect(tester.takeException(), isNull);
}

Future<void> _expectNoReplay(WidgetTester tester) async {
  tester.element(find.byType(XonBoardApp)).markNeedsBuild();
  await tester.pumpAndSettle();
  _expectSingleNotice(tester);
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  expect(find.byType(SnackBar), findsNothing);
}

Future<void> _rename(
  WidgetTester tester,
  String key,
  String label,
  String value,
) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, label), value);
  await tester.tap(find.widgetWithText(FilledButton, '변경'));
  await tester.pumpAndSettle();
}

Future<void> _openSlide(WidgetTester tester) async {
  final card = find.byType(WorkoutSlideListCard).first;
  await tester.ensureVisible(card);
  await tester.tap(card);
  await tester.pumpAndSettle();
  expect(find.byType(SlideEditorScreen), findsOneWidget);
}

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  required _Saves actions,
  double scale = 1,
  bool library = false,
  _Templates? templates,
  LocalSlideEditorRepository? repository,
}) async {
  tester.view.physicalSize = const Size(834, 1194);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  final guard = ExitGuard(), childGuard = ExitGuard();
  final router = GoRouter(
    initialLocation: library ? '/library' : '/editor/w',
    routes: [
      GoRoute(
        path: '/library',
        builder: (_, _) => SavedSlideEditorScreen(id: 'm', guard: childGuard),
      ),
      GoRoute(
        path: '/editor/:id',
        builder: (_, state) => WorkoutEditorScreen(
          workoutId: state.pathParameters['id']!,
          guard: guard,
        ),
        onExit: (_, _) => guard.confirm(),
        routes: [
          GoRoute(
            path: 'slides/:mid',
            builder: (_, state) => SlideEditorScreen(
              workoutId: state.pathParameters['id']!,
              moduleId: state.pathParameters['mid']!,
              guard: childGuard,
              request: state.extra as SlideEditRequest?,
            ),
            onExit: (_, _) => childGuard.confirm(),
          ),
        ],
      ),
    ],
  );
  final scope = ProviderScope(
    retry: (_, _) => null,
    overrides: [
      memoryWorkoutRecovery,
      fixtureWorkoutDetails,
      fixtureSavedSlideOrder,
      workoutControllerProvider.overrideWith(_Workouts.new),
      workoutActionControllerProvider.overrideWith(() => actions),
      slideEditorRepositoryProvider.overrideWithValue(
        repository ?? LocalSlideEditorRepository(SlideEditorLocalDataSource()),
      ),
      slideTemplatesControllerProvider.overrideWith2(
        (_) => templates ?? _Templates(),
      ),
      libraryFoldersProvider.overrideWith((ref) => Stream.value([])),
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          const AuthUser(
            id: 'u',
            email: '',
            displayName: 'Coach',
            photoUrl: null,
          ),
        ),
      ),
      appRouterProvider.overrideWithValue(router),
      errorReporterProvider.overrideWithValue(ErrorReporter(_Diagnostics())),
      billingPurchaseControllerProvider.overrideWith(_Billing.new),
      storeEntitlementProvider.overrideWith((ref) => Stream.value(null)),
      appUpdateControllerProvider.overrideWith(_Updates.new),
      iosClassControlsProvider.overrideWith((ref) async {}),
      androidClassNotificationsProvider.overrideWith((ref) async => true),
    ],
    child: const XonBoardApp(),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(scope);
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(XonBoardApp)));
}

class _Saves extends WorkoutActionController {
  _Saves({this.failure, this.failFirst = true});
  final Object? failure;
  final bool failFirst;
  final attempts = <Workout>[];
  @override
  Future<Workout?> save(Workout value) async {
    attempts.add(value);
    state = const AsyncLoading();
    if (failFirst && attempts.length == 1) {
      state = AsyncError(
        failure ??
            FirebaseFunctionsException(
              code: 'unavailable',
              message: 'fixture offline',
            ),
        StackTrace.current,
      );
      return null;
    }
    ref.read(workoutControllerProvider.notifier).upsert(value);
    ref.read(workoutDetailProvider(value.id).notifier).replace(value);
    state = const AsyncData(null);
    return value;
  }
}

class _Workouts extends FixtureWorkoutController {
  @override
  Stream<List<Workout>> fullBuild() => Stream.value([_workout]);
}

class _Templates extends SlideTemplatesController {
  final attempts = <WorkoutModule>[];
  @override
  Stream<List<WorkoutModule>> build(String scope) => Stream.value([_module]);
  @override
  Future<bool> updateTemplate(
    WorkoutModule updated, {
    WorkoutModule? base,
  }) async {
    attempts.add(updated);
    return attempts.length > 1;
  }
}

class _Billing extends BillingPurchaseController {
  @override
  BillingActivity build() => const BillingActivity();
  @override
  Future<void> recoverPendingPurchases() async {}
}

class _Updates extends AppUpdateController {
  @override
  Future<({AppRelease release, UpdateKind kind})?> build() async => null;
}

class _Diagnostics implements DiagnosticSink {
  @override
  Future<void> send(DiagnosticEvent event) async {}
}

class _CleanupFailure extends LocalSlideEditorRepository {
  _CleanupFailure() : super(SlideEditorLocalDataSource());
  @override
  Future<void> clearDraft(String key) async =>
      throw StateError('local cleanup failure');
}
