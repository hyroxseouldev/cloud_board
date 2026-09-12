import 'package:cloud_board/src/app/feature/profile/domain/repositories/account_deletion_repository.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/controllers/account_deletion_controller.dart';
import 'package:cloud_board/src/app/core/services/android_class_notifications.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/router/app_router.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class XonBoardApp extends ConsumerWidget {
  const XonBoardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void showActionResult(
      AsyncValue<String?>? previous,
      AsyncValue<String?> next,
      String errorPrefix,
    ) {
      if (previous?.isLoading != true) return;
      final isError = next.hasError;
      final message = isError ? '$errorPrefix: ${next.error}' : next.value;
      if (message == null) return;
      _scaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            backgroundColor: isError ? Colors.red.shade800 : null,
          ),
        );
    }

    ref.listen(androidClassNotificationsProvider, (previous, next) {
      if (next.value == false && previous?.value != false) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
              '알림을 허용하면 앱 밖에서도 수업을 제어할 수 있습니다. 앱 내 제어는 계속 사용할 수 있습니다.',
            ),
          ),
        );
      }
    });
    ref.listen(authStateProvider, (previous, next) {
      if (next.value != null && previous?.value?.id != next.value?.id) {
        ref.invalidate(accountDeletionControllerProvider);
      }
    });
    ref.listen(accountDeletionControllerProvider, (previous, next) {
      showActionResult(
        previous?.whenData((value) => value?.message),
        next.whenData((value) => value?.message),
        '계정 삭제를 완료하지 못했습니다',
      );
    });
    ref.listen(authControllerProvider, (previous, next) {
      showActionResult(previous, next, '인증 작업에 실패했습니다');
    });
    ref.listen(workoutActionControllerProvider, (previous, next) {
      showActionResult(previous, next, '워크아웃 작업에 실패했습니다');
    });

    return MaterialApp.router(
      title: 'CloudBoard',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: XonTheme.light,
      builder: XonTheme.responsiveBuilder,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
