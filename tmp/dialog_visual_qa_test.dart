import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
void main() {
  for (final size in [const Size(390,844),const Size(834,1194)]) {
    testWidgets('dialog visual $size', (tester) async {
      tester.view.physicalSize=size; tester.view.devicePixelRatio=1;
      final font=FontLoader('Pretendard')..addFont(rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'))..addFont(rootBundle.load('assets/fonts/pretendard/Pretendard-SemiBold.otf'));
      await tester.runAsync(() => font.load());
      await tester.pumpWidget(RepaintBoundary(key: const ValueKey('capture'),child: MaterialApp(theme:XonTheme.light,builder:XonTheme.responsiveBuilder, home:Builder(builder:(context)=>Scaffold(body:Center(child:TextButton(onPressed:()=>showDialog<void>(context:context,builder:(context)=>AppAlertDialog(title:const Text('저장하지 않고 나갈까요?'),content:const Text('저장하지 않은 변경사항이 사라집니다.'),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('계속 편집')),FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('저장 안 하고 나가기'))])),child:const Text('open'))))))));
      await tester.tap(find.text('open'));await tester.pumpAndSettle();
      final boundary=tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('capture')));
      await tester.runAsync(() async {final image=await boundary.toImage();final bytes=await image.toByteData(format:ui.ImageByteFormat.png);await Directory('output/dialog-style').create(recursive:true);await File('output/dialog-style/${size.width.toInt()}.png').writeAsBytes(bytes!.buffer.asUint8List());});
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox());tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();
    });
  }
}
