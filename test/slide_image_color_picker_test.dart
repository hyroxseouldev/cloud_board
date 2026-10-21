import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:cloud_board/src/app/core/widgets/hex_color_field.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/image_color_sampling.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_image_color_picker.dart';

String source({int red = 246, int green = 90, int blue = 19}) {
  final image = img.Image(width: 4, height: 2, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(red, green, blue, 255));
  image.setPixelRgba(1, 0, 54, 81, 209, 255);
  image.setPixelRgba(3, 1, 0, 0, 0, 0);
  return 'data:image/png;base64,${base64Encode(img.encodePng(image))}';
}

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> sample(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('color-sample-image')));
  await tester.pump();
  await waitForImage(tester);
  final viewport = tester.getRect(
    find.byKey(const ValueKey('image-color-viewport')),
  );
  final image = containedImageRect(
    const Size(4, 2),
    viewport.size,
  ).shift(viewport.topLeft);
  await tester.tapAt(
    Offset(image.left + image.width * .125, image.top + image.height * .25),
  );
  await tester.pumpAndSettle();
  expect(find.text('#F65A13'), findsOneWidget);
}

Future<void> waitForImage(WidgetTester tester) async {
  for (
    var i = 0;
    i < 50 &&
        find.byKey(const ValueKey('image-color-viewport')).evaluate().isEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(
    find.byKey(const ValueKey('image-color-viewport')),
    findsOneWidget,
    reason: tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .join(' | '),
  );
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  testWidgets(
    'sampler rejects letterbox/transparency, maps zoom/pan, and clears replaced image',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: SlideImageColorPicker(source: source())),
      );
      await waitForImage(tester);
      final viewportFinder = find.byKey(const ValueKey('image-color-viewport'));
      Rect viewport() => tester.getRect(viewportFinder);
      Rect imageRect() => containedImageRect(const Size(4, 2), viewport().size);
      Future<void> select(Offset point) async {
        await tester.tapAt(viewport().topLeft + point);
        await tester.pumpAndSettle();
      }

      await select(Offset(20, 10));
      expect(find.textContaining('바깥 여백'), findsOneWidget);
      var rect = imageRect();
      await select(
        Offset(rect.left + rect.width * .875, rect.top + rect.height * .75),
      );
      expect(find.textContaining('완전히 투명한'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('image-color-accept')),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, find.byTooltip('이미지 확대'));
      final transform = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      expect(transform.value.getMaxScaleOnAxis(), 1.5);
      final beforePan = transform.value.clone();
      await tester.dragFrom(viewport().center, const Offset(25, 20));
      await tester.pumpAndSettle();
      expect(transform.value, isNot(beforePan));
      rect = imageRect();
      // Pixel (1,0) is blue; transform its center into the gesture viewport.
      final blue = MatrixUtils.transformPoint(
        transform.value,
        Offset(rect.left + rect.width * .375, rect.top + rect.height * .25),
      );
      await select(blue);
      expect(find.text('#3651D1'), findsOneWidget);
      final oldImage = tester.widget<RawImage>(find.byType(RawImage)).image!;
      await tester.pumpWidget(
        MaterialApp(
          home: SlideImageColorPicker(
            source: source(red: 10, green: 20, blue: 30),
          ),
        ),
      );
      await waitForImage(tester);
      expect(oldImage.debugDisposed, isTrue);
      expect(find.byKey(const ValueKey('image-picked-color')), findsNothing);
      expect(transform.value, Matrix4.identity());
      rect = imageRect();
      await select(
        Offset(rect.left + rect.width * .125, rect.top + rect.height * .25),
      );
      expect(find.text('#0A141E'), findsOneWidget);
      final newImage = tester.widget<RawImage>(find.byType(RawImage)).image!;
      await tester.pumpWidget(const SizedBox());
      expect(newImage.debugDisposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'nested sampler cancel and outer cancel never apply staged color or pair',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HexColorField(
              compact: true,
              label: '운동 게이지',
              initialValue: '#112233',
              onChanged: (_) => changes++,
              onPickerApplied: (_, _) => changes++,
              pairedColorLabel: '같은 구간의 시간 텍스트에도 함께 적용',
              onSampleImage: (context) =>
                  showSlideImageColorPicker(context, source()),
            ),
          ),
        ),
      );
      await tap(tester, find.byKey(const ValueKey('color-swatch-운동 게이지')));
      await sample(tester);
      await tap(tester, find.byTooltip('색상 추출 취소'));
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('picker-hex-input')),
            )
            .controller!
            .text,
        '#112233',
      );
      await sample(tester);
      await tap(tester, find.byKey(const ValueKey('image-color-accept')));
      expect(changes, 0);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('picker-hex-input')),
            )
            .controller!
            .text,
        '#F65A13',
      );
      await tap(tester, find.byKey(const ValueKey('color-apply-pair')));
      await tap(tester, find.byTooltip('취소'));
      expect(changes, 0);
      await tap(tester, find.byKey(const ValueKey('color-swatch-운동 게이지')));
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('color-apply-pair')),
            )
            .value,
        false,
      );
      await tap(tester, find.byTooltip('취소'));
      expect(tester.takeException(), isNull);
    },
  );

  for (final missing in ['', 'not-an-image']) {
    testWidgets(
      'unreadable source "$missing" leaves the manual picker available',
      (tester) async {
        String? changed;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HexColorField(
                label: '시간',
                initialValue: '#FFFFFF',
                onChanged: (v) => changed = v,
                onSampleImage: (context) =>
                    showSlideImageColorPicker(context, missing),
              ),
            ),
          ),
        );
        await tap(tester, find.byTooltip('시간 컬러 피커'));
        await tap(tester, find.byKey(const ValueKey('color-sample-image')));
        expect(find.textContaining('수동으로'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('image-color-accept')),
              )
              .onPressed,
          isNull,
        );
        await tap(tester, find.byTooltip('색상 추출 취소'));
        final field = find.byKey(const ValueKey('picker-hex-input'));
        await tester.ensureVisible(field);
        await tester.enterText(field, '#123456');
        await tap(tester, find.text('선택'));
        expect(changed, '#123456');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final pair in [false, true]) {
    testWidgets(
      'editor applies ${pair ? "paired" : "individual"} sampled color once to latest module',
      (tester) async {
        tester.view.physicalSize = const Size(834, 1194);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final original = WorkoutModule.empty('slide').copyWith(
          name: '수업',
          imageSource: source(),
          workGaugeColor: '#112233',
          workTextColor: '#445566',
          restGaugeColor: '#778899',
          restTextColor: '#AABBCC',
        );
        final provider = slideEditorControllerProvider('w', original, 'local');
        final container = ProviderContainer(
          overrides: [
            slideEditorRepositoryProvider.overrideWithValue(
              LocalSlideEditorRepository(SlideEditorLocalDataSource()),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: SlideEditorScreen(
                workoutId: 'w',
                moduleId: 'slide',
                guard: ExitGuard(),
                request: SlideEditRequest(
                  module: original,
                  onSave: (_) async =>
                      throw StateError('No save/API calls in this test'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.byKey(const ValueKey('color-swatch-운동 게이지'));
        await tester.scrollUntilVisible(
          field,
          250,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('slide-editor-settings')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tap(tester, field);
        await sample(tester);
        await tap(tester, find.byKey(const ValueKey('image-color-accept')));
        expect(container.read(provider).module, original);
        if (pair) {
          await tap(tester, find.byKey(const ValueKey('color-apply-pair')));
        }
        // An unrelated edit made while the modal is open must survive final apply.
        final latest = original.copyWith(
          text: 'new text',
          name: 'latest title',
          appearance: original.appearance.copyWith(timerY: .7),
        );
        container.read(provider.notifier).update(latest);
        var updates = 0;
        final subscription = container.listen(provider, (before, after) {
          if (before?.module != after.module) updates++;
        });
        await tap(tester, find.text('선택'));
        expect(updates, 1);
        expect(
          container.read(provider).module,
          latest.copyWith(
            workGaugeColor: '#F65A13',
            workTextColor: pair ? '#F65A13' : latest.workTextColor,
          ),
        );
        subscription.close();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
