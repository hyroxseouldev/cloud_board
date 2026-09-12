import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/profile/domain/entities/user_profile.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/controllers/user_profile_controller.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/views/user_profile_screen.dart';
import 'package:cloud_board/src/app/feature/profile/data/repositories/account_deletion_repository_impl.dart';
import 'package:cloud_board/src/app/feature/profile/domain/repositories/account_deletion_repository.dart';

// Production profile UI, fake profile only. This tool cannot delete any account.
void main() {
  testWidgets('capture profile account deletion and confirmation', (
    tester,
  ) async {
    await (FontLoader('Pretendard')..addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          androidTvProvider.overrideWith((ref) async => false),
          userProfileControllerProvider.overrideWith(_Profile.new),
          accountDeletionRepositoryProvider.overrideWith(
            (ref) => _NeverDelete(),
          ),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: XonTheme.light,
            builder: XonTheme.responsiveBuilder,
            home: const UserProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('계정 삭제'));
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('docs/account-deletion/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('profile');
    await tester.tap(find.text('계정 삭제'));
    await tester.pumpAndSettle();
    await capture('confirmation');
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('계정 삭제'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Profile extends UserProfileController {
  @override
  Future<UserProfile> build() async => const UserProfile(
    id: 'preview',
    email: 'preview@example.invalid',
    displayName: '테스트 운영자',
    photoUrl: null,
  );
}

class _NeverDelete implements AccountDeletionRepository {
  @override
  Future<AccountDeletionResult> deleteAccount() =>
      throw StateError('Screenshot tool cannot delete accounts');
}
