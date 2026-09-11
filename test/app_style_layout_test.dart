import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('resizing preserves themed controls and dialog actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: XonTheme.light,
        builder: XonTheme.responsiveBuilder,
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('설정')),
            body: FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AppAlertDialog(
                  title: const Text('워크아웃 설정 저장'),
                  content: const Text(
                    '변경한 설정을 저장합니다. 화면에 표시할 안내 문구와 사운드 설정을 확인해 주세요.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed: () {
                        saves++;
                        Navigator.pop(context);
                      },
                      child: const Text('변경사항 저장'),
                    ),
                  ],
                ),
              ),
              child: const Text('팝업 열기'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(834, 1194);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('팝업 열기'));
    await tester.pumpAndSettle();
    // An open dialog must remain usable after a compact resize and keyboard inset.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('변경사항 저장').hitTestable(), findsOneWidget);
    await tester.tap(find.text('변경사항 저장'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(find.byType(AppAlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
