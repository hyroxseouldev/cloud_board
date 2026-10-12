@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/draft_asset_store_web.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('IndexedDB commits binary assets across connections and prunes only their draft', () async {
    final databaseName =
        'draft-assets-test-${DateTime.now().microsecondsSinceEpoch}';
    IndexedDbDraftAssetStore store() =>
        IndexedDbDraftAssetStore(databaseName: databaseName);
    final first = store();
    final bytes = Uint8List(5 * 1024 * 1024)..[0] = 3;
    await first.write('account-a', 'live', bytes);
    await first.write('account-a', 'orphan', Uint8List.fromList([9]));
    await first.write('account-b', 'live', Uint8List.fromList([4]));
    final reopened = store();
    expect(await reopened.exists('account-a', 'live'), isTrue);
    expect(await reopened.exists('account-a', 'missing'), isFalse);
    expect(await reopened.read('account-a', 'live'), orderedEquals(bytes));
    await reopened.retain('account-a', {'live'});
    expect(await reopened.read('account-a', 'orphan'), isNull);
    expect(await reopened.read('account-b', 'live'), orderedEquals([4]));
    expect(await reopened.read('account-a', 'live'), orderedEquals(bytes));
    await reopened.retain('account-a', {});
    expect(await reopened.exists('account-a', 'live'), isFalse);
    expect(await reopened.read('account-b', 'live'), orderedEquals([4]));
  });
}
