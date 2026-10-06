import 'dart:async';

import 'package:cloud_board/src/app/core/utils/async_value_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'coalesces concurrent reads, expires values, and retries errors',
    () async {
      var now = DateTime(2026);
      final cache = AsyncValueCache<String, int>(clock: () => now);
      final pending = Completer<int>();
      var reads = 0;
      Future<int> fetch() {
        reads++;
        return pending.future;
      }

      final first = cache.load('a', fetch);
      final second = cache.load('a', fetch);
      expect(identical(first, second), isTrue);
      pending.complete(1);
      expect(await first, 1);
      expect(await cache.load('a', fetch), 1);
      expect(reads, 1);
      now = now.add(const Duration(seconds: 31));
      expect(
        await cache.load('a', () async {
          reads++;
          return 2;
        }),
        2,
      );
      expect(reads, 2);
      await expectLater(
        cache.load('error', () async => throw StateError('offline')),
        throwsStateError,
      );
      expect(await cache.load('error', () async => 3), 3);
    },
  );

  test(
    'late reads cannot overwrite saved values or repopulate a cleared account',
    () async {
      final cache = AsyncValueCache<String, int>();
      final pending = Completer<int>();
      final first = cache.load('a', () => pending.future);
      cache.put('a', 2);
      pending.complete(1);
      expect(await first, 1);
      expect(await cache.load('a', () async => 99), 2);
      final old = Completer<int>();
      final request = cache.load('b', () => old.future);
      cache.clear();
      old.complete(3);
      await request;
      expect(await cache.load('b', () async => 4), 4);
    },
  );

  test('least recently used values are evicted', () async {
    final cache = AsyncValueCache<String, int>(capacity: 2);
    cache.put('a', 1);
    cache.put('b', 2);
    await cache.load('a', () async => 99);
    cache.put('c', 3);
    expect(await cache.load('a', () async => 99), 1);
    expect(await cache.load('b', () async => 4), 4);
  });
}
