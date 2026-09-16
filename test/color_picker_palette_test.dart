import 'package:cloud_board/src/app/core/widgets/hex_color_field.dart';
import 'package:cloud_board/src/app/core/services/recent_color_store.dart';
import 'package:cloud_board/src/app/core/services/saved_color_store.dart';
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
  testWidgets(
    'compact sheet preserves color on cancel and supports keyboard, palette and HSV controls',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      var changed = '#112233';
      final store = RecentColorStore(SharedPreferencesAsync());
      await tester.pumpWidget(
        MaterialApp(
          theme: XonTheme.light,
          home: Scaffold(
            body: HexColorField(
              compact: true,
              label: '색상',
              initialValue: changed,
              recentColorStore: store,
              onChanged: (v) => changed = v,
            ),
          ),
        ),
      );
      Future<void> open() async {
        await tester.tap(find.byKey(const ValueKey('color-swatch-색상')));
        await tester.pumpAndSettle();
      }

      await open();
      final square = find.byKey(const ValueKey('color-saturation-value'));
      await tester.ensureVisible(square);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(square));
      await tester.pumpAndSettle();
      final before = tester
          .widget<TextFormField>(find.byKey(const ValueKey('picker-hex-input')))
          .controller!
          .text;
      final hue = find.byKey(const ValueKey('color-hue-slider'));
      await tester.ensureVisible(hue);
      await tester.pumpAndSettle();
      tester.widget<Slider>(hue).onChanged!(120);
      await tester.pumpAndSettle();
      final after = tester
          .widget<TextFormField>(find.byKey(const ValueKey('picker-hex-input')))
          .controller!
          .text;
      final a = HSVColor.fromColor(Color(parseHexColor(before)!));
      final b = HSVColor.fromColor(Color(parseHexColor(after)!));
      expect(b.saturation, closeTo(a.saturation, .02));
      expect(b.value, closeTo(a.value, .02));
      await tester.ensureVisible(find.byTooltip('취소'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('취소'));
      await tester.pumpAndSettle();
      expect(changed, '#112233');
      expect(await store.load(), isEmpty);
      await open();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final hex = find.byKey(const ValueKey('picker-hex-input'));
      await tester.ensureVisible(hex);
      await tester.pumpAndSettle();
      await tester.enterText(hex, '#FFFFFF');
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, '선택').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, '선택'));
      await tester.pumpAndSettle();
      expect(changed, '#FFFFFF');
      expect((await store.load()).first, '#FFFFFF');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'saved colors are shared, removable and separate from applied recent colors',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final recent = RecentColorStore(SharedPreferencesAsync());
      var changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: XonTheme.light,
          home: Scaffold(
            body: Column(
              children: [
                HexColorField(
                  compact: true,
                  label: '타이머',
                  initialValue: '#ABCDEF',
                  recentColorStore: recent,
                  onChanged: (_) => changes++,
                ),
                HexColorField(
                  label: '대기 화면',
                  initialValue: '#112233',
                  recentColorStore: recent,
                  onChanged: (_) => changes++,
                ),
              ],
            ),
          ),
        ),
      );
      Future<void> tapVisible(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byKey(const ValueKey('color-swatch-타이머')));
      await tester.pumpAndSettle();
      await tapVisible(find.byKey(const ValueKey('save-color-button')));
      expect(await const SavedColorStore().load(), [
        '#000000',
        '#FFFFFF',
        '#ABCDEF',
      ]);
      await tapVisible(find.byTooltip('취소'));
      expect(changes, 0);
      expect(await recent.load(), isEmpty);

      await tester.tap(find.byTooltip('대기 화면 컬러 피커'));
      await tester.pumpAndSettle();
      final saved = find.byKey(const ValueKey('saved-color-#ABCDEF'));
      await tapVisible(saved);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('picker-hex-input')),
            )
            .controller!
            .text,
        '#ABCDEF',
      );
      await tester.longPress(saved);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('saved-color-#ABCDEF')), findsNothing);
      expect(await const SavedColorStore().load(), ['#000000', '#FFFFFF']);
      await tester.tap(find.text('선택'));
      await tester.pumpAndSettle();
      expect(changes, 1);
      expect(await recent.load(), ['#ABCDEF']);
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(390, 844),
    const Size(834, 1194),
    const Size(844, 390),
  ]) {
    testWidgets(
      'full width sheet, saved palette and HSV preserve independent values at $size',
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
          await tapVisible(find.byKey(ValueKey('saved-color-$hex')));
          await tester.tap(find.text('선택'));
          await tester.pumpAndSettle();
          expect(changed, hex);
          expect((await store.load()).first, hex);
        }
        await open();
        final sheet = tester.getRect(find.byType(BottomSheet));
        expect(sheet.width, closeTo(size.width, 1));
        expect(find.text('기본색'), findsNothing);
        final hex = find.byKey(const ValueKey('picker-hex-input'));
        await tester.ensureVisible(hex);
        await tester.enterText(hex, '#FF0000');
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('color-saturation-value')),
        );
        await tester.pumpAndSettle();
        final square = tester.getRect(
          find.byKey(const ValueKey('color-saturation-value')),
        );
        await tester.tapAt(square.center);
        await tester.pumpAndSettle();
        final currentHex = tester.widget<TextFormField>(hex).controller!.text;
        final before = HSVColor.fromColor(Color(parseHexColor(currentHex)!));
        expect(before.saturation, closeTo(.5, .02));
        expect(before.value, closeTo(.5, .02));
        // Changing hue keeps the selected saturation/brightness intact.
        final hue = find.byKey(const ValueKey('color-hue-slider'));
        await tester.ensureVisible(hue);
        await tester.pumpAndSettle();
        tester.widget<Slider>(hue).onChanged!(90);
        await tester.pumpAndSettle();
        await tester.tap(find.text('선택'));
        await tester.pumpAndSettle();
        final after = HSVColor.fromColor(Color(parseHexColor(changed)!));
        expect(after.hue, closeTo(90, 2));
        expect(after.saturation, closeTo(before.saturation, .02));
        expect(after.value, closeTo(before.value, .02));
        final saved = await store.load();
        await open();
        await tapVisible(find.byKey(const ValueKey('saved-color-#000000')));
        await tapVisible(find.byTooltip('취소'));
        expect(find.text('색상 선택'), findsNothing);
        expect(await store.load(), saved);
        expect(changed, saved.first);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
