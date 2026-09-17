import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/hex_color_field.dart';
import 'package:cloud_board/src/app/core/services/saved_color_store.dart';
import 'package:cloud_board/src/app/core/services/recent_color_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
void main() {
  for (final size in [const Size(390,844),const Size(834,1194)]) {
    testWidgets('color sheet visual $size', (tester) async {
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
      for (final color in ['#CF978A','#595F5D','#B29C83','#B77C60']) {
        await const SavedColorStore().add(color);
        await RecentColorStore(SharedPreferencesAsync()).add(color);
      }
      tester.view.physicalSize=size; tester.view.devicePixelRatio=1;
      final font=FontLoader('Pretendard')..addFont(rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'))..addFont(rootBundle.load('assets/fonts/pretendard/Pretendard-SemiBold.otf'));
      await tester.runAsync(() => font.load());
      await tester.pumpWidget(RepaintBoundary(key: const ValueKey('capture'),child: MaterialApp(theme:XonTheme.light,builder:XonTheme.responsiveBuilder, home:Scaffold(body:HexColorField(compact: true,label:'컬러', initialValue:'#CF978A',onChanged: (_) {})))));
      await tester.tap(find.byKey(const ValueKey('color-swatch-컬러')));await tester.pumpAndSettle();
      final boundary=tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('capture')));
      await tester.runAsync(() async {final image=await boundary.toImage();final bytes=await image.toByteData(format:ui.ImageByteFormat.png);await Directory('output/color-sheet').create(recursive:true);await File('output/color-sheet/${size.width.toInt()}.png').writeAsBytes(bytes!.buffer.asUint8List());});
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox());tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();
    });
  }
}
