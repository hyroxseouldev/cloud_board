import 'dart:async';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/device_mode_repository.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/device_mode_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _Modes implements DeviceModeRepository {
  DeviceMode mode = DeviceMode.display;
  Completer<void>? pending;
  bool fail = false;

  @override
  Future<DeviceMode> load() async => mode;

  @override
  Future<void> save(DeviceMode value) async {
    await pending?.future;
    if (fail) throw StateError('save failed');
    mode = value;
  }
}

void main() {
  testWidgets(
    'mode toggle preserves selection while saving and supports retry',
    (tester) async {
      final repository = _Modes();
      final changes = <DeviceMode>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            androidTvProvider.overrideWith((ref) async => false),
            deviceModeRepositoryProvider.overrideWith(
              (ref) async => repository,
            ),
          ],
          child: MaterialApp(
            theme: XonTheme.light,
            builder: XonTheme.responsiveBuilder,
            home: Scaffold(body: DeviceModeToggle(onChanged: changes.add)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      SegmentedButton<DeviceMode> toggle() =>
          tester.widget(find.byType(SegmentedButton<DeviceMode>));
      expect(toggle().selected, {DeviceMode.display});
      repository.pending = Completer<void>();
      repository.fail = true;
      await tester.tap(find.text('Control'));
      await tester.pump();
      expect(toggle().selected, {DeviceMode.display});
      expect(toggle().onSelectionChanged, isNull);
      repository.pending!.complete();
      await tester.pumpAndSettle();
      expect(toggle().selected, {DeviceMode.display});
      expect(changes, isEmpty);
      expect(find.text('기기 모드를 바꾸지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);

      repository.fail = false;
      await tester.tap(find.text('Control'));
      await tester.pumpAndSettle();
      expect(toggle().selected, {DeviceMode.controller});
      expect(repository.mode, DeviceMode.controller);
      expect(changes, [DeviceMode.controller]);
      await tester.tap(find.text('Display'));
      await tester.pumpAndSettle();
      expect(toggle().selected, {DeviceMode.display});
      expect(repository.mode, DeviceMode.display);
      expect(changes, [DeviceMode.controller, DeviceMode.display]);
      expect(tester.takeException(), isNull);
    },
  );
}
