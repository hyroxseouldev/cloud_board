import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';

Map<String, Object?> encodeDisplayPreparation(DisplayPreparation value) => {
  'schemaVersion': 1, 'sessionId': value.sessionId, 'revision': value.revision,
  'manifestHash': value.manifestHash, 'workoutId': value.workoutId,
  'expiresAtMs': value.expiresAtMs, 'requiredProtocol': value.requiredProtocol,
  'targets': {for (final id in value.targetDeviceIds) id: true},
  'images': value.images, 'sounds': value.sounds,
  'imageCount': value.images.length,
};
List<String> _strings(Object? value) => value is List
    ? value.cast<String>() : value == null ? const [] : (value as Map).values.cast<String>().toList();
DisplayPreparation? decodeDisplayPreparation(Object? value) {
  try {
    if (value is! Map || value['schemaVersion'] != 1) return null;
    final images = _strings(value['images']), sounds = _strings(value['sounds']);
    final targets = (value['targets'] as Map).keys.cast<String>().toList();
    if (images.length > 64 || targets.length > 32 || sounds.length > 4 ||
        value['imageCount'] != images.length) return null;
    return DisplayPreparation(sessionId: value['sessionId'] as String,
      revision: (value['revision'] as num).toInt(), manifestHash: value['manifestHash'] as String,
      workoutId: value['workoutId'] as String, expiresAtMs: (value['expiresAtMs'] as num).toInt(),
      requiredProtocol: (value['requiredProtocol'] as num).toInt(),
      targetDeviceIds: targets, images: images, sounds: sounds);
  } catch (_) { return null; }
}
DisplayPreparationReceipt? decodePreparationReceipt(Object? value) {
  try {
    if (value is! Map) return null;
    return DisplayPreparationReceipt(sessionId: value['sessionId'] as String,
      revision: (value['revision'] as num).toInt(), manifestHash: value['manifestHash'] as String,
      status: value['status'] as String, checkedAtMs: (value['checkedAtMs'] as num).toInt(),
      imageCount: (value['imageCount'] as num).toInt(), audioReady: value['audioReady'] == true);
  } catch (_) { return null; }
}
