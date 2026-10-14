// Production widgets with local data; no live account, TV or network writes.
// flutter test --no-pub tool/sta149_151_capture_test.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/widgets/main_navigation_dock.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/views/display_settings_screen.dart';
import 'package:cloud_board/src/app/feature/device/presentation/views/first_tv_connection_screen.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/add_display_dialog.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/views/more_screen.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/views/user_profile_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_library_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_list_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../test/support/management_journey_fixture.dart';

void main() {
  testWidgets('capture STA-149 to STA-151 management states', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Capture fixtures use the same isolated package metadata as widget tests.
    // ignore: invalid_use_of_visible_for_testing_member
    PackageInfo.setMockInitialValues(
      appName: 'CloudBoard',
      packageName: 'fixture',
      version: '1.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(
        rootBundle.load('assets/fonts/pretendard/Pretendard-$weight.otf'),
      );
    }
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final loading = StreamController<List<DisplayDevice>>();
    addTearDown(loading.close);
    final offline = managementTv(online: false);
    final sample =
        Workout.empty(
          'strength',
          const WorkoutAuthor(id: 'coach', displayName: '김코치', photoUrl: null),
        ).copyWith(
          name: '함께하는 기초 체력',
          folder: '그룹 수업',
          modules: [
            WorkoutModule.empty('warmup')
                .copyWith(name: '몸 풀기', workSeconds: 300),
            WorkoutModule.empty('main')
                .copyWith(name: '순환 운동', workSeconds: 120, sets: 4),
          ],
        );

    for (final scene
        in <
          ({
            String name,
            Widget page,
            ManagementFixture data,
            MainDestination? dock,
            double width,
            double scale,
          })
        >[
          (
            name: 'home',
            page: const WorkoutListScreen(),
            data: ManagementFixture(
              workouts: [
                sample,
                sample.copyWith(id: 'second', name: '금요일 전신 서킷'),
              ],
              devices: Stream.value([managementTv()]),
            ),
            dock: MainDestination.home,
            width: 390,
            scale: 1,
          ),
          (
            name: 'library-empty',
            page: const SlideLibraryScreen(asMainTab: true),
            data: ManagementFixture(),
            dock: MainDestination.library,
            width: 390,
            scale: 1,
          ),
          (
            name: 'more',
            page: const MoreScreen(),
            data: ManagementFixture(),
            dock: MainDestination.more,
            width: 390,
            scale: 1,
          ),
          (
            name: 'more-320-text2x',
            page: const MoreScreen(),
            data: ManagementFixture(),
            dock: MainDestination.more,
            width: 320,
            scale: 2,
          ),
          (
            name: 'profile',
            page: const UserProfileScreen(),
            data: ManagementFixture(),
            dock: null,
            width: 390,
            scale: 1,
          ),
          (
            name: 'displays-empty',
            page: const DisplaySettingsScreen(asMainTab: true),
            data: ManagementFixture(),
            dock: MainDestination.displays,
            width: 390,
            scale: 1,
          ),
          (
            name: 'displays-loading',
            page: const DisplaySettingsScreen(asMainTab: true),
            data: ManagementFixture(devices: loading.stream),
            dock: MainDestination.displays,
            width: 390,
            scale: 1,
          ),
          (
            name: 'displays-offline',
            page: const DisplaySettingsScreen(asMainTab: true),
            data: ManagementFixture(devices: Stream.value([offline])),
            dock: MainDestination.displays,
            width: 390,
            scale: 1,
          ),
          (
            name: 'first-tv',
            page: const FirstTvConnectionScreen(),
            data: ManagementFixture(),
            dock: null,
            width: 390,
            scale: 1,
          ),
          (
            name: 'pairing-code',
            page: const Scaffold(body: AddDisplayDialog()),
            data: ManagementFixture(),
            dock: null,
            width: 390,
            scale: 1,
          ),
          (
            name: 'controls-paused',
            page: managementControlPanel(),
            data: ManagementFixture(),
            dock: null,
            width: 390,
            scale: 1,
          ),
          (
            name: 'controls-pending-320-text2x',
            page: managementControlPanel(busy: true),
            data: ManagementFixture(),
            dock: null,
            width: 320,
            scale: 2,
          ),
        ]) {
      tester.view.physicalSize = Size(scene.width * 2, 1688);
      tester.view.devicePixelRatio = 2;
      final boundary = GlobalKey();
      final page = scene.dock == null
          ? scene.page
          : Scaffold(
              body: Column(
                children: [
                  Expanded(child: scene.page),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: MainNavigationDock(
                      selected: scene.dock!,
                      onSelected: (_) {},
                    ),
                  ),
                ],
              ),
            );
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: scene.data.app(page, textScale: scene.scale),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final images = tester.elementList(find.byType(Image)).toList();
      await tester.runAsync(
        () => Future.wait(
          images.map(
            (element) =>
                precacheImage((element.widget as Image).image, element),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: scene.name);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          'docs/design/todo-2026-10-13/sta149-151-${scene.name}.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      scene.data.dispose();
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
