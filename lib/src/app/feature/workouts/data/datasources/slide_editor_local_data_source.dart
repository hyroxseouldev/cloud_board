import 'package:shared_preferences/shared_preferences.dart';

class SlideEditorLocalDataSource {
  SlideEditorLocalDataSource({this._preferences});
  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get preferences =>
      _preferences ??= SharedPreferencesAsync();
  // Serialize writes, including clearing a draft after a successful save.
  Future<void> _pending = Future.value();
  Future<String?> read(String key) async {
    await _pending;
    return preferences.getString('cloudboard.slide-editor.v1.$key');
  }

  Future<void> write(String key, String? value) {
    final next = _pending.then((_) async {
      final storageKey = 'cloudboard.slide-editor.v1.$key';
      if (value == null) {
        await preferences.remove(storageKey);
      } else {
        await preferences.setString(storageKey, value);
      }
    });
    _pending = next.catchError((Object _) {});
    return next;
  }
}
