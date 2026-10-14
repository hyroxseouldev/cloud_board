import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
part 'tv_playback_lifecycle.g.dart';

@Riverpod(keepAlive: true)
class TvPlaybackVisible extends _$TvPlaybackVisible {
  TvPlaybackVisible({this.initiallyVisible = true});
  final bool initiallyVisible;
  @override
  bool build() => initiallyVisible;
  void setVisible(bool value) => state = value;
}

/// TV playback is foreground-only. This never sends a shared pause/end command.
/// A failed wake retries with bounded backoff; a connection event or explicit
/// retry can start another cycle after that budget is exhausted.
class TvPlaybackLifecycle extends ConsumerStatefulWidget {
  const TvPlaybackLifecycle({
    super.key,
    required this.isTv,
    required this.child,
  });
  final bool isTv;
  final Widget child;
  @override
  ConsumerState<TvPlaybackLifecycle> createState() =>
      _TvPlaybackLifecycleState();
}

class _TvPlaybackLifecycleState extends ConsumerState<TvPlaybackLifecycle>
    with WidgetsBindingObserver {
  int _epoch = 0;
  int _attempts = 0;
  int _scopeRender = 0;
  String? _owner;
  bool _scopeReady = false;
  bool _scopeInitialized = false;
  Future<void>? _pending;
  Timer? _retry;
  static const _delays = [1, 2, 4, 8, 16];

  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  bool get _eligible => mounted && widget.isTv && _foreground && _scopeReady;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _block() {
    ++_epoch;
    _retry?.cancel();
    _retry = null;
    _attempts = 0;
    // setEnabled(false) synchronously invalidates queued native audio work.
    unawaited(
      ref.read(beepPlayerProvider).setEnabled(false).catchError((Object _) {}),
    );
    ref.read(tvPlaybackVisibleProvider.notifier).setVisible(false);
    ref.read(playbackRecoveryControllerProvider.notifier).suspend();
  }

  void _syncScope(AsyncValue<String?> scope) {
    final ready = !scope.isLoading && !scope.hasError && scope.value != null;
    final owner = ready ? scope.value : null;
    if (_scopeInitialized && _scopeReady == ready && _owner == owner) return;
    _scopeInitialized = true;
    _scopeReady = ready;
    _owner = owner;
    _block();
    if (_eligible) {
      unawaited(_recover());
    } else if (_foreground &&
        !scope.isLoading &&
        !scope.hasError &&
        owner == null) {
      // An unpaired TV still needs its pairing screen; its audio remains muted.
      ref.read(tvPlaybackVisibleProvider.notifier).setVisible(true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isTv) return;
    _block();
    if (state == AppLifecycleState.resumed) {
      if (_eligible) {
        unawaited(_recover());
      } else if (!_scopeReady) {
        // No linked center means there is no class that can be resumed.
        ref.read(tvPlaybackVisibleProvider.notifier).setVisible(true);
      }
    }
  }

  Future<void> _recover() async {
    if (!_eligible) return;
    _retry?.cancel();
    _retry = null;
    final previous = _pending;
    final epoch = _epoch;
    if (previous != null) {
      await previous;
      if (!_eligible || epoch != _epoch) return;
      final state = ref.read(playbackRecoveryControllerProvider);
      if (!state.isLoading && !state.hasError && state.hasValue) return;
    }
    if (!_eligible || epoch != _epoch) return;
    _attempts++;
    final pending = ref
        .read(playbackRecoveryControllerProvider.notifier)
        .recover(restartTransport: false);
    _pending = pending;
    try {
      await pending;
    } finally {
      if (identical(_pending, pending)) _pending = null;
    }
    if (!_eligible || epoch != _epoch) return;
    final result = ref.read(playbackRecoveryControllerProvider);
    if (!result.isLoading && !result.hasError && result.hasValue) {
      _release();
    } else if (result.hasError) {
      _scheduleRetry(result.error);
    }
  }

  void _scheduleRetry(Object? error) {
    if (!_eligible || _retry != null || _attempts > _delays.length) return;
    final code = operationFailureCode(error);
    if (code == 'permission-denied' || code == 'unauthenticated') return;
    final epoch = _epoch;
    final index = (_attempts - 1).clamp(0, _delays.length - 1);
    _retry = Timer(Duration(seconds: _delays[index]), () {
      _retry = null;
      if (_eligible && epoch == _epoch) unawaited(_recover());
    });
  }

  void _release() {
    if (!_eligible) return;
    _retry?.cancel();
    _retry = null;
    final epoch = _epoch;
    unawaited(() async {
      try {
        await ref.read(beepPlayerProvider).setEnabled(true);
        if (!_eligible || epoch != _epoch) {
          if (mounted) await ref.read(beepPlayerProvider).setEnabled(false);
          return;
        }
        ref.read(tvPlaybackVisibleProvider.notifier).setVisible(true);
      } catch (_) {
        // Audio initialization must never release an obsolete foreground gate.
      }
    }());
  }

  @override
  void dispose() {
    ++_epoch;
    _retry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isTv) {
      final scope = ref.watch(accountOwnerIdProvider);
      final render = ++_scopeRender;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && render == _scopeRender) _syncScope(scope);
      });
      ref.listen(playbackConnectionProvider, (previous, next) {
        if (!_eligible || next.isLoading || next.hasError) return;
        if (next.value == false && previous?.value == true) {
          _block();
          unawaited(_recover());
        } else if (next.value == true && previous?.value != true) {
          _attempts = 0;
          unawaited(_recover());
        }
      });
      // Manual/remote callers join the same controller and can release the gate.
      ref.listen(playbackRecoveryControllerProvider, (_, next) {
        if (!_eligible) return;
        if (!next.isLoading && !next.hasError && next.hasValue) {
          _release();
        } else if (next.hasError) {
          _scheduleRetry(next.error);
        } else if (next.isLoading) {
          unawaited(
            ref
                .read(beepPlayerProvider)
                .setEnabled(false)
                .catchError((Object _) {}),
          );
          ref.read(tvPlaybackVisibleProvider.notifier).setVisible(false);
        }
      });
    }
    return widget.child;
  }
}
