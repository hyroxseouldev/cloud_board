import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_firestore_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_storage_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_write_conflict.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final cacheInitialized in [false, true]) {
    for (final isCopy in [false, true]) {
      test(
        '${isCopy ? 'copied' : 'new'} workout cached reopen protects a deleted '
        'server record (cache initialized: $cacheInitialized)',
        () async {
          final source = _Source();
          final repo = await _repository(_Auth(), source);
          if (cacheInitialized) await repo.loadOne('missing');
          final original = _workout('original');
          final draft = isCopy
              ? original.copyWith(id: 'copy', name: 'Copied class')
              : original;
          final saved = await repo.save(draft);
          expect(source.requiredExisting.single, isFalse);
          final reads = source.reads;
          final reopened = await repo.loadOne(saved.id);
          expect(reopened, saved);
          expect(source.reads, reads, reason: 'saved details are cached');

          source.records.remove(('owner', saved.id));
          await expectLater(
            repo.save(reopened!.copyWith(name: 'Unsaved edit')),
            throwsA(isA<WorkoutWriteConflict>()),
          );
          expect(source.requiredExisting.last, isTrue);
          expect(source.records, isEmpty);
        },
      );
    }
  }

  test('known saved IDs never carry over to a different account', () async {
    final auth = _Auth();
    final source = _Source();
    final repo = await _repository(auth, source);
    await repo.loadOne('missing');
    await repo.save(_workout('shared-id'));
    auth.uid = 'another-owner';
    final saved = await repo.save(_workout('shared-id'));
    expect(saved.ownerId, 'another-owner');
    expect(source.requiredExisting, [false, false]);
    expect(source.records.length, 2);
  });

  test(
    'failed image refresh does not commit a revision or replace cached content',
    () async {
      final source = _Source();
      final storage = _Storage();
      final repo = await _repository(_Auth(), source, storage: storage);
      final original = _workout('existing').copyWith(
        modules: [
          WorkoutModule.empty('slide').copyWith(
            designTemplate: 'studio-v1-numbered',
            text: 'Run 200m',
            imageSource: 'https://example.com/previous.png',
            designFingerprint: 'v1:previous',
          ),
        ],
      );
      source.records[('owner', original.id)] = WorkoutModel.fromEntity(
        original,
      );
      expect(await repo.loadOne(original.id), original);
      storage.error = StateError('PNG upload failed');
      final edited = original.copyWith(name: 'Unsaved class name');
      await expectLater(repo.save(edited), throwsStateError);
      expect(source.requiredExisting, isEmpty);
      expect(source.records[('owner', original.id)]!.toEntity(), original);
      expect(await repo.loadOne(original.id), original);
      expect(edited.name, 'Unsaved class name');

      storage.error = null;
      expect((await repo.save(edited)).name, edited.name);
      expect(source.requiredExisting, [true]);
    },
  );
}

Workout _workout(String id) => Workout.empty(
  id,
  const WorkoutAuthor(id: 'owner', displayName: '', photoUrl: null),
);

Future<WorkoutRepositoryImpl> _repository(
  _Auth auth,
  _Source source, {
  _Storage? storage,
}) async => WorkoutRepositoryImpl(
  auth,
  source,
  storage ?? _Storage(),
  WorkoutLocalDataSource(await SharedPreferences.getInstance()),
);

class _Source extends WorkoutFirestoreDataSource {
  _Source() : super(_Firestore());

  final records = <(String, String), WorkoutModel>{};
  final requiredExisting = <bool>[];
  int reads = 0;

  @override
  Future<WorkoutModel?> loadOne(
    String userId,
    String workoutId, {
    bool requireServer = false,
  }) async {
    reads++;
    return records[(userId, workoutId)];
  }

  @override
  Future<WorkoutModel> save(
    String userId,
    WorkoutModel workout, {
    bool ifAbsent = false,
    DateTime? expectedUpdatedAt,
    bool requireExisting = false,
  }) async {
    requiredExisting.add(requireExisting);
    final key = (userId, workout.id);
    final previous = records[key];
    if (ifAbsent && previous != null) return previous;
    ensureWorkoutRevision(
      expected: expectedUpdatedAt,
      current: previous?.updatedAt,
      requireExisting: requireExisting,
    );
    records[key] = workout;
    return workout;
  }
}

class _Storage implements WorkoutStorageDataSource {
  Object? error;
  @override
  Future<Workout> syncImages(
    String userId,
    Workout workout, {
    void Function(int completed, int total)? onProgress,
  }) async {
    if (error != null) throw error!;
    return workout;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  String uid = 'owner';
  @override
  User get currentUser => _User(uid);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  String? get displayName => null;
  @override
  String? get photoURL => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Firestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
