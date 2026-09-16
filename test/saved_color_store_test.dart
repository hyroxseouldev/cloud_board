import 'package:cloud_board/src/app/core/services/saved_color_store.dart';
import 'package:cloud_board/src/app/core/services/recent_color_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test('saved palette persists defaults, deduplicates and keeps intentional empty list', () async {
    const store = SavedColorStore();
    expect(await store.load(), ['#000000', '#FFFFFF']);
    await store.add('#aabbcc');
    await store.add('#AABBCC');
    await store.add('invalid');
    expect(await const SavedColorStore().load(), [
      '#000000',
      '#FFFFFF',
      '#AABBCC',
    ]);
    for (final color in await store.load()) {
      await store.remove(color);
    }
    expect(await const SavedColorStore().load(), isEmpty);
  });

  test(
    'independent pickers serialize writes without affecting recent colors',
    () async {
      final recent = RecentColorStore(SharedPreferencesAsync());
      await recent.add('#123456');
      await Future.wait([
        const SavedColorStore().add('#112233'),
        const SavedColorStore().add('#445566'),
        const SavedColorStore().remove('#000000'),
      ]);
      expect(await const SavedColorStore().load(), [
        '#FFFFFF',
        '#112233',
        '#445566',
      ]);
      expect(await recent.load(), ['#123456']);
    },
  );
}
