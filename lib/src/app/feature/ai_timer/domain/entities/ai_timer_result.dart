import 'package:freezed_annotation/freezed_annotation.dart';
part 'ai_timer_result.freezed.dart';

@freezed
abstract class AiTimerAccess with _$AiTimerAccess {
  const factory AiTimerAccess({
    required bool premium,
    required bool enabled,
    required int remaining,
    required int limit,
    required DateTime resetsAt,
  }) = _AiTimerAccess;
}

@freezed
abstract class AiTimerSuggestion with _$AiTimerSuggestion {
  const factory AiTimerSuggestion({
    String? name,
    int? workSeconds,
    int? restSeconds,
    int? sets,
    @Default([]) List<String> warnings,
    @Default(false) bool cached,
    required int remaining,
  }) = _AiTimerSuggestion;
}

class AiTimerFailure implements Exception {
  const AiTimerFailure(this.message, {this.code = 'unknown'});
  final String message;
  final String code;
  @override
  String toString() => message;
}
