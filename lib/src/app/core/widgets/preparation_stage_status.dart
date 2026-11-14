import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:cloud_board/src/app/core/theme/app_motion.dart';

/// Time describes the current observed stage, never estimated completion.
class PreparationStageStatus extends HookWidget {
  const PreparationStageStatus({super.key, required this.label, this.detail});
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final slow = useState(false);
    useEffect(() {
      slow.value = false;
      final timer = Timer(const Duration(seconds: 5), () => slow.value = true);
      return timer.cancel;
    }, [label]);
    return Semantics(
      liveRegion: true,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: SizedBox.square(
          dimension: 24,
          child: AppMotion.reduced(context)
              ? const Icon(Icons.hourglass_top_rounded)
              : const CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text(label),
        subtitle: detail != null || slow.value
            ? Text(
                [
                  ?detail,
                  if (slow.value) '$label · 5초 이상 기다리고 있어요.',
                ].join('\n'),
              )
            : null,
      ),
    );
  }
}
