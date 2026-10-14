/// A resource limit is known only after validating its explicit entitlement.
/// Unknown and unlimited both have no finite cap but must never be conflated.
class PlanResourceLimit {
  const PlanResourceLimit.unknown() : known = false, limit = null;
  const PlanResourceLimit.unlimited() : known = true, limit = null;
  const PlanResourceLimit.finite(int value)
    : assert(value >= 0),
      known = true,
      limit = value;

  final bool known;
  final int? limit;
  bool get isUnlimited => known && limit == null;
}
