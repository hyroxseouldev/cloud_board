import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/app_startup_screen.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Paints before platform/network initialization, and keeps failures retryable.
class AppBootstrap extends HookWidget {
  const AppBootstrap({
    super.key,
    required this.initialize,
    required this.builder,
  });

  final Future<bool> Function() initialize;
  final Widget Function(bool isTv) builder;

  @override
  Widget build(BuildContext context) {
    final attempt = useState(0);
    final result = useState<bool?>(null);
    final failed = useState(false);
    useEffect(() {
      var cancelled = false;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (cancelled) return;
        try {
          final value = await initialize();
          if (!cancelled) result.value = value;
        } catch (_) {
          if (!cancelled) failed.value = true;
        }
      });
      return () => cancelled = true;
    }, [attempt.value]);
    if (result.value case final bool isTv) return builder(isTv);
    return MaterialApp(
      theme: XonTheme.light,
      debugShowCheckedModeBanner: false,
      home: AppStartupScreen(
        onRetry: failed.value
            ? () {
                failed.value = false;
                attempt.value++;
              }
            : null,
      ),
    );
  }
}
