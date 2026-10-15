import 'dart:async';

import 'package:cloud_board/src/app/core/config/app_brand.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/data/repositories/onboarding_repository.dart';
import 'package:cloud_board/src/app/feature/onboarding/data/models/center_onboarding_model.dart';
import 'package:cloud_board/src/app/feature/onboarding/data/repositories/exploration_repository_impl.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/center_onboarding.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/exploration_progress.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/onboarding_fixture.dart';

Future<void> tapVisible(WidgetTester tester, String label) async {
  if (find.text(label).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(label),
      180,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await tester.pump();
}

Future<void> enterVerification(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, '01012345678');
  await tapVisible(tester, '휴대폰 인증하기');
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byType(TextField).last);
  await tester.enterText(find.byType(TextField).last, '123456');
  await tapVisible(tester, '인증하고 계속하기');
}

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
      users.add(onboardingUser);
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
      users.add(onboardingUser.copyWith(id: 'other'));
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
  test('verification completion from before A to B to A cannot grant access or celebrate', () async {
    final users = StreamController<AuthUser?>();
    final repository = FakeOnboarding(const CenterOnboarding())
      ..verifyGate = Completer<void>();
    final container = ProviderContainer(
      retry: (_, _) => null,
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
    container.listen(onboardingCompletionProvider, (_, _) {});
    users.add(onboardingUser);
    await container.pump();
    await container.read(onboardingControllerProvider.future);
    final verifying = container
        .read(onboardingActionProvider.notifier)
        .verifyCode('123456');
    users.add(onboardingUser.copyWith(id: 'other'));
    await container.pump();
    await container.read(onboardingControllerProvider.future);
    users.add(onboardingUser);
    await container.pump();
    await container.read(onboardingControllerProvider.future);
    repository.verifyGate!.complete();
    expect(await verifying, isFalse);
    expect(
      container.read(onboardingControllerProvider).requireValue.serviceReady,
      isFalse,
    );
    expect(container.read(onboardingCompletionProvider), isFalse);
  });

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
      'freeAvailable': true,
      'freeActive': true,
    }).toEntity();
    expect(restored.profile, p);
    expect(restored.step, 2);
    expect(restored.revision, 4);
    expect(restored.freeAvailable, isTrue);
    expect(restored.freeActive, isTrue);
    expect(
      CenterOnboardingModel.fromJson({}).toEntity().freeAvailable,
      isFalse,
    );
  });
  test('only server-confirmed access opens service; old completion cannot bypass it', () async {
    final repo = FakeOnboarding(
      const CenterOnboarding(completed: true, deferred: true),
    );
    final container = ProviderContainer.test(
      overrides: [
        authStateProvider.overrideWith((_) => Stream.value(onboardingUser)),
        onboardingRepositoryProvider.overrideWith((_) => repo),
      ],
    );
    container.listen(authStateProvider, (_, _) {});
    container.listen(onboardingRequiredProvider, (_, _) {});
    await container.pump();
    expect(await container.read(onboardingRequiredProvider.future), isTrue);
    for (final value in [
      confirmedFree.copyWith(activationReady: false),
      confirmedFree.copyWith(hasAccess: false),
      confirmedFree.copyWith(phoneRequired: true),
    ]) {
      container.read(onboardingControllerProvider.notifier).replace(value);
      expect(await container.read(onboardingRequiredProvider.future), isTrue);
    }
    container
        .read(onboardingControllerProvider.notifier)
        .replace(confirmedFree);
    expect(await container.read(onboardingRequiredProvider.future), isFalse);
    // A real, unexpired paid/trial grant remains usable without new SMS proof.
    container
        .read(onboardingControllerProvider.notifier)
        .replace(
          confirmedFree.copyWith(
            phoneRequired: true,
            freeActive: false,
            status: 'trialing',
          ),
        );
    expect(await container.read(onboardingRequiredProvider.future), isFalse);
  });

  test('missing activation confirmation never implies successful Free', () {
    final old = CenterOnboardingModel.fromJson({
      'phoneRequired': false,
      'hasAccess': true,
      'freeActive': true,
    }).toEntity();
    expect(old.serviceReady, isFalse);
    expect(old.trialEligible, isFalse);
    final current = CenterOnboardingModel.fromJson({
      'phoneRequired': false,
      'hasAccess': true,
      'freeActive': true,
      'activationReady': true,
    });
    expect(current.toEntity().serviceReady, isTrue);
    expect(
      CenterOnboardingModel.fromJson(current.toJson()).toEntity(),
      current.toEntity(),
    );
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(834, 1194),
  ]) {
    testWidgets(
      'SMS -> confirmed Free -> service without center questionnaire at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = FakeOnboarding(const CenterOnboarding())
          ..verifyGate = Completer<void>();
        await tester.pumpWidget(onboardingApp(repo));
        await tester.pumpAndSettle();
        expect(find.text(AppBrand.name), findsOneWidget);
        expect(find.text('Free 플랜을 사용하려면 휴대폰 인증을 완료해 주세요.'), findsOneWidget);
        await enterVerification(tester);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Free 플랜이 활성화됐어요.'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        repo.verifyGate!.complete();
        await tester.pumpAndSettle();
        expect(find.text('Free 플랜이 활성화됐어요.'), findsOneWidget);
        expect(find.textContaining('1개월'), findsNothing);
        expect(repo.saves, 0);
        expect(repo.value.profile.isComplete, isFalse);
        await tapVisible(tester, '내 수업으로 가기');
        await tester.pumpAndSettle();
        expect(find.text('내 수업 화면'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'verification failure preserves phone/code and load repairs partial activation',
    (tester) async {
      final repo = FakeOnboarding(const CenterOnboarding())
        ..verifyError = StateError('권한 반영 재시도 필요');
      await tester.pumpWidget(onboardingApp(repo));
      await tester.pumpAndSettle();
      await enterVerification(tester);
      await tester.pumpAndSettle();
      expect(find.text('Free 플랜이 활성화됐어요.'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '01012345678',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        '123456',
      );
      repo.loadError = StateError('네트워크 연결 실패');
      await tapVisible(tester, '이용 상태 다시 확인');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('네트워크 연결 실패'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('네트워크 연결 실패'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        '123456',
      );
      repo.loadError = null;
      repo.value = confirmedFree;
      await tapVisible(tester, '이용 상태 다시 확인');
      await tester.pumpAndSettle();
      expect(find.text('Free 플랜이 활성화됐어요.'), findsOneWidget);
      expect(repo.verifications, 1);
      expect(repo.saves, 0);
    },
  );

  testWidgets(
    'restart ignores retired sample selection and retries server activation without SMS',
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
        confirmedFree.copyWith(activationReady: false),
      );
      await tester.pumpWidget(onboardingApp(repo));
      await tester.pumpAndSettle();
      expect(find.text('Free 플랜이 활성화됐어요.'), findsNothing);
      expect(find.text('이용 상태를 확인해 주세요.'), findsOneWidget);
      repo.value = confirmedFree;
      await tapVisible(tester, '이용 상태 다시 확인');
      await tester.pumpAndSettle();
      expect(find.text('선택한 예시로 내 수업 만들기'), findsNothing);
      expect(find.text('먼저 둘러보기'), findsNothing);
      await tapVisible(tester, '내 수업으로 가기');
      await tester.pumpAndSettle();
      expect(find.text('내 수업 화면'), findsOneWidget);
      expect(repo.verifications, 0);
      expect(repo.saves, 0);
    },
  );

  testWidgets('center form is optional and failed save preserves fields', (
    tester,
  ) async {
    final repo = FakeOnboarding(
      confirmedFree.copyWith(
        profile: const CenterProfile(
          purpose: 'preparing',
          role: 'owner',
          centerTypes: ['gym'],
          undecidedName: true,
          undecidedRegion: true,
        ),
      ),
    )..fail = true;
    await tester.pumpWidget(onboardingApp(repo, editing: true));
    await tester.pumpAndSettle();
    expect(find.text('센터 정보를 수정해요'), findsOneWidget);
    await tapVisible(tester, '다음');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('저장 실패'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('저장 실패'), findsOneWidget);
    repo.fail = false;
    await tapVisible(tester, '다음');
    await tester.pumpAndSettle();
    expect(find.textContaining('프리미엄 1개월'), findsNothing);
    await tapVisible(tester, '센터 설정 마치기');
    await tester.pumpAndSettle();
    expect(repo.value.completed, isTrue);
    expect(repo.value.profile.role, 'owner');
    expect(repo.value.freeActive, isTrue);
  });

  testWidgets(
    'unverified existing paid access continues, with optional SMS verification',
    (tester) async {
      final repo = FakeOnboarding(
        confirmedFree.copyWith(phoneRequired: true, freeActive: false),
      );
      await tester.pumpWidget(onboardingApp(repo));
      await tester.pumpAndSettle();
      expect(find.text('기존 이용 권한을 계속 사용할 수 있어요.'), findsOneWidget);
      expect(find.text('Free 플랜이 활성화됐어요.'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await tapVisible(tester, '휴대폰 인증하기');
      await tester.pumpAndSettle();
      expect(find.text('휴대폰 번호'), findsOneWidget);
      expect(repo.verifications, 0);
    },
  );

  testWidgets(
    'existing live trial dates remain visible in optional center setup',
    (tester) async {
      final repo = FakeOnboarding(
        confirmedFree.copyWith(
          freeActive: false,
          status: 'trialing',
          trialStartedAtMs: 1790330400000,
          trialEndsAtMs: 1792922400000,
          profile: const CenterProfile(
            purpose: 'preparing',
            role: 'owner',
            centerTypes: ['gym'],
            undecidedName: true,
            undecidedRegion: true,
          ),
        ),
      );
      await tester.pumpWidget(onboardingApp(repo, editing: true));
      await tester.pumpAndSettle();
      await tapVisible(tester, '다음');
      await tester.pumpAndSettle();
      expect(find.text('이용 중인 권한을 그대로 이어가요'), findsOneWidget);
      await tester.ensureVisible(find.textContaining('기존 체험 기간:'));
      expect(find.textContaining('기존 체험 기간:'), findsOneWidget);
      expect(find.textContaining('무료 이용 시작'), findsNothing);
    },
  );
}
