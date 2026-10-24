/// A local consistency check for useful errors. RTDB rules repeat these checks
/// atomically on every presence write; this is never a substitute for rules.
bool displayMayResume({
  required String uid,
  required String ownerId,
  required String deviceId,
  required String pairingCode,
  required Object? grant,
  required Object? access,
  required Object? device,
}) {
  if (grant is! Map || access is! Map || device is! Map) return false;
  return uid.isNotEmpty &&
      grant['protocol'] == 1 &&
      grant['ownerId'] == ownerId &&
      grant['deviceId'] == deviceId &&
      access['ownerId'] == ownerId &&
      access['deviceId'] == deviceId &&
      device['id'] == deviceId &&
      device['displayUid'] == uid &&
      device['paired'] == true &&
      device['mode'] == 'display' &&
      RegExp(r'^\d{6}$').hasMatch(pairingCode) &&
      grant['pairingCode'] == pairingCode &&
      access['pairingCode'] == pairingCode &&
      device['pairingCode'] == pairingCode &&
      device['pairedAtMs'] is num &&
      (device['pairedAtMs'] as num) > 0 &&
      grant['pairedAtMs'] == device['pairedAtMs'] &&
      access['pairedAtMs'] == device['pairedAtMs'];
}

bool ownerDisplayMayResume({
  required String uid,
  required String ownerId,
  required String deviceId,
  required String pairingCode,
  required Object? grant,
  required Object? device,
}) {
  if (grant is! Map || device is! Map) return false;
  return uid == ownerId &&
      grant['protocol'] == 1 &&
      grant['ownerId'] == ownerId &&
      grant['deviceId'] == deviceId &&
      device['id'] == deviceId &&
      device['displayUid'] == null &&
      device['paired'] == true &&
      RegExp(r'^\d{6}$').hasMatch(pairingCode) &&
      grant['pairingCode'] == pairingCode &&
      device['pairingCode'] == pairingCode &&
      device['pairedAtMs'] is num &&
      (device['pairedAtMs'] as num) > 0 &&
      grant['pairedAtMs'] == device['pairedAtMs'];
}
