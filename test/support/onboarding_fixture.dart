import 'dart:async';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/data/repositories/onboarding_repository.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/center_onboarding.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/views/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const onboardingUser = AuthUser(
  id: 'owner',
  email: '',
  displayName: '테스트',
  photoUrl: null,
  needsOnboarding: true,
);
const confirmedFree = CenterOnboarding(
  phoneRequired: false,
  storeId: 'center',
  activationReady: true,
  hasAccess: true,
  freeActive: true,
  status: 'active',
);

class FakeOnboarding implements OnboardingRepository {
  FakeOnboarding(this.value);
  CenterOnboarding value;
  Object? loadError, verifyError;
  bool fail = false;
  Completer<void>? loadGate, saveGate, verifyGate;
  int saves = 0, loads = 0, verifications = 0;
  String? sentPhone, submittedCode;
  CenterOnboarding? verifiedValue;
  @override
  Future<CenterOnboarding> load() async {
    loads++;
    final response = value, error = loadError;
    await loadGate?.future;
    if (error != null) throw error;
    return response;
  }

  @override
  Future<void> sendCode(String phone) async {
    sentPhone = phone;
    if (fail) throw StateError('문자 전송 실패');
  }

  @override
  Future<CenterOnboarding> verifyCode(String code) async {
    submittedCode = code;
    verifications++;
    await verifyGate?.future;
    if (verifyError != null) throw verifyError!;
    return value = verifiedValue ?? confirmedFree;
  }

  @override
  Future<CenterOnboarding> save(
    CenterOnboarding current,
    CenterProfile profile,
    int step,
    String action,
  ) async {
    saves++;
    await saveGate?.future;
    if (fail) throw StateError('저장 실패');
    return value = value.copyWith(
      profile: profile,
      revision: current.revision + 1,
      step: step,
      completed: action == 'complete',
      deferred: action == 'defer',
    );
  }
}

Widget onboardingApp(
  FakeOnboarding repository, {
  String? purpose,
  bool editing = false,
}) => ProviderScope(
  overrides: [
    authStateProvider.overrideWith((ref) => Stream.value(onboardingUser)),
    onboardingRepositoryProvider.overrideWith((ref) => repository),
  ],
  child: MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: XonTheme.light,
    routerConfig: GoRouter(
      initialLocation: '/onboarding${editing ? '?edit=true' : ''}',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('내 수업 화면')),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, state) => OnboardingScreen(
            purpose: purpose,
            editing: state.uri.queryParameters['edit'] == 'true',
            verifyPhone: state.uri.queryParameters['verify'] == 'true',
          ),
        ),
        GoRoute(
          path: '/explore',
          builder: (_, _) => const Scaffold(body: Text('예시 체험 화면')),
        ),
        GoRoute(
          path: '/starter-workouts',
          builder: (_, state) => Scaffold(
            key: ValueKey('resumed-${state.uri.queryParameters['starter']}'),
            body: const Text('내 수업 준비 화면'),
          ),
        ),
        GoRoute(
          path: '/first-class',
          builder: (_, _) => const Scaffold(body: Text('첫 수업 안내')),
        ),
      ],
    ),
  ),
);
