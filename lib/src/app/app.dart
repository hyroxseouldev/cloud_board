import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class XonBoardApp extends ConsumerWidget {
  const XonBoardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'XON BOARD',
    debugShowCheckedModeBanner: false,
    theme: XonTheme.light,
    routerConfig: ref.watch(appRouterProvider),
  );
}
