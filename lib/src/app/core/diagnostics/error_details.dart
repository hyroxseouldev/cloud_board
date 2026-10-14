import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/feature/support/domain/entities/support_ticket.dart';
import 'package:go_router/go_router.dart';
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
    if (error == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.help_outline_rounded, size: 18),
          label: const Text('문제 문의하기'),
          onPressed: () => openSupportForError(
            context,
            ref.read(errorReporterProvider),
            error!,
            stack,
            action,
          ),
        ),
        if (kDebugMode)
          TextButton.icon(
            icon: const Icon(Icons.info_outline, size: 18),
            label: const Text('오류 상세'),
            onPressed: () => showErrorDetails(
              context,
              ref.read(errorReporterProvider),
              error!,
              stack,
              action,
            ),
          ),
      ],
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
  final supportContext = context;
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
          onPressed: () {
            Navigator.pop(context);
            openSupportForError(supportContext, reporter, error, stack, action);
          },
          child: const Text('문제 문의하기'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}

Future<void> openSupportForError(
  BuildContext context,
  ErrorReporter reporter,
  Object error,
  StackTrace? stack,
  String action,
) async {
  final event =
      reporter.eventFor(error) ??
      reporter.capture(error, stack ?? StackTrace.current, action: action);
  final isTv = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(androidTvProvider).value;
  if (isTv == true) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('연결된 기기에서 문의해 주세요'),
        content: Text(
          '휴대폰이나 웹의 더보기 → 문의하기에서 TV 진단을 함께 보낼 수 있어요.\n\n오류 ID: ${event.id}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
    return;
  }
  if (!context.mounted) return;
  await context.push(
    '/support',
    extra: {
      ...supportDiagnosticsForEvent(event),
      '_supportOwnerId': ProviderScope.containerOf(
        context,
        listen: false,
      ).read(authStateProvider).value?.id,
    },
  );
}

Map<String, Object?> supportDiagnosticsForEvent(DiagnosticEvent event) =>
    filterSupportDiagnostics({
      ...event.context,
      'errorId': event.id,
      'occurredAtMs': event.occurredAt.millisecondsSinceEpoch,
      'code': event.code,
    });
