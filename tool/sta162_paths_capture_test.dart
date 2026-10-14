// Supplementary evidence from production selector/editor/preview/export paths.
// flutter test --no-pub tool/sta162_paths_capture_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slide_design_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slide_design_studio.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/original_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'sta162_capture_test.dart' show cases, metrics, stressCases;

class _Drafts extends SlideEditorLocalDataSource {
  final drafts = <String, Map<String, dynamic>>{};
  final styles = <String, String>{};
  @override
  Future<Map<String, dynamic>?> readDraft(String key) async => drafts[key];
  @override
  Future<void> writeDraft(String key, Map<String, dynamic> value) async {
    drafts[key] = value;
  }

  @override
  Future<void> clearDraft(String key) async {
    drafts.remove(key);
  }

  @override
  Future<String?> read(String key) async => styles[key];
  @override
  Future<void> write(String key, String? value) async {
    value == null ? styles.remove(key) : styles[key] = value;
  }
}

void main() {
  testWidgets(
    'capture selector, phone/tablet editor, 4K and PNG playback fallback',
    (tester) async {
      final directory = Directory('docs/design/sta162/paths')
        ..createSync(recursive: true);
      final fonts = FontLoader('Pretendard');
      for (final weight in [
        'Regular',
        'Medium',
        'SemiBold',
        'Bold',
        'ExtraBold',
        'Black',
      ]) {
        fonts.addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-$weight.otf'),
        );
      }
      await fonts.load();
      for (final font in [
        ('NotoSerifKR', 'assets/fonts/noto_serif_kr/NotoSerifKR-Variable.ttf'),
        (
          'RacingSansOne',
          'assets/fonts/racing_sans_one/RacingSansOne-Regular.ttf',
        ),
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      Future<void> mount(Widget page, Size size, {double dpr = 1}) async {
        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = size * dpr;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: ProviderScope(
              key: UniqueKey(),
              overrides: [
                aiSlideDesignOwnerIdProvider.overrideWithValue(null),
                aiSlideDesignStoreIdProvider.overrideWithValue(null),
                aiSlidesOwnerIdProvider.overrideWithValue(null),
                slideEditorRepositoryProvider.overrideWithValue(
                  LocalSlideEditorRepository(_Drafts()),
                ),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: XonTheme.light,
                builder: XonTheme.responsiveBuilder,
                home: page,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      Future<void> capture(String name, {double dpr = 1}) async {
        final images = tester.elementList(find.byType(Image)).toList();
        await tester.runAsync(
          () => Future.wait(
            images.map((e) => precacheImage((e.widget as Image).image, e)),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: name);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: dpr);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${directory.path}/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      final source = cases();
      final catalog = source['catalog-banner']!;
      final starter = source['interval-starter_warmup']!;
      await mount(
        Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AiSlideDesignStudio(
                section: AiSlideDesignStudioSection.templates,
                draft: aiSlideDesignSample,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
        const Size(834, 1194),
        dpr: 2,
      );
      final card = find.byKey(const ValueKey('ai-design-catalog-banner'));
      await tester.ensureVisible(card);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(card);
      await tester.pump(const Duration(milliseconds: 300));
      // Original artwork uses ui.Image in a CustomPainter, not Image widgets.
      // Await the same cache key as every mounted preview, then release the
      // fixture's clone; the production widget retains its own image handle.
      final originals = tester.elementList(find.byType(WorkoutSlidePreview));
      await tester.runAsync(() async {
        for (final element in originals) {
          final preview = element.widget as WorkoutSlidePreview;
          final original = preview.module.designStyle?.originalTemplate;
          if (original == null) continue;
          final width = tester.getSize(find.byWidget(preview)).width;
          final pixels = width * MediaQuery.devicePixelRatioOf(element);
          final decoded = await loadOriginalSlideImage(
            original,
            targetWidth: (pixels / 64).ceil() * 64,
          );
          decoded.dispose();
        }
      });
      await tester.pump();
      expect(find.byIcon(Icons.image_outlined), findsNothing);
      await Scrollable.ensureVisible(
        tester.element(find.text('일반 템플릿')),
        alignment: 0,
      );
      await tester.pump();
      await capture('catalog-selection-tablet', dpr: 2);

      final saved = <String, Object?>{};
      for (final entry in {
        'catalog-banner': catalog,
        'interval-warmup': starter,
      }.entries) {
        for (final viewport in {
          'phone': const Size(390, 844),
          'tablet': const Size(834, 1194),
        }.entries) {
          await mount(
            SlideEditorScreen(
              workoutId: 'sta162-${entry.key}',
              moduleId: entry.value.id,
              guard: ExitGuard(),
              request: SlideEditRequest(
                module: entry.value,
                needsInitialSave: true,
                onSave: (_) async => true,
              ),
            ),
            viewport.value,
            dpr: 2,
          );
          await capture('${entry.key}-editor-${viewport.key}', dpr: 2);
        }
        final prepared = (await tester.runAsync(
          () => prepareSlideDesign(entry.value),
        ))!;
        expect(prepared.designFingerprint, slideDesignFingerprint(entry.value));
        final png = base64Decode(prepared.imageSource.split(',').last);
        File('${directory.path}/${entry.key}-saved-artwork.png')
            .writeAsBytesSync(png);
        final fallback = prepared.copyWith(
          designTemplate: null,
          designStyle: null,
        );
        for (final viewport in {
          '1080p': const Size(1920, 1080),
          '4k': const Size(3840, 2160),
        }.entries) {
          await mount(
            Scaffold(
              body: WorkoutSlidePreview(
                module: prepared,
                isRest: false,
                borderRadius: 0,
              ),
            ),
            viewport.value,
          );
          await capture('${entry.key}-canvas-${viewport.key}');
        }
        await mount(
          Scaffold(
            body: WorkoutSlidePreview(
              module: fallback,
              isRest: false,
              borderRadius: 0,
            ),
          ),
          const Size(1920, 1080),
        );
        await capture('${entry.key}-saved-png-fallback');
        saved[entry.key] = {
          'fingerprint': prepared.designFingerprint,
          'pngBytes': png.length,
          'metrics': metrics(entry.value),
          'sameTimerAndSets':
              prepared.appearance.timerX == entry.value.appearance.timerX &&
              prepared.appearance.timerY == entry.value.appearance.timerY &&
              prepared.appearance.timerSize ==
                  entry.value.appearance.timerSize &&
              prepared.showSets == entry.value.showSets,
        };
      }
      final stress = stressCases(catalog)['stress-studio-24']!;
      for (final entry in {
        '24-rows-single': stress,
        '24-rows-columns': stress.copyWith(designLayout: 'columns'),
      }.entries) {
        await mount(
          Scaffold(
            body: WorkoutSlidePreview(
              module: entry.value,
              isRest: false,
              borderRadius: 0,
            ),
          ),
          const Size(1920, 1080),
        );
        await capture(entry.key);
        saved[entry.key] = metrics(entry.value);
      }
      final frozen = jsonDecode(
        File('docs/design/sta162/before/modules.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final existing = WorkoutModuleModel.fromJson(
        frozen['interval-starter_warmup'] as Map<String, dynamic>,
      ).toEntity();
      await mount(
        Scaffold(
          body: WorkoutSlidePreview(
            module: existing,
            isRest: false,
            borderRadius: 0,
          ),
        ),
        const Size(1920, 1080),
      );
      await capture('existing-user-warmup-preserved-style');
      saved['existing-user-warmup'] = {
        'weight': existing.designFontWeight,
        'italic': existing.designItalic,
        'subtitle': existing.designSubtitle,
        'metrics': metrics(existing),
      };
      File('${directory.path}/evidence.json')
          .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(saved));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
