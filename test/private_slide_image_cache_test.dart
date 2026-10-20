import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/private_slide_image_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final png = Uint8List.fromList(
    img.encodePng(img.Image(width: 16, height: 9)),
  );
  test('unchanged thumbnail remains immediately available when another version changes', () async {
    final cache = PrivateSlideImageCache()..retainKeys({'a/1', 'b/1'});
    addTearDown(cache.dispose);
    var reads = 0;
    Future<Uint8List?> read() async {
      reads++;
      return png;
    }

    (await cache.load('a/1', read))!.dispose();
    (await cache.load('b/1', read))!.dispose();
    cache.retainKeys({'a/1', 'b/2'});
    final retained = cache.peek('a/1');
    expect(retained, isNotNull);
    retained!.dispose();
    expect(cache.peek('b/1'), isNull);
    (await cache.load('a/1', read))!.dispose();
    expect(reads, 2);
  });
  test(
    'eviction keeps active clones valid and limits retained entries to eight',
    () async {
      final cache = PrivateSlideImageCache()
        ..retainKeys({for (var i = 0; i < 9; i++) '$i'});
      addTearDown(cache.dispose);
      final active = await cache.load('0', () async => png);
      for (var i = 1; i < 9; i++) {
        (await cache.load('$i', () async => png))!.dispose();
      }
      expect(cache.peek('0'), isNull);
      expect(active!.width, 16);
      active.dispose();
    },
  );
  test('revoked scope discards pending decode and never returns a cached private image', () async {
    final cache = PrivateSlideImageCache()..retainKeys({'private'});
    addTearDown(cache.dispose);
    final gate = Completer<Uint8List?>();
    final pending = cache.load('private', () => gate.future);
    cache.retainKeys({});
    gate.complete(png);
    expect(await pending, isNull);
    expect(cache.peek('private'), isNull);
  });
  test('decoded thumbnail expires at its independent memory TTL', () async {
    final cache = PrivateSlideImageCache(
      lifetime: const Duration(milliseconds: 10),
    )..retainKeys({'private'});
    addTearDown(cache.dispose);
    (await cache.load('private', () async => png))!.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(cache.peek('private'), isNull);
  });
}
