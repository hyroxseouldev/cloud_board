// Production page fixtures; no Firebase, real account, purchase or TV writes.
import 'dart:async';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/center_onboarding.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/first_class_progress.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/first_class_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/profile/domain/entities/user_profile.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/controllers/user_profile_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/library_folder_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_templates_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_control_panel.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'main_navigation_fixture.dart';

const managementProfile = UserProfile(
  id: 'coach',
  email: 'coach@example.invalid',
  displayName: '김코치',
  photoUrl: null,
  subscriptionPlan: 'plus',
  subscriptionStatus: SubscriptionStatus.active,
  displayLimit: 3,
);
DisplayDevice managementTv({
  String id = 'tv',
  String name = '메인 TV',
  bool online = true,
  bool enabled = true,
}) => DisplayDevice(
  id: id,
  name: name,
  zoneId: 'main',
  zoneName: '메인 운동 구역',
  online: online,
  lastSeenAtMs: online ? DateTime.now().millisecondsSinceEpoch : 0,
  currentSessionId: null,
  acknowledgedRevision: 0,
  paired: true,
  displayState: enabled ? 'auto' : 'standby',
);

class ManagementFixture {
  ManagementFixture({
    Stream<List<DisplayDevice>>? devices,
    UserProfile profile = managementProfile,
    Future<CenterOnboarding>? onboarding,
    FirstClassScope? scope = (
      userId: 'coach',
      centerId: 'center',
      centerReady: true,
    ),
    List<Workout>? workouts,
    List<WorkoutModule> slides = const [],
    ManagementClaims? claims,
  }) {
    this.claims = claims ?? ManagementClaims();
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authStateProvider.overrideWith(
          (_) => Stream.value(
            AuthUser(
              id: profile.id,
              email: profile.email,
              displayName: profile.displayName,
              photoUrl: profile.photoUrl,
            ),
          ),
        ),
        androidTvProvider.overrideWith((_) async => false),
        deviceModeControllerProvider.overrideWith(ManagementMode.new),
        displayDevicesProvider.overrideWith((_) => devices ?? Stream.value([])),
        deviceClaimControllerProvider.overrideWith(() => this.claims),
        userProfileControllerProvider.overrideWith(
          () => ManagementProfiles(profile),
        ),
        onboardingControllerProvider.overrideWith(
          () => ManagementOnboarding(onboarding),
        ),
        firstClassScopeProvider.overrideWith((_) async => scope),
        firstClassControllerProvider.overrideWith(ManagementFirstClass.new),
        activePlaybackSessionProvider.overrideWith((_) => Stream.value(null)),
        workoutRepositoryProvider.overrideWith(
          (_) async => NavigationWorkoutRepository(workouts ?? []),
        ),
        libraryFoldersProvider.overrideWith((_) => Stream.value([])),
        slideTemplatesControllerProvider.overrideWith2(
          (_) => ManagementSlides(slides),
        ),
      ],
    );
  }
  late final ProviderContainer container;
  late final ManagementClaims claims;
  void dispose() => container.dispose();
  Widget app(Widget page, {double textScale = 1, GoRouter? router}) {
    Widget builder(BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: true,
      ),
      child: XonTheme.responsiveBuilder(context, child),
    );
    return UncontrolledProviderScope(
      container: container,
      child: router == null
          ? MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: XonTheme.light,
              builder: builder,
              home: page,
            )
          : MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: XonTheme.light,
              builder: builder,
              routerConfig: router,
            ),
    );
  }
}

class ManagementMode extends DeviceModeController {
  @override
  Future<DeviceMode> build() async => DeviceMode.controller;
}

class ManagementProfiles extends UserProfileController {
  ManagementProfiles(this.profile);
  final UserProfile profile;
  @override
  Future<UserProfile> build() async => profile;
}

class ManagementOnboarding extends OnboardingController {
  ManagementOnboarding(this.result);
  final Future<CenterOnboarding>? result;
  @override
  Future<CenterOnboarding> build() =>
      result ??
      Future.value(
        const CenterOnboarding(
          phoneRequired: false,
          storeId: 'center',
          completed: true,
        ),
      );
}

class ManagementFirstClass extends FirstClassController {
  @override
  Future<FirstClassProgress?> build() async => null;
}

class ManagementSlides extends SlideTemplatesController {
  ManagementSlides(this.slides);
  final List<WorkoutModule> slides;
  @override
  Stream<List<WorkoutModule>> build(String scope) => Stream.value(slides);
}

class ManagementClaims extends DeviceClaimController {
  final toggles = <({String id, String state, List<String> replace})>[];
  int claimCount = 0;
  Completer<bool>? claimResult;
  Object? toggleError;
  @override
  Future<bool> claim({
    required String code,
    required String name,
    required String zoneName,
  }) async {
    claimCount++;
    state = const AsyncLoading();
    final result = await (claimResult?.future ?? Future.value(false));
    state = const AsyncData(null);
    return result;
  }

  @override
  Future<bool> setDisplayState({
    required String deviceId,
    required String displayState,
    List<String> replaceDeviceIds = const [],
  }) async {
    toggles.add((id: deviceId, state: displayState, replace: replaceDeviceIds));
    if (toggleError != null) {
      state = AsyncError(toggleError!, StackTrace.current);
      return false;
    }
    return true;
  }
}

Widget managementControlPanel({bool busy = false}) => WorkoutControlPanel(
  title: '토요일 함께하는 기초 체력 수업',
  moduleCount: 3,
  currentModule: 1,
  paused: true,
  busy: busy,
  onPrevious: () {},
  onToggle: () {},
  onNext: () {},
  onExit: () {},
  onMinimize: () {},
  onLockChanged: (_) {},
  onSelectModule: (_) async {},
  previewBuilder: (_, index) => ColoredBox(
    color: const Color(0xFF2B332E),
    child: Center(
      child: Text(
        '운동 ${index + 1}',
        style: const TextStyle(color: Colors.white),
      ),
    ),
  ),
  timeline: const Text('현재 구간 · 8분 남음'),
);
