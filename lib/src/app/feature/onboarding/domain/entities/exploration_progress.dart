import 'package:freezed_annotation/freezed_annotation.dart';

part 'exploration_progress.freezed.dart';
part 'exploration_progress.g.dart';

/// Local, account-scoped learning state. Never a center permission or TV ACK.
@freezed
abstract class ExplorationProgress with _$ExplorationProgress {
  const factory ExplorationProgress({
    @Default('basics') String templateKey,
    @Default('exploring') String purpose,
    @Default(false) bool pendingImport,
    @Default(<String>[]) List<String> completedTemplates,
    @Default(<String>[]) List<String> events,
  }) = _ExplorationProgress;

  factory ExplorationProgress.fromJson(Map<String, dynamic> json) =>
      _$ExplorationProgressFromJson(json);
}
