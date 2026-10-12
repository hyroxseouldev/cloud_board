import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/draft_asset_store.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _key = 'account-a/workout/slide';
const _metadata = 'cloudboard.slide-editor.v2.draft.$_key';
const _legacy = 'cloudboard.slide-editor.v1.draft.$_key';
final _original = WorkoutModule.empty('slide');
String _image(int byte) =>
    'data:image/png;base64,${base64Encode([byte, 2, 3])}';

void main() {
  late DraftTestPreferences preferences;
  late MemoryDraftAssets assets;
  late LocalSlideEditorRepository repository;
  LocalSlideEditorRepository reopen() => LocalSlideEditorRepository(
    SlideEditorLocalDataSource(preferences: preferences, assets: assets),
  );
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = DraftTestPreferences();
    assets = MemoryDraftAssets();
    repository = reopen();
  });

  test(
    'v1 data URI migrates after durable asset and restores after restart',
    () async {
      final module = _original.copyWith(imageSource: _image(1), text: 'legacy');
      preferences.values[_legacy] = jsonEncode(
        WorkoutModuleModel.fromEntity(module).toJson(),
      );
      expect(await repository.loadDraft(_key), module);
      expect(preferences.values.containsKey(_legacy), isFalse);
      expect(preferences.values[_metadata], isNot(contains(_image(1))));
      expect(assets.writes, 1);
      expect(await reopen().loadDraft(_key), module);
      await reopen().saveDraft(_key, module.copyWith(text: 'updated'));
      expect(await reopen().loadDraft(_key), module.copyWith(text: 'updated'));
      expect(
        assets.writes,
        1,
        reason: 'Existing durable assets are reused after restart',
      );
    },
  );

  test('asset or metadata failure preserves legacy recovery', () async {
    final module = _original.copyWith(imageSource: _image(1));
    preferences.values[_legacy] = jsonEncode(
      WorkoutModuleModel.fromEntity(module).toJson(),
    );
    assets.failWrite = true;
    await expectLater(repository.loadDraft(_key), throwsStateError);
    expect(preferences.values.containsKey(_legacy), isTrue);
    expect(preferences.values.containsKey(_metadata), isFalse);
    assets.failWrite = false;
    preferences.failing.add('metadata');
    await expectLater(repository.loadDraft(_key), throwsStateError);
    expect(preferences.values.containsKey(_legacy), isTrue);
    preferences.failing.remove('metadata');
    expect(await reopen().loadDraft(_key), module);
  });

  test(
    'interrupted replacement retains referenced image and collects orphan',
    () async {
      final first = _original.copyWith(imageSource: _image(1));
      final second = _original.copyWith(imageSource: _image(9));
      await repository.saveDraft(_key, first);
      preferences.failing.add('metadata');
      await expectLater(repository.saveDraft(_key, second), throwsStateError);
      expect(assets.values.length, 2);
      preferences.failing.remove('metadata');
      expect(await reopen().loadDraft(_key), first);
      expect(assets.values.length, 1);
      await repository.saveDraft(_key, second);
      expect(await reopen().loadDraft(_key), second);
      expect(assets.values.length, 1);
    },
  );

  test('first-save interruption is cleaned even without metadata', () async {
    preferences.failing.add('metadata');
    await expectLater(
      repository.saveDraft(_key, _original.copyWith(imageSource: _image(1))),
      throwsStateError,
    );
    expect(assets.values, isNotEmpty);
    preferences.failing.remove('metadata');
    expect(await reopen().loadDraft(_key), isNull);
    expect(assets.values, isEmpty);
  });

  test(
    'multiple source instances serialize image swaps and clear together',
    () async {
      final gate = Completer<void>();
      assets.writeGate = gate.future;
      final first = repository.saveDraft(
        _key,
        _original.copyWith(imageSource: _image(1)),
      );
      final second = reopen().saveDraft(
        _key,
        _original.copyWith(imageSource: _image(9)),
      );
      final clear = reopen().clearDraft(_key);
      gate.complete();
      await Future.wait([first, second, clear]);
      expect(await repository.loadDraft(_key), isNull);
      expect(assets.values, isEmpty);
      await repository.saveDraft(
        _key,
        _original.copyWith(imageSource: _image(1)),
      );
      expect(
        await reopen().loadDraft(_key),
        _original.copyWith(imageSource: _image(1)),
      );
    },
  );

  test('clear is ordered behind image write and tombstone blocks legacy resurrection', () async {
    final module = _original.copyWith(imageSource: _image(1));
    final gate = Completer<void>();
    assets.writeGate = gate.future;
    final save = repository.saveDraft(_key, module);
    final clear = repository.clearDraft(_key);
    await Future<void>.delayed(Duration.zero);
    expect(preferences.values.containsKey(_metadata), isFalse);
    gate.complete();
    await Future.wait([save, clear]);
    expect(await reopen().loadDraft(_key), isNull);
    expect(assets.values, isEmpty);

    await repository.saveDraft(_key, module);
    preferences.values[_legacy] = jsonEncode(
      WorkoutModuleModel.fromEntity(module).toJson(),
    );
    preferences.failing.add('legacyRemove');
    await repository.clearDraft(_key);
    expect(preferences.values.containsKey(_legacy), isTrue);
    expect(await reopen().loadDraft(_key), isNull);
    preferences.failing.remove('legacyRemove');
    expect(await reopen().loadDraft(_key), isNull);
    expect(assets.values, isEmpty);
  });

  test(
    'cleanup failure is retried without failing committed metadata',
    () async {
      await repository.saveDraft(
        _key,
        _original.copyWith(imageSource: _image(1)),
      );
      assets.failRetain = true;
      final latest = _original.copyWith(imageSource: _image(9));
      await repository.saveDraft(_key, latest);
      expect(assets.values.length, 2);
      expect(await reopen().loadDraft(_key), latest);
      assets.failRetain = false;
      expect(await reopen().loadDraft(_key), latest);
      expect(assets.values.length, 1);
    },
  );

  test(
    'account keys and URL/image changes cannot reuse a deleted asset',
    () async {
      final image = _original.copyWith(imageSource: _image(1));
      const other = 'account-b/workout/slide';
      await repository.saveDraft(_key, image);
      await repository.saveDraft(other, image);
      expect(assets.values.length, 2);
      await repository.clearDraft(_key);
      expect(await repository.loadDraft(other), image);
      expect(assets.values.length, 1);
      await repository.saveDraft(_key, image);
      await repository.saveDraft(
        _key,
        _original.copyWith(imageSource: 'https://example.com/picture.png'),
      );
      expect(assets.values.length, 1);
      await repository.saveDraft(_key, image);
      expect(await reopen().loadDraft(_key), image);
      expect(assets.values.length, 2);
    },
  );

  test('missing asset reports recoverable storage failure without deleting metadata', () async {
    await repository.saveDraft(
      _key,
      _original.copyWith(imageSource: _image(1)),
    );
    assets.values.clear();
    await expectLater(reopen().loadDraft(_key), throwsFormatException);
    expect(preferences.values.containsKey(_metadata), isTrue);
  });

  for (final fails in [false, true]) {
    test(
      'markSaved during an asset write leaves a clean saved state (failure=$fails)',
      () async {
        final container = ProviderContainer(
          overrides: [
            slideEditorRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
        final provider = slideEditorControllerProvider(
          'workout',
          _original,
          'account-a',
        );
        container.listen(provider, (_, _) {});
        await Future<void>.delayed(Duration.zero);
        final controller = container.read(provider.notifier);
        final gate = Completer<void>();
        assets.writeGate = gate.future;
        assets.failWrite = fails;
        final saved = _original.copyWith(imageSource: _image(1));
        controller.update(saved);
        final pendingFlush = controller.flush();
        await Future<void>.delayed(Duration.zero);
        final pendingSave = controller.markSaved(saved);
        gate.complete();
        await Future.wait([pendingFlush, pendingSave]);
        expect(container.read(provider).dirty, isFalse);
        expect(container.read(provider).localSaved, isFalse);
        expect(container.read(provider).storageError, isNull);
        final key = base64Url.encode(utf8.encode('account-a/workout/slide'));
        expect(await reopen().loadDraft(key), isNull);
        expect(assets.values, isEmpty);
      },
    );
  }

  testWidgets(
    '5 MiB image is written once across 20 debounced text/timer edits',
    (tester) async {
      final bytes = Uint8List(5 * 1024 * 1024);
      for (var index = 0; index < bytes.length; index++) {
        bytes[index] = index % 251;
      }
      final image = 'data:image/png;base64,${base64Encode(bytes)}';
      final pictured = _original.copyWith(imageSource: image);
      final baseline = Stopwatch()..start();
      var baselineBytes = 0;
      for (var index = 0; index <= 20; index++) {
        baselineBytes += utf8
            .encode(
              jsonEncode(
                WorkoutModuleModel.fromEntity(
                  pictured.copyWith(
                    text: 'Edit $index',
                    workSeconds: 30 + index,
                  ),
                ).toJson(),
              ),
            )
            .length;
      }
      baseline.stop();

      final container = ProviderContainer(
        overrides: [
          slideEditorRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final provider = slideEditorControllerProvider(
        'workout',
        _original,
        'account-a',
      );
      container.listen(provider, (_, _) {});
      await tester.pump();
      final controller = container.read(provider.notifier);
      final optimized = Stopwatch()..start();
      for (var index = 0; index <= 20; index++) {
        controller.update(
          pictured.copyWith(text: 'Edit $index', workSeconds: 30 + index),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
      }
      optimized.stop();
      final metadataWrites = preferences.writes
          .where((value) => value.$1.contains('.v2.draft.'))
          .toList();
      expect(metadataWrites.length, 21);
      expect(assets.writes, 1);
      expect(assets.bytesWritten, 5 * 1024 * 1024);
      expect(metadataWrites.every((value) => value.$2 < 3000), isTrue);
      expect(container.read(provider).localSaved, isTrue);
      final key = base64Url.encode(utf8.encode('account-a/workout/slide'));
      final restored = await reopen().loadDraft(key);
      expect(restored?.imageSource, image);
      expect(restored?.text, 'Edit 20');
      expect(restored?.workSeconds, 50);
      // A debug-host algorithm measurement, not a device/profile frame claim.
      // ignore: avoid_print
      print(
        jsonEncode({
          'fixture':
              '5 MiB binary image, 21 saves, 20 edits at 500 ms fake intervals',
          'baselineSerializedBytes': baselineBytes,
          'baselineSerializationMicros': baseline.elapsedMicroseconds,
          'assetWrites': assets.writes,
          'assetBytes': assets.bytesWritten,
          'metadataWrites': metadataWrites.length,
          'metadataBytes': metadataWrites.fold<int>(
            0,
            (sum, value) => sum + value.$2,
          ),
          'optimizedSaveMicros': optimized.elapsedMicroseconds,
        }),
      );
      await controller.markSaved(restored!);
      expect(await reopen().loadDraft(key), isNull);
      expect(assets.values, isEmpty);
    },
  );
}

class DraftTestPreferences extends SharedPreferencesAsync {
  final values = <String, Object>{};
  final writes = <(String, int)>[];
  final failing = <String>{};
  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<void> setString(String key, String value) async {
    if (failing.contains('metadata') && key.contains('.v2.draft.')) {
      throw StateError('Disk full');
    }
    writes.add((key, utf8.encode(value).length));
    values[key] = value;
  }

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
  @override
  Future<void> remove(String key) async {
    if (failing.contains('legacyRemove') && key.contains('.v1.draft.')) {
      throw StateError('Disk full');
    }
    values.remove(key);
  }
}

class MemoryDraftAssets implements DraftAssetStore {
  final values = <String, Uint8List>{};
  int writes = 0;
  int bytesWritten = 0;
  bool failWrite = false;
  bool failRetain = false;
  Future<void>? writeGate;
  @override
  Future<bool> exists(String draft, String asset) async =>
      values.containsKey('$draft/$asset');
  @override
  Future<Uint8List?> read(String draft, String asset) async =>
      values['$draft/$asset'];
  @override
  Future<void> write(String draft, String asset, Uint8List bytes) async {
    if (writeGate != null) await writeGate;
    if (failWrite) throw StateError('Disk full');
    values['$draft/$asset'] = bytes;
    writes++;
    bytesWritten += bytes.length;
  }

  @override
  Future<void> retain(String draft, Set<String> assets) async {
    if (failRetain) throw StateError('Disk full');
    values.removeWhere(
      (key, _) =>
          key.startsWith('$draft/') &&
          !assets.contains(key.substring(draft.length + 1)),
    );
  }
}
