import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          getUserProfileProvider.overrideWith(
            (ref) => GetUserProfile(repository),
          ),
          updateUserProfileProvider.overrideWith(
            (ref) => UpdateUserProfile(repository),
          ),
          androidTvProvider.overrideWith((ref) async => false),
        ],
        child: MaterialApp(
          theme: XonTheme.light,
          builder: XonTheme.responsiveBuilder,
          home: const UserProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final name = find.widgetWithText(TextField, '이름');
    await tester.enterText(name, 'New coach');
    await tester.ensureVisible(find.text('변경사항 저장'));
    await tester.tap(find.text('변경사항 저장'));
    await tester.pump();
    expect(find.text('계정 정보'), findsOneWidget);
    expect(find.text('이용 정보'), findsOneWidget);
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
    expect(find.text('계정 정보'), findsOneWidget);
    expect(find.text('New coach'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('프로필을 저장하지 못했습니다'), findsOneWidget);

    repository.pending = Completer<UserProfile>();
    await tester.tap(find.text('변경사항 저장'));
    await tester.pump();
    repository.pending.complete(_profile.copyWith(displayName: 'New coach'));
    await tester.pumpAndSettle();
    expect(repository.saves, 2);
    expect(find.text('프로필을 저장했습니다.'), findsOneWidget);
    expect(find.text('New coach'), findsNWidgets(2));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('로그아웃'), findsOneWidget);
  });
}
