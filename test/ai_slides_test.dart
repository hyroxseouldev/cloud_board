import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:image/image.dart' as img;

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_slides_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';

const draft = AiSlideDraft(
  title: 'WARM UP',
  layout: 'numbered',
  lines: ['Squat 10 reps', '런지 12회', 'Jumping Jack 20 reps'],
  workSeconds: 300,
  restSeconds: 0,
  sets: 1,
);

class FakeAiSlidesRepository implements AiSlidesRepository {
  bool premium = true;
  bool? allowed;
  int limit = 30;
  int remaining = 30;
  int calls = 0;
  int accessCalls = 0;
  Object? accessFailure;
  Completer<AiSlidesResult>? pending;
  Object? failure;
  AiSlidesResult result = const AiSlidesResult(
    slides: [draft],
    warnings: [],
    remaining: 29,
  );
  @override
  Future<AiSlidesAccess> access() async {
    accessCalls++;
    if (accessFailure != null) throw accessFailure!;
    return AiSlidesAccess(
      premium: premium,
      allowed: allowed,
      enabled: true,
      remaining: remaining,
      limit: limit,
    );
  }

  @override
  Future<AiSlidesResult> generate(String prompt) async {
    calls++;
    if (failure != null) throw failure!;
    return pending?.future ?? result;
  }
}

void main() {
  test('confirmation preserves explicit timings and uses normal defaults for missing values', () {
    for (final incomplete in [
      draft.copyWith(sets: 0),
      draft.copyWith(workSeconds: 3601),
    ]) {
      expect(
        () => confirmAiSlide(incomplete, 'slide'),
        throwsA(isA<AiSlidesFailure>()),
      );
    }
    final module = confirmAiSlide(draft, 'slide');
    expect(module.workSeconds, 300);
    expect(module.restSeconds, 0);
    expect(module.sets, 1);
    final defaults = WorkoutModule.empty('defaults');
    expect(module.includeFinalRest, defaults.includeFinalRest);
    final untimed = confirmAiSlide(
      draft.copyWith(workSeconds: null, restSeconds: null, sets: null),
      'untimed',
    );
    expect(untimed.workSeconds, defaults.workSeconds);
    expect(untimed.restSeconds, defaults.restSeconds);
    expect(untimed.sets, defaults.sets);
    final partial = confirmAiSlide(
      draft.copyWith(restSeconds: null),
      'partial',
    );
    expect(partial.workSeconds, 300);
    expect(partial.restSeconds, defaults.restSeconds);
    expect(module.text, contains('Squat 10 reps'));
    expect(module.designTemplate, 'stationd-v2-numbered');
    expect(
      module.appearance.showTitle,
      false,
      reason: 'Old clients must not duplicate baked text',
    );
    expect(
      () => confirmAiSlide(
        draft.copyWith(lines: List.filled(25, 'Squat')),
        'slide',
      ),
      throwsA(isA<AiSlidesFailure>()),
    );
  });
  test('theme and edits survive Firestore/library DTO roundtrips; old slides omit optional field', () {
    final original = WorkoutModule.empty('old');
    final oldJson = WorkoutModuleModel.fromEntity(original).toJson();
    expect(oldJson.containsKey('designTemplate'), false);
    expect(oldJson.containsKey('designAccentColor'), false);
    expect(WorkoutModuleModel.fromJson(oldJson).toEntity(), original);
    final edited = confirmAiSlide(
      draft.copyWith(
        designBackgroundColor: 0xFFF6F5F0,
        designTextColor: 0xFF151515,
        designAccentColor: 0xFF2876E8,
      ),
      'slide',
    ).copyWith(name: '새 제목', text: '런지 15회', workSeconds: 45);
    expect(
      WorkoutModuleModel.fromJson(
        WorkoutModuleModel.fromEntity(edited).toJson(),
      ).toEntity(),
      edited,
    );
  });
  test('free users never make a generation request', () async {
    final repository = FakeAiSlidesRepository()..premium = false;
    await expectLater(
      AiSlidesActions(repository).generate('수업 내용'),
      throwsA(isA<AiSlidesFailure>()),
    );
    expect(repository.calls, 0);
  });

  // STA-203 replaces the removed three-tab route assertions with the real
  // unified-route input/selection/usage/save/exit cases in slide_studio_page_test.
  // Legacy action, serialization, timing and PNG contracts remain here.
  test(
    'Plus with no remaining quota may still retrieve a server cached result',
    () async {
      final repository = FakeAiSlidesRepository()
        ..premium = false
        ..allowed = true
        ..limit = 10
        ..remaining = 0;
      await AiSlidesActions(repository).generate('Run 1km');
      expect(repository.calls, 1);
    },
  );

  testWidgets(
    'PNG export is 16:9, changes after edits, and supports every layout',
    (tester) async {
      await tester.runAsync(() async {
        await (FontLoader('Pretendard')..addFont(
              rootBundle.load('assets/fonts/pretendard/Pretendard-Bold.otf'),
            ))
            .load();
        for (final layout in ['numbered', 'list', 'interval']) {
          final module = confirmAiSlide(
            draft.copyWith(layout: layout),
            'export',
          );
          final source = await renderSlideDesign(module);
          expect(
            await renderSlideDesign(
              module.copyWith(
                workSeconds: 45,
                restSeconds: 15,
                sets: 8,
                intervalBlocks: const [
                  WorkoutIntervalBlock(
                    id: 'custom',
                    workSeconds: 30,
                    restSeconds: 10,
                    sets: 3,
                  ),
                ],
              ),
            ),
            source,
            reason: 'Timer settings must not add text to the slide artwork',
          );
          final bytes = base64Decode(source.split(',').last);
          final decoded = img.decodePng(bytes)!;
          expect(decoded.width, 1920);
          expect(decoded.height, 1080);
          expect(
            await renderSlideDesign(
              module.copyWith(text: '다른 운동 12회', workSeconds: 60),
            ),
            isNot(source),
          );
          if (const bool.fromEnvironment('AI_SLIDES_CAPTURE')) {
            await File('/tmp/cloudboard-slide-$layout.png').writeAsBytes(bytes);
          }
        }
        final dense = confirmAiSlide(
          draft.copyWith(
            layout: 'list',
            title: 'WAVE ZONE · FULL SESSION',
            lines: [
              'CASH IN',
              'RUN 1km',
              'SKI 1km',
              'SLED PUSH 50m',
              'MAIN · 6 STATION',
              'RUN 400m',
              'ROW 500m',
              'DUMBBELL SNATCH (ALTER) 20 reps',
              'DUMBBELL LUNGE 20 reps',
              'BOX JUMP OVER (STEP DOWN) 15 reps',
              'BURPEE OVER THE WAVE 10 reps',
              'CASH OUT',
              'RUN 1km',
              'SKI 1km',
              'SLED PULL 50m',
              'REST 2min',
              'ROUND 2',
              'ROW 500m',
              'LUNGE 20 reps',
              'PUSH UP 15 reps',
              'AIR SQUAT 20 reps',
              'BURPEE 10 reps',
              'WALK 200m',
              'COOL DOWN',
            ],
            designBackgroundColor: 0xFFF6F5F0,
            designTextColor: 0xFF151515,
            designAccentColor: 0xFF2876E8,
          ),
          'dense',
        );
        for (final showTimer in [true, false]) {
          final data = await renderSlideDesign(
            dense.copyWith(showTimer: showTimer),
          );
          final bytes = base64Decode(data.split(',').last);
          final decoded = img.decodePng(bytes)!;
          final background = decoded.getPixel(0, 0);
          expect([background.r, background.g, background.b], [246, 245, 240]);
          expect(dense.text.split('\n'), hasLength(24));
          if (const bool.fromEnvironment('AI_SLIDES_CAPTURE')) {
            await File('/tmp/cloudboard-slide-dense-$showTimer.png')
                .writeAsBytes(bytes);
          }
        }
        expect(
          await renderSlideDesign(
            WorkoutModule.empty('legacy')
                .copyWith(imageSource: 'https://example.com/old.png'),
          ),
          'https://example.com/old.png',
        );
      });
    },
  );
}
