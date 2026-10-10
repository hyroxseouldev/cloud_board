import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/data/repositories/onboarding_repository.dart';
import 'package:cloud_board/src/app/feature/onboarding/data/models/center_onboarding_model.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/center_onboarding.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/views/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_board/src/app/feature/onboarding/data/repositories/exploration_repository_impl.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/exploration_progress.dart';

import 'dart:async';

import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const user = AuthUser(
  id: 'owner',
  email: '',
  displayName: '테스트',
  photoUrl: null,
);

class FakeOnboarding implements OnboardingRepository {
  FakeOnboarding(this.value);
  CenterOnboarding value;
  bool fail = false;
  Completer<void>? saveGate;
  int starts = 0, saves = 0;
  @override
  Future<CenterOnboarding> load() async => value;
  @override
  Future<void> sendCode(String phone) async {
    if (fail) throw StateError('문자 전송 실패');
  }

  @override
  Future<CenterOnboarding> verifyCode(String code) async =>
      value = value.copyWith(phoneRequired: false, storeId: 'center');
  @override
  Future<CenterOnboarding> save(
    CenterOnboarding current,
    CenterProfile profile,
    int step,
    String action,
  ) async {
    saves++;
    await saveGate?.future;
    if (fail) throw StateError('저장 실패');
    return value = value.copyWith(
      profile: profile,
      revision: current.revision + 1,
      step: step,
      completed: action == 'complete',
      deferred: action == 'defer',
    );
  }

  @override
  Future<CenterOnboarding> startTrial() async {
    starts++;
    return value;
  }
}

Widget app(FakeOnboarding repository, {String? purpose}) => ProviderScope(
  overrides: [
    authStateProvider.overrideWith((ref) => Stream.value(user)),
    onboardingRepositoryProvider.overrideWith((ref) => repository),
  ],
  child: MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: XonTheme.light,
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => OnboardingScreen(purpose: purpose),
        ),
        GoRoute(
          path: '/explore',
          builder: (_, _) => const Scaffold(body: Text('예시 체험 화면')),
        ),
        GoRoute(
          path: '/starter-workouts',
          builder: (_, state) => Scaffold(
            key: ValueKey('resumed-${state.uri.queryParameters['starter']}'),
            body: const Text('내 수업 준비 화면'),
          ),
        ),
        GoRoute(
          path: '/first-class',
          builder: (_, _) => const Scaffold(body: Text('첫 수업 안내')),
        ),
      ],
    ),
  ),
);
void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  test(
    'late onboarding response cannot replace the newly signed-in account',
    () async {
      final users = StreamController<AuthUser?>();
      final repository = FakeOnboarding(
        const CenterOnboarding(phoneRequired: false, storeId: 'first'),
      );
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((_) => users.stream),
          onboardingRepositoryProvider.overrideWith((_) => repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await users.close();
      });
      container.listen(onboardingControllerProvider, (_, _) {});
      container.listen(onboardingActionProvider, (_, _) {});
      users.add(user);
      await container.pump();
      await container.read(onboardingControllerProvider.future);
      repository.saveGate = Completer<void>();
      final saving = container
          .read(onboardingActionProvider.notifier)
          .save(const CenterProfile(purpose: 'operating'), 1);
      repository.value = const CenterOnboarding(
        phoneRequired: false,
        storeId: 'second',
        profile: CenterProfile(purpose: 'exploring'),
      );
      users.add(user.copyWith(id: 'other'));
      await container.pump();
      await container.read(onboardingControllerProvider.future);
      repository.saveGate!.complete();
      expect(await saving, isFalse);
      expect(
        container.read(onboardingControllerProvider).value?.profile.purpose,
        'exploring',
      );
      expect(container.read(onboardingActionProvider).isLoading, isFalse);
    },
  );
  test('DTO roundtrip retains purpose, unknown choices and saved progress', () {
    const p = CenterProfile(
      purpose: 'exploring',
      role: 'coach',
      centerTypes: ['gym'],
      undecidedName: true,
      undecidedRegion: true,
      environmentSkipped: true,
    );
    expect(p.isComplete, isTrue);
    expect(p.copyWith(purpose: 'operating').isComplete, isFalse);
    final restored = CenterOnboardingModel.fromJson({
      'phoneRequired': false,
      'profile': CenterOnboardingModel.profileJson(p),
      'step': 2,
      'revision': 4,
    }).toEntity();
    expect(restored.profile, p);
    expect(restored.step, 2);
    expect(restored.revision, 4);
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(834, 1194),
  ]) {
    testWidgets('purpose selection fits $size and does not begin trial', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeOnboarding(
        const CenterOnboarding(phoneRequired: false, storeId: 'center'),
      );
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '다음'))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('먼저 둘러보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('먼저 둘러보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(repo.value.profile.purpose, 'exploring');
      expect(repo.starts, 0);
      expect(repo.saves, 1);
      expect(repo.value.deferred, isTrue);
      expect(find.text('예시 체험 화면'), findsOneWidget);
      expect(find.text('센터를 조금 알려주세요'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('failed save keeps selected purpose and retry is possible', (
    tester,
  ) async {
    final repo = FakeOnboarding(
      const CenterOnboarding(phoneRequired: false, storeId: 'center'),
    )..fail = true;
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('오픈할 센터 준비하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('어떻게 시작하고 싶으세요?'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(repo.value.profile.purpose, 'preparing');
    expect(repo.starts, 0);
    expect(find.text('내 수업 준비 화면'), findsOneWidget);
  });
  testWidgets(
    'operating intent is preselected, then continues center setup without trial',
    (tester) async {
      final repo = FakeOnboarding(
        const CenterOnboarding(phoneRequired: false, storeId: 'center'),
      );
      await tester.pumpWidget(app(repo, purpose: 'operating'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(repo.value.profile.purpose, 'operating');
      expect(repo.value.deferred, isFalse);
      expect(find.text('센터를 조금 알려주세요'), findsOneWidget);
      expect(repo.starts, 0);
    },
  );
  testWidgets(
    'restart restores this account pending sample import through onboarding',
    (tester) async {
      await LocalExplorationRepository(SharedPreferencesAsync()).save(
        'owner',
        const ExplorationProgress(
          templateKey: 'team',
          purpose: 'preparing',
          pendingImport: true,
        ),
      );
      final repo = FakeOnboarding(
        const CenterOnboarding(phoneRequired: false, storeId: 'center'),
      );
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(repo.value.profile.purpose, 'preparing');
      expect(find.byKey(const ValueKey('resumed-team')), findsOneWidget);
      expect(repo.starts, 0);
    },
  );
  testWidgets(
    'phone verification is shown before center setup; no trial on verify',
    (tester) async {
      final repo = FakeOnboarding(const CenterOnboarding());
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(find.text('휴대폰 번호'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '01012345678');
      final pageScroll = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('인증번호 받기'),
        150,
        scrollable: pageScroll,
      );
      await tester.tap(find.text('인증번호 받기'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('인증번호'),
        150,
        scrollable: pageScroll,
      );
      await tester.enterText(find.byType(TextField).last, '123456');
      await tester.scrollUntilVisible(
        find.text('인증하고 계속하기'),
        150,
        scrollable: pageScroll,
      );
      await tester.tap(find.text('인증하고 계속하기'));
      await tester.pumpAndSettle();
      expect(find.text('어떻게 시작하고 싶으세요?'), findsOneWidget);
      expect(repo.starts, 0);
    },
  );
  testWidgets('trial requires explicit start and completed form resumes', (
    tester,
  ) async {
    final repo = FakeOnboarding(
      CenterOnboarding(
        phoneRequired: false,
        storeId: 'center',
        step: 2,
        profile: const CenterProfile(
          purpose: 'exploring',
          role: 'owner',
          centerTypes: ['gym'],
          undecidedName: true,
          undecidedRegion: true,
        ),
        serverNowMs: 1790330400000,
        suggestedTrialEndsAtMs: 1792922400000,
      ),
    );
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    expect(repo.starts, 0);
    await tester.tap(find.text('1개월 무료로 시작하기'));
    await tester.pumpAndSettle();
    expect(repo.starts, 1);
    expect(repo.value.completed, isTrue);
    expect(find.text('예시 수업 미리보기'), findsOneWidget);
  });

  testWidgets('existing access finishes setup without offering a new trial', (
    tester,
  ) async {
    final repo = FakeOnboarding(
      const CenterOnboarding(
        phoneRequired: false,
        storeId: 'center',
        step: 2,
        hasAccess: true,
        trialEligible: false,
        profile: CenterProfile(
          purpose: 'exploring',
          role: 'owner',
          centerTypes: ['gym'],
          undecidedName: true,
          undecidedRegion: true,
        ),
      ),
    );
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    expect(find.text('지금 시작하면'), findsNothing);
    expect(find.text('체험은 나중에 시작하기'), findsNothing);
    await tester.tap(find.text('센터 설정 마치기'));
    await tester.pumpAndSettle();
    expect(repo.starts, 0);
    expect(repo.value.completed, isTrue);
  });
}
