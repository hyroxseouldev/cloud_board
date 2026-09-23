import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/account_slide_editor_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_library_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_storage_data_source.dart';

import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/slide_editor_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
part 'slide_editor_repository_impl.g.dart';

class LocalSlideEditorRepository implements SlideEditorRepository {
  LocalSlideEditorRepository(this.source);
  final SlideEditorLocalDataSource source;
  @override
  Future<WorkoutModule?> loadDraft(String key) async {
    final value = await source.read('draft.$key');
    return value == null
        ? null
        : WorkoutModuleModel.fromJson(jsonDecode(value) as Map<String, dynamic>)
              .toEntity();
  }

  @override
  Future<void> saveDraft(String key, WorkoutModule module) => source.write(
    'draft.$key',
    jsonEncode(WorkoutModuleModel.fromEntity(module).toJson()),
  );
  @override
  Future<void> clearDraft(String key) => source.write('draft.$key', null);
  @override
  Stream<List<WorkoutModule>> watchTemplates(String scope) =>
      Stream.fromFuture(loadTemplates(scope));
  @override
  Stream<List<WorkoutModule>> watchStyles(String scope) =>
      Stream.fromFuture(loadStyles(scope));
  @override
  Future<List<WorkoutModule>> loadTemplates(String scope) async {
    final value = await source.read('templates.$scope');
    return value == null
        ? []
        : (jsonDecode(value) as List)
              .map(
                (item) =>
                    WorkoutModuleModel.fromJson(item as Map<String, dynamic>)
                        .toEntity(),
              )
              .toList();
  }

  @override
  Future<void> saveTemplates(
    String scope,
    List<WorkoutModule> templates, {
    List<WorkoutModule>? previous,
  }) => source.write(
    'templates.$scope',
    jsonEncode(
      templates
          .map((value) => WorkoutModuleModel.fromEntity(value).toJson())
          .toList(),
    ),
  );

  @override
  Future<List<WorkoutModule>> loadStyles(String scope) async {
    final value = await source.read('styles.$scope');
    return value == null
        ? []
        : (jsonDecode(value) as List)
              .map(
                (item) =>
                    WorkoutModuleModel.fromJson(item as Map<String, dynamic>)
                        .toEntity(),
              )
              .toList();
  }

  @override
  Future<void> saveStyles(
    String scope,
    List<WorkoutModule> styles, {
    List<WorkoutModule>? previous,
  }) => source.write(
    'styles.$scope',
    jsonEncode(
      styles
          .map((value) => WorkoutModuleModel.fromEntity(value).toJson())
          .toList(),
    ),
  );
}

@Riverpod(keepAlive: true)
SlideEditorRepository slideEditorRepository(Ref ref) =>
    AccountSlideEditorRepository(
      SlideEditorLocalDataSource(),
      FirebaseAuth.instance,
      SlideLibraryDataSource(
        FirebaseFirestore.instance,
        FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
      ),
      WorkoutStorageDataSource(FirebaseStorage.instance),
    );
