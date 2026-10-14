import 'dart:async';

import 'package:cloud_board/src/app/feature/device/data/repositories/display_preparation_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/display_preparation_repository.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/complete_display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/prepare_display_media.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/retry_display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/display_preparation_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const _ready = (
  ready: true,
  imageCount: 2,
  audioReady: true,
  failureCode: null,
);

void main() {
  test(
    'receipt retries reuse prepared media and only finish after heartbeat',
    () async {
      var prepares = 0, writes = 0, beats = 0;
      final health = <(String, String?, int)>[];
      final delays = <Duration>[];
      final result = await completeDisplayPreparation(
        prepare: () async {
          prepares++;
          return _ready;
        },
        respond: (_, ready) async {
          expect(ready, isTrue);
          if (++writes < 3) throw TimeoutException('transport secret URL');
        },
        heartbeat: () async {
          beats++;
        },
        cancelled: () => false,
        health: (stage, code, attempt) => health.add((stage, code, attempt)),
        delay: (duration) async {
          delays.add(duration);
        },
      );
      expect(result, DisplayPreparationOutcome.ready);
      expect(prepares, 1);
      expect(writes, 3);
      expect(beats, 1);
      expect(delays, [const Duration(seconds: 1), const Duration(seconds: 2)]);
      expect(health.where((item) => item.$2 != null), [
        ('response_write', 'timeout', 1),
        ('response_write', 'timeout', 2),
      ]);
    },
  );

  for (final stage in ['media', 'response_write', 'heartbeat']) {
    test(
      '$stage failure stays failed after bounded retries and never false ready',
      () async {
        final attempts = <String, int>{};
        final health = <(String, String?, int)>[];
        Future<void> step(String value) async {
          attempts[value] = (attempts[value] ?? 0) + 1;
          if (value == stage) {
            throw StateError('private media path or device token');
          }
        }

        final result = await completeDisplayPreparation(
          prepare: () async {
            await step('media');
            return _ready;
          },
          respond: (_, ready) async {
            await step('response_write');
          },
          heartbeat: () => step('heartbeat'),
          cancelled: () => false,
          health: (stage, code, attempt) => health.add((stage, code, attempt)),
          delay: (_) async {},
        );
        expect(result, isNot(DisplayPreparationOutcome.ready));
        expect(attempts[stage], 4);
        expect(
          health.where((item) => item.$2 != null).map((item) => item.$2),
          everyElement('unexpected'),
        );
        if (stage != 'heartbeat') expect(attempts['heartbeat'], isNull);
      },
    );
  }

  test('media failure receipt is explicitly failed and permission stops all later stages', () async {
    var media = 0, response = 0, heartbeat = 0;
    final result = await completeDisplayPreparation(
      prepare: () async {
        media++;
        return (
          ready: false,
          imageCount: 1,
          audioReady: false,
          failureCode: 'unavailable',
        );
      },
      respond: (_, ready) async {
        expect(ready, isFalse);
        response++;
      },
      heartbeat: () async {
        heartbeat++;
      },
      cancelled: () => false,
      health: (_, _, _) {},
      delay: (_) async {},
    );
    expect(result, DisplayPreparationOutcome.failed);
    expect((media, response, heartbeat), (4, 1, 0));
    final denied = await completeDisplayPreparation(
      prepare: () async => throw FirebaseException(
        plugin: 'database',
        code: 'permission-denied',
      ),
      respond: (_, _) async {
        response++;
      },
      heartbeat: () async {
        heartbeat++;
      },
      cancelled: () => false,
      health: (_, _, _) {},
      delay: (_) async {},
    );
    expect(denied, DisplayPreparationOutcome.failed);
    expect((response, heartbeat), (1, 0));
  });

  for (final code in ['permission-denied', 'unauthenticated']) {
    test('$code stops without a timer or duplicate operation', () async {
      var calls = 0, delays = 0;
      final result = await retryDisplayPreparation<bool>(
        operation: () async {
          calls++;
          throw FirebaseException(plugin: 'database', code: code);
        },
        cancelled: () => false,
        onFailure: (_, _) {},
        delay: (_) async {
          delays++;
        },
      );
      expect(result, isNull);
      expect((calls, delays), (1, 0));
    });
  }

  test('background/account/request change during native work prevents any stale response', () async {
    final pending = Completer<DisplayMediaPreparationResult>();
    var cancelled = false, writes = 0;
    final work = completeDisplayPreparation(
      prepare: () => pending.future,
      respond: (_, _) async {
        writes++;
      },
      heartbeat: () async {
        writes++;
      },
      cancelled: () => cancelled,
      health: (_, _, _) {},
      delay: (_) async {},
    );
    cancelled = true;
    pending.complete(_ready);
    expect(await work, DisplayPreparationOutcome.cancelled);
    expect(writes, 0);
  });

  test('cancellation during backoff prevents the next write', () async {
    var cancelled = false, calls = 0;
    final result = await retryDisplayPreparation<bool>(
      operation: () async {
        calls++;
        throw TimeoutException('offline');
      },
      cancelled: () => cancelled,
      onFailure: (_, _) {},
      delay: (_) async {
        cancelled = true;
      },
    );
    expect(result, isNull);
    expect(calls, 1);
  });

  testWidgets(
    'request-read errors are diagnosed and resubscribed after network backoff',
    (tester) async {
      final repository = _Repository()..failures = 2;
      final container = ProviderContainer(
        overrides: [
          displayPreparationRepositoryProvider.overrideWith((_) => repository),
        ],
      );
      final subscription = container.listen(
        displayPreparationRequestProvider('tv'),
        (_, _) {},
      );
      await tester.pump();
      expect(repository.calls, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(repository.calls, 2);
      await tester.pump(const Duration(seconds: 2));
      expect(repository.calls, 3);
      expect(
        container.read(displayPreparationRequestProvider('tv')).hasError,
        isFalse,
      );
      expect(repository.health, [
        ('request_read', 'unavailable', 1),
        ('request_read', 'unavailable', 2),
        ('request_read', null, 1),
      ]);
      subscription.close();
      container.dispose();
    },
  );

  testWidgets(
    'permission-denied request subscription is stopped until a new scope/connection',
    (tester) async {
      final repository = _Repository()
        ..failures = 10
        ..code = 'permission-denied';
      final container = ProviderContainer(
        overrides: [
          displayPreparationRepositoryProvider.overrideWith((_) => repository),
        ],
      );
      final subscription = container.listen(
        displayPreparationRequestProvider('tv'),
        (_, _) {},
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 40));
      expect(repository.calls, 1);
      expect(
        container.read(displayPreparationRequestProvider('tv')).hasError,
        isTrue,
      );
      subscription.close();
      container.dispose();
    },
  );
}

class _Repository extends Fake implements DisplayPreparationRepository {
  int calls = 0, failures = 0;
  String code = 'unavailable';
  final health = <(String?, String?, int)>[];
  @override
  Stream<DisplayPreparation?> watchRequest(String deviceId) {
    calls++;
    return calls <= failures
        ? Stream.error(FirebaseException(plugin: 'database', code: code))
        : Stream.value(null);
  }

  @override
  Future<void> reportHealth(
    String deviceId, {
    String? stage,
    String? code,
    int attempt = 1,
    String? requestId,
  }) async {
    health.add((stage, code, attempt));
  }
}
