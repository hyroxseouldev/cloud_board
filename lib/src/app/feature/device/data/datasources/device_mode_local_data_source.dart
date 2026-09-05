import 'package:shared_preferences/shared_preferences.dart';

class DeviceModeLocalDataSource {
  const DeviceModeLocalDataSource(this._preferences);

  static const _modeKey = 'device_mode';
  final SharedPreferences _preferences;

  String? load() => _preferences.getString(_modeKey);

  Future<void> save(String value) async {
    final saved = await _preferences.setString(_modeKey, value);
    if (!saved) throw StateError('기기 모드를 저장하지 못했습니다.');
  }
}

class DeviceIdentityLocalDataSource {
  const DeviceIdentityLocalDataSource(this._preferences);

  static const _deviceIdKey = 'device_id';
  final SharedPreferences _preferences;

  Future<String> loadOrCreate() async {
    final stored = _preferences.getString(_deviceIdKey);
    if (stored != null && stored.isNotEmpty) return stored;
    final generated =
        'device-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final saved = await _preferences.setString(_deviceIdKey, generated);
    if (!saved) throw StateError('기기 식별자를 저장하지 못했습니다.');
    return generated;
  }
}
