import 'package:cloud_board/src/app/feature/onboarding/domain/entities/first_class_progress.dart';

abstract interface class FirstClassRepository {
  Future<FirstClassProgress> load(String userId, String centerId);
  Future<void> save(
    String userId,
    String centerId,
    FirstClassProgress progress,
  );
  Future<void> record(
    String userId,
    String centerId,
    String sessionId,
    String event,
  );
}
