@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/draft_asset_store_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native assets survive reopening and prune only unreferenced files in their scope', () async {
    final directory = await Directory.systemTemp.createTemp('draft-assets-');
    addTearDown(() => directory.delete(recursive: true));
    FileDraftAssetStore store() =>
        FileDraftAssetStore(directory: () async => directory);
    final first = store();
    final bytes = Uint8List.fromList([1, 2, 3]);
    await first.write('account-a', 'live', bytes);
    await first.write('account-a', 'orphan', bytes);
    await first.write('account-b', 'live', bytes);
    await File(
      '${directory.path}/slide-draft-assets-v2/account-a/partial.pending',
    ).writeAsBytes([9]);
    final reopened = store();
    expect(await reopened.exists('account-a', 'live'), isTrue);
    expect(await reopened.read('account-a', 'live'), orderedEquals(bytes));
    await reopened.retain('account-a', {'live'});
    expect(await reopened.read('account-a', 'orphan'), isNull);
    expect(await reopened.read('account-a', 'partial.pending'), isNull);
    expect(await reopened.read('account-b', 'live'), orderedEquals(bytes));
    expect(await reopened.read('account-a', 'live'), orderedEquals(bytes));
    await reopened.retain('account-a', {});
    expect(await reopened.exists('account-a', 'live'), isFalse);
    expect(await reopened.read('account-b', 'live'), orderedEquals(bytes));
  });
}
