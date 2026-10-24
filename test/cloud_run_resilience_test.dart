import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/onboarding/data/repositories/onboarding_repository.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/first_class_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/onboarding_controller.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/router/app_router.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/existing_member_access.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/entities/store_entitlement.dart';
import 'package:cloud_board/src/app/feature/device/domain/display_resume_authorization.dart';
import 'package:cloud_board/src/app/feature/device/data/datasources/device_pairing_realtime_data_source.dart';

import 'support/main_navigation_fixture.dart';
import 'support/onboarding_fixture.dart';

void main() {
  test('home first-class guidance reads DB summary without invoking onboarding load', () async {
    final repo = FakeOnboarding(
      confirmedFree.copyWith(storeId: 'center', completed: true),
    )..loadError = StateError('Functions 500');
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((_) => Stream.value(onboardingUser)),
        accountOwnerIdProvider.overrideWith(
          (_) => Stream.value(onboardingUser.id),
        ),
        onboardingRepositoryProvider.overrideWith((_) => repo),
      ],
    );
    addTearDown(container.dispose);
    container.listen(firstClassScopeProvider, (_, _) {});
    await container.pump();
    await container.read(authStateProvider.future);
    await container.pump();
    final scope = await container.read(firstClassScopeProvider.future);
    expect(scope?.centerId, 'center');
    expect(scope?.centerReady, true);
    expect(repo.summaryReads, 1);
    expect(repo.loads, 0);
  });
  const grant = StoreEntitlement(
    ownerId: 'owner',
    status: 'active',
    plan: 'free',
    validUntilMs: 2000,
    revision: 3,
    serverConfirmed: true,
    canStartClass: true,
    policyVersion: 'plan-entitlements-v2',
  );
  final wire = {
    'managed': true,
    'canStartClass': true,
    'status': 'active',
    'plan': 'free',
    'validUntilMs': 2000,
    'revision': 3,
    'source': 'verified_free',
    'policyVersion': 'plan-entitlements-v2',
  };
  bool allowed(
    StoreEntitlement value, {
    Object? access,
    String uid = 'owner',
    int now = 1000,
  }) => existingMemberMayEnter(
    uid: uid,
    grant: value,
    source: 'verified_free',
    realtimeAccess: access ?? wire,
    serverNowMs: now,
  );
  test('only the current server-confirmed, unexpired matching entitlement admits entry', () {
    expect(allowed(grant), true);
    expect(allowed(grant, uid: 'other'), false);
    expect(allowed(grant, now: 2000), false);
    expect(allowed(grant.copyWith(serverConfirmed: false)), false);
    expect(allowed(grant.copyWith(canStartClass: false)), false);
    for (final status in [
      'suspended',
      'expired',
      'pending_connection',
      'awaiting_web',
    ]) {
      expect(allowed(grant.copyWith(status: status)), false, reason: status);
    }
    for (final key in [
      'plan',
      'status',
      'validUntilMs',
      'revision',
      'source',
      'policyVersion',
      'managed',
      'canStartClass',
    ]) {
      expect(allowed(grant, access: {...wire, key: null}), false, reason: key);
    }
  });
  test('Free and paid projections use identical entry decisions', () {
    for (final plan in ['free', 'plus', 'premium']) {
      expect(
        allowed(grant.copyWith(plan: plan), access: {...wire, 'plan': plan}),
        true,
      );
    }
  });
  test('display reconnect requires both pointers and the exact server registration generation', () {
    final access = {
      'ownerId': 'owner',
      'deviceId': 'screen',
      'pairingCode': '123456',
      'pairedAtMs': 1,
    };
    final proof = {...access, 'protocol': 1};
    final device = {
      'id': 'screen',
      'displayUid': 'tv',
      'mode': 'display',
      'paired': true,
      'pairingCode': '123456',
      'pairedAtMs': 1,
    };
    bool check({Object? g, Object? a, Object? d, String uid = 'tv'}) =>
        displayMayResume(
          uid: uid,
          ownerId: 'owner',
          deviceId: 'screen',
          pairingCode: '123456',
          grant: g ?? proof,
          access: a ?? access,
          device: d ?? device,
        );
    expect(check(), true);
    expect(check(uid: 'new-anonymous-login'), false);
    expect(check(d: {...device, 'displayUid': null}), false);
    expect(check(d: {...device, 'paired': false}), false);
    expect(check(g: {...proof, 'pairedAtMs': 2}), false);
    expect(check(a: {...access, 'ownerId': 'other'}), false);
  });
  test('rules-authorized presence cannot reuse an old verification or ready timestamp', () {
    final raw = {
      'id': 'screen',
      'paired': true,
      'mode': 'display',
      'presenceProtocol': 2,
      'currentConnectionId': 'new',
      'connectionVerification': {'connectionId': 'old', 'verifiedAtMs': 100},
      'presence': {
        'new': {
          'online': true,
          'authorizedAtMs': 1000,
          'lastSeenAtMs': 1000,
          'readyAtMs': 900,
        },
      },
    };
    final d = decodeDisplayDevice('screen', raw);
    expect(d.verifiedConnectionId, 'old');
    expect(d.connectionAuthenticated(1100), true);
    expect(d.playbackReady(1100), false);
    final absent = decodeDisplayDevice('screen', {
      ...raw,
      'presence': {
        'new': {'online': true, 'lastSeenAtMs': 1000, 'readyAtMs': 1000},
      },
    });
    expect(absent.connectionAuthenticated(1100), false);
  });
  for (final failure in ['500', 'timeout']) {
    testWidgets(
      'real router opens home without invoking onboarding during $failure',
      (tester) async {
        final repo = FakeOnboarding(confirmedFree)
          ..loadError = StateError(failure);
        if (failure == 'timeout') repo.loadGate = Completer<void>();
        final preview = NavigationPreviewData(
          active: false,
          count: 0,
          onboarding: repo,
          existingAccess: Stream.value(true),
        );
        addTearDown(preview.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: preview.container,
            child: const MainNavigationPreview(),
          ),
        );
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        final router = preview.container.read(appRouterProvider);
        expect(router.routeInformationProvider.value.uri.path, '/');
        expect(repo.loads, 0);
        expect(tester.takeException(), isNull);
        repo.loadGate?.complete();
      },
    );
  }
  testWidgets(
    'a later access revocation invalidates router success and uses recovery',
    (tester) async {
      final access = StreamController<bool>.broadcast();
      final repo = FakeOnboarding(confirmedFree);
      final preview = NavigationPreviewData(
        active: false,
        count: 0,
        onboarding: repo,
        existingAccess: access.stream,
      );
      addTearDown(() async {
        preview.dispose();
        await access.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: preview.container,
          child: const MainNavigationPreview(),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      access.add(true);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final router = preview.container.read(appRouterProvider);
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(repo.loads, 0);
      // A previous profile lookup must not become a stale permission fallback.
      final profile = preview.container.read(
        onboardingControllerProvider.future,
      );
      await tester.runAsync(() => profile);
      repo.loadError = StateError('functions down');
      access.add(false);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(router.routeInformationProvider.value.uri.path, '/auth-loading');
      expect(repo.loads, 2);
    },
  );
}
