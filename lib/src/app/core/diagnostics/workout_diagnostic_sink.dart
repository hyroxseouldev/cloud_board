import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';

/// Preserve native crash reporting and also send handled save failures to the
/// authenticated, bounded queue used by Cloud Logging alerts on every platform.
class WorkoutDiagnosticSink implements DiagnosticSink {
  WorkoutDiagnosticSink({required this.primary, required this.alerts});
  final DiagnosticSink primary;
  final DiagnosticSink alerts;

  @override
  Future<void> send(DiagnosticEvent event) async {
    final isSave = const {
      'workout.save',
      'workout.duplicate',
    }.contains(event.context['action']);
    await Future.wait([
      Future.sync(() => primary.send(event)).catchError((Object _) {}),
      if (isSave)
        Future.sync(() => alerts.send(event)).catchError((Object _) {}),
    ]);
  }
}
