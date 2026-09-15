import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/core/utils/hex_color.dart';

class RecentColorStore {
  const RecentColorStore(this._preferences);

  const RecentColorStore.local() : _preferences = null;

  static const storageKey = 'cloudboard.recent-colors.v1';
  static const maxColors = 10;

  final SharedPreferencesAsync? _preferences;
  static List<String> _memoryFallback = const [];
  static Future<void>? _pendingWrite;

  SharedPreferencesAsync? _resolvePreferences() {
    if (_preferences != null) return _preferences;
    try {
      return SharedPreferencesAsync();
    } on StateError {
      return null;
    }
  }

  Future<List<String>> load() async {
    await _pendingWrite;
    return _load();
  }

  Future<List<String>> _load() async {
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

  Future<List<String>> add(String value) {
    final previous = _pendingWrite;
    final result = previous == null
        ? _add(value)
        : previous.then((_) => _add(value));
    late final Future<void> pending;
    void clearPending() {
      if (identical(_pendingWrite, pending)) _pendingWrite = null;
    }

    pending = result.then<void>(
      (_) => clearPending(),
      onError: (Object _, StackTrace _) => clearPending(),
    );
    _pendingWrite = pending;
    return result;
  }

  Future<List<String>> _add(String value) async {
    if (!isHexColor(value)) return _load();
    final normalized = value.toUpperCase();
    final current = await _load();
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
