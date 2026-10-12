import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/core/diagnostics/diagnostic_queue.dart';
import 'package:cloud_board/src/app/core/services/installed_app_info.dart';

part 'operation_telemetry.g.dart';

const _actions = {
  'workout.save',
  'tv.prepare',
  'playback.control.submit',
  'playback.control.ack',
};
const _codes = {
  'permission-denied',
  'unauthenticated',
  'unavailable',
  'deadline-exceeded',
  'resource-exhausted',
  'aborted',
  'not-found',
  'failed-precondition',
  'revision_conflict',
  'session_changed',
  'timeout',
  'cancelled',
  'unexpected',
};

String operationFailureCode(Object? error) {
  final code = error is FirebaseException
      ? error.code
      : error is TimeoutException
      ? 'timeout'
      : error is String
      ? error
      : null;
  return _codes.contains(code) ? code! : 'unexpected';
}

/// Never awaited by product actions. Events contain no workout or device data.
class OperationTelemetry {
  OperationTelemetry({
    required this.readAccount,
    required this.emit,
    DateTime Function()? clock,
    String Function()? createId,
  }) : clock = clock ?? DateTime.now,
       createId = createId ?? _randomId;
  final String? Function() readAccount;
  final Future<void> Function(Map<String, dynamic>, String account) emit;
  final DateTime Function() clock;
  final String Function() createId;
  Future<void> _pending = Future.value();
  static String _randomId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  OperationAttempt start(String action) {
    final account = readAccount();
    final attempt = OperationAttempt._(
      this,
      action,
      account,
      createId(),
      clock().toUtc(),
    );
    if (_actions.contains(action) && account != null)
      _record(attempt, 'attempt', 0);
    return attempt;
  }

  void _record(
    OperationAttempt attempt,
    String outcome,
    int elapsed, [
    Object? error,
  ]) {
    final account = attempt.account;
    if (!_actions.contains(attempt.action) ||
        account == null ||
        readAccount() != account)
      return;
    final now = clock().toUtc();
    final event = <String, dynamic>{
      'operationId': attempt.id,
      'action': attempt.action,
      'outcome': outcome,
      'startedAt': attempt.startedAt.toIso8601String(),
      'occurredAt': (now.isBefore(attempt.startedAt) ? attempt.startedAt : now)
          .toIso8601String(),
      'durationMs': elapsed.clamp(0, 86400000),
      if (outcome == 'failure') 'code': operationFailureCode(error),
    };
    _pending = _pending
        .then((_) async {
          if (readAccount() == account) await emit(event, account);
        })
        .catchError((Object _) {});
  }

  /// Useful for deterministic tests; product actions never wait for telemetry.
  Future<void> flush() => _pending;
}

class OperationAttempt {
  OperationAttempt._(
    this.telemetry,
    this.action,
    this.account,
    this.id,
    this.startedAt,
  );
  final OperationTelemetry telemetry;
  final String action;
  final String? account;
  final String id;
  final DateTime startedAt;
  final Stopwatch _elapsed = Stopwatch()..start();
  bool _completed = false;
  void success() => _finish('success');
  void failure(Object? error) => _finish('failure', error);
  void cancel() => _finish('cancelled');
  void _finish(String outcome, [Object? error]) {
    if (_completed) return;
    _completed = true;
    _elapsed.stop();
    telemetry._record(this, outcome, _elapsed.elapsedMilliseconds, error);
  }
}

@Riverpod(keepAlive: true)
OperationTelemetry operationTelemetry(Ref ref) {
  String? account() {
    try {
      if (Firebase.app().options.projectId.startsWith('demo-')) return null;
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  // Tests and local emulator previews do not create storage/platform listeners.
  if (Firebase.apps.isEmpty ||
      Firebase.app().options.projectId.startsWith('demo-')) {
    return OperationTelemetry(readAccount: () => null, emit: (_, _) async {});
  }
  final key =
      'cloudboard.operation-telemetry.v1.${Firebase.app().options.projectId}';
  final auth = FirebaseAuth.instance;
  final queue = DiagnosticQueue(
    capacity: 128,
    read: () async => (await SharedPreferences.getInstance()).getString(key),
    write: (value) async {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, value);
      }
    },
    send: (event, owner) async {
      if (account() != owner) throw StateError('Telemetry account changed');
      final payload = Map<String, dynamic>.from(event)..remove('eventId');
      try {
        await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
            .httpsCallable(
              'recordOperationTelemetry',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 8),
              ),
            )
            .call({...payload, 'accountId': owner});
      } on FirebaseFunctionsException catch (error) {
        // Invalid/expired data cannot succeed later and must not block newer events.
        if (error.code == 'invalid-argument' ||
            error.code == 'permission-denied')
          return;
        rethrow;
      }
    },
  );
  final subscription = auth.authStateChanges().listen((user) {
    unawaited(queue.setAccount(user?.uid).catchError((Object _) {}));
  });
  ref.onDispose(() {
    queue.dispose();
    unawaited(subscription.cancel());
  });
  Future<Map<String, String>>? metadata;
  Future<Map<String, String>> readMetadata() => metadata ??= () async {
    var version = const String.fromEnvironment(
      'APP_BUILD_NAME',
      defaultValue: 'unknown',
    );
    var build = const String.fromEnvironment(
      'APP_BUILD_NUMBER',
      defaultValue: 'unknown',
    );
    try {
      final info = await readInstalledAppInfo().timeout(
        const Duration(seconds: 2),
      );
      version = info.version;
      build = info.buildNumber;
    } catch (_) {}
    if (!RegExp(r'^(unknown|\d+(?:[.\-+][a-zA-Z0-9]+){0,8})$')
            .hasMatch(version) ||
        version.length > 40)
      version = 'unknown';
    if (!RegExp(r'^(unknown|\d+(?:\.\d+){0,4})$').hasMatch(build) ||
        build.length > 20)
      build = 'unknown';
    return {
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'version': version,
      'build': build,
    };
  }();
  return OperationTelemetry(
    readAccount: account,
    emit: (event, owner) async {
      final info = await readMetadata();
      if (account() != owner) return;
      await queue.setAccount(owner);
      if (account() != owner) return;
      await queue.enqueue({
        ...event,
        ...info,
        'eventId': '${event['operationId']}:${event['outcome']}',
      });
    },
  );
}
