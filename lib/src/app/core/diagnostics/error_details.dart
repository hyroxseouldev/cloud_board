import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';

class ErrorDetailsButton extends ConsumerWidget {
  const ErrorDetailsButton({
    super.key,
    required this.error,
    this.stack,
    this.action = 'ui.error',
  });
  final Object? error;
  final StackTrace? stack;
  final String action;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode || error == null) return const SizedBox.shrink();
    return TextButton.icon(
      icon: const Icon(Icons.info_outline, size: 18),
      label: const Text('오류 상세'),
      onPressed: () => showErrorDetails(
        context,
        ref.read(errorReporterProvider),
        error!,
        stack,
        action,
      ),
    );
  }
}

Future<void> showErrorDetails(
  BuildContext context,
  ErrorReporter reporter,
  Object error,
  StackTrace? stack,
  String action,
) async {
  final event =
      reporter.eventFor(error) ??
      reporter.capture(error, stack ?? StackTrace.current, action: action);
  if (!kDebugMode) return;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('오류 상세'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: SelectableText(
            event.details,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: event.details));
            if (context.mounted) {
              ScaffoldMessenger.maybeOf(
                context,
              )?.showSnackBar(const SnackBar(content: Text('오류 정보를 복사했습니다.')));
            }
          },
          child: const Text('복사'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}
