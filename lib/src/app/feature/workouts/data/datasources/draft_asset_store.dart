import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/draft_asset_store_stub.dart'
    if (dart.library.io) 'package:cloud_board/src/app/feature/workouts/data/datasources/draft_asset_store_io.dart'
    if (dart.library.js_interop) 'package:cloud_board/src/app/feature/workouts/data/datasources/draft_asset_store_web.dart'
    as platform;

/// Draft assets are local to a single account/workout/slide key. Implementations
/// must finish durable writes before returning and preserve existing assets on
/// failure. Metadata, rather than directory contents, owns the live reference.
abstract interface class DraftAssetStore {
  Future<bool> exists(String draft, String asset);
  Future<Uint8List?> read(String draft, String asset);
  Future<void> write(String draft, String asset, Uint8List bytes);
  Future<void> retain(String draft, Set<String> assets);
}

DraftAssetStore createDraftAssetStore() => platform.createDraftAssetStore();
