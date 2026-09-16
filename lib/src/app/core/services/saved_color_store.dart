import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/core/utils/hex_color.dart';

/// User-managed colors, shared by all color pickers on this device.
class SavedColorStore {
  const SavedColorStore();

  static const storageKey = 'cloudboard.saved-colors.v1';
  static const initialColors = ['#000000', '#FFFFFF'];
  static Future<void>? _pendingWrite;

  Future<List<String>> load() async {
    await _pendingWrite;
    return _load();
  }

  Future<List<String>> _load() async {
    final stored = await SharedPreferencesAsync().getStringList(storageKey);
    return (stored ?? initialColors)
        .where(isHexColor)
        .map((value) => value.toUpperCase())
        .toSet()
        .toList();
  }

  Future<List<String>> add(String value) => _update(value, remove: false);
  Future<List<String>> remove(String value) => _update(value, remove: true);

  Future<List<String>> _update(String value, {required bool remove}) {
    final previous = _pendingWrite;
    Future<List<String>> write() async {
      final current = await _load();
      if (!isHexColor(value)) return current;
      final normalized = value.toUpperCase();
      final updated = remove
          ? current.where((color) => color != normalized).toList()
          : [...current, if (!current.contains(normalized)) normalized];
      await SharedPreferencesAsync().setStringList(storageKey, updated);
      return updated;
    }

    final result = previous == null ? write() : previous.then((_) => write());
    late final Future<void> pending;
    void clear() {
      if (identical(_pendingWrite, pending)) _pendingWrite = null;
    }

    pending = result.then<void>(
      (_) => clear(),
      onError: (Object _, StackTrace _) => clear(),
    );
    _pendingWrite = pending;
    return result;
  }
}
