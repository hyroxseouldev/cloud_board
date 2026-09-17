import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Keeps the platform keyboard and its return action, with a common dismiss
/// control for mobile keyboards that do not offer a Done key.
class KeyboardDismissRegion extends StatelessWidget {
  const KeyboardDismissRegion({super.key, required this.child});

  final Widget child;
  static const _toolbarHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final mobile =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
    final keyboardInset = media.viewInsets.bottom;
    final visible = mobile && keyboardInset > 0;

    return Actions(
      actions: <Type, Action<Intent>>{
        EditableTextTapOutsideIntent:
            CallbackAction<EditableTextTapOutsideIntent>(
              onInvoke: (intent) {
                intent.focusNode.unfocus();
                return null;
              },
            ),
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Reserve room through the same inset used by Scaffold and dialogs,
          // so the accessory never covers a field or bottom-sheet action.
          MediaQuery(
            data: media.copyWith(
              viewInsets: media.viewInsets.copyWith(
                bottom: keyboardInset + (visible ? _toolbarHeight : 0),
              ),
            ),
            child: child,
          ),
          if (visible)
            Positioned(
              left: 0,
              right: 0,
              bottom: keyboardInset,
              height: _toolbarHeight,
              child: TextFieldTapRegion(
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  shape: Border(
                    top: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, _toolbarHeight),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        icon: const Icon(
                          Icons.keyboard_hide_outlined,
                          size: 22,
                          semanticLabel: '키보드 내리기',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
