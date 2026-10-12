import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/draft_asset_store.dart';

DraftAssetStore createDraftAssetStore() => FileDraftAssetStore();

/// Application-support files survive application restarts and cache eviction.
class FileDraftAssetStore implements DraftAssetStore {
  FileDraftAssetStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  Future<Directory> _draftDirectory(String draft) async =>
      Directory('${(await _directory()).path}/slide-draft-assets-v2/$draft');

  @override
  Future<bool> exists(String draft, String asset) async =>
      File('${(await _draftDirectory(draft)).path}/$asset').exists();

  @override
  Future<Uint8List?> read(String draft, String asset) async {
    final file = File('${(await _draftDirectory(draft)).path}/$asset');
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<void> write(String draft, String asset, Uint8List bytes) async {
    final directory = await _draftDirectory(draft);
    await directory.create(recursive: true);
    final target = File('${directory.path}/$asset');
    if (await target.exists()) return;
    // Metadata can never observe a partially written image. A terminated write
    // leaves only a .pending file, removed by the next successful recovery.
    final temporary = File('${target.path}.pending');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(target.path);
  }

  @override
  Future<void> retain(String draft, Set<String> assets) async {
    final directory = await _draftDirectory(draft);
    if (!await directory.exists()) return;
    await for (final entry in directory.list()) {
      final name = entry.uri.pathSegments.last;
      if (entry is File && !assets.contains(name)) await entry.delete();
    }
  }
}
