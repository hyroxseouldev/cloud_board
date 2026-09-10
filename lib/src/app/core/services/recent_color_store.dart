import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/core/utils/hex_color.dart';

class RecentColorStore {
  const RecentColorStore(this._preferences);

  const RecentColorStore.local() : _preferences = null;

  static const storageKey = 'cloudboard.recent-colors.v1';
  static const maxColors = 5;

  final SharedPreferencesAsync? _preferences;
  static List<String> _memoryFallback = const [];

  SharedPreferencesAsync? _resolvePreferences() {
    if (_preferences != null) return _preferences;
    try {
      return SharedPreferencesAsync();
    } on StateError {
      return null;
    }
  }

  Future<List<String>> load() async {
    List<String> stored;
    try {
      stored =
          await _resolvePreferences()?.getStringList(storageKey) ??
          _memoryFallback;
    } on Object {
      stored = _memoryFallback;
    }
    final colors = <String>[];
    for (final value in stored) {
      if (!isHexColor(value)) continue;
      final normalized = value.toUpperCase();
      if (!colors.contains(normalized)) colors.add(normalized);
      if (colors.length == maxColors) break;
    }
    return colors;
  }

  Future<List<String>> add(String value) async {
    if (!isHexColor(value)) return load();
    final normalized = value.toUpperCase();
    final current = await load();
    final updated = [
      normalized,
      ...current.where((color) => color != normalized),
    ].take(maxColors).toList();
    try {
      final preferences = _resolvePreferences();
      if (preferences == null) {
        _memoryFallback = updated;
      } else {
        await preferences.setStringList(storageKey, updated);
      }
    } on Object {
      _memoryFallback = updated;
    }
    return updated;
  }
}
