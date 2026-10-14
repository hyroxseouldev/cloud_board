import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';
import 'package:cloud_board/src/app/feature/operations/data/operation_event_writer.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/operation_event_recorder.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';

void main() {
  test('event time uses known server offset and missing TV retains unknown version', () async {
    final events = <OperationEvent>[];
    final writer = OperationEventWriter((event) async {
      events.add(event);
    });
    final container = ProviderContainer(
      overrides: [
        operationEventWriterProvider.overrideWith((ref) => writer),
        serverTimeOffsetProvider.overrideWith((ref) => Stream.value(3600000)),
        errorReporterProvider.overrideWith(
          (ref) => ErrorReporter(
            _Sink(),
            defaults: {'role': 'app', 'version': 'phone-version'},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(
      serverTimeOffsetProvider,
      (_, _) {},
      fireImmediately: true,
    );
    await container.read(serverTimeOffsetProvider.future);
    final before = DateTime.now().millisecondsSinceEpoch + 3600000;
    final trigger = Provider<void>((ref) {
      recordOperationEvent(
        ref,
        type: 'command_receipt_failed',
        phase: 'tv_receipt',
        deviceId: 'deleted-tv',
        deviceRole: 'display',
        sessionId: 'class',
      );
    });
    container.read(trigger);
    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(1));
    expect(events.single.occurredAtMs, greaterThanOrEqualTo(before));
    expect(events.single.deviceRole, 'display');
    expect(events.single.deviceId, 'deleted-tv');
    expect(events.single.appVersion, isNull);
    expect(events.single.deviceName, isNull);
  });
}

class _Sink implements DiagnosticSink {
  @override
  Future<void> send(DiagnosticEvent event) async {}
}
