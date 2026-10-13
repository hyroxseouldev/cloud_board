// Run before production edits, then repeat with STA162_PHASE=after.
// flutter test --no-pub --dart-define=STA162_PHASE=before tool/sta162_capture_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/starter_workouts.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const phase = String.fromEnvironment('STA162_PHASE', defaultValue: 'after');
const author = WorkoutAuthor(
  id: 'fixture',
  displayName: 'Fixture',
  photoUrl: null,
);

Map<String, WorkoutModule> cases() => {
  for (final design in aiSlideDesignCatalog)
    design.id: previewAiSlide(
      applyAiSlideTheme(aiSlideDesignSample, design.theme),
      design.id,
    ),
  for (final starter in StarterWorkout.values)
    for (final module in starter.create(author).modules)
      '${starter.key}-${module.id}': module,
};

Map<String, WorkoutModule> stressCases(WorkoutModule source) {
  const mixed =
      '제자리 런지 LUNGE 20회 천천히 균형 잡기\nGoblet Squat 12 + Run 250m\n어깨 가동성 Shoulder Rotation 30초\nWall Ball 20회 편안한 속도로 반복\n플랭크 PLANK 40초 호흡 유지\nRecovery Walk 200m';
  final rows24 = List.generate(24, (i) => '운동 ${i + 1} · 10회').join('\n');
  return {
    'stress-studio-24': source.copyWith(text: rows24),
    'stress-studio-mixed6': source.copyWith(text: mixed),
    for (final version in ['v1', 'v2']) ...{
      'stress-legacy-$version-short': source.copyWith(
        designTemplate: 'stationd-$version-numbered',
        designStyle: null,
        text: '가볍게 걷기\n어깨 돌리기\n맨몸 스쿼트',
      ),
      'stress-legacy-$version-mixed6': source.copyWith(
        designTemplate: 'stationd-$version-numbered',
        designStyle: null,
        text: mixed,
      ),
      'stress-legacy-$version-24': source.copyWith(
        designTemplate: 'stationd-$version-numbered',
        designStyle: null,
        text: rows24,
      ),
    },
  };
}

Map<String, Object?> metrics(WorkoutModule module) {
  final layout = measureSlideDesign(module);
  List<double> rect(Rect r) => [r.left, r.top, r.width, r.height];
  return {
    'minFontSize': layout.minFontSize,
    'warning': layout.warning,
    'columns': layout.columns,
    'textBounds': rect(layout.textBounds),
    'timerExclusion': layout.timerExclusion == null
        ? null
        : rect(layout.timerExclusion!),
    'sections': [
      for (final s in layout.sections)
        {'heading': s.heading, 'lines': s.lines, 'rect': rect(s.rect)},
    ],
    'textRuns': [
      for (final run in layout.textRuns)
        {
          'role': run.role,
          'value': run.value,
          'fontSize': run.fontSize,
          'fontWeight': run.fontWeight,
          'fontFamily': run.fontFamily,
          // v1 did not expose italic metrics. Keep this harness compilable
          // when copied into the immutable baseline checkout for reproduction.
          if (phase == 'after') 'italic': (run as dynamic).italic as bool?,
          'rect': rect(run.rect),
        },
    ],
  };
}

void main() {
  testWidgets(
    'capture all 12 general catalog designs and nine starter slides',
    (tester) async {
      expect(phase, anyOf('before', 'after'));
      final output = Directory('docs/design/sta162/$phase');
      if (phase == 'before' &&
          output.existsSync() &&
          !const bool.fromEnvironment('STA162_OVERWRITE')) {
        fail(
          'Immutable before evidence already exists. Use an isolated baseline checkout or explicitly set STA162_OVERWRITE=true.',
        );
      }
      output.createSync(recursive: true);
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
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1920, 1080);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final modules = cases();
      expect(modules.length, 21);
      final measured = <String, Object?>{};
      for (final entry in modules.entries) {
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(fontFamily: 'Pretendard'),
              home: Scaffold(
                body: WorkoutSlidePreview(
                  module: entry.value,
                  isRest: false,
                  borderRadius: 0,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: entry.key);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${output.path}/${entry.key}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        measured[entry.key] = metrics(entry.value);
      }
      for (final entry in stressCases(modules['catalog-banner']!).entries) {
        measured[entry.key] = metrics(entry.value);
      }
      final inputs = {...modules, ...stressCases(modules['catalog-banner']!)};
      const json = JsonEncoder.withIndent('  ');
      File('${output.path}/metrics.json')
          .writeAsStringSync(json.convert(measured));
      if (phase == 'after') {
        final frozen = jsonDecode(
          File('docs/design/sta162/before/modules.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        File('${output.path}/frozen-input-metrics.json').writeAsStringSync(
          json.convert({
            for (final entry in frozen.entries)
              entry.key: metrics(
                WorkoutModuleModel.fromJson(entry.value as Map<String, dynamic>)
                    .toEntity(),
              ),
          }),
        );
      }
      File('${output.path}/modules.json').writeAsStringSync(
        json.convert({
          for (final entry in inputs.entries)
            entry.key: WorkoutModuleModel.fromEntity(entry.value).toJson(),
        }),
      );
      File('${output.path}/manifest.json').writeAsStringSync(
        json.convert({
          'phase': phase,
          'viewport': [1920, 1080],
          'devicePixelRatio': 1,
          'rendererVersion': slideDesignRendererVersion,
          'gitHead': Process.runSync('git', [
            'rev-parse',
            'HEAD',
          ]).stdout.toString().trim(),
          'sources': {
            for (final path in [
              'lib/src/app/feature/workouts/data/datasources/slide_design_renderer.dart',
              'lib/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart',
              'lib/src/app/feature/workouts/domain/starter_workouts.dart',
              if (phase == 'after') ...[
                'lib/src/app/feature/workouts/domain/slide_design_typography.dart',
                'lib/src/app/feature/workouts/domain/entities/workout.dart',
              ],
            ])
              path: sha256.convert(File(path).readAsBytesSync()).toString(),
          },
          'pngCount': modules.length,
          'note': 'Production WorkoutSlidePreview and timer overlay; no live TV, network or physical-distance readability claim.',
        }),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
