import 'package:cloud_board/src/app/core/widgets/hex_color_field.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_duration_field.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_editor_style.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('timing wheels preserve cancel, validation and atomic apply', (
    tester,
  ) async {
    final work = TextEditingController(text: '01:30');
    final rest = TextEditingController(text: '00:45');
    final sets = TextEditingController(text: '5');
    addTearDown(work.dispose);
    addTearDown(rest.dispose);
    addTearDown(sets.dispose);
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: SlideEditorStyle.theme(ThemeData()),
        home: Scaffold(
          body: SlideTimingBlocks(
            workController: work,
            restController: rest,
            setsController: sets,
            onChanged: () => changes++,
            workValidator: (_) => null,
            restValidator: (_) => null,
            setsValidator: (_) => null,
          ),
        ),
      ),
    );
    Future<void> select(String key, int index) async {
      tester
          .widget<CupertinoPicker>(find.byKey(ValueKey(key)))
          .onSelectedItemChanged!(index);
      await tester.pump();
    }

    Future<void> open() async {
      await tester.tap(find.byKey(const ValueKey('timing-summary-block')));
      await tester.pumpAndSettle();
    }

    await open();
    // Minutes, seconds and sets remain available together.
    expect(find.byType(CupertinoPicker), findsNWidgets(3));
    await select('combined-minutes-picker', 0);
    await select('combined-seconds-picker', 0);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '완료'))
          .onPressed,
      isNull,
    );
    expect(work.text, '01:30');
    expect(changes, 0);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(work.text, '01:30');
    expect(rest.text, '00:45');
    expect(sets.text, '5');
    await open();
    await select('combined-minutes-picker', 2);
    await select('combined-seconds-picker', 10);
    await select('combined-set-count-picker', 6);
    await tester.tap(find.text('휴식'));
    await tester.pumpAndSettle();
    await select('combined-minutes-picker', 0);
    await select('combined-seconds-picker', 0);
    expect(changes, 0);
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();
    expect(work.text, '02:10');
    expect(rest.text, '00:00');
    expect(sets.text, '7');
    expect(changes, 1);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets(
      'color dialog keeps apply visible at $size and cancel preserves value',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? changed;
        await tester.pumpWidget(
          MaterialApp(
            theme: SlideEditorStyle.theme(ThemeData()),
            home: Scaffold(
              body: HexColorField(
                label: '색상',
                initialValue: '#112233',
                onChanged: (v) => changed = v,
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('색상 컬러 피커'));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(FilledButton, '선택').hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('취소'));
        await tester.pumpAndSettle();
        expect(changed, isNull);
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField))
              .controller!
              .text,
          '#112233',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
