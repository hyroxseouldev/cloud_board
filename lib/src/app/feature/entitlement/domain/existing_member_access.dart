import 'package:cloud_board/src/app/feature/entitlement/domain/entities/store_entitlement.dart';

/// Both server-owned projections must describe the same current grant. Missing,
/// stale, suspended or partially projected grants use the existing recovery UI.
bool existingMemberMayEnter({
  required String uid,
  required StoreEntitlement grant,
  required String source,
  required Object? realtimeAccess,
  required int serverNowMs,
}) {
  if (realtimeAccess is! Map) return false;
  if (uid.isEmpty ||
      source.isEmpty ||
      grant.revision < 0 ||
      grant.policyVersion.isEmpty ||
      !const {
        'active',
        'trialing',
        'grace_period',
        'canceling',
        'past_due',
      }.contains(grant.status) ||
      !grant.allowsNewClass(uid, serverNowMs) ||
      realtimeAccess['canStartClass'] != true ||
      realtimeAccess['managed'] != true) {
    return false;
  }
  final fields = {
    'plan': grant.plan,
    'status': grant.status,
    'validUntilMs': grant.validUntilMs,
    'revision': grant.revision,
    'source': source,
    'policyVersion': grant.policyVersion,
  };
  for (final field in fields.entries) {
    if (field.value != realtimeAccess[field.key]) return false;
  }
  return true;
}
