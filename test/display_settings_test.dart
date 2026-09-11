import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/add_display_dialog.dart';

class _Claim extends DeviceClaimController {
  final calls = <({String code, String name, String zone})>[];
  @override
  Future<bool> claim({
    required String code,
    required String name,
    required String zoneName,
  }) async {
    calls.add((code: code, name: name, zone: zoneName));
    if (calls.length == 1) {
      state = AsyncError(StateError('코드가 만료되었습니다'), StackTrace.current);
      return false;
    }
    state = const AsyncData(null);
    return true;
  }
}

void main() {
  testWidgets(
    'add display validates code, preserves failed input and closes after retry',
    (tester) async {
      final controller = _Claim();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceClaimControllerProvider.overrideWith(() => controller),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => const AddDisplayDialog(),
                  ),
                  child: const Text('추가'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('추가'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, '기기 이름').hitTestable(),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextField, '구역 이름').hitTestable(),
        findsOneWidget,
      );
      await tester.enterText(find.widgetWithText(TextField, '기기 이름'), '입구 TV');
      await tester.enterText(find.widgetWithText(TextField, '구역 이름'), '입구 구역');
      await tester.tap(find.text('기기 이름 · 구역'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('기기 이름 · 구역'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '기기 이름'))
            .controller!
            .text,
        '입구 TV',
      );
      await tester.tap(find.text('연결하기'));
      await tester.pumpAndSettle();
      expect(find.text('6자리 코드를 입력해 주세요.'), findsOneWidget);
      expect(controller.calls, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextField, '디스플레이의 6자리 코드'),
        '123456',
      );
      await tester.tap(find.text('연결하기'));
      await tester.pumpAndSettle();
      expect(find.byType(AddDisplayDialog), findsOneWidget);
      expect(find.textContaining('코드가 만료되었습니다'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '디스플레이의 6자리 코드'))
            .controller!
            .text,
        '123456',
      );
      await tester.tap(find.text('연결하기'));
      await tester.pumpAndSettle();
      expect(find.byType(AddDisplayDialog), findsNothing);
      expect(controller.calls.length, 2);
      expect(controller.calls.last, (
        code: '123456',
        name: '입구 TV',
        zone: '입구 구역',
      ));
      expect(tester.takeException(), isNull);
    },
  );
}
