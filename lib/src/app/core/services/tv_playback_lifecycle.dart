import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
part 'tv_playback_lifecycle.g.dart';

@Riverpod(keepAlive: true)
class TvPlaybackVisible extends _$TvPlaybackVisible {
  @override
  bool build() => true;
  void setVisible(bool value) => state = value;
}

/// TV playback is foreground-only. This never sends a shared pause/end command.
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isTv) return;
    final epoch = ++_epoch;
    final audio = ref.read(beepPlayerProvider);
    // Cancel queued and currently playing audio before any widget rebuild.
    unawaited(audio.setEnabled(false).catchError((Object _) {}));
    ref.read(tvPlaybackVisibleProvider.notifier).setVisible(false);
    if (state != AppLifecycleState.resumed) return;
    unawaited(() async {
      await ref
          .read(playbackRecoveryControllerProvider.notifier)
          .recover(restartTransport: false);
      if (!mounted || epoch != _epoch) return;
      if (!ref.read(playbackRecoveryControllerProvider).hasValue) return;
      await audio.setEnabled(true);
      if (mounted && epoch == _epoch) {
        ref.read(tvPlaybackVisibleProvider.notifier).setVisible(true);
      }
    }());
  }

  @override
  void dispose() {
    ++_epoch;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A manual recovery can also release the foreground gate after a failed resume.
    ref.listen(playbackRecoveryControllerProvider, (_, next) {
      if (widget.isTv &&
          next.hasValue &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(ref.read(beepPlayerProvider).setEnabled(true));
        ref.read(tvPlaybackVisibleProvider.notifier).setVisible(true);
      }
    });
    return widget.child;
  }
}
