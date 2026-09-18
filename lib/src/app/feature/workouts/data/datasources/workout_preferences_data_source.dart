import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/countdown_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';

typedef _SettingsRead = ({
  WorkoutPreferences? common,
  WorkoutPreferences initial,
});

class WorkoutPreferencesDataSource {
  WorkoutPreferencesDataSource(this.firestore, this.storage, this.auth);
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final FirebaseAuth auth;
  final _pending = <String, Future<_SettingsRead>>{};
  String? _cachedOwner;
  _SettingsRead? _cached;
  DateTime? _expires;
  int _generation = 0;

  void clear() {
    _generation++;
    _cachedOwner = null;
    _cached = null;
    _expires = null;
    _pending.clear();
  }

  void checkOwner(String ownerId) {
    if (ownerId.isEmpty ||
        auth.currentUser?.uid != ownerId ||
        auth.currentUser!.isAnonymous) {
      clear();
      throw StateError('로그인 계정이 변경됐습니다. 다시 열어 주세요.');
    }
  }

  Future<_SettingsRead> _read(String ownerId, {bool fresh = false}) async {
    checkOwner(ownerId);
    if (!fresh &&
        _cachedOwner == ownerId &&
        _cached != null &&
        DateTime.now().isBefore(_expires!)) {
      return _cached!;
    }
    final key = '$ownerId:$fresh';
    final existing = _pending[key];
    if (existing != null) return existing;
    if (fresh) _generation++;
    final generation = _generation;
    final request = _fetch(ownerId, fresh: fresh);
    _pending[key] = request;
    try {
      final result = await request;
      checkOwner(ownerId);
      if (generation == _generation) {
        _cachedOwner = ownerId;
        _cached = result;
        _expires = DateTime.now().add(const Duration(seconds: 30));
      }
      return result;
    } finally {
      if (identical(_pending[key], request)) _pending.remove(key);
    }
  }

  Future<_SettingsRead> _fetch(String ownerId, {required bool fresh}) async {
    final options = GetOptions(
      source: fresh ? Source.server : Source.serverAndCache,
    );
    final doc = await firestore
        .doc('users/$ownerId/settings/workout')
        .get(options)
        .timeout(const Duration(seconds: 8));
    if (doc.exists) {
      final json = doc.data()!;
      if (json['schemaVersion'] != 1 || json['preferences'] is! Map) {
        throw const FormatException('지원하지 않는 계정 설정입니다. 앱을 업데이트해 주세요.');
      }
      final value = WorkoutPreferences.fromJson(
        Map<String, dynamic>.from(json['preferences']),
      ).copyWith(revision: (json['revision'] as num).toInt());
      return (common: value, initial: value);
    }
    // One legacy read resolves both fields; countdown defaults are NOT common settings.
    final legacy =
        (await firestore
                .doc('users/$ownerId')
                .get(options)
                .timeout(const Duration(seconds: 8)))
            .data();
    final json = legacy?['workoutSettings'];
    final common = json is Map
        ? WorkoutPreferences.fromJson(Map<String, dynamic>.from(json))
        : null;
    final countdown = legacy?['countdownDefaults'];
    return (
      common: common,
      initial:
          common ??
          WorkoutPreferences(
            countdown: countdown is Map
                ? CountdownPreferences.fromJson(
                    Map<String, dynamic>.from(countdown),
                  )
                : const CountdownPreferences(),
          ),
    );
  }

  Future<WorkoutPreferences?> load(
    String ownerId, {
    bool fresh = false,
  }) async => (await _read(ownerId, fresh: fresh)).common;

  Future<WorkoutPreferences> loadForEditing(String ownerId) async =>
      (await _read(ownerId)).initial;

  Future<WorkoutPreferences> save(
    String ownerId,
    WorkoutPreferences value,
  ) async {
    checkOwner(ownerId);
    var source = value.countdown.imageSource;
    if (source.isNotEmpty &&
        !source.startsWith('https://') &&
        !source.startsWith('http://')) {
      final image = WorkoutImageSource.decode(source);
      if (!WorkoutImageSource.supportedContentTypes.contains(
        image.contentType,
      )) {
        throw const FormatException('지원하지 않는 이미지 형식입니다.');
      }
      final file = storage.ref(
        'users/$ownerId/brand/workout-settings/${DateTime.now().microsecondsSinceEpoch}',
      );
      await file.putData(
        image.bytes,
        SettableMetadata(contentType: image.contentType),
      );
      source = await file.getDownloadURL();
    }
    checkOwner(ownerId);
    final normalized = value.copyWith(
      soundVolume: value.soundVolume.clamp(0, 1),
      countdown: value.countdown.copyWith(
        imageSource: source,
        seconds: value.countdown.seconds.clamp(0, 60),
      ),
      revision: value.revision + 1,
    );
    final target = firestore.doc('users/$ownerId/settings/workout');
    await firestore.runTransaction((transaction) async {
      final previous = (await transaction.get(target)).data();
      checkOwner(ownerId);
      if ((previous?['revision'] ?? 0) != value.revision) {
        throw StateError('다른 기기에서 설정이 변경됐습니다. 다시 불러온 뒤 적용해 주세요.');
      }
      if (previous != null && previous['schemaVersion'] != 1) {
        throw const FormatException('지원하지 않는 설정 버전입니다.');
      }
      final contentOnly = previous?['contentOnly'] == true;
      transaction.set(target, {
        'schemaVersion': 1,
        'revision': normalized.revision,
        'updatedAt': FieldValue.serverTimestamp(),
        'contentOnly': contentOnly,
        'preferences': normalized.toJson(),
      });
      // Temporary one-way mirror for installed legacy readers. Rules prevent
      // legacy writers from silently replacing the canonical preferences.
      if (!contentOnly) {
        transaction.set(firestore.doc('users/$ownerId'), {
          'uid': ownerId,
          'workoutSettings': normalized.toJson(),
        }, SetOptions(merge: true));
      }
    });
    checkOwner(ownerId);
    clear();
    _cachedOwner = ownerId;
    _cached = (common: normalized, initial: normalized);
    _expires = DateTime.now().add(const Duration(seconds: 30));
    return normalized;
  }
}
