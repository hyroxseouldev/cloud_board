import 'dart:async';

import 'package:cloud_board/src/app/feature/operations/data/models/audience_branding_model.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/audience_branding.dart';

/// Retained per owner across transport/provider refreshes. A pending disk write
/// must not turn an already confirmed rendering policy back into a first read.
class AudienceBrandingMemory {
  AudienceBrandingModel? value;

  void remember(AudienceBrandingModel next) {
    if (next.supersedes(value)) value = next;
  }
}

/// Reconnects independently of playback. Missing data and transport failures
/// never synthesize Free or erase a confirmed paid hide preference.
Stream<AudienceBranding?> watchConfirmedAudienceBranding({
  required String ownerId,
  required Future<AudienceBrandingModel?> Function() loadCached,
  required Future<void> Function(AudienceBrandingModel) saveCached,
  required Stream<AudienceBrandingModel?> Function() watchRemote,
  Duration retryDelay = const Duration(seconds: 15),
  int Function()? nowMs,
  AudienceBrandingMemory? memory,
}) {
  final clock = nowMs ?? () => DateTime.now().millisecondsSinceEpoch;
  late StreamController<AudienceBranding?> output;
  StreamSubscription<AudienceBrandingModel?>? subscription;
  Timer? retry;
  AudienceBrandingModel? confirmed;
  var disposed = false;
  // Serialize disk writes, so an older async write cannot replace a newer one.
  var writes = Future<void>.value();

  void emit(AudienceBrandingModel? next) {
    if (disposed) return;
    if (next != null &&
        next.ownerId == ownerId &&
        next.validUntilMs > clock() &&
        next.supersedes(confirmed)) {
      confirmed = next;
      memory?.remember(next);
      writes = writes.then((_) => saveCached(next)).catchError((Object _) {});
    }
    output.add(confirmed?.toEntity());
  }

  void connect() {
    if (disposed) return;
    retry?.cancel();
    void reconnect() {
      retry?.cancel();
      if (!disposed) retry = Timer(retryDelay, connect);
    }

    try {
      subscription = watchRemote().listen(
        emit,
        onError: (Object error, StackTrace stack) {
          emit(null);
          reconnect();
        },
        onDone: reconnect,
        cancelOnError: true,
      );
    } catch (_) {
      emit(null);
      reconnect();
    }
  }

  output = StreamController<AudienceBranding?>(
    onListen: () async {
      try {
        final inMemory = memory?.value;
        final cached = inMemory?.ownerId == ownerId
            ? inMemory
            : await loadCached();
        if (cached?.ownerId == ownerId) {
          confirmed = cached;
          memory?.remember(cached!);
        }
      } catch (_) {
        // A storage failure must not prevent a live server projection.
      }
      if (disposed) return;
      final latest = memory?.value;
      if (latest?.ownerId == ownerId && latest!.supersedes(confirmed)) {
        confirmed = latest;
      }
      output.add(confirmed?.toEntity());
      connect();
    },
    onCancel: () async {
      disposed = true;
      retry?.cancel();
      await subscription?.cancel();
      await writes;
    },
  );
  return output.stream.distinct();
}
