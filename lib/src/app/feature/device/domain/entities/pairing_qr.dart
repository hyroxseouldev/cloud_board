/// Only Cloud Board pairing payloads (or an exact six-digit code) are accepted.
/// Scanning never navigates to arbitrary URLs or sends account identifiers.
String pairingQrPayload(String code) => 'cloudboard://pair?code=$code';

String? pairingCodeFromQr(String raw) {
  final value = raw.trim();
  final digits = RegExp(r'^\d{6}$');
  if (digits.hasMatch(value)) return value;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'cloudboard' ||
      uri.host != 'pair' ||
      uri.path.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.queryParametersAll.length != 1) {
    return null;
  }
  final codes = uri.queryParametersAll['code'];
  if (codes == null || codes.length != 1 || !digits.hasMatch(codes.single)) {
    return null;
  }
  return codes.single;
}
