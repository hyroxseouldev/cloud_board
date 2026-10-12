import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/draft_asset_store.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_recovery_repository.dart';

part 'workout_recovery_repository_impl.g.dart';

/// Keep a complete editor snapshot, including local images, without putting
/// image bytes in preferences. Commit the pointer last, so failed replacement
/// never destroys the previous recoverable snapshot.
class LocalWorkoutRecoveryRepository implements WorkoutRecoveryRepository {
  LocalWorkoutRecoveryRepository({this._preferences, DraftAssetStore? assets})
    : assets = assets ?? createDraftAssetStore();
  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get preferences =>
      _preferences ??= SharedPreferencesAsync();
  final DraftAssetStore assets;
  static Future<void>? _pending;
  final _images = <String, String>{};

  String _scope(String ownerId, String slot) =>
      sha256.convert(utf8.encode('workout-recovery:$ownerId:$slot')).toString();
  String _key(String scope) => 'cloudboard.workout-recovery.v1.$scope';

  Future<T> _ordered<T>(Future<T> Function() action) {
    final next = _pending?.then((_) => action()) ?? Future<T>.sync(action);
    final pending = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending = pending;
    pending.whenComplete(() {
      if (identical(_pending, pending)) _pending = null;
    });
    return next;
  }

  @override
  Future<WorkoutRecoveryDraft?> load(
    String ownerId,
    String slot,
  ) => _ordered(() async {
    final scope = _scope(ownerId, slot);
    final pointer = await preferences.getString(_key(scope));
    if (pointer == null) return null;
    final bytes = await assets.read(scope, pointer);
    if (bytes == null) throw const FormatException('Missing recovery snapshot');
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (json['version'] != 1 || json['ownerId'] != ownerId) {
      throw const FormatException('Invalid recovery snapshot');
    }
    final workout = Map<String, dynamic>.from(json['workout'] as Map);
    final references = Map<String, dynamic>.from(json['images'] as Map);
    Future<String> resolve(String source) async {
      final id = references[source];
      if (id == null) return source;
      final image = await assets.read(scope, id as String);
      if (image == null) throw const FormatException('Missing recovery image');
      return utf8.decode(image);
    }

    workout['countdownImageSource'] = await resolve(
      workout['countdownImageSource'] as String,
    );
    for (final module in workout['modules'] as List) {
      module['imageUrl'] = await resolve(module['imageUrl'] as String);
    }
    return WorkoutRecoveryDraft(
      workout: WorkoutModel.fromJson(workout).toEntity(),
      isNew: json['isNew'] == true,
    );
  });

  @override
  Future<void> save(String ownerId, String slot, WorkoutRecoveryDraft draft) =>
      _ordered(() async {
        if (ownerId.isEmpty || draft.workout.ownerId != ownerId) {
          throw StateError('Recovery account mismatch');
        }
        final scope = _scope(ownerId, slot);
        final json = WorkoutModel.fromEntity(draft.workout).toJson();
        final images = <String, String>{};
        Future<String> persistImage(String source) async {
          if (!source.startsWith('data:')) return source;
          // Bound this cache: only the current workout's image strings are retained.
          final id = _images[source] ??= sha256
              .convert(utf8.encode(source))
              .toString();
          if (!await assets.exists(scope, id)) {
            await assets.write(
              scope,
              id,
              Uint8List.fromList(utf8.encode(source)),
            );
          }
          final marker = 'recovery-image:$id';
          images[marker] = id;
          return marker;
        }

        json['countdownImageSource'] = await persistImage(
          json['countdownImageSource'] as String,
        );
        for (final module in json['modules'] as List) {
          module['imageUrl'] = await persistImage(module['imageUrl'] as String);
        }
        final bytes = Uint8List.fromList(
          utf8.encode(
            jsonEncode(
              {
                'version': 1,
                'ownerId': ownerId,
                'isNew': draft.isNew,
                'workout': json,
                'images': images,
              },
              toEncodable: (value) => value is Timestamp
                  ? value.toDate().toIso8601String()
                  : throw FormatException('Unsupported recovery value'),
            ),
          ),
        );
        final pointer = sha256.convert(bytes).toString();
        await assets.write(scope, pointer, bytes);
        await preferences.setString(_key(scope), pointer);
        _images.removeWhere((_, id) => !images.containsValue(id));
        try {
          await assets.retain(scope, {pointer, ...images.values});
        } catch (_) {
          /* A committed draft survives deferred cleanup. */
        }
      });

  @override
  Future<void> clear(String ownerId, String slot) => _ordered(() async {
    final scope = _scope(ownerId, slot);
    await preferences.remove(_key(scope));
    try {
      await assets.retain(scope, {});
    } catch (_) {
      /* Retry cleanup later. */
    }
  });
}

@Riverpod(keepAlive: true)
WorkoutRecoveryRepository workoutRecoveryRepository(Ref ref) =>
    LocalWorkoutRecoveryRepository();
