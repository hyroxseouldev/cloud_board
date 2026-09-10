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
  Future<void> saveStyles(String scope, List<WorkoutModule> styles) =>
      source.write(
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
    LocalSlideEditorRepository(SlideEditorLocalDataSource());
