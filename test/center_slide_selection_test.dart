import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_reference_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_slides_editor_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_editor_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/slide_design_style.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const standardTheme = AiSlideTheme(
  designStyle: SlideDesignStyle(family: 'banner', fontFamily: 'sans'),
  showTimer: false,
);

CenterSlideRecipe recipe(String id) => CenterSlideRecipe(
  templateId: id,
  revision: 1,
  centerId: 'center-one',
  width: 1920,
  height: 1080,
  backgroundColor: 0xffffffff,
  fields: const [],
);

AiSlideTheme remoteTheme(String id) =>
    AiSlideTheme(centerRecipe: recipe(id), showTimer: false);

AiSlideDraft remoteSample(String label) => AiSlideDraft(
  title: '$label class',
  layout: 'list',
  designHeaderLabel: '$label header',
  designSubtitle: '$label subtitle',
  lines: ['$label first', '', '$label third'],
  workSeconds: 300,
  restSeconds: 100,
  sets: 2,
);

class MemoryEditorRepository implements AiSlidesEditorRepository {
  final drafts = <AiSlidesSavedDraft?>[];
  final themes = <AiSlideTheme>[];
  @override
  Future<AiSlidesSavedDraft?> loadDraft(String ownerId) async => null;
  @override
  Stream<AiSlideTheme?> watchTheme(String ownerId) => Stream.value(null);
  @override
  Future<void> saveDraft(String ownerId, AiSlidesSavedDraft? draft) async {
    drafts.add(draft);
  }

  @override
  Future<void> saveTheme(String ownerId, AiSlideTheme theme) async {
    themes.add(theme);
  }
}

Future<void> settle(ProviderContainer container) async {
  for (var index = 0; index < 5; index++) {
    await Future<void>.delayed(Duration.zero);
    await container.pump();
  }
}

void expectContent(AiSlideDraft actual, AiSlideDraft expected) {
  expect(actual.title, expected.title);
  expect(actual.designHeaderLabel, expected.designHeaderLabel);
  expect(actual.designSubtitle, expected.designSubtitle);
  expect(actual.lines, expected.lines);
  expect(actual.workSeconds, expected.workSeconds);
  expect(actual.restSeconds, expected.restSeconds);
  expect(actual.sets, expected.sets);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late MemoryEditorRepository repository;
  late AiSlidesController controller;
  AiSlideDraft current() => container.read(aiSlidesControllerProvider).draft!;

  setUp(() async {
    repository = MemoryEditorRepository();
    container = ProviderContainer(
      overrides: [
        aiSlidesOwnerIdProvider.overrideWith((ref) => 'owner-one'),
        aiSlidesEditorActionsProvider.overrideWithValue(
          AiSlidesEditorActions(repository),
        ),
        aiSlidesControllerProvider.overrideWith(AiSlidesController.fresh),
      ],
    );
    container.read(aiSlidesControllerProvider);
    await settle(container);
    controller = container.read(aiSlidesControllerProvider.notifier);
  });
  tearDown(() => container.dispose());

  test(
    'standard to remote to standard preserves edited content and timing',
    () {
      controller.applyDesign(standardTheme);
      final edited = current().copyWith(
        title: 'Edited lesson',
        designHeaderLabel: 'My header',
        designSubtitle: 'My subtitle',
        lines: ['Edited first', '', 'Edited third'],
        workSeconds: 73,
        restSeconds: 11,
        sets: 4,
      );
      controller.updateDraft(edited);
      controller.applyDesign(
        remoteTheme('remote-a'),
        sample: remoteSample('A'),
      );
      expectContent(current(), edited);
      expect(current().centerRecipe?.templateId, 'remote-a');
      expect(current().designStyle, isNull);
      controller.applyDesign(standardTheme);
      expectContent(current(), edited);
      expect(current().centerRecipe, isNull);
      expect(current().designStyle, standardTheme.designStyle);
    },
  );

  test(
    'untouched samples are replaced across standard and remote selections',
    () {
      controller.applyDesign(standardTheme);
      controller.applyDesign(
        remoteTheme('remote-a'),
        sample: remoteSample('A'),
      );
      expectContent(current(), remoteSample('A'));
      controller.applyDesign(
        remoteTheme('remote-b'),
        sample: remoteSample('B'),
      );
      expectContent(current(), remoteSample('B'));
      expect(current().centerRecipe?.templateId, 'remote-b');
      controller.applyDesign(standardTheme);
      final standardSample = applyAiSlideTheme(
        initialAiSlideDesignDraft(standardTheme),
        standardTheme,
      );
      expectContent(current(), standardSample);
      expect(current().centerRecipe, isNull);
    },
  );

  test('changing only a sample timer counts as a user edit', () {
    controller.applyDesign(standardTheme);
    final timed = current().copyWith(workSeconds: 91, restSeconds: 13, sets: 5);
    controller.updateDraft(timed);
    controller.applyDesign(remoteTheme('remote-a'), sample: remoteSample('A'));
    expectContent(current(), timed);
    controller.applyDesign(standardTheme);
    expectContent(current(), timed);
  });

  test('undo restores the sample baseline used by the next selection', () {
    controller.applyDesign(remoteTheme('remote-a'), sample: remoteSample('A'));
    controller.applyDesign(remoteTheme('remote-b'), sample: remoteSample('B'));
    controller.undo();
    expectContent(current(), remoteSample('A'));
    expect(current().centerRecipe?.templateId, 'remote-a');
    controller.applyDesign(remoteTheme('remote-c'), sample: remoteSample('C'));
    expectContent(current(), remoteSample('C'));
    expect(current().centerRecipe?.templateId, 'remote-c');
  });

  test('undoing a content edit restores an untouched sample', () {
    controller.applyDesign(remoteTheme('remote-a'), sample: remoteSample('A'));
    controller.updateDraft(current().copyWith(title: 'Manual correction'));
    controller.undo();
    expectContent(current(), remoteSample('A'));
    controller.applyDesign(remoteTheme('remote-b'), sample: remoteSample('B'));
    expectContent(current(), remoteSample('B'));
  });

  test('undoing a visual switch retains edited content on the next switch', () {
    controller.applyDesign(standardTheme);
    final edited = current().copyWith(title: 'Real lesson', workSeconds: 87);
    controller.updateDraft(edited);
    controller.applyDesign(remoteTheme('remote-a'), sample: remoteSample('A'));
    controller.undo();
    expectContent(current(), edited);
    expect(current().centerRecipe, isNull);
    controller.applyDesign(remoteTheme('remote-b'), sample: remoteSample('B'));
    expectContent(current(), edited);
  });

  test('clear discards previous sample and undo history', () async {
    controller.applyDesign(remoteTheme('remote-a'), sample: remoteSample('A'));
    controller.updateDraft(current().copyWith(title: 'Manual correction'));
    await controller.clearDraft();
    expect(container.read(aiSlidesControllerProvider).draft, isNull);
    expect(container.read(aiSlidesControllerProvider).canUndo, isFalse);
    controller.applyDesign(remoteTheme('remote-b'), sample: remoteSample('B'));
    expectContent(current(), remoteSample('B'));
    controller.undo();
    expect(container.read(aiSlidesControllerProvider).draft, isNull);
  });

  test(
    'remote recipes cannot reach legacy draft or theme persistence',
    () async {
      final persistent = ProviderContainer(
        overrides: [
          aiSlidesOwnerIdProvider.overrideWith((ref) => 'owner-one'),
          aiSlidesEditorActionsProvider.overrideWithValue(
            AiSlidesEditorActions(repository),
          ),
        ],
      );
      addTearDown(persistent.dispose);
      persistent.read(aiSlidesControllerProvider);
      await settle(persistent);
      final notifier = persistent.read(aiSlidesControllerProvider.notifier);
      notifier.applyDesign(remoteTheme('remote-a'), sample: remoteSample('A'));
      await notifier.flush();
      await notifier.saveTheme();
      expect(repository.drafts, isEmpty);
      expect(repository.themes, isEmpty);
      notifier.applyDesign(standardTheme);
      await notifier.flush();
      await notifier.saveTheme();
      expect(repository.drafts.single?.draft?.centerRecipe, isNull);
      expect(repository.themes.single.centerRecipe, isNull);
    },
  );
}
