import 'package:cloud_board/src/app/feature/onboarding/data/repositories/exploration_repository_impl.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/exploration_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_board/src/app/core/router/auth_entry_routes.dart';
import 'package:cloud_board/src/app/feature/onboarding/data/repositories/onboarding_repository.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/center_onboarding.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/views/onboarding_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/onboarding_fixture.dart';
import 'support/main_navigation_fixture.dart';

import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/onboarding_controller.dart';

import 'dart:async';

import 'package:cloud_board/src/app/core/router/app_router.dart';
import 'package:cloud_board/src/app/core/widgets/app_startup_screen.dart';
import 'package:cloud_board/src/app/core/widgets/soft_rhythm_loading_mark.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('return locations reject external and recursive entry destinations', () {
    for (final value in [
      'https://example.com',
      '//example.com',
      '/auth-loading?from=/profile',
      '/login?from=/profile',
      '/onboarding',
      '/explore?starter=basics&purpose=operating',
      '/explore/play/basics',
      r'/\example.com',
      'profile',
    ]) {
      expect(entryReturnLocation(value), isNull, reason: value);
    }
    expect(
      entryReturnLocation('/player/w?start=2&session=s#step'),
      '/player/w?start=2&session=s#step',
    );
    expect(
      entryReturnLocation('/onboarding?verify=true'),
      '/onboarding?verify=true',
    );
  });

  testWidgets(
    'iOS and Android cold entry waits without a result screen then opens home',
    (tester) async {
      final repo = FakeOnboarding(confirmedFree)..loadGate = Completer<void>();
      final preview = NavigationPreviewData(
        active: false,
        count: 0,
        onboarding: repo,
      );
      addTearDown(preview.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: preview.container,
          child: const MainNavigationPreview(),
        ),
      );
      await _frames(tester);
      final router = preview.container.read(appRouterProvider);
      expect(router.routeInformationProvider.value.uri.path, '/auth-loading');
      expect(find.byType(AppStartupScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.text('Free 플랜이 활성화됐어요.'), findsNothing);
      repo.loadGate!.complete();
      await _frames(tester);
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.text('기존 이용 권한을 계속 사용할 수 있어요.'), findsNothing);
      expect(repo.loads, 1);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'server lookup error offers retry without onboarding or stale success',
    (tester) async {
      final repo = FakeOnboarding(confirmedFree)
        ..loadError = StateError('offline');
      final preview = NavigationPreviewData(
        active: false,
        count: 0,
        onboarding: repo,
      );
      addTearDown(preview.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: preview.container,
          child: const MainNavigationPreview(),
        ),
      );
      await _frames(tester);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      repo.loadError = null;
      repo.loadGate = Completer<void>();
      await tester.tap(find.text('다시 시도'));
      await _frames(tester);
      expect(find.byType(SoftRhythmLoadingMark), findsOneWidget);
      expect(find.text('Free 플랜이 활성화됐어요.'), findsNothing);
      repo.loadGate!.complete();
      await _frames(tester);
      expect(
        preview.container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/',
      );
      expect(repo.loads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in ['free', 'active', 'trialing']) {
    testWidgets(
      'returning $status restores the exact destination after delayed confirmation',
      (tester) async {
        final repo = FakeOnboarding(
          confirmedFree.copyWith(
            freeActive: status == 'free',
            phoneRequired: status != 'free',
            status: status,
          ),
        )..loadGate = Completer<void>();
        final harness = await _EntryHarness.create(tester, repo);
        addTearDown(harness.dispose);
        const destination = '/player/saved-workout?start=2&session=class#step';
        var waiting = await harness.redirect(destination);
        harness.users.add(onboardingUser);
        await tester.pump(const Duration(milliseconds: 1));
        waiting = await harness.redirect(waiting);
        expect(Uri.parse(waiting).path, '/auth-loading');
        expect(Uri.parse(waiting).queryParameters['from'], destination);
        await tester.pump(const Duration(seconds: 1));
        expect(await harness.redirect(waiting), waiting);
        repo.loadGate!.complete();
        await tester.pump(const Duration(milliseconds: 1));
        expect(await harness.redirect(waiting), destination);
        expect(await harness.redirect('/onboarding'), '/');
        expect(await harness.redirect('/login/email'), '/');
        expect(harness.container.read(appRouterProvider), same(harness.router));
      },
    );
  }

  for (final flag in ['verify', 'edit']) {
    testWidgets(
      'cold explicit $flag survives auth restoration and server loading',
      (tester) async {
        final repo = FakeOnboarding(confirmedFree)
          ..loadGate = Completer<void>();
        final harness = await _EntryHarness.create(tester, repo);
        addTearDown(harness.dispose);
        final destination =
            '/onboarding?$flag=true&starter=team&purpose=preparing&from=%2Fprofile';
        final waiting = await harness.redirect(destination);
        expect(Uri.parse(waiting).queryParameters['from'], destination);
        harness.users.add(onboardingUser);
        await tester.pump(const Duration(milliseconds: 1));
        expect(await harness.redirect(waiting), waiting);
        repo.loadGate!.complete();
        await tester.pump(const Duration(milliseconds: 1));
        expect(await harness.redirect(waiting), destination);
        expect(await harness.redirect(destination), destination);
      },
    );
  }

  testWidgets(
    'lookup failure stays blocked, retry restores intent, expiry requires onboarding',
    (tester) async {
      final repo = FakeOnboarding(confirmedFree)
        ..loadError = StateError('offline');
      final harness = await _EntryHarness.create(tester, repo);
      addTearDown(harness.dispose);
      harness.users.add(onboardingUser);
      await tester.pump(const Duration(milliseconds: 1));
      final waiting = await harness.redirect('/profile');
      expect(Uri.parse(waiting).path, '/auth-loading');
      expect(
        harness.container.read(onboardingRequiredProvider).hasError,
        isTrue,
      );
      repo.loadError = null;
      repo.loadGate = Completer<void>();
      harness.container.invalidate(onboardingControllerProvider);
      await tester.pump(const Duration(milliseconds: 1));
      expect(await harness.redirect(waiting), waiting);
      repo.loadGate!.complete();
      await tester.pump(const Duration(milliseconds: 1));
      expect(await harness.redirect(waiting), '/profile');
      repo.value = confirmedFree.copyWith(
        hasAccess: false,
        activationReady: false,
        freeActive: false,
        status: 'expired',
      );
      harness.container.invalidate(onboardingControllerProvider);
      await tester.pump(const Duration(milliseconds: 1));
      final blocked = Uri.parse(await harness.redirect('/profile'));
      expect(blocked.path, '/onboarding');
      expect(blocked.queryParameters['from'], '/profile');
    },
  );

  testWidgets(
    'real controllers reject prior ready access and late loads across account changes',
    (tester) async {
      final repo = FakeOnboarding(confirmedFree);
      final harness = await _EntryHarness.create(tester, repo);
      addTearDown(harness.dispose);
      harness.users.add(onboardingUser);
      await tester.pump(const Duration(milliseconds: 1));
      expect(await harness.redirect('/profile'), '/profile');
      final oldLoad = Completer<void>();
      repo.loadGate = oldLoad;
      harness.container.invalidate(onboardingControllerProvider);
      await tester.pump(const Duration(milliseconds: 1));
      final waiting = await harness.redirect(
        '/player/account-a-workout?session=a',
      );
      final newLoad = Completer<void>();
      repo.loadGate = newLoad;
      repo.loadError = StateError('account B lookup failed');
      harness.users.add(onboardingUser.copyWith(id: 'other'));
      await tester.pump(const Duration(milliseconds: 1));
      expect(Uri.parse(await harness.redirect(waiting)).path, '/auth-loading');
      oldLoad.complete();
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        harness.container.read(onboardingRequiredProvider).isLoading,
        isTrue,
      );
      newLoad.complete();
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        harness.container.read(onboardingRequiredProvider).hasError,
        isTrue,
      );
      expect(Uri.parse(await harness.redirect(waiting)).path, '/auth-loading');
      repo.loadError = null;
      repo.loadGate = null;
      harness.container.invalidate(onboardingControllerProvider);
      await tester.pump(const Duration(milliseconds: 1));
      expect(await harness.redirect(waiting), '/');
      harness.users.add(null);
      await tester.pump(const Duration(milliseconds: 1));
      expect(Uri.parse(await harness.redirect('/profile')).path, '/login');
      harness.users.add(onboardingUser.copyWith(id: 'other'));
      await tester.pump(const Duration(milliseconds: 1));
      expect(await harness.redirect('/login/email'), '/');
    },
  );

  for (final nextOwner in ['owner', 'other']) {
    testWidgets(
      'normal private page return after sign-out is scoped to $nextOwner',
      (tester) async {
        final harness = await _EntryHarness.create(
          tester,
          FakeOnboarding(confirmedFree),
        );
        addTearDown(harness.dispose);
        harness.users.add(onboardingUser);
        await _frames(tester);
        const destination =
            '/player/account-a-workout?start=2&session=account-a-session#step';
        expect(await harness.redirect(destination), destination);

        harness.users.add(null);
        await _frames(tester);
        final login = Uri.parse(await harness.redirect(destination));
        expect(login.path, '/login');
        expect(login.queryParameters['from'], destination);
        final email = withEntryReturn('/login/email', destination);
        expect(await harness.redirect(email), email);

        harness.users.add(onboardingUser.copyWith(id: nextOwner));
        await _frames(tester);
        expect(
          await harness.redirect(email),
          nextOwner == onboardingUser.id ? destination : '/',
        );
      },
    );
  }

  testWidgets(
    'coalesced sign-out and another login cannot retain the normal private page',
    (tester) async {
      final harness = await _EntryHarness.create(
        tester,
        FakeOnboarding(confirmedFree),
      );
      addTearDown(harness.dispose);
      harness.users.add(onboardingUser);
      await _frames(tester);
      const destination = '/player/account-a-workout?session=account-a-session';
      expect(await harness.redirect(destination), destination);

      // Both auth events arrive before navigation processes the signed-out state.
      harness.users.add(null);
      harness.users.add(onboardingUser.copyWith(id: 'other'));
      await _frames(tester);
      expect(await harness.redirect(destination), '/');
      expect(await harness.redirect('/profile'), '/profile');
    },
  );

  testWidgets(
    'late account A lookup cannot restore its private return or complete account B entry',
    (tester) async {
      final repo = FakeOnboarding(confirmedFree);
      final harness = await _EntryHarness.create(tester, repo);
      addTearDown(harness.dispose);
      harness.users.add(onboardingUser);
      await _frames(tester);
      const destination = '/player/account-a-workout?session=account-a-session';
      expect(await harness.redirect(destination), destination);

      final oldLoad = Completer<void>();
      repo.loadGate = oldLoad;
      harness.container.invalidate(onboardingControllerProvider);
      await _frames(tester);
      harness.users.add(null);
      await _frames(tester);
      final login = await harness.redirect(destination);
      expect(Uri.parse(login).queryParameters['from'], destination);

      final newLoad = Completer<void>();
      repo.loadGate = newLoad;
      repo.value = const CenterOnboarding();
      harness.users.add(onboardingUser.copyWith(id: 'other'));
      await _frames(tester);
      final waiting = await harness.redirect(login);
      expect(Uri.parse(waiting).path, '/auth-loading');
      expect(Uri.parse(waiting).queryParameters.containsKey('from'), isFalse);

      oldLoad.complete();
      await _frames(tester);
      expect(
        harness.container.read(onboardingRequiredProvider).isLoading,
        isTrue,
      );
      expect(await harness.redirect(waiting), waiting);
      newLoad.complete();
      await _frames(tester);
      expect(await harness.redirect(waiting), '/onboarding');
      expect(
        harness.container
            .read(onboardingControllerProvider)
            .requireValue
            .serviceReady,
        isFalse,
      );
      expect(harness.container.read(onboardingCompletionProvider), isFalse);
      // The read creates an auto-disposed provider; drain its disposal timer.
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'account change removes a private return from an unfinished verification route',
    (tester) async {
      final repo = FakeOnboarding(const CenterOnboarding());
      final harness = await _EntryHarness.create(tester, repo);
      addTearDown(harness.dispose);
      harness.users.add(onboardingUser);
      await _frames(tester);
      final first = Uri.parse(
        await harness.redirect('/player/account-a?session=a'),
      );
      expect(first.path, '/onboarding');
      expect(first.queryParameters['from'], '/player/account-a?session=a');
      harness.users.add(onboardingUser.copyWith(id: 'other'));
      await _frames(tester);
      final second = Uri.parse(await harness.redirect(first.toString()));
      expect(second.path, '/onboarding');
      expect(second.queryParameters.containsKey('from'), isFalse);
    },
  );

  testWidgets(
    'saved exploration cannot replace home or explicit destinations',
    (tester) async {
      await LocalExplorationRepository(SharedPreferencesAsync()).save(
        'owner',
        const ExplorationProgress(
          templateKey: 'team',
          purpose: 'preparing',
          pendingImport: true,
        ),
      );
      final harness = await _EntryHarness.create(
        tester,
        FakeOnboarding(confirmedFree),
      );
      addTearDown(harness.dispose);
      harness.users.add(onboardingUser);
      await _frames(tester);
      expect(await harness.redirect('/onboarding'), '/');
      expect(
        await harness.redirect('/explore?starter=basics&purpose=operating'),
        '/explore?starter=basics&purpose=operating',
      );
      expect(
        await harness.redirect('/login?from=%2Fexplore%3Fstarter%3Dbasics'),
        '/',
      );
      expect(await harness.redirect('/login?from=%2Fprofile'), '/profile');
      expect(
        await harness.redirect('/login?starter=interval&purpose=exploring'),
        '/starter-workouts?starter=interval&purpose=exploring',
      );
      harness.users.add(onboardingUser.copyWith(id: 'other'));
      await tester.pump(const Duration(milliseconds: 1));
      final pending = await harness.redirect('/onboarding');
      await _frames(tester);
      expect(await harness.redirect(pending), '/');
    },
  );

  testWidgets(
    'new verification keeps one completion screen then enters service without repeating',
    (tester) async {
      final repo = FakeOnboarding(const CenterOnboarding());
      final preview = NavigationPreviewData(
        active: false,
        count: 0,
        onboarding: repo,
      );
      addTearDown(preview.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: preview.container,
          child: const MainNavigationPreview(),
        ),
      );
      await _frames(tester);
      final router = preview.container.read(appRouterProvider);
      expect(router.routeInformationProvider.value.uri.path, '/onboarding');
      await tester.enterText(find.byType(TextField).first, '01012345678');
      await tester.ensureVisible(find.text('휴대폰 인증하기'));
      await tester.tap(find.text('휴대폰 인증하기'));
      await _frames(tester);
      await tester.enterText(find.byType(TextField).last, '123456');
      await tester.scrollUntilVisible(
        find.text('인증하고 계속하기'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byType(TextField).last);
      await tester.enterText(find.byType(TextField).last, '123456');
      await tester.ensureVisible(find.text('인증하고 계속하기'));
      await tester.tap(find.text('인증하고 계속하기'));
      await _frames(tester);
      expect(router.routeInformationProvider.value.uri.path, '/onboarding');
      expect(find.text('Free 플랜이 활성화됐어요.'), findsOneWidget);
      await tester.ensureVisible(find.text('내 수업으로 가기'));
      await tester.tap(find.text('내 수업으로 가기'));
      await _frames(tester);
      expect(router.routeInformationProvider.value.uri.path, '/');
      router.go('/onboarding');
      await _frames(tester);
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  const user = AuthUser(
    id: 'u',
    email: 'coach@example.com',
    displayName: 'Coach',
    photoUrl: null,
  );

  testWidgets('owner access waits for server confirmation', (tester) async {
    final gate = Completer<bool>();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(user.copyWith(needsOnboarding: true)),
        ),
        onboardingRequiredProvider.overrideWith((ref) => gate.future),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(appRouterProvider, (_, _) {});
    addTearDown(subscription.close);
    final router = subscription.read();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(milliseconds: 1));
    final context = tester.element(find.byType(SizedBox).first);
    Future<String> redirected(String path) async =>
        (await router.configuration.redirect(
          context,
          router.configuration.findMatch(Uri.parse(path)),
          redirectHistory: [],
        )).uri.path;
    expect(await redirected('/'), '/auth-loading');
    expect(await redirected('/onboarding'), '/onboarding');
    expect(await redirected('/login/email'), '/auth-loading');
    gate.complete(false);
    await tester.pump(const Duration(milliseconds: 1));
    expect(await redirected('/profile'), '/profile');
    expect(await redirected('/onboarding'), '/');
    expect(await redirected('/login'), '/');
    expect(await redirected('/login/email'), '/');
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'restores auth before showing login and keeps the router stable',
    (tester) async {
      final users = StreamController<AuthUser?>();
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => users.stream),
          onboardingRequiredProvider.overrideWith((ref) async => false),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await users.close();
      });
      final subscription = container.listen(appRouterProvider, (_, _) {});
      addTearDown(subscription.close);
      final router = subscription.read();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(SoftRhythmLoadingMark), findsOneWidget);
      expect(find.byType(AppStartupScreen), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/auth-loading');

      // Exercise the real redirect configuration without constructing feature
      // screens that require Firebase and device integrations.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox).first);
      Future<Uri> redirect(String location) async {
        final matches = await router.configuration.redirect(
          context,
          router.configuration.findMatch(Uri.parse(location)),
          redirectHistory: [],
        );
        return matches.uri;
      }

      final pending = await redirect('/player/workout?start=2&session=class');
      expect(pending.path, '/auth-loading');
      users.add(user);
      await tester.pump(const Duration(milliseconds: 1));
      expect(container.read(appRouterProvider), same(router));
      expect((await redirect('/login')).path, '/');
      expect(
        (await redirect(pending.toString())).toString(),
        '/player/workout?start=2&session=class',
      );

      // Profile changes must not reset navigation or create a new router.
      users.add(user.copyWith(displayName: 'Updated'));
      await tester.pump(const Duration(milliseconds: 1));
      expect(container.read(appRouterProvider), same(router));
      expect((await redirect('/profile')).path, '/profile');

      users.add(null);
      await tester.pump(const Duration(milliseconds: 1));
      expect(container.read(appRouterProvider), same(router));
      expect((await redirect('/profile')).path, '/login');
      expect((await redirect('/login')).path, '/login');
      expect((await redirect('/login/email')).path, '/login/email');
      expect((await redirect(pending.toString())).path, '/login');
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _EntryHarness {
  _EntryHarness(this.tester, this.container, this.users, this.router);
  final WidgetTester tester;
  final ProviderContainer container;
  final StreamController<AuthUser?> users;
  final GoRouter router;

  static Future<_EntryHarness> create(
    WidgetTester tester,
    FakeOnboarding repo,
  ) async {
    final users = StreamController<AuthUser?>();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authStateProvider.overrideWith((_) => users.stream),
        onboardingRepositoryProvider.overrideWith((_) => repo),
        existingMemberAccessProvider.overrideWith((_) => Stream.value(false)),
      ],
    );
    container.listen(appRouterProvider, (_, _) {});
    final router = container.read(appRouterProvider);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(milliseconds: 1));
    return _EntryHarness(tester, container, users, router);
  }

  Future<String> redirect(String location) async {
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    final result = await router.configuration.redirect(
      tester.element(find.byType(SizedBox).first),
      router.configuration.findMatch(Uri.parse(location)),
      redirectHistory: [],
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    return result.uri.toString();
  }

  void dispose() {
    container.dispose();
    unawaited(users.close());
  }
}
