// Render production settings/news widgets with editorial copy and fake services.
// No network requests or production data writes.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/profile/domain/entities/user_profile.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/controllers/user_profile_controller.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/views/user_profile_screen.dart';
import 'package:cloud_board/src/app/feature/update_news/data/models/update_news_model.dart';
import 'package:cloud_board/src/app/feature/update_news/data/repositories/update_news_repository_impl.dart';
import 'package:cloud_board/src/app/feature/update_news/domain/entities/update_news.dart';
import 'package:cloud_board/src/app/feature/update_news/domain/repositories/update_news_repository.dart';
import 'package:cloud_board/src/app/feature/update_news/presentation/views/update_news_screen.dart';

void main() {
  testWidgets('capture settings, update list and detail', (tester) async {
    await (FontLoader('Pretendard')..addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    // This file is a flutter_test capture tool outside the test/ directory.
    // ignore: invalid_use_of_visible_for_testing_member
    PackageInfo.setMockInitialValues(
      appName: 'CloudBoard',
      packageName: 'cloud_board',
      version: '1.0.0',
      buildNumber: '542',
      buildSignature: '',
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, _) => const UserProfileScreen(),
          routes: [
            GoRoute(
              path: 'updates',
              builder: (_, _) => const UpdateNewsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) =>
                      UpdateNewsDetailScreen(id: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              const AuthUser(
                id: 'preview',
                email: 'preview@example.invalid',
                displayName: '센터 운영자',
                photoUrl: null,
              ),
            ),
          ),
          androidTvProvider.overrideWith((ref) async => false),
          userProfileControllerProvider.overrideWith(_Profile.new),
          updateNewsRepositoryProvider.overrideWithValue(_News()),
        ],
        child: RepaintBoundary(
          key: boundary,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: XonTheme.light,
            builder: XonTheme.responsiveBuilder,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async => tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('/tmp/cloudboard-update-news-$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.ensureVisible(find.text('업데이트 소식'));
    await tester.pumpAndSettle();
    await capture('settings');
    await tester.tap(find.text('업데이트 소식'));
    await tester.pumpAndSettle();
    await capture('list');
    await tester.tap(find.text('더 편해진 수업 준비'));
    await tester.pumpAndSettle();
    await capture('detail');
    expect(tester.takeException(), isNull);
  });
}

class _Profile extends UserProfileController {
  @override
  Future<UserProfile> build() async => const UserProfile(
    id: 'preview',
    email: 'preview@example.invalid',
    displayName: '센터 운영자',
    photoUrl: null,
  );
}

class _News implements UpdateNewsRepository {
  final Set<String> ids = {};
  @override
  Future<List<UpdateNews>> load() async => [
    UpdateNewsModel.fromJson({
      ...jsonDecode(File('release-notes/current.json').readAsStringSync())
          as Map<String, dynamic>,
      'builds': {'ios': '542'},
    }).toEntity(),
  ];
  @override
  Future<InstalledRelease> installed() async =>
      (platform: 'ios', version: '1.0.0', build: '542');
  @override
  Future<Set<String>> readIds(String uid) async => {...ids};
  @override
  Future<void> saveReadIds(String uid, Set<String> values) async {
    ids.addAll(values);
  }
}
