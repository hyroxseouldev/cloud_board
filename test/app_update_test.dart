import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/router/app_router.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/app_update/presentation/controllers/app_update_controller.dart';
import 'package:cloud_board/src/app/feature/billing/data/datasources/billing_data_source.dart';
import 'package:cloud_board/src/app/feature/billing/data/repositories/billing_repository.dart';
import 'package:cloud_board/src/app/feature/billing/domain/entities/billing_status.dart';
import 'package:cloud_board/src/app/feature/billing/domain/usecases/billing_actions.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/app_update/domain/entities/app_release.dart';
import 'package:cloud_board/src/app/feature/app_update/domain/repositories/app_release_repository.dart';
import 'package:cloud_board/src/app/feature/app_update/domain/usecases/check_app_update.dart';
import 'package:cloud_board/src/app/feature/app_update/data/models/app_release_model.dart';
import 'package:cloud_board/src/app/feature/app_update/presentation/widgets/app_update_gate.dart';

const release = AppRelease(
  latestBuild: 550,
  minimumBuild: 530,
  publishedBuild: 550,
  version: '1.1.0',
  storeUrl: 'https://apps.apple.com/app/id6809105126',
  enabled: true,
  published: true,
);

class FakeReleases implements AppReleaseRepository {
  AppRelease? value = release;
  final requestedPlatforms = <String>[];
  int build = 540, snooze = 0;
  bool offline = false;
  @override
  Future<AppRelease?> load(String platform) async {
    requestedPlatforms.add(platform);
    if (offline) throw StateError('offline');
    return value;
  }

  @override
  Future<int> installedBuild() async => build;
  @override
  Future<int> dismissedUntil(int build) async => snooze;
  @override
  Future<void> dismiss(int build, int until) async {
    snooze = until;
  }
}

class FixedUpdate extends AppUpdateController {
  @override
  Future<({AppRelease release, UpdateKind kind})?> build() async =>
      (release: release, kind: UpdateKind.required);
}

class NoStore extends BillingDataSource {
  @override
  Stream<List<StorePurchase>> get events => const Stream.empty();
}

void main() {
  testWidgets(
    'TV reads its own release policy on initial check, retry and resume',
    (tester) async {
      final repository = FakeReleases()
        ..value = release.copyWith(
          storeUrl: 'https://play.google.com/store/apps/details?id=com.sunmkim.cloudboard',
        )
        ..build = 1;
      final container = ProviderContainer(
        overrides: [
          androidTvProvider.overrideWith((ref) async => true),
          checkAppUpdateProvider.overrideWithValue(CheckAppUpdate(repository)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: TvAppUpdateGate(readyForUpdate: true, child: Text('TV 대기')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (kIsWeb) {
        expect(repository.requestedPlatforms, isEmpty);
      } else {
        expect(repository.requestedPlatforms, ['tv']);
        expect(find.text('새 버전으로 함께해요'), findsOneWidget);
        await tester.tap(find.text('다시 확인'));
        await tester.pumpAndSettle();
        expect(repository.requestedPlatforms, ['tv', 'tv']);
        repository.value = null;
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(repository.requestedPlatforms, ['tv', 'tv', 'tv']);
        expect(find.text('새 버전으로 함께해요'), findsNothing);
        expect(find.text('TV 대기'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets('unknown TV detection never borrows a phone release policy', (
    tester,
  ) async {
    final repository = FakeReleases();
    final container = ProviderContainer(
      overrides: [
        androidTvProvider.overrideWith(
          (ref) async => throw StateError('unknown device'),
        ),
        checkAppUpdateProvider.overrideWithValue(CheckAppUpdate(repository)),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    try {
      await container.read(appUpdateControllerProvider.future);
    } catch (_) {}
    expect(repository.requestedPlatforms, isEmpty);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));

  test(
    'TV unpublished, missing, unknown and invalid store policies fail open',
    () async {
      final repository = FakeReleases()
        ..value = release.copyWith(
          storeUrl: 'https://play.google.com/store/apps/details?id=com.sunmkim.cloudboard',
        )
        ..build = 1;
      final check = CheckAppUpdate(repository);
      final tv = repository.value!;
      expect((await check.call('tv'))?.kind, UpdateKind.required);
      for (final value in [
        null,
        tv.copyWith(published: false),
        tv.copyWith(publishedBuild: 0),
        tv.copyWith(enabled: false),
        tv.copyWith(
          storeUrl: 'https://play.google.com/store/apps/details?id=other.app',
        ),
        tv.copyWith(
          storeUrl: 'https://play.google.com/store/apps/details?id=com.sunmkim.cloudboard&redirect=evil',
        ),
        release,
      ]) {
        repository.value = value;
        expect(await check.call('tv'), isNull);
      }
      repository.value = tv;
      repository.build = 0;
      expect(await check.call('tv'), isNull);
      repository.build = 1;
      repository.offline = true;
      expect(await check.call('tv'), isNull);
    },
  );

  testWidgets(
    'TV remote opens the store, retries failure, and cannot activate content behind a required update',
    (tester) async {
      var opens = 0, retries = 0, underlying = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdatePresentation(
              release: release.copyWith(
                storeUrl: 'https://play.google.com/store/apps/details?id=com.sunmkim.cloudboard',
              ),
              kind: UpdateKind.required,
              television: true,
              onLater: () {},
              onRetry: () => retries++,
              openStore: (_) async {
                opens++;
                return false;
              },
              child: TextButton(
                onPressed: () => underlying++,
                child: const Text('수업 시작'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(opens, 1);
      expect(find.textContaining('스토어를 열지 못했어요'), findsOneWidget);
      // Browsers reserve arrows for scrolling; native TV uses D-pad focus.
      await tester.sendKeyEvent(
        kIsWeb ? LogicalKeyboardKey.tab : LogicalKeyboardKey.arrowRight,
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(retries, 1);
      expect(underlying, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'initial and manual native update checks use published platform keys',
    (tester) async {
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';
      final repository = FakeReleases();
      if (platform == 'android') {
        repository.value = release.copyWith(
          storeUrl: 'https://play.google.com/store/apps/details?id=com.sunmkim.cloudboard',
        );
      }
      final container = ProviderContainer(
        overrides: [
          androidTvProvider.overrideWith((ref) async => false),
          checkAppUpdateProvider.overrideWithValue(CheckAppUpdate(repository)),
        ],
      );
      addTearDown(container.dispose);
      final initial = await container.read(appUpdateControllerProvider.future);
      if (kIsWeb) {
        expect(initial, isNull);
        expect(repository.requestedPlatforms, isEmpty);
        return;
      }
      expect(initial?.kind, UpdateKind.optional);
      await container.read(appUpdateControllerProvider.notifier).checkNow();
      expect(repository.requestedPlatforms, [platform, platform]);
      expect(
        container.read(appUpdateControllerProvider).requireValue?.kind,
        UpdateKind.optional,
      );
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'required update waits for playback recovery and a paused class to end',
    (tester) async {
      final stream = StreamController<PlaybackSession?>();
      addTearDown(stream.close);
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
      );
      addTearDown(router.dispose);
      final session = PlaybackSession(
        id: 'class',
        ownerId: 'owner',
        zoneId: 'main',
        workout: Workout.empty(
          'w',
          const WorkoutAuthor(id: 'owner', displayName: '', photoUrl: null),
        ),
        status: PlaybackStatus.paused,
        stepIndex: 0,
        remainingMs: 5000,
        anchorServerMs: 1,
        revision: 1,
        updatedByDeviceId: 'phone',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appRouterProvider.overrideWith((ref) => router),
            androidTvProvider.overrideWith((ref) async => false),
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
            billingActionsProvider.overrideWith(
              (ref) => BillingActions(FirebaseBillingRepository(NoStore())),
            ),
            appUpdateControllerProvider.overrideWith(FixedUpdate.new),
            activePlaybackSessionProvider.overrideWith((ref) => stream.stream),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AppUpdateGate(child: Text('수업 제어'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('새 버전으로 함께해요'), findsNothing);
      stream.add(session);
      await tester.pumpAndSettle();
      expect(find.text('새 버전으로 함께해요'), findsNothing);
      stream.add(session.copyWith(status: PlaybackStatus.completed));
      await tester.pumpAndSettle();
      expect(find.text('새 버전으로 함께해요'), findsOneWidget);
      stream.addError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('새 버전으로 함께해요'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'showing and dismissing an update retains an unkeyed form subtree',
    (tester) async {
      Widget mount(UpdateKind kind) => MaterialApp(
        home: Scaffold(
          body: UpdatePresentation(
            release: release,
            kind: kind,
            onLater: () {},
            onRetry: () {},
            child: const TextField(),
          ),
        ),
      );
      await tester.pumpWidget(mount(UpdateKind.none));
      await tester.enterText(find.byType(TextField), '아직 저장 안 한 이름');
      await tester.pumpWidget(mount(UpdateKind.required));
      await tester.pumpWidget(mount(UpdateKind.none));
      expect(find.text('아직 저장 안 한 이름'), findsOneWidget);
    },
  );
  test(
    'build comparison handles required, optional, current, newer and unknown',
    () {
      UpdateKind check(int b) =>
          release.evaluate(platform: 'ios', installedBuild: b);
      expect(check(529), UpdateKind.required);
      expect(check(530), UpdateKind.optional);
      expect(check(550), UpdateKind.none);
      expect(check(551), UpdateKind.none);
      expect(check(0), UpdateKind.none);
    },
  );
  test(
    'unpublished, invalid, disabled, foreign or misleading links never block',
    () {
      for (final invalid in [
        release.copyWith(published: false),
        release.copyWith(enabled: false),
        release.copyWith(publishedBuild: 549),
        release.copyWith(minimumBuild: 560),
        release.copyWith(minimumBuild: 0),
        release.copyWith(
          storeUrl: 'https://apps.apple.com.evil.test/app/id6809105126',
        ),
        release.copyWith(storeUrl: 'https://apps.apple.com/app/id1'),
        release.copyWith(storeUrl: 'javascript:alert(1)'),
        release.copyWith(
          storeUrl: 'https://evil@apps.apple.com/app/id6809105126',
        ),
        release.copyWith(
          storeUrl: 'https://apps.apple.com:444/app/id6809105126',
        ),
      ]) {
        expect(
          invalid.evaluate(platform: 'ios', installedBuild: 1),
          UpdateKind.none,
        );
      }
      expect(
        release
            .copyWith(
              storeUrl: 'https://play.google.com/store/apps/details?id=com.sunmkim.cloudboard',
            )
            .validFor('android'),
        isTrue,
      );
    },
  );
  test('fractional or string build config is rejected before coercion', () {
    expect(
      () => AppReleaseModel.fromJson({'latestBuild': 550.4}),
      throwsFormatException,
    );
    expect(
      () => AppReleaseModel.fromJson({'latestBuild': '550'}),
      throwsFormatException,
    );
  });
  test(
    'offline is fail-open and snooze never hides a required update',
    () async {
      final repository = FakeReleases(), check = CheckAppUpdate(FakeReleases());
      expect((await check.call('ios'))!.kind, UpdateKind.optional);
      final actions = CheckAppUpdate(repository);
      await actions.dismiss(550);
      expect(await actions.call('ios'), isNull);
      expect(await actions.call('ios', ignoreSnooze: true), isNotNull);
      repository.build = 529;
      expect((await actions.call('ios'))!.kind, UpdateKind.required);
      repository.offline = true;
      expect(await actions.call('ios'), isNull);
    },
  );
  testWidgets(
    'required update preserves draft, rejects underlying input, reports store failure',
    (tester) async {
      final controller = TextEditingController(text: '작성 중');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdatePresentation(
              release: release,
              kind: UpdateKind.required,
              onLater: () {},
              onRetry: () {},
              openStore: (_) async => false,
              child: TextField(controller: controller),
            ),
          ),
        ),
      );
      expect(find.text('나중에'), findsNothing);
      await tester.tap(find.text('업데이트'));
      await tester.pumpAndSettle();
      expect(find.textContaining('스토어를 열지 못했어요'), findsOneWidget);
      expect(controller.text, '작성 중');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('optional update can be dismissed at narrow large text sizes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: UpdatePresentation(
            release: release,
            kind: UpdateKind.optional,
            onLater: () => dismissed = true,
            onRetry: () {},
            child: const Text('홈'),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('나중에'));
    await tester.tap(find.text('나중에'));
    expect(dismissed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
