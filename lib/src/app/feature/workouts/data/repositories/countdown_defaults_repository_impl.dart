import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/countdown_defaults_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/countdown_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/countdown_defaults_repository.dart';
part 'countdown_defaults_repository_impl.g.dart';

class CountdownDefaultsRepositoryImpl implements CountdownDefaultsRepository {
  CountdownDefaultsRepositoryImpl(this.source);
  final CountdownDefaultsDataSource source;
  @override
  Future<CountdownPreferences> load(String ownerId) => source.load(ownerId);
  @override
  Future<void> save(String ownerId, CountdownPreferences value) =>
      source.save(ownerId, value);
}

@riverpod
CountdownDefaultsRepository countdownDefaultsRepository(Ref ref) =>
    CountdownDefaultsRepositoryImpl(
      CountdownDefaultsDataSource(
        FirebaseFirestore.instance,
        FirebaseStorage.instance,
        FirebaseAuth.instance,
      ),
    );
