import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/saved_slide_order_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/saved_slide_chips.dart';

import 'support/saved_slide_order_fixture.dart';

void main() {
  Future<({OrderFirestore db, List<String> added})> mount(
    WidgetTester tester, {
    int count = 4,
    double width = 700,
    double textScale = 1,
    TargetPlatform platform = TargetPlatform.windows,
  }) async {
    final ids = List.generate(count, (i) => 'slide-$i');
    final db = OrderFirestore()..seed('owner', ids, order: ids);
    final added = <String>[];
    addTearDown(db.events.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedSlideOrderRepositoryProvider.overrideWith(
            (ref) => orderRepository(db, OrderAuth()),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: MediaQuery(
                  data: MediaQueryData(
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: SavedSlideChips(
                    scope: 'owner',
                    templates: [
                      for (final id in ids)
                        WorkoutModule.empty(id)
                            .copyWith(name: 'Slide ${id.split('-').last}'),
                    ],
                    onAdd: (item) => added.add(item.id),
                    emptyMessage: 'empty',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (db: db, added: added);
  }

  Finder chip(int i) => find.byKey(ValueKey('saved-slide-chip-slide-$i'));

  testWidgets(
    'only chip scrollbars hidden; tap adds and horizontal swipe reaches last chip',
    (tester) async {
      final fixture = await mount(tester, count: 12, width: 320);
      expect(find.byType(Scrollbar), findsNothing);
      await tester.tap(chip(0));
      expect(fixture.added, ['slide-0']);
      final list = find.byKey(const ValueKey('workout-slide-templates'));
      await tester.drag(list, const Offset(-1800, 0));
      await tester.pumpAndSettle();
      await tester.tap(chip(11));
      expect(fixture.added, ['slide-0', 'slide-11']);
      expect(fixture.db.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets(
      '${kind.name} reorders without adding on release; next tap still adds',
      (tester) async {
        final fixture = await mount(tester);
        final gesture = await tester.startGesture(
          tester.getCenter(chip(0)),
          kind: kind,
        );
        if (kind == PointerDeviceKind.touch) {
          await tester.pump(
            kLongPressTimeout + const Duration(milliseconds: 100),
          );
        }
        await gesture.moveTo(tester.getCenter(chip(2)) + const Offset(30, 0));
        await tester.pump(const Duration(milliseconds: 400));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(fixture.added, isEmpty);
        expect(fixture.db.docs['users/owner']!['savedSlideOrder'], [
          'slide-1',
          'slide-2',
          'slide-0',
          'slide-3',
        ]);
        await tester.tap(chip(0));
        expect(fixture.added, ['slide-0']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'horizontal pointer scroll remains available without reordering',
    (tester) async {
      final fixture = await mount(tester, count: 12, width: 320);
      final list = find.byKey(const ValueKey('workout-slide-templates'));
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(list),
          scrollDelta: const Offset(1800, 0),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(chip(11));
      expect(fixture.added, ['slide-11']);
      expect(fixture.db.writes, isEmpty);
    },
  );

  testWidgets('edge drag autoscroll exposes offscreen chips', (tester) async {
    final fixture = await mount(tester, count: 15, width: 320);
    final list = find.byKey(const ValueKey('workout-slide-templates'));
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)).first,
    );
    final gesture = await tester.startGesture(tester.getCenter(chip(0)));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(
      Offset(tester.getRect(list).right - 2, tester.getCenter(chip(0)).dy),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(scrollable.position.pixels, greaterThan(100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(fixture.added, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'accessible menu moves previous/next and failure rolls back with retry',
    (tester) async {
      final fixture = await mount(tester);
      await tester.tap(find.byTooltip('순서 편집'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saved-slide-menu-slide-0')));
      await tester.pumpAndSettle();
      final previous = tester.widget<PopupMenuItem<int>>(
        find.widgetWithText(PopupMenuItem<int>, '이전으로 이동'),
      );
      expect(previous.enabled, false);
      fixture.db.fail = true;
      await tester.tap(find.text('다음으로 이동'));
      await tester.pumpAndSettle();
      expect(fixture.db.docs['users/owner']!['savedSlideOrder'], [
        'slide-0',
        'slide-1',
        'slide-2',
        'slide-3',
      ]);
      expect(find.text('칩 순서 저장을 확인하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
      fixture.db.fail = false;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(fixture.db.docs['users/owner']!['savedSlideOrder'], [
        'slide-1',
        'slide-0',
        'slide-2',
        'slide-3',
      ]);
      expect(fixture.added, isEmpty);
    },
  );

  for (final count in [0, 1]) {
    testWidgets('$count chip hides ordering entry', (tester) async {
      await mount(tester, count: count);
      expect(
        find.byKey(const ValueKey('saved-slide-order-edit')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.windows,
  ]) {
    testWidgets(
      '${platform.name} narrow large text has no overflow and keyboard focus remains available',
      (tester) async {
        final fixture = await mount(
          tester,
          width: 320,
          textScale: 2,
          platform: platform,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, isNotNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(fixture.added, ['slide-0']);
        expect(find.byType(Scrollbar), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
