import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/library_failure.dart';

import 'package:cloud_board/src/app/feature/playback/domain/playback_failure.dart';

/// Only technical, non-content fields can leave the device.
const diagnosticContextKeys = {
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
};

String redactDiagnostic(String value, {int limit = 3000}) {
  var clean = value
      .replaceAllMapped(RegExp(r'https?://[^\s)]+'), (match) {
        final frame = RegExp(
          r'(main\.dart\.js|dart_sdk\.js|flutter_bootstrap\.js)(:\d+(?::\d+)?)',
        ).firstMatch(match[0]!);
        return frame == null ? '[url]' : '${frame[1]}${frame[2]}';
      })
      .replaceAll(RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'), '[email]')
      .replaceAll(
        RegExp(r'(?:(?:\+82|0)[ -]?)1[016789](?:[ -]?\d){7,8}'),
        '[phone]',
      )
      .replaceAll(
        RegExp(r'(?:/Users/|/home/|[A-Za-z]:\\Users\\)[^\s:)]+'),
        '[local-path]',
      )
      .replaceAll(
        RegExp(r'(?:users|displayAccess|pairingCodes)/[^\s\]"\x27]+'),
        '[database-path]',
      )
      .replaceAll(RegExp(r'(?i:bearer\s+)[A-Za-z0-9._-]+'), '[token]')
      .replaceAll(
        RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
        '[token]',
      )
      .replaceAll(
        RegExp(
          r'(?i:(?:token|password|secret|authorization|api[_-]?key)\s*[=:]\s*)[^\s,;]+',
        ),
        '[credential]',
      )
      .replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f]'), '');
  return clean.length > limit ? clean.substring(0, limit) : clean;
}

Map<String, Object?> safeDiagnosticContext(Map<String, Object?> context) =>
    Map.unmodifiable({
      for (final entry in context.entries)
        if (diagnosticContextKeys.contains(entry.key) &&
            (entry.value is String ||
                entry.value is num ||
                entry.value is bool ||
                entry.value == null))
          entry.key: entry.value is String
              ? redactDiagnostic(entry.value as String, limit: 160)
              : entry.value,
    });

String diagnosticCode(Object error) => switch (error) {
  LibraryFailure failure when failure.cause != null => diagnosticCode(
    failure.cause!,
  ),
  PlaybackFailure failure => failure.code,
  FirebaseException failure => '${failure.plugin}/${failure.code}',
  RangeError _ => 'invalid_index',
  FormatException _ => 'invalid_data',
  TimeoutException _ => 'network_timeout',
  StateError _ => 'invalid_state',
  _ => 'unexpected_error',
};

String diagnosticMessage(Object error) => switch (error) {
  LibraryFailure failure => failure.message,
  PlaybackFailure failure => failure.message,
  FirebaseException failure
      when const {
        'permission-denied',
        'unauthenticated',
      }.contains(failure.code) =>
    '접근 권한을 확인하지 못했습니다. 로그인 상태를 확인해 주세요.',
  FirebaseException _ ||
  TimeoutException _ => '서버 응답을 확인하지 못했습니다. 연결 상태를 확인해 주세요.',
  RangeError _ || FormatException _ => '수업 데이터가 일치하지 않습니다. 최신 상태를 다시 불러와 주세요.',
  StateError failure => redactDiagnostic(failure.message),
  _ => '작업을 완료하지 못했습니다. 오류 상세에서 원인을 확인해 주세요.',
};

class DiagnosticEvent {
  DiagnosticEvent({
    required this.id,
    required this.occurredAt,
    required this.error,
    required this.stack,
    required this.context,
    required this.breadcrumbs,
    this.fatal = false,
  });
  final String id;
  final DateTime occurredAt;
  // Preserve the original object/stack for local inspection and injectable sinks.
  final Object error;
  final StackTrace stack;
  final Map<String, Object?> context;
  final List<Map<String, Object?>> breadcrumbs;
  final bool fatal;
  String get code => diagnosticCode(error);
  String get message => diagnosticMessage(error);
  Map<String, Object?> toJson() => {
    'eventId': id,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'severity': fatal ? 'fatal' : 'error',
    'type': error.runtimeType.toString(),
    'code': code,
    'message': redactDiagnostic(
      error is FormatException
          ? (error as FormatException).message
          : error.toString(),
    ),
    if (error is LibraryFailure && (error as LibraryFailure).cause != null)
      'causeType': (error as LibraryFailure).cause.runtimeType.toString(),
    'stack': redactDiagnostic(stack.toString(), limit: 6000),
    'context': context,
    'breadcrumbs': breadcrumbs,
  };
  String get details {
    final json = toJson();
    return '오류 ID: $id\n시간: ${json['occurredAt']}\n코드: $code\n유형: ${json['type']}\n${json['message']}\n${context.entries.map((e) => '${e.key}: ${e.value}').join('\n')}\n\n${json['stack']}';
  }
}

abstract interface class DiagnosticSink {
  Future<void> send(DiagnosticEvent event);
}

/// Reports once at the user-operation boundary, never inside retried transactions.
class ErrorReporter {
  ErrorReporter(
    this.sink, {
    Map<String, Object?> defaults = const {},
    DateTime Function()? clock,
  }) : defaults = safeDiagnosticContext(defaults),
       _clock = clock ?? DateTime.now;
  final DiagnosticSink sink;
  final Map<String, Object?> defaults;
  final DateTime Function() _clock;
  final _events = LinkedHashMap<Object, DiagnosticEvent>.identity();
  final _breadcrumbs = Queue<Map<String, Object?>>();
  DiagnosticEvent? eventFor(Object? error) =>
      _events[error] ?? (error is LibraryFailure ? _events[error.cause] : null);
  void resetAccount() {
    _events.clear();
    _breadcrumbs.clear();
  }

  void breadcrumb(String action, [Map<String, Object?> context = const {}]) {
    _breadcrumbs.add(safeDiagnosticContext({'action': action, ...context}));
    while (_breadcrumbs.length > 15) {
      _breadcrumbs.removeFirst();
    }
  }

  DiagnosticEvent capture(
    Object error,
    StackTrace stack, {
    required String action,
    Map<String, Object?> context = const {},
    bool fatal = false,
  }) {
    final existing = eventFor(error);
    if (existing != null) return existing;
    final now = _clock().toUtc();
    final event = DiagnosticEvent(
      id: '${now.microsecondsSinceEpoch.toRadixString(36)}-${Random.secure().nextInt(1 << 32).toRadixString(36)}',
      occurredAt: now,
      error: error,
      stack: stack,
      fatal: fatal,
      context: safeDiagnosticContext({
        ...defaults,
        ...context,
        'action': action,
        if (error is IndexError) ...{
          'stepIndex': error.invalidValue,
          'stepCount': error.length,
        },
        if (error is FirebaseException) ...{
          'firebaseCode': error.code,
          'firebasePlugin': error.plugin,
        },
        if (error is PlaybackFailure) ...{
          if (error.expectedRevision != null)
            'expectedRevision': error.expectedRevision,
          if (error.observedRevision != null)
            'observedRevision': error.observedRevision,
          if (error.commandId != null) 'commandId': error.commandId,
        },
      }),
      breadcrumbs: List.unmodifiable(_breadcrumbs),
    );
    _events[error] = event;
    while (_events.length > 100) {
      _events.remove(_events.keys.first);
    }
    // Telemetry failure must not block controls or recursively report itself.
    unawaited(
      Future<void>.sync(() => sink.send(event)).catchError((Object _) {}),
    );
    return event;
  }
}
