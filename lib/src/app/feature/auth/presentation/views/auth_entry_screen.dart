import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/widgets/app_startup_screen.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/onboarding_controller.dart';

/// The same entry surface covers auth restoration and server access confirmation.
/// Neither a pending lookup nor a failed lookup means onboarding is required.
class AuthEntryScreen extends ConsumerWidget {
  const AuthEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final access = auth.value?.needsOnboarding == true
        ? ref.watch(onboardingRequiredProvider)
        : null;
    final authFailed = !auth.isLoading && auth.hasError;
    final accessFailed = access != null && !access.isLoading && access.hasError;
    return AppStartupScreen(
      onRetry: authFailed || accessFailed
          ? () {
              if (authFailed) {
                ref.invalidate(authStateProvider);
              } else {
                ref.invalidate(existingMemberAccessProvider);
                ref.invalidate(onboardingRequiredProvider);
                ref.invalidate(onboardingControllerProvider);
              }
            }
          : null,
    );
  }
}
