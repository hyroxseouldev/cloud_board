import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateNewsDataSource {
  Future<Map<String, dynamic>?> load() async {
    final document = FirebaseFirestore.instance.doc('appContent/updateNews');
    try {
      return (await document
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 6)))
          .data();
    } catch (_) {
      final cached = await document.get(const GetOptions(source: Source.cache));
      if (!cached.exists) rethrow;
      return cached.data();
    }
  }

  String _key(String uid) => 'update_news_read_v1_$uid';
  Future<Set<String>> readIds(String uid) async =>
      (await SharedPreferences.getInstance())
          .getStringList(_key(uid))
          ?.toSet() ??
      {};
  Future<void> saveReadIds(String uid, Set<String> ids) async {
    final saved = await (await SharedPreferences.getInstance()).setStringList(
      _key(uid),
      ids.toList(),
    );
    if (!saved) throw StateError('읽은 상태를 저장하지 못했습니다.');
  }
}
