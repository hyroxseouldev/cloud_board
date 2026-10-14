import 'dart:async';

import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/views/display_settings_screen.dart';
import 'package:cloud_board/src/app/feature/device/presentation/views/first_tv_connection_screen.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/add_display_dialog.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/center_onboarding.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/views/more_screen.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/views/user_profile_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_library_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'support/management_journey_fixture.dart';

void main() {
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'CloudBoard',
      packageName: 'fixture',
      version: '1.0',
      buildNumber: '1',
      buildSignature: '',
    ),
  );
  Future<void> mount(
    WidgetTester tester,
    ManagementFixture data,
    Widget page, {
    double width = 390,
    double scale = 1,
    GoRouter? router,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(data.dispose);
    await tester.pumpWidget(data.app(page, textScale: scale, router: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'more groups six real destinations and profile summary navigates',
    (tester) async {
      final data = ManagementFixture();
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const MoreScreen()),
          for (final path in [
            '/profile',
            '/operations',
            '/subscription',
            '/first-class',
            '/explore',
            '/profile/updates',
          ])
            GoRoute(
              path: path,
              builder: (_, _) => Scaffold(body: Text('destination $path')),
            ),
        ],
      );
      addTearDown(router.dispose);
      await mount(tester, data, const MoreScreen(), router: router);
      expect(
        tester.getTopLeft(find.text('수업과 센터')).dy,
        lessThan(tester.getTopLeft(find.text('시작과 소식')).dy),
      );
      expect(
        tester.getTopLeft(find.text('매장 관리')).dy,
        lessThan(tester.getTopLeft(find.text('첫 수업 준비')).dy),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('more-profile-summary')))
            .height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.text('프로필 및 설정'));
      await tester.pumpAndSettle();
      expect(find.text('destination /profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unknown profile verification is not presented as a trial offer',
    (tester) async {
      final pending = Completer<CenterOnboarding>();
      await mount(
        tester,
        ManagementFixture(onboarding: pending.future),
        const UserProfileScreen(),
      );
      expect(find.text('인증·센터 정보를 확인하고 있습니다'), findsOneWidget);
      expect(find.textContaining('무료 체험'), findsNothing);
      pending.complete(
        const CenterOnboarding(
          phoneRequired: false,
          storeId: 'center',
          completed: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('휴대폰 인증 완료 · 센터 정보 수정'), findsOneWidget);
      expect(find.text('이름·사진 수정'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'display inventory waits without zero then distinguishes offline',
    (tester) async {
      final stream = StreamController<List<DisplayDevice>>();
      addTearDown(stream.close);
      await mount(
        tester,
        ManagementFixture(devices: stream.stream),
        const DisplaySettingsScreen(asMainTab: true),
      );
      expect(find.text('등록된 TV와 연결 상태를 확인하고 있습니다.'), findsOneWidget);
      expect(find.textContaining('등록 0대'), findsNothing);
      expect(find.textContaining('아직 등록된 디스플레이'), findsNothing);
      stream.add([managementTv(online: false)]);
      await tester.pumpAndSettle();
      expect(find.text('등록 1대 · 온라인 0대'), findsOneWidget);
      expect(find.textContaining('TV 앱과 인터넷 연결을 확인해 주세요.'), findsOneWidget);
      await tester.tap(find.byTooltip('디스플레이 메뉴'));
      await tester.pumpAndSettle();
      expect(find.text('TV 응답 확인'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final limit in [1, 3]) {
    testWidgets(
      'display limit $limit sends only explicitly chosen replacement IDs',
      (tester) async {
        final claims = ManagementClaims();
        final devices = [
          for (var i = 0; i < limit; i++)
            managementTv(id: 'old-$i', name: '사용 중 TV ${i + 1}'),
          managementTv(id: 'target', name: '새 TV', enabled: false),
        ];
        await mount(
          tester,
          ManagementFixture(
            devices: Stream.value(devices),
            claims: claims,
            profile: managementProfile.copyWith(
              subscriptionPlan: limit == 1 ? 'free' : 'plus',
              displayLimit: limit,
            ),
          ),
          const DisplaySettingsScreen(asMainTab: true),
        );
        final target = find.byType(Switch).last;
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(claims.toggles, isEmpty);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, '선택한 TV 대신 송출'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        expect(claims.toggles, isEmpty);
        await tester.tap(target);
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(CheckboxListTile, '사용 중 TV $limit'),
        );
        await tester.pump();
        await tester.tap(find.text('선택한 TV 대신 송출'));
        await tester.pumpAndSettle();
        expect(claims.toggles, hasLength(1));
        expect(claims.toggles.single.id, 'target');
        expect(claims.toggles.single.state, 'auto');
        expect(claims.toggles.single.replace, ['old-${limit - 1}']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'pairing prevents duplicate requests and preserves code while waiting',
    (tester) async {
      final claims = ManagementClaims()..claimResult = Completer<bool>();
      await mount(
        tester,
        ManagementFixture(claims: claims),
        const Scaffold(body: AddDisplayDialog()),
      );
      await tester.enterText(
        find.widgetWithText(TextField, '디스플레이의 6자리 코드'),
        '123456',
      );
      final callback = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '연결하기'))
          .onPressed!;
      callback();
      callback();
      await tester.pump();
      expect(claims.claimCount, 1);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '디스플레이의 6자리 코드'))
            .controller!
            .text,
        '123456',
      );
      claims.claimResult!.complete(false);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '연결하기'))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'server display allowance rejection gives the next action and retains state',
    (tester) async {
      final claims = ManagementClaims()
        ..toggleError = FirebaseException(
          plugin: 'functions',
          code: 'resource-exhausted',
        );
      await mount(
        tester,
        ManagementFixture(
          devices: Stream.value([managementTv(enabled: false)]),
          claims: claims,
        ),
        const DisplaySettingsScreen(asMainTab: true),
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.textContaining('송출 중인 TV를 먼저 끄거나 구독 관리'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('library search reset restores existing slides', (tester) async {
    await mount(
      tester,
      ManagementFixture(
        slides: [WorkoutModule.empty('s').copyWith(name: '기초 수업')],
      ),
      const SlideLibraryScreen(),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '슬라이드 검색'), '없는 수업');
    await tester.pumpAndSettle();
    await tester.tap(find.text('검색 지우기'));
    await tester.pumpAndSettle();
    expect(find.text('기초 수업'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'home shows offline registered displays without a connected success label',
    (tester) async {
      await mount(
        tester,
        ManagementFixture(devices: Stream.value([managementTv(online: false)])),
        const WorkoutListScreen(),
      );
      await tester.pumpAndSettle();
      expect(find.text('등록된 디스플레이 오프라인 · TV 확인'), findsOneWidget);
      expect(find.textContaining('대 연결됨'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty workout library creates a class through its real route', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SlideLibraryScreen()),
        GoRoute(
          path: '/editor/new',
          builder: (_, _) => const Scaffold(body: Text('new class editor')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await mount(
      tester,
      ManagementFixture(),
      const SlideLibraryScreen(),
      router: router,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('워크아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '수업 만들기'));
    await tester.pumpAndSettle();
    expect(find.text('new class editor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    for (final (name, page) in <(String, Widget)>[
      ('more', const MoreScreen()),
      ('profile', const UserProfileScreen()),
      ('displays', const DisplaySettingsScreen(asMainTab: true)),
      ('connect', const FirstTvConnectionScreen()),
      ('library', const SlideLibraryScreen()),
      ('controls', managementControlPanel()),
    ]) {
      testWidgets(
        '$name fits $width at twice the text size with reachable controls',
        (tester) async {
          await mount(
            tester,
            ManagementFixture(
              devices: Stream.value([
                managementTv(name: '아주 긴 이름의 센터 메인 운동 공간 TV', online: false),
              ]),
              profile: managementProfile.copyWith(displayName: '아주 긴 이름의 김코치'),
            ),
            page,
            width: width,
            scale: 2,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (name == 'more') {
            await tester.scrollUntilVisible(find.text('업데이트 소식'), 240);
            await Scrollable.ensureVisible(
              tester.element(find.text('업데이트 소식')),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            expect(find.text('업데이트 소식').hitTestable(), findsOneWidget);
          }
          if (name == 'library') {
            final createSlide = find.widgetWithText(TextButton, '슬라이드 만들기');
            // At 2x text the unavailable-policy explanation can put this lazy
            // sliver beyond the cache extent. Scroll to build it first, just
            // as a user reaches the action below the usage notice.
            await tester.scrollUntilVisible(
              createSlide,
              240,
              scrollable: find
                  .descendant(
                    of: find.byType(CustomScrollView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await tester.pumpAndSettle();
            expect(createSlide.hitTestable(), findsOneWidget);
            expect(
              tester.getSize(createSlide).height,
              greaterThanOrEqualTo(48),
            );
          }
          if (name == 'controls') {
            expect(find.text('2/3 슬라이드 · 일시정지'), findsOneWidget);
            expect(
              tester.getSize(find.byTooltip('재생')).height,
              greaterThanOrEqualTo(48),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
