class PlanUsage {
  const PlanUsage({
    required this.workoutCount,
    required this.savedSlideCount,
    this.serverConfirmed = false,
  });
  final int workoutCount, savedSlideCount;
  final bool serverConfirmed;
}

abstract interface class PlanUsageRepository {
  Stream<PlanUsage?> watch(String ownerId);
}
