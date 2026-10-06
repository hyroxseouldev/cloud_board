import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/core/diagnostics/error_details.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/auth_error_message.dart';

/// Remains available after the transient snackbar disappears.
class AuthErrorNotice extends StatelessWidget {
  const AuthErrorNotice({super.key, required this.error, this.stack});

  final Object error;
  final StackTrace? stack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            authErrorMessage(error),
            style: TextStyle(color: colors.onErrorContainer),
          ),
          const SizedBox(height: 8),
          SelectableText(
            '오류 코드: ${redactDiagnostic(diagnosticCode(error), limit: 160)}',
            style: TextStyle(fontSize: 12, color: colors.onErrorContainer),
          ),
          ErrorDetailsButton(error: error, stack: stack, action: 'auth.signIn'),
        ],
      ),
    );
  }
}
