import 'package:flutter/material.dart';
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
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('CloudBoard', style: TextStyle(fontSize: 28)),
              const SizedBox(height: 24),
              if (!failed.value) const CircularProgressIndicator(),
              if (failed.value) ...[
                const Text('앱을 준비하지 못했습니다. 연결을 확인해 주세요.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    failed.value = false;
                    attempt.value++;
                  },
                  child: const Text('다시 시도'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
