import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_library_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_storage_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/library_failure.dart';

/// Drafts stay on-device; reusable templates and styles belong to the account.
class AccountSlideEditorRepository extends LocalSlideEditorRepository {
  AccountSlideEditorRepository(
    super.source,
    this.auth,
    this.remote,
    this.storage,
  );
  final FirebaseAuth auth;
  final SlideLibraryDataSource remote;
  final WorkoutStorageDataSource storage;
  final _migrations = <String, Future<void>>{};
  final _imported = <String>{};

  void _requireAccount(String scope) {
    if (auth.currentUser?.uid != scope) {
      throw const LibraryFailure('로그인 계정을 확인해 주세요.');
    }
  }

  Map<String, dynamic> _json(WorkoutModule value) =>
      WorkoutModuleModel.fromEntity(value).toJson();
  List<WorkoutModule> _decode(List<Map<String, dynamic>> items) =>
      items.map((item) => WorkoutModuleModel.fromJson(item).toEntity()).toList()
        ..sort((a, b) => a.id.compareTo(b.id));

  Future<void> _migrate(String scope, String kind) async {
    _requireAccount(scope);
    final key = '$scope/$kind';
    if (_imported.contains(key)) return;
    final pending = _migrations[key];
    if (pending != null) return pending;
    final task = _importLocal(scope, kind);
    _migrations[key] = task;
    try {
      await task;
      _imported.add(key);
    } finally {
      _migrations.remove(key);
    }
  }

  Future<void> _importLocal(String scope, String kind) async {
    final local = kind == 'templates'
        ? await super.loadTemplates(scope)
        : await super.loadStyles(scope);
    if (local.isEmpty) return;
    final fingerprint = sha256
        .convert(utf8.encode(jsonEncode(local.map(_json).toList())))
        .toString();
    final key = 'account-import.$kind.$scope';
    if (await source.read(key) == fingerprint) return;
    // Import each batch atomically. Server skips existing items and tombstones,
    // so retries or later device upgrades never resurrect/overwrite cloud data.
    for (var start = 0; start < local.length; start += 25) {
      final changes = <Map<String, dynamic>>[];
      for (final item in local.skip(start).take(25)) {
        final prepared = await _prepare(scope, kind, item);
        changes.add({'id': item.id, 'base': null, 'value': _json(prepared)});
      }
      _requireAccount(scope);
      await remote.mutate(scope, kind, changes, migration: true);
    }
    _requireAccount(scope);
    // Keep original local payload as a recovery backup, including old favorites.
    await source.write(key, fingerprint);
  }

  Future<WorkoutModule> _prepare(
    String scope,
    String kind,
    WorkoutModule item,
  ) async => kind == 'styles'
      ? item.copyWith(imageSource: '', favorite: false)
      : item.copyWith(
          imageSource: await storage.uploadImage(
            scope,
            '_slide_library',
            item.imageSource,
          ),
        );

  Stream<List<WorkoutModule>> _watch(String scope, String kind) async* {
    await _migrate(scope, kind);
    yield* remote.watch(scope, kind).map((items) {
      _requireAccount(scope);
      return _decode(items);
    });
  }

  Future<List<WorkoutModule>> _load(String scope, String kind) async {
    await _migrate(scope, kind);
    final items = await remote.load(scope, kind);
    _requireAccount(scope);
    return _decode(items);
  }

  Future<void> _save(
    String scope,
    String kind,
    List<WorkoutModule> items,
    List<WorkoutModule>? previous,
  ) async {
    _requireAccount(scope);
    if (previous == null) throw const LibraryFailure('라이브러리를 불러온 뒤 저장해 주세요.');
    final before = {for (final item in previous) item.id: item};
    final after = {for (final item in items) item.id: item};
    final changes = <Map<String, dynamic>>[];
    for (final id in {...before.keys, ...after.keys}) {
      if (before[id] == after[id]) continue;
      final item = after[id];
      changes.add({
        'id': id,
        'base': before[id] == null ? null : _json(before[id]!),
        'value': item == null ? null : _json(await _prepare(scope, kind, item)),
      });
    }
    if (changes.isEmpty) return;
    _requireAccount(scope);
    try {
      await remote.mutate(scope, kind, changes);
    } on FirebaseFunctionsException catch (error) {
      throw LibraryFailure(
        error.message ?? '동기화하지 못했습니다. 연결을 확인하고 다시 시도해 주세요.',
      );
    }
  }

  @override
  Stream<List<WorkoutModule>> watchTemplates(String scope) =>
      _watch(scope, 'templates');
  @override
  Stream<List<WorkoutModule>> watchStyles(String scope) =>
      _watch(scope, 'styles');
  @override
  Future<List<WorkoutModule>> loadTemplates(String scope) =>
      _load(scope, 'templates');
  @override
  Future<List<WorkoutModule>> loadStyles(String scope) =>
      _load(scope, 'styles');
  @override
  Future<void> saveTemplates(
    String scope,
    List<WorkoutModule> templates, {
    List<WorkoutModule>? previous,
  }) => _save(scope, 'templates', templates, previous);
  @override
  Future<void> saveStyles(
    String scope,
    List<WorkoutModule> styles, {
    List<WorkoutModule>? previous,
  }) => _save(scope, 'styles', styles, previous);
}
