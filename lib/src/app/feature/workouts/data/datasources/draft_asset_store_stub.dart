import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/draft_asset_store.dart';

DraftAssetStore createDraftAssetStore() => _UnsupportedDraftAssetStore();

class _UnsupportedDraftAssetStore implements DraftAssetStore {
  Never _unsupported() => throw UnsupportedError('Local draft assets');
  @override
  Future<bool> exists(String draft, String asset) async => _unsupported();
  @override
  Future<Uint8List?> read(String draft, String asset) async => _unsupported();
  @override
  Future<void> write(String draft, String asset, Uint8List bytes) async =>
      _unsupported();
  @override
  Future<void> retain(String draft, Set<String> assets) async => _unsupported();
}
