import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'feature/auth/presentation/controllers/auth_controller.dart';
import 'feature/device/domain/entities/device_mode.dart';
import 'feature/device/presentation/controllers/device_mode_controller.dart';
import 'feature/playback/presentation/controllers/playback_session_controller.dart';
import 'feature/workouts/presentation/controllers/workout_controller.dart';

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

    ref.listen(authControllerProvider, (previous, next) {
      showActionResult(previous, next, '인증 작업에 실패했습니다');
    });
    ref.listen(workoutActionControllerProvider, (previous, next) {
      showActionResult(previous, next, '워크아웃 작업에 실패했습니다');
    });
    ref.listen(playbackActionControllerProvider, (previous, next) {
      showActionResult(previous, next, '재생 제어에 실패했습니다');
    });
    ref.listen(deviceModeControllerProvider, (previous, next) {
      if (previous?.isLoading != true) return;
      final isError = next.hasError;
      final mode = next.value;
      final message = isError
          ? '기기 모드를 변경하지 못했습니다: ${next.error}'
          : mode == DeviceMode.display
          ? '디스플레이 모드로 전환했습니다.'
          : '컨트롤러 모드로 전환했습니다.';
      _scaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            backgroundColor: isError ? Colors.red.shade800 : null,
          ),
        );
    });

    return MaterialApp.router(
      title: 'CloudBoard',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: XonTheme.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
