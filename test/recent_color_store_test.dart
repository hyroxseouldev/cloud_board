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

  test('최근 색상은 최대 10개를 최신순으로 저장하고 다시 선택하면 맨 앞으로 이동한다', () async {
    final preferences = SharedPreferencesAsync();
    final store = RecentColorStore(preferences);
    for (var i = 1; i <= 11; i++) {
      await store.add('#${i.toRadixString(16).padLeft(6, '0')}');
    }
    await store.add('#000005');
    final restored = await RecentColorStore(preferences).load();
    expect(restored, [
      '#000005',
      '#00000B',
      '#00000A',
      '#000009',
      '#000008',
      '#000007',
      '#000006',
      '#000004',
      '#000003',
      '#000002',
    ]);
  });

  test('서로 다른 입력창에서 연속 저장해도 최근 색상이 유실되지 않는다', () async {
    final preferences = SharedPreferencesAsync();
    await Future.wait([
      for (var i = 1; i <= 10; i++)
        RecentColorStore(preferences)
            .add('#${i.toRadixString(16).padLeft(6, '0')}'),
    ]);
    final colors = await RecentColorStore(preferences).load();
    expect(colors.length, 10);
    expect(colors.first, '#00000A');
    expect(colors.last, '#000001');
  });

  test('소문자는 대문자로 정규화하고 잘못된 색상은 무시한다', () async {
    final store = RecentColorStore(SharedPreferencesAsync());

    await store.add('#aabbcc');
    await store.add('#xyz');

    expect(await store.load(), ['#AABBCC']);
  });
}
