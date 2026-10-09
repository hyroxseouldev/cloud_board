import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/core/diagnostics/diagnostic_queue.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';

part 'diagnostics_provider.g.dart';

ErrorReporter? _applicationReporter;
@Riverpod(keepAlive: true)
ErrorReporter errorReporter(Ref ref) =>
    _applicationReporter ?? ErrorReporter(_NoopSink());

class _NoopSink implements DiagnosticSink {
  @override
  Future<void> send(DiagnosticEvent event) async {}
}

Future<ErrorReporter> initializeDiagnostics({
  required bool isTv,
  bool localOnly = false,
}) async {
  if (localOnly) return _applicationReporter = ErrorReporter(_NoopSink());
  PackageInfo? package;
  try {
    package = await PackageInfo.fromPlatform().timeout(
      const Duration(seconds: 2),
    );
  } catch (_) {}
  final sink = kIsWeb ? _WebSink() : _CrashlyticsSink();
  final reporter = _applicationReporter = ErrorReporter(
    sink,
    defaults: {
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'version':
          package?.version ??
          const String.fromEnvironment(
            'APP_BUILD_NAME',
            defaultValue: 'unknown',
          ),
      'build':
          package?.buildNumber ??
          const String.fromEnvironment(
            'APP_BUILD_NUMBER',
            defaultValue: 'unknown',
          ),
      'role': isTv ? 'tv' : 'app',
    },
  );
  String? previous = FirebaseAuth.instance.currentUser?.uid;
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (previous != user?.uid) reporter.resetAccount();
    previous = user?.uid;
  });
  return reporter;
}

class _CrashlyticsSink implements DiagnosticSink {
  @override
  Future<void> send(DiagnosticEvent event) async {
    final payload = event.toJson();
    // Per-event information avoids racing mutable global custom keys.
    // Original error type and sanitized original message are both retained.
    await FirebaseCrashlytics.instance.recordError(
      '${payload['type']}: ${payload['message']}',
      StackTrace.fromString(payload['stack'] as String),
      reason: '${event.context['action']} [${event.code}]',
      information: [
        jsonEncode({...payload}..remove('stack')),
      ],
      fatal: event.fatal,
      printDetails: false,
    );
  }
}

class _WebSink implements DiagnosticSink {
  _WebSink() {
    final auth = FirebaseAuth.instance;
    queue = DiagnosticQueue(
      read: () async => (await SharedPreferences.getInstance()).getString(_key),
      write: (value) async {
        final prefs = await SharedPreferences.getInstance();
        if (value == null) {
          await prefs.remove(_key);
        } else {
          await prefs.setString(_key, value);
        }
      },
      send: (event, account) async {
        if (auth.currentUser?.uid != account) {
          throw StateError('Diagnostic account changed');
        }
        await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
            .httpsCallable(
              'reportClientDiagnostic',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 8),
              ),
            )
            .call({...event, 'accountId': account});
      },
    );
    // This application-wide sink lives for the auth/app lifetime.
    auth.authStateChanges().listen((user) {
      unawaited(queue.setAccount(user?.uid).catchError((Object _) {}));
    });
    unawaited(
      queue.setAccount(auth.currentUser?.uid).catchError((Object _) {}),
    );
  }
  static const _key = 'cloudboard.diagnostics.v1';
  late final DiagnosticQueue queue;
  @override
  Future<void> send(DiagnosticEvent event) =>
      queue.enqueue(Map<String, dynamic>.from(event.toJson()));
}
