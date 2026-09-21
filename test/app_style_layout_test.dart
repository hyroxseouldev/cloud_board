import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/theme/app_style.dart';
import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:cloud_board/src/app/core/widgets/web_page_frame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('web page bounds controls and preserves state across resizing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1920, 1080);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fullWidth = ValueNotifier(false);
    addTearDown(fullWidth.dispose);
    const pageKey = ValueKey('management-page');
    Size? contentSize;
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: fullWidth,
          builder: (context, expanded, _) => WebPageFrame(
            fullWidth: expanded,
            child: Builder(
              builder: (context) {
                contentSize = MediaQuery.sizeOf(context);
                return Scaffold(
                  key: pageKey,
                  appBar: AppBar(title: const Text('워크아웃')),
                  body: const TextField(),
                  floatingActionButton: FloatingActionButton(
                    onPressed: () {},
                    child: const Icon(Icons.add),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final page = find.byKey(pageKey);
    final width = kIsWeb ? AppStyle.webPageMaxWidth : 1920.0;
    expect(tester.getSize(page).width, width);
    expect(tester.getTopLeft(page).dx, (1920 - width) / 2);
    expect(contentSize!.width, width);
    expect(
      tester.getRect(find.byType(FloatingActionButton)).right,
      lessThanOrEqualTo(tester.getRect(page).right),
    );
    await tester.enterText(find.byType(TextField), '편집 중인 내용');
    for (final size in [const Size(834, 1194), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.getSize(page).width, size.width);
      expect(contentSize!.width, size.width);
      expect(find.text('편집 중인 내용'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    tester.view.physicalSize = const Size(1920, 1080);
    fullWidth.value = true;
    await tester.pumpAndSettle();
    expect(tester.getSize(page).width, 1920);
    fullWidth.value = false;
    await tester.pumpAndSettle();
    expect(tester.getSize(page).width, width);
    expect(find.text('편집 중인 내용'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    final cancel = find.widgetWithText(TextButton, '취소');
    final confirm = find.widgetWithText(FilledButton, '변경사항 저장');
    expect(
      tester.getSize(cancel).width,
      closeTo(tester.getSize(confirm).width, .1),
    );
    expect(
      tester.getTopLeft(cancel).dy,
      closeTo(tester.getTopLeft(confirm).dy, .1),
    );
    // An open dialog must remain usable after a compact resize and keyboard inset.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('변경사항 저장').hitTestable(), findsOneWidget);
    expect(cancel.hitTestable(), findsOneWidget);
    expect(
      tester.getSize(cancel).width,
      closeTo(tester.getSize(confirm).width, .1),
    );
    expect(
      tester.getSize(cancel).height,
      closeTo(tester.getSize(confirm).height, .1),
    );
    await tester.tap(find.text('변경사항 저장'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(find.byType(AppAlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
