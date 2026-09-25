import 'dart:async';
import 'dart:typed_data';

import 'package:go_router/go_router.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/entitlement/presentation/controllers/entitlement_controller.dart';
import 'package:cloud_board/src/app/feature/profile/domain/entities/user_profile.dart';
import 'package:cloud_board/src/app/feature/profile/domain/repositories/user_profile_repository.dart';
import 'package:cloud_board/src/app/feature/profile/domain/usecases/user_profile_actions.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/views/user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const _profile = UserProfile(
  id: 'coach',
  email: 'coach@example.com',
  displayName: 'Coach',
  photoUrl: null,
);

class _Profiles implements UserProfileRepository {
  Completer<UserProfile> pending = Completer<UserProfile>();
  int saves = 0;

  @override
  Future<UserProfile> getProfile() async => _profile;

  @override
  Future<UserProfile> updateProfile({
    required String displayName,
    Uint8List? avatarBytes,
    String? avatarExtension,
  }) {
    saves++;
    return pending.future;
  }
}

void main() {
  testWidgets('profile stays visible during save and failure allows retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(834, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Profiles();
    final guard = ExitGuard();
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, _) => const UserProfileScreen(),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, _) => EditUserProfileScreen(guard: guard),
              onExit: (_, _) => guard.confirm(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    final accounts = StreamController<AuthUser?>();
    addTearDown(accounts.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) async* {
            yield const AuthUser(
              id: 'coach',
              email: 'coach@example.com',
              displayName: 'Coach',
              photoUrl: null,
            );
            yield* accounts.stream;
          }),
          storeAccountLinkProvider.overrideWith((ref) async => 'linked'),
          getUserProfileProvider.overrideWith(
            (ref) => GetUserProfile(repository),
          ),
          updateUserProfileProvider.overrideWith(
            (ref) => UpdateUserProfile(repository),
          ),
          androidTvProvider.overrideWith((ref) async => false),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: XonTheme.light,
          builder: XonTheme.responsiveBuilder,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byTooltip('프로필 수정'));
    await tester.pumpAndSettle();
    expect(find.byType(EditUserProfileScreen), findsOneWidget);
    final name = find.byType(TextField);
    await tester.enterText(name, 'New coach');
    await tester.pump();
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('저장하지 않고 나갈까요?'), findsOneWidget);
    await tester.tap(find.text('계속 편집'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('프로필 저장'));
    await tester.tap(find.text('프로필 저장'));
    await tester.pump();
    expect(find.text('로그인 계정'), findsOneWidget);
    expect(find.text('New coach'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(repository.saves, 1);

    repository.pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('로그인 계정'), findsOneWidget);
    expect(find.text('New coach'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('프로필을 저장하지 못했습니다'), findsOneWidget);

    repository.pending = Completer<UserProfile>();
    await tester.tap(find.text('프로필 저장'));
    await tester.pump();
    repository.pending.complete(_profile.copyWith(displayName: 'New coach'));
    await tester.pumpAndSettle();
    expect(repository.saves, 2);
    expect(find.text('프로필을 저장했습니다.'), findsOneWidget);
    expect(find.text('New coach'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/profile');
    expect(find.text('New coach'), findsOneWidget);
    await tester.ensureVisible(find.text('로그아웃'));
    expect(find.text('로그아웃'), findsOneWidget);

    accounts.add(
      const AuthUser(
        id: 'another-coach',
        email: 'another@example.com',
        displayName: 'Another coach',
        photoUrl: null,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('New coach'), findsNothing);
    expect(find.text('coach@example.com'), findsNothing);
  });
}
