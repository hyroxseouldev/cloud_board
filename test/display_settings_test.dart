import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/views/display_settings_screen.dart';
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

class _DisplayActions extends DeviceClaimController {
  _DisplayActions({this.fail = false});

  final bool fail;
  final calls = <({String deviceId, String displayState})>[];

  @override
  Future<bool> setDisplayState({
    required String deviceId,
    required String displayState,
  }) async {
    calls.add((deviceId: deviceId, displayState: displayState));
    state = fail
        ? AsyncError(StateError('디스플레이 상태 변경 실패'), StackTrace.current)
        : const AsyncData(null);
    return !fail;
  }
}

class _ControllerMode extends DeviceModeController {
  @override
  Future<DeviceMode> build() async => DeviceMode.controller;
}

DisplayDevice _device({String displayState = 'auto', String name = '입구 TV'}) =>
    DisplayDevice(
      id: 'display-1',
      name: name,
      zoneId: 'zone-1',
      zoneName: '첫 번째 운동 구역',
      online: true,
      lastSeenAtMs: 0,
      currentSessionId: null,
      acknowledgedRevision: 12,
      paired: true,
      displayState: displayState,
    );

Future<void> _pumpDisplays(
  WidgetTester tester, {
  required DisplayDevice device,
  required _DisplayActions controller,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        displayDevicesProvider.overrideWith((ref) => Stream.value([device])),
        deviceClaimControllerProvider.overrideWith(() => controller),
        deviceModeControllerProvider.overrideWith(_ControllerMode.new),
      ],
      child: MaterialApp(theme: XonTheme.light, home: DisplaySettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final displayState in ['auto', 'standby']) {
    testWidgets('$displayState display switches off using black state', (
      tester,
    ) async {
      final controller = _DisplayActions();
      await _pumpDisplays(
        tester,
        device: _device(displayState: displayState),
        controller: controller,
      );

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(controller.calls, [
        (deviceId: 'display-1', displayState: 'black'),
      ]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('black display switches on using auto state', (tester) async {
    final controller = _DisplayActions();
    await _pumpDisplays(
      tester,
      device: _device(displayState: 'black'),
      controller: controller,
    );

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(controller.calls, [(deviceId: 'display-1', displayState: 'auto')]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed display toggle shows feedback and retains device state', (
    tester,
  ) async {
    final controller = _DisplayActions(fail: true);
    await _pumpDisplays(tester, device: _device(), controller: controller);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(controller.calls, [(deviceId: 'display-1', displayState: 'black')]);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long display name fits a 390 pixel screen with usable controls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _DisplayActions();
      await _pumpDisplays(
        tester,
        device: _device(name: '아주 긴 이름이 있는 입구 디스플레이 ' * 8),
        controller: controller,
      );

      expect(find.text('등록된 디스플레이'), findsOneWidget);
      expect(find.text('추가').hitTestable(), findsOneWidget);
      expect(find.byType(Switch).hitTestable(), findsOneWidget);
      expect(find.byTooltip('디스플레이 메뉴').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
            theme: XonTheme.light,
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
