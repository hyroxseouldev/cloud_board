// Production widgets with local fixtures; run after the targeted journey tests.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/views/login_screen.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/center_onboarding.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/first_class_progress.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/first_class_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/views/explore_screen.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/views/first_class_screen.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/views/onboarding_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/starter_workouts.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/starter_workouts_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_rehearsal_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _Auth extends AuthController {
  _Auth(this.error);
  final bool error;
  @override
  AsyncValue<String?> build() => error
      ? AsyncError(
          FirebaseAuthException(code: 'network-request-failed'),
          StackTrace.current,
        )
      : const AsyncData(null);
  @override
  Future<void> signInWithGoogle() => Completer<void>().future;
}

class _Progress extends FirstClassController {
  _Progress(this.value);
  final FirstClassProgress value;
  @override
  Future<FirstClassProgress?> build() async => value;
}

class _Onboarding extends OnboardingController {
  _Onboarding(this.value);
  final CenterOnboarding value;
  @override
  Future<CenterOnboarding> build() async => value;
}

void main() {
  testWidgets(
    'capture STA145 welcome and STA152 first-use production widgets',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final font = FontLoader('Pretendard');
      for (final weight in ['Regular', 'Medium', 'SemiBold']) {
        font.addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-$weight.otf'),
        );
      }
      await font.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();

      Future<void> capture(
        String name,
        Widget screen, {
        TargetPlatform platform = TargetPlatform.android,
        Size size = const Size(390, 844),
        double scale = 1,
        bool error = false,
        String? tap,
        String? show,
        FirstClassProgress progress = const FirstClassProgress(
          sessionId: 'capture',
          savedWorkoutId: 'class_from_basics',
        ),
        CenterOnboarding onboarding = const CenterOnboarding(
          phoneRequired: false,
          storeId: 'capture',
          freeAvailable: true,
        ),
      }) async {
        debugDefaultTargetPlatformOverride = platform;
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: ProviderScope(
              key: ValueKey(name),
              overrides: [
                androidTvProvider.overrideWith((_) async => false),
                authStateProvider.overrideWith((_) => Stream.value(null)),
                authControllerProvider.overrideWith(() => _Auth(error)),
                firstClassControllerProvider.overrideWith(
                  () => _Progress(progress),
                ),
                onboardingControllerProvider.overrideWith(
                  () => _Onboarding(onboarding),
                ),
                displayDevicesProvider.overrideWith((_) => Stream.value([])),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: XonTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: XonTheme.responsiveBuilder(context, child),
                ),
                home: screen,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final images = tester.elementList(find.byType(Image)).toList();
        await tester.runAsync(() async {
          await Future.wait(
            images.map((e) => precacheImage((e.widget as Image).image, e)),
          );
        });
        await tester.pumpAndSettle();
        if (tap != null) {
          await tester.ensureVisible(find.text(tap));
          await tester.tap(find.text(tap));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        }
        if (show != null) {
          await tester.ensureVisible(find.text(show));
          await tester.pump(const Duration(milliseconds: 500));
        }
        expect(tester.takeException(), isNull, reason: name);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File(
            'docs/design/todo-2026-10-13/sta145-152/$name.png',
          );
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox());
      }

      await capture('login-android-390', const LoginScreen());
      await capture(
        'login-ios-390',
        const LoginScreen(),
        platform: TargetPlatform.iOS,
      );
      await capture(
        'login-320-large-text',
        const LoginScreen(),
        size: const Size(320, 568),
        scale: 2,
      );
      await capture(
        'login-320-large-text-actions',
        const LoginScreen(),
        size: const Size(320, 568),
        scale: 2,
        show: '예시 수업 둘러보기',
      );
      await capture(
        'login-android-320',
        const LoginScreen(),
        size: const Size(320, 568),
      );
      await capture('login-loading', const LoginScreen(), tap: 'Google로 계속하기');
      await capture(
        'login-error',
        const LoginScreen(),
        error: true,
        show: '오류 상세',
      );
      await capture('recommended-example', const ExploreScreen());
      await capture(
        'example-options',
        const ExploreScreen(),
        tap: '다른 예시·시작 목적 선택',
      );
      await capture(
        'demo',
        WorkoutRehearsalScreen(
          workout: StarterWorkout.basics.createDemo(),
          demo: true,
          onCreate: () {},
        ),
      );
      await capture(
        'save-starter',
        const StarterWorkoutsScreen(initialTemplate: StarterWorkout.basics),
      );
      await capture('first-saved', const FirstClassScreen());
      await capture(
        'first-achievement',
        const FirstClassScreen(),
        progress: const FirstClassProgress(
          sessionId: 'capture',
          savedWorkoutId: 'class_from_basics',
          rehearsedWorkoutId: 'class_from_basics',
        ),
      );
      await capture('onboarding-purpose', const OnboardingScreen());
      await capture(
        'phone-verification',
        const OnboardingScreen(
          starter: StarterWorkout.basics,
          purpose: 'preparing',
        ),
        onboarding: const CenterOnboarding(),
      );
      await capture(
        'free-choice',
        const OnboardingScreen(),
        onboarding: const CenterOnboarding(
          phoneRequired: false,
          storeId: 'capture',
          step: 2,
          freeAvailable: true,
        ),
      );
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
