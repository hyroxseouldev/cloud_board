import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/core/theme/app_dialog_theme.dart';
import 'package:cloud_board/src/app/core/theme/app_style.dart';

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
  Widget build(BuildContext context) {
    final theme = AppDialogTheme.of(Theme.of(context));
    if (actions?.length == 2) {
      final heading = Semantics(
        namesRoute: true,
        child: DefaultTextStyle(
          style: AppDialogTheme.twoActionTitle,
          child: title,
        ),
      );
      final body = scrollable
          ? SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppStyle.popupMinHeight - 72,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 28,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heading,
                      if (content != null) ...[
                        const SizedBox(height: 12),
                        content!,
                      ],
                    ],
                  ),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  if (content != null) ...[
                    const SizedBox(height: 12),
                    Flexible(child: content!),
                  ],
                ],
              ),
            );
      return Theme(
        data: theme,
        child: Dialog(
          backgroundColor: AppDialogTheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: AppDialogTheme.twoActionShape,
          insetPadding: AppDialogTheme.insetPadding,
          constraints: const BoxConstraints(
            minWidth: AppStyle.popupWidth,
            maxWidth: AppStyle.popupWidth,
            minHeight: AppStyle.popupMinHeight,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: DefaultTextStyle(
                  style: AppDialogTheme.data.contentTextStyle!,
                  child: body,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Theme(
                  data: AppDialogTheme.twoActionFooter(theme),
                  child: DefaultTextStyle.merge(
                    textAlign: TextAlign.center,
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: actions![0]),
                          const SizedBox(width: 8),
                          Expanded(child: actions![1]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Theme(
      data: theme,
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
        constraints: const BoxConstraints(
          minWidth: AppStyle.popupWidth,
          maxWidth: AppStyle.popupWidth,
          minHeight: AppStyle.popupMinHeight,
        ),
      ),
    );
  }
}
