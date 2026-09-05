import 'package:flutter/material.dart';

class AsyncActionOverlay extends StatelessWidget {
  const AsyncActionOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      AbsorbPointer(absorbing: isLoading, child: child),
      if (isLoading) ...[
        const Positioned.fill(child: ColoredBox(color: Color(0x33000000))),
        const Positioned.fill(
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    ],
  );
}
