/// Historic display metadata is captured at the event boundary, never joined to
/// today's mutable device record. Missing old metadata stays unknown.
Map<String, Object?> operationDeviceSnapshot(Map<dynamic, dynamic> device) => {
  'schemaVersion': 2,
  'deviceRole': 'display',
  if (device['name'] is String) 'deviceName': device['name'],
  if (device['zoneName'] is String) 'zoneName': device['zoneName'],
  if (device['appVersion'] is String) 'appVersion': device['appVersion'],
};
