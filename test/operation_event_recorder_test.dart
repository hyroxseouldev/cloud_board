import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_board/src/app/feature/operations/data/operation_event_writer.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/operation_event_recorder.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';

import 'support/playback_recovery_fixture.dart' show RecoveryUser;

void main() {
  test('event time uses known server offset and missing TV retains unknown version', () async {
    final events = <OperationEvent>[];
    final writer = OperationEventWriter((event) async {
      events.add(event);
    });
    final container = ProviderContainer(
      overrides: [
        accountOwnerIdProvider.overrideWith((_) => Stream.value('owner')),
        firebaseAccountUserProvider.overrideWith(
          (_) => Stream.value(RecoveryUser('owner')),
        ),
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
    container.listen(accountOwnerIdProvider, (_, _) {});
    container.listen(firebaseAccountUserProvider, (_, _) {});
    await container.read(serverTimeOffsetProvider.future);
    await container.read(accountOwnerIdProvider.future);
    await container.read(firebaseAccountUserProvider.future);
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

  for (final boundary in [
    'stable',
    'owner-return',
    'auth-return',
    'owner-loading',
    'auth-loading',
    'owner-error',
    'auth-error',
    'owner-null',
    'auth-null',
  ]) {
    testWidgets('deferred event device identity respects $boundary scope', (
      tester,
    ) async {
      final owners = StreamController<String?>.broadcast(sync: true);
      final users = StreamController<User?>.broadcast(sync: true);
      final device = Completer<String>();
      final events = <OperationEvent>[];
      final writer = OperationEventWriter((event) async => events.add(event));
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          accountOwnerIdProvider.overrideWith(
            (_) => Stream.multi((sink) {
              sink.add('owner');
              final sub = owners.stream.listen(
                sink.add,
                onError: sink.addError,
              );
              sink.onCancel = sub.cancel;
            }),
          ),
          firebaseAccountUserProvider.overrideWith(
            (_) => Stream.multi((sink) {
              sink.add(RecoveryUser('owner'));
              final sub = users.stream.listen(sink.add, onError: sink.addError);
              sink.onCancel = sub.cancel;
            }),
          ),
          operationEventWriterProvider.overrideWith((_) => writer),
          deviceIdProvider.overrideWith((_) => device.future),
          serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
        ],
      );
      addTearDown(() async {
        container.dispose();
        writer.dispose();
        await owners.close();
        await users.close();
      });
      container.listen(accountOwnerIdProvider, (_, _) {});
      container.listen(firebaseAccountUserProvider, (_, _) {});
      await tester.pump();
      final trigger = Provider<void>(
        (ref) => recordOperationEvent(
          ref,
          type: 'command_failed',
          phase: 'server_approval',
          sessionId: 'class',
        ),
      );
      container.read(trigger);
      await tester.pump();
      final owner = boundary.startsWith('owner');
      final kind = boundary.split('-').last;
      if (kind == 'loading') {
        container.invalidate(
          owner ? accountOwnerIdProvider : firebaseAccountUserProvider,
        );
        container.read(
          owner ? accountOwnerIdProvider : firebaseAccountUserProvider,
        );
      } else if (kind == 'error') {
        if (owner) {
          owners.addError(StateError('owner unavailable'));
        } else {
          users.addError(StateError('auth unavailable'));
        }
      } else if (kind == 'null') {
        if (owner) {
          owners.add(null);
        } else {
          users.add(null);
        }
      } else if (kind == 'return') {
        if (owner) {
          owners.add('other');
        } else {
          users.add(RecoveryUser('other'));
        }
        await tester.pump();
        if (owner) {
          owners.add('owner');
        } else {
          users.add(RecoveryUser('owner'));
        }
      }
      await tester.pump();
      device.complete('phone');
      await tester.pump(const Duration(milliseconds: 1));
      expect(events, hasLength(boundary == 'stable' ? 1 : 0));
    });
  }
}

class _Sink implements DiagnosticSink {
  @override
  Future<void> send(DiagnosticEvent event) async {}
}
