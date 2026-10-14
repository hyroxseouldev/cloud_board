import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/library_failure.dart';

class PlanLimitFailure {
  const PlanLimitFailure({
    required this.resource,
    required this.limit,
    required this.used,
  });
  final String resource;
  final int limit, used;
  static PlanLimitFailure? from(Object? error) {
    if (error is LibraryFailure) return from(error.cause);
    if (error is! FirebaseFunctionsException ||
        error.code != 'resource-exhausted') {
      return null;
    }
    final details = error.details;
    if (details is! Map ||
        details['reason'] != 'plan-limit' ||
        !const ['workouts', 'savedSlides'].contains(details['resource']) ||
        details['limit'] is! int ||
        details['used'] is! int) {
      return null;
    }
    return PlanLimitFailure(
      resource: details['resource'] as String,
      limit: details['limit'] as int,
      used: details['used'] as int,
    );
  }

  String get message => resource == 'workouts'
      ? '수업 $limit개를 모두 저장했어요. 새 수업을 저장하려면 기존 수업을 정리해 주세요.'
      : '재사용 슬라이드 $limit개를 모두 저장했어요. 기존 슬라이드를 정리한 뒤 다시 저장해 주세요.';
}
