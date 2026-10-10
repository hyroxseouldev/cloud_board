import 'package:cloud_board/src/app/feature/onboarding/domain/entities/exploration_progress.dart';

abstract interface class ExplorationRepository {
  Future<ExplorationProgress> load(String? userId);
  Future<void> save(String? userId, ExplorationProgress value);
}
