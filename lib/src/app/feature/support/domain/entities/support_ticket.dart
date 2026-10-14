import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'support_ticket.freezed.dart';

const supportAttachmentLimit = 5 * 1024 * 1024;
const supportMessageLimit = 4000;

@freezed
abstract class SupportAttachment with _$SupportAttachment {
  const factory SupportAttachment({
    required Uint8List bytes,
    required String contentType,
    required String fileId,
  }) = _SupportAttachment;
}

@freezed
abstract class SupportTicket with _$SupportTicket {
  const factory SupportTicket({
    required String id,
    required String number,
    required int receivedAtMs,
    required String notificationStatus,
  }) = _SupportTicket;
}

@freezed
abstract class SupportDraft with _$SupportDraft {
  const factory SupportDraft({
    required String requestId,
    @Default('') String message,
    @Default('') String replyEmail,
    @Default({}) Map<String, Object?> diagnostics,
    SupportAttachment? attachment,
    SupportTicket? ticket,
    @Default(false) bool submitting,
    @Default(false) bool frozen,
    String? error,
  }) = _SupportDraft;
}

// Only structured technical references leave the app. Never attach raw errors,
// stack traces, auth state, URLs or arbitrary provider snapshots.
const supportDiagnosticKeys = {
  'operationId',
  'startStage',
  'preparationStage',
  'errorId',
  'occurredAtMs',
  'action',
  'role',
  'platform',
  'version',
  'build',
  'workoutId',
  'sessionId',
  'commandId',
  'expectedRevision',
  'observedRevision',
  'stepIndex',
  'stepCount',
  'moduleIndex',
  'moduleCount',
  'status',
  'remainingMs',
  'countdownMs',
  'connected',
  'recovering',
  'retryCount',
  'elapsedMs',
  'lastReceiptMs',
  'ackRevision',
  'firebaseCode',
  'firebasePlugin',
  'code',
};
const supportTvDiagnosticKeys = {
  'deviceId',
  'appVersion',
  'appBuild',
  'appPlatform',
  'online',
  'paired',
  'preparationStatus',
  'preparationRevision',
  'checkedAtMs',
  'imageCount',
  'audioReady',
};

Map<String, Object?> filterSupportDiagnostics(Map<String, Object?> values) {
  Object? safe(Object? value) {
    if (value is bool || value is int) return value;
    if (value is double && value.isFinite) return value;
    if (value is! String || value.isEmpty || value == 'unknown') return null;
    // Technical IDs only; do not include accidental credentials or URLs.
    if (RegExp(r'(?i:bearer|password|token=|https?://|@)').hasMatch(value)) {
      return null;
    }
    return value.length <= 160 ? value : value.substring(0, 160);
  }

  final result = <String, Object?>{};
  for (final key in supportDiagnosticKeys) {
    final value = safe(values[key]);
    if (value != null) result[key] = value;
  }
  final tvs = values['tvs'];
  if (tvs is List) {
    result['tvs'] = [
      for (final tv in tvs.whereType<Map>().take(10))
        {
          for (final key in supportTvDiagnosticKeys)
            if (safe(tv[key]) != null) key: safe(tv[key]),
        },
    ];
  }
  return result;
}
