import 'dart:convert';

// Existing cached_network_image transitive interfaces, isolated to this fixture.
// ignore: depend_on_referenced_packages
import 'package:file/memory.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Returns a real PNG from local memory and records the requested media sources.
/// No HTTP, Firebase, or cache database is opened by this fake transport.
class PlaybackImageCacheFixture implements BaseCacheManager {
  final requests = <String>[];
  final _files = MemoryFileSystem();
  static const png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    requests.add(url);
    final file = _files.file('/image-${requests.length}.png')
      ..writeAsBytesSync(base64Decode(png));
    yield FileInfo(file, FileSource.Online, DateTime(2100), url);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
