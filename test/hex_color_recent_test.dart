import 'package:cloud_board/src/app/core/services/recent_color_store.dart';
import 'package:cloud_board/src/app/core/widgets/hex_color_field.dart';
import 'package:flutter/material.dart';
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

  testWidgets('컬러 피커에서 최근 색상을 바로 선택한다', (tester) async {
    final store = RecentColorStore(SharedPreferencesAsync());
    await store.add('#112233');
    await store.add('#AABBCC');
    String? changed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HexColorField(
            label: '색상',
            initialValue: '#FFFFFF',
            recentColorStore: store,
            onChanged: (value) => changed = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('색상 컬러 피커'));
    await tester.pumpAndSettle();
    expect(find.text('최근 색상'), findsOneWidget);
    expect(find.byKey(const ValueKey('recent-color-#AABBCC')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('recent-color-#112233')));
    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();

    expect(changed, '#112233');
    expect((await store.load()).first, '#112233');
    expect(tester.takeException(), isNull);
  });
}
