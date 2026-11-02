import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';

/// Preserve native crash reporting and also send handled save failures to the
/// authenticated, bounded queue used by Cloud Logging alerts on every platform.
/// Preparation failures must also be available without a Crashlytics relaunch.
class WorkoutDiagnosticSink implements DiagnosticSink {
  WorkoutDiagnosticSink({required this.primary, required this.alerts});
  final DiagnosticSink primary;
  final DiagnosticSink alerts;

  @override
  Future<void> send(DiagnosticEvent event) async {
    final needsRemoteDiagnostic = const {
      'workout.save',
      'workout.duplicate',
      'tv.prepare.request',
      'tv.prepare.receipts',
      'tv.prepare.request_read',
      'tv.prepare.images',
      'tv.prepare.audio',
      'tv.prepare.response',
      'tv.prepare.heartbeat',
    }.contains(event.context['action']);
    await Future.wait([
      Future.sync(() => primary.send(event)).catchError((Object _) {}),
      if (needsRemoteDiagnostic)
        Future.sync(() => alerts.send(event)).catchError((Object _) {}),
    ]);
  }
}
