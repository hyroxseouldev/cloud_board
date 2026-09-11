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
