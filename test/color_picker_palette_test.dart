import 'package:cloud_board/src/app/core/widgets/hex_color_field.dart';
import 'package:cloud_board/src/app/core/services/recent_color_store.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/utils/hex_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  for (final size in [
    const Size(390, 844),
    const Size(834, 1194),
    const Size(844, 390),
  ]) {
    testWidgets(
      'basic palette, hue ring and SV square preserve independent values at $size',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final store = RecentColorStore(SharedPreferencesAsync());
        var changed = '#112233';
        await tester.pumpWidget(
          MaterialApp(
            theme: XonTheme.light,
            builder: XonTheme.responsiveBuilder,
            home: Scaffold(
              body: HexColorField(
                label: '색상',
                initialValue: changed,
                recentColorStore: store,
                onChanged: (value) => changed = value,
              ),
            ),
          ),
        );
        Future<void> open() async {
          await tester.tap(find.byTooltip('색상 컬러 피커'));
          await tester.pumpAndSettle();
        }

        Future<void> tapVisible(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        for (final hex in ['#000000', '#FFFFFF']) {
          await open();
          await tapVisible(find.byKey(ValueKey('basic-color-$hex')));
          await tester.tap(find.text('선택'));
          await tester.pumpAndSettle();
          expect(changed, hex);
          expect((await store.load()).first, hex);
        }
        await open();
        await tapVisible(find.byKey(const ValueKey('basic-color-#FF0000')));
        await tester.ensureVisible(
          find.byKey(const ValueKey('color-saturation-value')),
        );
        await tester.pumpAndSettle();
        final square = tester.getRect(
          find.byKey(const ValueKey('color-saturation-value')),
        );
        await tester.tapAt(square.center);
        await tester.pumpAndSettle();
        final currentHex = tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data ?? '')
            .firstWhere((s) => isHexColor(s));
        final before = HSVColor.fromColor(Color(parseHexColor(currentHex)!));
        expect(before.saturation, closeTo(.5, .02));
        expect(before.value, closeTo(.5, .02));
        // Changing hue keeps the selected saturation/brightness intact.
        await tester.ensureVisible(find.byKey(const ValueKey('color-wheel')));
        await tester.pumpAndSettle();
        final ring = tester.getRect(find.byKey(const ValueKey('color-wheel')));
        await tester.tapAt(ring.bottomCenter - const Offset(0, 12));
        await tester.pumpAndSettle();
        await tester.tap(find.text('선택'));
        await tester.pumpAndSettle();
        final after = HSVColor.fromColor(Color(parseHexColor(changed)!));
        expect(after.hue, closeTo(90, 2));
        expect(after.saturation, closeTo(before.saturation, .02));
        expect(after.value, closeTo(before.value, .02));
        final saved = await store.load();
        await open();
        await tapVisible(find.byKey(const ValueKey('basic-color-#000000')));
        await tapVisible(find.byTooltip('취소'));
        expect(find.text('색상 선택'), findsNothing);
        expect(await store.load(), saved);
        expect(changed, saved.first);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
