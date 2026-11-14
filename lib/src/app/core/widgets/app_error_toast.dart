import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shad;

import 'package:cloud_board/src/app/core/theme/app_colors.dart';

/// Root-owned error feedback. Pass safe, already-mapped copy; diagnostics stay
/// with the action/controller that owns the failure.
abstract final class AppErrorToast {
  static AppErrorToastController of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_AppErrorToastScope>();
    if (scope == null) {
      throw FlutterError('AppErrorToastHost must wrap the app navigator.');
    }
    return scope.controller;
  }

  static VoidCallback show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 5),
  }) => of(context).show(message, duration: duration);
}

class AppErrorToastController extends ChangeNotifier {
  _ErrorNotice? _notice;
  Timer? _timer;
  int _scopeRevision = 0;

  int get scopeRevision => _scopeRevision;

  /// Invalidates pending results when the signed-in account changes.
  void resetScope() {
    _scopeRevision++;
    clear();
  }

  /// One visible error, no hidden queue. Repeated copy during the same notice
  /// does not stack or extend its lifetime. A new action can clear then retry.
  VoidCallback show(
    String message, {
    Duration duration = const Duration(seconds: 5),
  }) {
    final current = _notice;
    if (current != null && current.message == message) {
      return () => _dismiss(current);
    }
    final notice = _ErrorNotice(message);
    _timer?.cancel();
    _notice = notice;
    _timer = Timer(duration, () => _dismiss(notice));
    notifyListeners();
    return () => _dismiss(notice);
  }

  void _dismiss(_ErrorNotice notice) {
    if (identical(_notice, notice)) clear();
  }

  void clear() {
    _timer?.cancel();
    _timer = null;
    if (_notice == null) return;
    _notice = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _ErrorNotice {
  _ErrorNotice(this.message);
  final String message;
}

class _AppErrorToastScope extends InheritedWidget {
  const _AppErrorToastScope({required this.controller, required super.child});
  final AppErrorToastController controller;

  @override
  bool updateShouldNotify(_AppErrorToastScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Installed inside MaterialApp.builder, outside its navigator. The overlay is
/// a sibling of the route subtree, so route/dialog/local ShadAppBuilder overlays
/// cannot cover it or redirect errors into a page-local Sonner.
class AppErrorToastHost extends StatefulWidget {
  const AppErrorToastHost({super.key, required this.child, this.controller});
  final Widget child;
  final AppErrorToastController? controller;

  @override
  State<AppErrorToastHost> createState() => _AppErrorToastHostState();
}

class _AppErrorToastHostState extends State<AppErrorToastHost> {
  late final _ownedController = AppErrorToastController();
  AppErrorToastController get controller =>
      widget.controller ?? _ownedController;

  @override
  void dispose() {
    _ownedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AppErrorToastScope(
    controller: controller,
    child: Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final notice = controller._notice;
            if (notice == null) return const SizedBox.shrink();
            // 0.59 Sonner retains overflow toasts and has no clear-all API.
            // Mount only the bounded presentation, never the route subtree, for
            // each notice; disposing it cancels Sonner timers synchronously.
            return _SonnerNotice(
              key: ValueKey((
                notice,
                MediaQuery.sizeOf(context).width,
                MediaQuery.textScalerOf(context),
              )),
              notice: notice,
              onClose: () => controller._dismiss(notice),
            );
          },
        ),
      ],
    ),
  );
}

class _SonnerNotice extends StatefulWidget {
  const _SonnerNotice({super.key, required this.notice, required this.onClose});
  final _ErrorNotice notice;
  final VoidCallback onClose;

  @override
  State<_SonnerNotice> createState() => _SonnerNoticeState();
}

class _SonnerNoticeState extends State<_SonnerNotice> {
  final _sonnerKey = GlobalKey<shad.ShadSonnerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sonnerKey.currentState!.show(
        shad.ShadToast(
          // The host owns expiry/close/account clearing, so Sonner never hides
          // asynchronously after its scope is disposed.
          duration: const Duration(days: 365),
          constraints: BoxConstraints.tightFor(
            width:
                math.min(420, MediaQuery.sizeOf(context).width) -
                24 -
                MediaQuery.paddingOf(context).horizontal,
          ),
          backgroundColor: AppColors.surface,
          border: shad.ShadBorder.all(color: AppColors.controlBorder),
          radius: BorderRadius.circular(14),
          padding: const EdgeInsets.fromLTRB(14, 14, 48, 14),
          closeIconPosition: const shad.ShadPosition(top: 0, right: 0),
          showCloseIconOnlyWhenHovered: false,
          closeIcon: IconButton(
            key: const ValueKey('error-toast-close'),
            onPressed: widget.onClose,
            icon: const Icon(
              Icons.close_rounded,
              semanticLabel: '오류 알림 닫기',
              size: 18,
              color: AppColors.muted,
            ),
          ),
          description: Semantics(
            container: true,
            liveRegion: true,
            label: '오류',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.notice.message)),
              ],
            ),
          ),
          descriptionStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            height: 1.45,
            color: AppColors.ink,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return shad.ShadTheme(
      data: shad.ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const shad.ShadZincColorScheme.light(),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: shad.ShadSonner(
          key: _sonnerKey,
          visibleToastsAmount: 1,
          alignment: Alignment.bottomCenter,
          padding: EdgeInsets.fromLTRB(
            12 + media.padding.left,
            12 + media.padding.top,
            12 + media.padding.right,
            12 + math.max(media.viewInsets.bottom, media.padding.bottom),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
