import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/operations/data/repositories/store_operations_repository_impl.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operation_history.dart';
import 'package:cloud_board/src/app/feature/operations/domain/repositories/store_operations_repository.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';

void main() {
  test('unresolved next owner cannot query retained previous center', () async {
    final accounts = [StreamController<String?>(), StreamController<String?>()];
    var subscriptions = 0;
    final repository = _Repository();
    final container = ProviderContainer(
      overrides: [
        accountOwnerIdProvider.overrideWith(
          (ref) => accounts[subscriptions++].stream,
        ),
        storeOperationsRepositoryProvider.overrideWith((ref) => repository),
      ],
    );
    addTearDown(() async {
      container.dispose();
      for (final account in accounts) {
        await account.close();
      }
    });
    final source = operationEventsInRangeProvider(
      const OperationEventRange(startAtMs: 1, endBeforeMs: 10),
    );
    container.listen(source, (_, _) {}, fireImmediately: true);
    accounts.first.add('first-center');
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    expect(repository.queries, 1);
    expect(container.read(source).hasValue, isTrue);
    container.invalidate(accountOwnerIdProvider);
    expect(container.read(source).isLoading, isTrue);
    await container.pump();
    expect(
      repository.queries,
      1,
      reason: 'Retained previous owner must never start a query',
    );
    accounts.last.add(null);
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(source).hasError, isTrue);
    expect(repository.queries, 1);
  });
}

class _Repository extends Fake implements StoreOperationsRepository {
  var queries = 0;
  @override
  Stream<OperationEventBatch> watchEventsInRange(OperationEventRange range) {
    queries++;
    return Stream.value(
      const OperationEventBatch(events: [], isComplete: true),
    );
  }
}
