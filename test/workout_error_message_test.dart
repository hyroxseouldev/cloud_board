import 'dart:async';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_failure.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/library_failure.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_edit_access.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/workout_error_message.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/main_navigation_fixture.dart';

void main() {
  test(
    'preparation failure retains its original exception and diagnostics',
    () async {
      final fixture = NavigationPreviewData(active: false, count: 1);
      addTearDown(fixture.dispose);
      final error = StateError('TECHNICAL_PRIVATE');
      fixture.repository.detailError = error;
      fixture.container.listen(workoutActionControllerProvider, (_, _) {});
      final result = await fixture.container
          .read(workoutActionControllerProvider.notifier)
          .prepare('preview-0');
      expect(result, isNull);
      expect(
        fixture.container.read(workoutActionControllerProvider).error,
        same(error),
      );
      expect(
        fixture.container
            .read(errorReporterProvider)
            .eventFor(error)
            ?.context['action'],
        'workout.prepare',
      );
    },
  );
  for (final code in [
    'unavailable',
    'deadline-exceeded',
    'network-request-failed',
  ]) {
    test('$code explains connection recovery without technical text', () {
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: code,
        message: 'private/technical/detail',
      );
      final message = workoutErrorMessage(error);
      expect(message, contains('인터넷 연결'));
      expect(message, isNot(contains('private')));
      expect(message, isNot(contains('cloud_firestore')));
    });
  }
  test(
    'permission, deleted content and active lesson have distinct next steps',
    () {
      final permission = workoutErrorMessage(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      expect(permission, contains('소유자나 관리자'));
      expect(permission, isNot(contains('다시 로그인')));
      expect(
        workoutErrorMessage(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'object-not-found',
          ),
        ),
        contains('삭제'),
      );
      expect(
        workoutErrorMessage(StateError(workoutPlayingEditMessage)),
        contains('수업을 종료'),
      );
      expect(
        workoutErrorMessage(TimeoutException('stack here')),
        contains('인터넷 연결'),
      );
    },
  );
  test('unknown exceptions and server playback messages are never echoed', () {
    for (final error in [
      StateError('Sensitive technical details'),
      const FormatException('Sensitive technical details'),
      Exception('Sensitive technical details'),
      const LibraryFailure('Sensitive technical details'),
      LibraryFailure(
        'Sensitive technical details',
        cause: FirebaseException(
          plugin: 'cloud_functions',
          code: 'internal',
          message: 'Sensitive technical details',
        ),
      ),
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'internal',
        message: 'Sensitive technical details',
      ),
    ]) {
      expect(workoutErrorMessage(error), isNot(contains('Sensitive')));
      expect(playbackErrorMessage(error), isNot(contains('Sensitive')));
    }
    for (final code in ['revision_conflict', 'invalid_timing', 'unknown']) {
      final message = playbackErrorMessage(
        PlaybackFailure(code, 'Sensitive technical details'),
      );
      expect(message, isNot(contains('Sensitive')));
      expect(message, isNot(contains('PlaybackFailure')));
    }
  });
  test(
    'library conflicts and guarded account errors retain safe next steps',
    () {
      expect(
        workoutErrorMessage(
          LibraryFailure(
            'PRIVATE',
            cause: FirebaseException(
              plugin: 'cloud_functions',
              code: 'aborted',
              message: 'PRIVATE',
            ),
          ),
        ),
        contains('최신 내용'),
      );
      expect(
        workoutErrorMessage(const LibraryFailure('로그인 계정을 확인해 주세요.')),
        contains('계정을 확인'),
      );
      expect(
        workoutErrorMessage(const LibraryFailure('라이브러리를 불러온 뒤 저장해 주세요.')),
        contains('최신 라이브러리'),
      );
    },
  );
  testWidgets(
    'signed-in shell shows exactly one safe playback failure notice',
    (tester) async {
      final fixture = NavigationPreviewData(active: false, count: 1);
      addTearDown(fixture.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: const MainNavigationPreview(),
        ),
      );
      await tester.pumpAndSettle();
      final failure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'TECHNICAL_PRIVATE',
      );
      fixture.commands.reportActionFailure(failure);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('인터넷 연결'), findsOneWidget);
      expect(find.textContaining('TECHNICAL_PRIVATE'), findsNothing);
      fixture.commands.reportActionFailure(failure);
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(SnackBar));
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: 'No second listener may queue the same failure',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('detail failure can retry in place and open the editor', (
    tester,
  ) async {
    final fixture = NavigationPreviewData(active: false, count: 1);
    addTearDown(fixture.dispose);
    fixture.repository.detailError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: 'TECHNICAL_PRIVATE',
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: XonTheme.light,
          home: const WorkoutEditorScreen(workoutId: 'preview-0'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('인터넷 연결'), findsOneWidget);
    expect(find.textContaining('TECHNICAL_PRIVATE'), findsNothing);
    expect(fixture.repository.detailReads, 1);
    fixture.repository.detailError = null;
    await tester.tap(find.widgetWithText(FilledButton, '다시 시도'));
    await tester.pumpAndSettle();
    expect(find.textContaining('인터넷 연결'), findsNothing);
    expect(find.text('HYROX 기초 체력'), findsOneWidget);
    expect(fixture.repository.detailReads, 2);
    expect(tester.takeException(), isNull);
  });
}
