// Firestore/Realtime Database doubles verify read policy without network access.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_board/src/app/core/config/app_brand.dart';
import 'package:cloud_board/src/app/core/config/legacy_brand_defaults.dart';
import 'package:cloud_board/src/app/feature/operations/data/datasources/store_operations_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/operations/data/models/store_operations_models.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_preferences_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_document.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_content.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const author = WorkoutAuthor(id: 'owner', displayName: '', photoUrl: null);

void main() {
  test('new factories follow current configuration while decoders retain frozen defaults', () {
    expect(Workout.empty('new', author).brandL, AppBrand.defaultWorkoutBrand);
    expect(const WorkoutPreferences().brandL, AppBrand.defaultWorkoutBrand);
    expect(BrandTemplate.initial().storeName, AppBrand.defaultStoreName);
    expect(WorkoutPreferences.fromJson({}).brandL, 'CloudBoard');
    expect(WorkoutPreferences.fromJson({'brandL': null}).brandL, 'CloudBoard');
    expect(BrandTemplateModel.fromJson({}).storeName, 'CloudBoard Studio');
    expect(
      BrandTemplateModel.fromJson({'storeName': null}).storeName,
      'CloudBoard Studio',
    );
    final legacy = WorkoutModel.fromEntity(
      Workout.empty('legacy', author),
    ).toJson()..remove('brandL');
    expect(() => WorkoutModel.fromJson(legacy), throwsA(isA<TypeError>()));
    expect(LegacyBrandDefaults.workoutBrand, 'CloudBoard');
    expect(LegacyBrandDefaults.storeName, 'CloudBoard Studio');
  });

  for (final text in [
    'CloudBoard',
    'CloudBoard Studio',
    'My gym',
    '',
    '클라우드보드 수업',
  ]) {
    test('stored user text "$text" survives every round trip unchanged', () {
      final workout = Workout.empty('stored', author).copyWith(brandL: text);
      expect(
        WorkoutModel.fromJson(WorkoutModel.fromEntity(workout).toJson())
            .toEntity()
            .brandL,
        text,
      );
      final settings = WorkoutPreferences(brandL: text);
      expect(WorkoutPreferences.fromJson(settings.toJson()).brandL, text);
      final brand = BrandTemplate.initial().copyWith(storeName: text);
      expect(
        BrandTemplateModel.fromJson(
          BrandTemplateModel.fromEntity(brand).toJson(),
        ).toEntity().storeName,
        text,
      );
    });
  }

  test('content-only document rendering fallback is independent of future app renames', () {
    final content = WorkoutContent.fromWorkout(
      Workout.empty('content', author),
    );
    final json = WorkoutDocument.encode(content);
    expect(json.containsKey('brandL'), isFalse);
    expect(WorkoutDocument.decode(json).brandL, 'CloudBoard');
    expect(
      WorkoutDocument.encode(
        WorkoutContent.fromWorkout(WorkoutDocument.decode(json).toEntity()),
      ),
      json,
    );
  });

  test('new account preferences use current defaults; old missing fields and countdown-only settings stay legacy', () async {
    final brandNew = _settingsSource({});
    expect(await brandNew.load('owner'), isNull);
    expect(
      (await brandNew.loadForEditing('owner')).brandL,
      AppBrand.defaultWorkoutBrand,
    );
    final noPreferencesYet = _settingsSource({
      'users/owner': {'uid': 'owner'},
    });
    expect(
      (await noPreferencesYet.loadForEditing('owner')).brandL,
      AppBrand.defaultWorkoutBrand,
    );
    final countdownOnly = _settingsSource({
      'users/owner': {
        'countdownDefaults': {'seconds': 7},
      },
    });
    expect(await countdownOnly.load('owner'), isNull);
    final countdown = await countdownOnly.loadForEditing('owner');
    expect(countdown.brandL, 'CloudBoard');
    expect(countdown.countdown.seconds, 7);
    for (final json in [
      <String, dynamic>{},
      {'brandL': 'CloudBoard'},
      {'brandL': 'Custom'},
      {'brandL': ''},
    ]) {
      final canonical = _settingsSource({
        'users/owner/settings/workout': {
          'schemaVersion': 1,
          'revision': 3,
          'preferences': json,
        },
      });
      expect(
        (await canonical.load('owner'))!.brandL,
        json['brandL'] ?? 'CloudBoard',
      );
      final legacy = _settingsSource({
        'users/owner': {'workoutSettings': json},
      });
      expect(
        (await legacy.load('owner'))!.brandL,
        json['brandL'] ?? 'CloudBoard',
      );
    }
  });

  test('absent store data creates current defaults; existing maps retain missing-field legacy value', () async {
    final signedOut = StoreOperationsRealtimeDataSource(_Realtime(null), null);
    expect(
      (await signedOut.watchBrandTemplate().first).storeName,
      AppBrand.defaultStoreName,
    );
    for (final value in [
      null,
      <String, Object?>{},
      {'storeName': 'CloudBoard Studio'},
      {'storeName': 'Custom'},
      {'storeName': ''},
    ]) {
      final source = StoreOperationsRealtimeDataSource(
        _Realtime(value),
        'owner',
      );
      final model = await source.watchBrandTemplate().first;
      expect(
        model.storeName,
        value == null
            ? AppBrand.defaultStoreName
            : (value['storeName'] ?? 'CloudBoard Studio'),
      );
    }
  });
}

WorkoutPreferencesDataSource _settingsSource(
  Map<String, Map<String, dynamic>> documents,
) => WorkoutPreferencesDataSource(_Firestore(documents), _Storage(), _Auth());

class _Firestore implements FirebaseFirestore {
  _Firestore(this.documents);
  final Map<String, Map<String, dynamic>> documents;
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) =>
      _Document(documents[path]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Document implements DocumentReference<Map<String, dynamic>> {
  _Document(this.value);
  final Map<String, dynamic>? value;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(value);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  @override
  User get currentUser => _User();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  @override
  String get uid => 'owner';
  @override
  bool get isAnonymous => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements FirebaseStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Realtime implements FirebaseDatabase {
  _Realtime(this.value);
  final Object? value;
  @override
  DatabaseReference ref([String? path]) => _Reference(value);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reference implements DatabaseReference {
  _Reference(this.value);
  final Object? value;
  @override
  DatabaseReference child(String path) => this;
  @override
  Stream<DatabaseEvent> get onValue => Stream.value(_Event(value));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Event implements DatabaseEvent {
  _Event(this.value);
  final Object? value;
  @override
  DataSnapshot get snapshot => _DataSnapshot(value);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DataSnapshot implements DataSnapshot {
  _DataSnapshot(this.value);
  @override
  final Object? value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
