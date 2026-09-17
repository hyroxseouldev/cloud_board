import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
void main() {
  for (final size in [const Size(834,1194),const Size(390,844)]) {
    testWidgets('render editor $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
      final font = FontLoader('Pretendard')..addFont(rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'));
      await tester.runAsync(() => font.load());
      final icons = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(File('/Users/sunmkim/fvm/versions/3.47.0/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
      await tester.runAsync(() => icons.load());
      final module = WorkoutModule.empty('visual').copyWith(name: '수업', workSeconds: 300, restSeconds: 60, sets: 6, text: '오늘의 운동');
      await tester.pumpWidget(ProviderScope(child: MaterialApp(theme: XonTheme.light,builder: XonTheme.responsiveBuilder,home: RepaintBoundary(key: const ValueKey('capture'), child: SlideEditorScreen(workoutId:'visual',moduleId:module.id,guard:ExitGuard(),request:SlideEditRequest(module:module,onSave:(_) async=>false))))));
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('capture')));
        await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format:ui.ImageByteFormat.png);
        await Directory('output/slide-editor-polish').create(recursive:true);await File('output/slide-editor-polish/${size.width.toInt()}-$name.png').writeAsBytes(bytes!.buffer.asUint8List());});
      }
      for (final label in ['타이머','배경','소리','설정']) {
        await tester.tap(find.descendant(of:find.byKey(const ValueKey('slide-editor-tabs')),matching:find.text(label)));
        await tester.pumpAndSettle();
        await capture(label);
        expect(tester.takeException(),isNull);
      }
      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio();
    });
  }
}
