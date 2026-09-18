import 'dart:async';

import 'package:cloud_board/src/app/core/router/app_router.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  const user = AuthUser(
    id: 'u',
    email: 'coach@example.com',
    displayName: 'Coach',
    photoUrl: null,
  );

  testWidgets(
    'restores auth before showing login and keeps the router stable',
    (tester) async {
      final users = StreamController<AuthUser?>();
      final container = ProviderContainer(
        overrides: [authStateProvider.overrideWith((ref) => users.stream)],
      );
      addTearDown(() async {
        container.dispose();
        await users.close();
      });
      final subscription = container.listen(appRouterProvider, (_, _) {});
      addTearDown(subscription.close);
      final router = subscription.read();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
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
      await tester.pump();
      expect(container.read(appRouterProvider), same(router));
      expect((await redirect('/login')).path, '/');
      expect(
        (await redirect(pending.toString())).toString(),
        '/player/workout?start=2&session=class',
      );

      // Profile changes must not reset navigation or create a new router.
      users.add(user.copyWith(displayName: 'Updated'));
      await tester.pump();
      expect(container.read(appRouterProvider), same(router));
      expect((await redirect('/profile')).path, '/profile');

      users.add(null);
      await tester.pump();
      expect(container.read(appRouterProvider), same(router));
      expect((await redirect('/profile')).path, '/login');
      expect((await redirect('/login')).path, '/login');
      expect((await redirect(pending.toString())).path, '/login');
    },
  );
}
