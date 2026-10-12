import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:cloud_board/src/app/feature/workouts/data/datasources/draft_asset_store.dart';

DraftAssetStore createDraftAssetStore() => IndexedDbDraftAssetStore();

/// Binary IndexedDB records avoid the synchronous Web Storage size limit.
class IndexedDbDraftAssetStore implements DraftAssetStore {
  IndexedDbDraftAssetStore({this.databaseName = 'cloudboard-slide-drafts-v2'});

  final String databaseName;
  Future<web.IDBDatabase>? _database;

  Future<web.IDBDatabase> _open() => _database ??= _connect();

  Future<web.IDBDatabase> _connect() async {
    final request = web.window.indexedDB.open(databaseName, 1);
    request.onupgradeneeded = ((web.Event _) {
      (request.result as web.IDBDatabase).createObjectStore('assets');
    }).toJS;
    try {
      return (await _result(request)) as web.IDBDatabase;
    } catch (_) {
      _database = null;
      rethrow;
    }
  }

  Future<JSAny?> _result(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) => completer.complete(
      request.result,
    )).toJS;
    request.onerror = ((web.Event _) => completer.completeError(
      StateError(request.error?.message ?? 'Draft asset request failed'),
    )).toJS;
    return completer.future;
  }

  Future<void> _committed(web.IDBTransaction transaction) {
    final completer = Completer<void>();
    transaction.oncomplete = ((web.Event _) => completer.complete()).toJS;
    transaction.onabort = ((web.Event _) => completer.completeError(
      StateError(
        transaction.error?.message ?? 'Draft asset transaction aborted',
      ),
    )).toJS;
    return completer.future;
  }

  @override
  Future<bool> exists(String draft, String asset) async {
    final database = await _open();
    final request = database
        .transaction('assets'.toJS)
        .objectStore('assets')
        .getKey('$draft/$asset'.toJS);
    return await _result(request) != null;
  }

  @override
  Future<Uint8List?> read(String draft, String asset) async {
    final database = await _open();
    final request = database
        .transaction('assets'.toJS)
        .objectStore('assets')
        .get('$draft/$asset'.toJS);
    final result = await _result(request);
    return result == null ? null : (result as JSUint8Array).toDart;
  }

  @override
  Future<void> write(String draft, String asset, Uint8List bytes) async {
    final database = await _open();
    final transaction = database.transaction('assets'.toJS, 'readwrite');
    final committed = _committed(transaction);
    transaction.objectStore('assets').put(bytes.toJS, '$draft/$asset'.toJS);
    await committed;
  }

  @override
  Future<void> retain(String draft, Set<String> assets) async {
    final database = await _open();
    final transaction = database.transaction('assets'.toJS, 'readwrite');
    final committed = _committed(transaction);
    final store = transaction.objectStore('assets');
    final prefix = '$draft/';
    final request = store.openKeyCursor(
      web.IDBKeyRange.bound(prefix.toJS, '$prefix\uffff'.toJS),
    );
    request.onsuccess = ((web.Event _) {
      final result = request.result;
      if (result == null) return;
      final cursor = result as web.IDBCursor;
      final key = (cursor.key as JSString).toDart;
      if (!assets.contains(key.substring(prefix.length))) {
        store.delete(cursor.key);
      }
      cursor.continue_();
    }).toJS;
    await committed;
  }
}
