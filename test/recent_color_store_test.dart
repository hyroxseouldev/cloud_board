import 'package:cloud_board/src/app/core/services/recent_color_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('최근 색상은 중복 없이 최대 5개를 최신순으로 저장한다', () async {
    final store = RecentColorStore(SharedPreferencesAsync());

    for (final color in [
      '#111111',
      '#222222',
      '#333333',
      '#444444',
      '#555555',
      '#666666',
    ]) {
      await store.add(color);
    }
    await store.add('#333333');

    expect(await store.load(), [
      '#333333',
      '#666666',
      '#555555',
      '#444444',
      '#222222',
    ]);
  });

  test('소문자는 대문자로 정규화하고 잘못된 색상은 무시한다', () async {
    final store = RecentColorStore(SharedPreferencesAsync());

    await store.add('#aabbcc');
    await store.add('#xyz');

    expect(await store.load(), ['#AABBCC']);
  });
}
