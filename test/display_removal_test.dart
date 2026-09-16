import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/views/display_settings_screen.dart';

DisplayDevice device(String id) => DisplayDevice(
  id: id,
  name: 'TV $id',
  zoneId: 'main',
  zoneName: '매장',
  online: true,
  lastSeenAtMs: 0,
  currentSessionId: null,
  acknowledgedRevision: 0,
  paired: true,
);

class _Mode extends DeviceModeController {
  @override
  Future<DeviceMode> build() async => DeviceMode.controller;
}

class _Remove extends DeviceClaimController {
  final result = Completer<bool>();
  final calls = <String>[];
  @override
  Future<bool> unpair(String id) async {
    calls.add(id);
    return result.future;
  }
}

void main() {
  for (final reduceMotion in [false, true]) {
    for (final (success, earlyStream) in [
      (false, false),
      (true, false),
      (true, true),
    ]) {
      testWidgets(
        'remove identity survives early stream update; success=$success reducedMotion=$reduceMotion earlyStream=$earlyStream',
        (tester) async {
          final devices = StreamController<List<DisplayDevice>>();
          final action = _Remove();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                displayDevicesProvider.overrideWith((ref) => devices.stream),
                deviceClaimControllerProvider.overrideWith(() => action),
                deviceModeControllerProvider.overrideWith(_Mode.new),
              ],
              child: MaterialApp(
                theme: XonTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: reduceMotion),
                  child: child!,
                ),
                home: const DisplaySettingsScreen(),
              ),
            ),
          );
          devices.add([device('a'), device('b'), device('c')]);
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('디스플레이 메뉴').at(1));
          await tester.pumpAndSettle();
          await tester.tap(find.text('연결 해제'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(action.calls, ['b']);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          // Database event precedes completion; the pending tile must remain.
          if (earlyStream) devices.add([device('c'), device('a')]);
          await tester.pump();
          await tester.pump();
          expect(find.text('TV b'), findsOneWidget);
          expect(
            tester
                .widgetList<PopupMenuButton<String>>(
                  find.byType(PopupMenuButton<String>),
                )
                .every((button) => !button.enabled),
            isTrue,
          );
          action.result.complete(success);
          await tester.pump();
          await tester.pump();
          if (success && !reduceMotion) {
            expect(find.text('TV b'), findsOneWidget);
            final before = tester.getRect(find.text('TV a'));
            await tester.pump(const Duration(milliseconds: 120));
            expect(
              tester.getRect(find.text('TV a')).top,
              lessThanOrEqualTo(before.top),
            );
          }
          await tester.pumpAndSettle();
          expect(find.text('TV b'), success ? findsNothing : findsOneWidget);
          expect(find.text('TV a'), findsOneWidget);
          expect(find.text('TV c'), findsOneWidget);
          expect(
            find.text(
              success
                  ? 'TV b 디스플레이 연결을 해제했습니다.'
                  : '연결을 해제하지 못했습니다. 다시 시도해 주세요.',
            ),
            findsOneWidget,
          );
          expect(action.calls, ['b']);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          unawaited(devices.close());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
