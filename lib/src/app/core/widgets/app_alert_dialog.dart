import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/core/theme/app_dialog_theme.dart';

/// Consistent form and confirmation dialogs with actions outside scrolling content.
class AppAlertDialog extends StatelessWidget {
  const AppAlertDialog({
    super.key,
    required this.title,
    this.content,
    this.actions,
    this.scrollable = true,
  });

  /// Disable when content already supplies a constrained scrolling viewport.
  final bool scrollable;
  final Widget title;
  final Widget? content;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Theme(
    data: AppDialogTheme.of(Theme.of(context)),
    child: AlertDialog(
      title: title,
      content: content,
      actions: actions,
      scrollable: scrollable,
      insetPadding: AppDialogTheme.insetPadding,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      actionsAlignment: MainAxisAlignment.end,
      actionsOverflowButtonSpacing: 8,
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 560),
    ),
  );
}
