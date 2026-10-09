import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/ai_slides/data/models/ai_slide_design_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_slide_design_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_slides_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_slides_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_reference_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_slide_design_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_slides_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slide_design_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_page.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_content_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_design_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/original_slide_renderer.dart';

import 'support/ai_slides_editor_fakes.dart';

class _DesignRepository implements AiSlideDesignRepository {
  final saved = <String, AiSlideDesign>{};
  final selected = <String, AiSlideDesign>{};
  final streams = <String, StreamController<List<AiSlideDesign>>>{};
  Completer<AiSlideDesignResult>? pending;
  Completer<AiSlideDesign?>? restoring;
  int calls = 0;
  int accessCalls = 0;
  VoidCallback? onGenerated;
  String scope(String owner, String? store) => '$owner/${store ?? 'legacy'}';
  @override
  Future<AiSlidesAccess> access(String ownerId) async {
    accessCalls++;
    return const AiSlidesAccess(
      premium: true,
      enabled: true,
      remaining: 30,
      limit: 30,
    );
  }

  @override
  Future<AiSlideDesignResult> generate(
    String ownerId,
    String prompt, {
    Uint8List? reference,
  }) async {
    calls++;
    onGenerated?.call();
    return pending?.future ??
        AiSlideDesignResult(
          designs: aiSlideDesignCatalog
              .take(reference == null ? 3 : 1)
              .toList(),
          remaining: 29,
        );
  }

  @override
  Future<AiSlideDesign?> loadSelected(String ownerId, String? storeId) async =>
      restoring?.future ?? selected[scope(ownerId, storeId)];
  @override
  Future<void> saveSelected(
    String ownerId,
    String? storeId,
    AiSlideDesign design,
  ) async {
    selected[scope(ownerId, storeId)] = design;
  }

  @override
  Future<void> saveTemplate(String ownerId, AiSlideDesign design) async {
    saved[design.id] = design;
    streams[scope(ownerId, design.storeId)]?.add(
      saved.values.where((value) => value.storeId == design.storeId).toList(),
    );
  }

  @override
  Stream<List<AiSlideDesign>> watchTemplates(String ownerId, String? storeId) =>
      (streams[scope(ownerId, storeId)] ??=
              StreamController<List<AiSlideDesign>>.broadcast())
          .stream;
}

class _ContentRepository implements AiSlidesRepository {
  bool premium = false;
  int calls = 0;
  int accessCalls = 0;
  int remaining = 30;
  AiSlideDraft output = const AiSlideDraft(
    title: '새 수업',
    layout: 'list',
    lines: ['DV Press 8 + BTP 10', 'Run 250m + FMCTP 30'],
  );
  @override
  Future<AiSlidesAccess> access() async {
    accessCalls++;
    return AiSlidesAccess(
      premium: premium,
      enabled: true,
      remaining: remaining,
      limit: 30,
    );
  }

  @override
  Future<AiSlidesResult> generate(String prompt) async {
    calls++;
    return AiSlidesResult(
      slides: [output],
      warnings: [],
      remaining: --remaining,
    );
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('content and design completion refresh the same quota', () async {
    final content = _ContentRepository()..premium = true;
    final designs = _DesignRepository()
      ..onGenerated = () => content.remaining--;
    final container = ProviderContainer(
      overrides: [
        aiSlidesOwnerIdProvider.overrideWithValue('alice'),
        aiSlideDesignOwnerIdProvider.overrideWithValue('alice'),
        aiSlideDesignStoreIdProvider.overrideWithValue('center-a'),
        aiSlidesRepositoryProvider.overrideWithValue(content),
        aiSlideDesignRepositoryProvider.overrideWithValue(designs),
        aiSlidesEditorRepositoryProvider.overrideWithValue(
          MemoryAiSlidesEditorRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(aiSlidesAccessProvider, (_, _) {});
    expect((await container.read(aiSlidesAccessProvider.future)).remaining, 30);
    final editor = container.read(aiSlidesControllerProvider.notifier);
    await _settle();
    await _settle();
    await editor.generate('운동 메모');
    expect((await container.read(aiSlidesAccessProvider.future)).remaining, 29);
    await container
        .read(aiSlideDesignControllerProvider.notifier)
        .generate('새로운 스타일');
    expect((await container.read(aiSlidesAccessProvider.future)).remaining, 28);
    expect(
      content.accessCalls,
      4,
      reason: 'Initial read, content preflight, and two completion refreshes',
    );
  });

  test(
    'WOD originals switch samples, preserve lesson edits and accept AI content',
    () async {
      final content = _ContentRepository()..premium = true;
      content.output = content.output.copyWith(
        workSeconds: 480,
        restSeconds: 60,
      );
      final container = ProviderContainer(
        overrides: [
          aiSlidesOwnerIdProvider.overrideWithValue('alice'),
          aiSlidesEditorRepositoryProvider.overrideWithValue(
            MemoryAiSlidesEditorRepository(),
          ),
          aiSlidesRepositoryProvider.overrideWithValue(content),
        ],
      );
      addTearDown(container.dispose);
      final editor = container.read(aiSlidesControllerProvider.notifier);
      await _settle();
      await _settle();
      for (final design in stationDReferenceDesigns) {
        final template = originalSlideTemplate(
          design.theme.designStyle!.originalTemplate,
        )!;
        editor.applyDesign(design.theme);
        final draft = container.read(aiSlidesControllerProvider).draft!;
        expect(draft.title, template.title);
        expect(draft.lines, template.lines);
        expect(draft.designSubtitle, template.subtitle);
        expect(draft.designHeaderLabel, template.programLabel);
        expect(
          AiSlideDesignModel.fromJson(
            AiSlideDesignModel.fromEntity(design).toJson(),
          ).toEntity(design.id),
          design,
        );
      }
      final edited = container
          .read(aiSlidesControllerProvider)
          .draft!
          .copyWith(lines: ['Ski 400m'], designSubtitle: '10mins On');
      editor.updateDraft(edited);
      editor.applyDesign(stationDReferenceDesigns.first.theme);
      expect(container.read(aiSlidesControllerProvider).draft!.lines, [
        'Ski 400m',
      ]);
      expect(
        container.read(aiSlidesControllerProvider).draft!.designSubtitle,
        '10mins On',
      );
      await editor.generate(
        '운동 8분 휴식 1분, DV Press 8 + BTP 10, Run 250m + FMCTP 30',
      );
      final generated = container.read(aiSlidesControllerProvider).draft!;
      expect(content.calls, 1);
      expect(generated.lines, content.output.lines);
      expect(generated.designSubtitle, '8mins On / 1min Off');
      expect(generated.designStyle!.originalTemplate, 'stationd-mon-v1');
      expect(generated.designHeaderLabel, 'UNBROKEN');
      expect(generated.showTimer, false);
    },
  );

  test(
    'customer original template stays outside the shared design catalog',
    () {
      expect(aiSlideDesignCatalog, hasLength(4));
      expect(
        aiSlideDesignCatalog.every(
          (design) => design.theme.designStyle?.originalTemplate == null,
        ),
        isTrue,
      );
      final original = initialAiSlideDesignDraft(dolpaReferenceDesign.theme);
      expect(original.title, 'Brick Session');
      expect(original.designSubtitle, '6mins On / 90s Off');
      expect(original.designHeaderLabel, isEmpty);
      final saved = dolpaReferenceDesign.copyWith(
        id: 'ai-design-owner-class',
        name: '돌파',
        storeId: 'center-a',
      );
      expect(
        AiSlideDesignModel.fromJson(
          AiSlideDesignModel.fromEntity(saved).toJson(),
        ).toEntity(saved.id),
        saved,
      );
      expect(original.lines, [
        'Ski 250m + Sled Pull 1 Way',
        'Run 250m + FMCTP 30',
        'Ski 250m + Wall Ball 30',
        'DV Press 8 + BTP 10',
      ]);
    },
  );

  test(
    'original selection keeps edited content and never injects class metadata',
    () async {
      final content = _ContentRepository()..premium = true;
      final container = ProviderContainer(
        overrides: [
          aiSlidesOwnerIdProvider.overrideWithValue('alice'),
          aiSlidesEditorRepositoryProvider.overrideWithValue(
            MemoryAiSlidesEditorRepository(),
          ),
          aiSlidesRepositoryProvider.overrideWithValue(content),
        ],
      );
      addTearDown(container.dispose);
      final editor = container.read(aiSlidesControllerProvider.notifier);
      await _settle();
      await _settle();
      editor.applyDesign(dolpaReferenceDesign.theme, classLabel: '돌파');
      var draft = container.read(aiSlidesControllerProvider).draft!;
      expect(draft.title, 'Brick Session');
      expect(draft.designHeaderLabel, isEmpty);
      expect(draft.showTimer, isFalse);
      expect(draft.lines, hasLength(4));
      editor.updateDraft(
        draft.copyWith(
          title: '수정한 수업',
          designSubtitle: '8mins On',
          lines: ['DV Press 12 + BTP 15'],
        ),
      );
      editor.applyDesign(dolpaReferenceDesign.theme, classLabel: '저장한 클래스 이름');
      draft = container.read(aiSlidesControllerProvider).draft!;
      expect(draft.title, '수정한 수업');
      expect(draft.designSubtitle, '8mins On');
      expect(draft.lines, ['DV Press 12 + BTP 15']);
      expect(draft.designHeaderLabel, isEmpty);
      await editor.generate(
        '새 수업 제목\nDV Press 8 + BTP 10\nRun 250m + FMCTP 30',
      );
      final generated = container.read(aiSlidesControllerProvider).draft!;
      expect(generated.title, '수정한 수업');
      expect(generated.lines, ['DV Press 8 + BTP 10', 'Run 250m + FMCTP 30']);
      expect(generated.showTimer, isFalse);
    },
  );

  testWidgets('original exposes an editable title and lesson fields', (
    tester,
  ) async {
    final original = applyAiSlideTheme(
      initialAiSlideDesignDraft(dolpaReferenceDesign.theme),
      dolpaReferenceDesign.theme,
    );
    AiSlideDraft? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiSlidesContentEditor(
              draft: original,
              warnings: const [],
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('ai-slide-header')), findsNothing);
    expect(find.byKey(const ValueKey('ai-slide-title')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('ai-slide-title')),
      '새 제목',
    );
    expect(changed!.title, '새 제목');
    expect(find.byKey(const ValueKey('ai-slide-subtitle')), findsOneWidget);
    expect(find.text('운동 문구 (최대 4행)'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('ai-original-lines')),
      'Ski 300m + Sled Pull 1 Way\nRun 250m + FMCTP 30\nSki 250m + Wall Ball 30\nDV Press 8 + BTP 10',
    );
    expect(changed!.title, original.title);
    expect(changed!.designSubtitle, original.designSubtitle);
    expect(changed!.lines.first, 'Ski 300m + Sled Pull 1 Way');
    expect(changed!.designStyle, original.designStyle);
    expect(
      slideDesignError(
        previewAiSlide(
          original.copyWith(lines: [...original.lines, 'Extra row']),
        ),
      ),
      isNotNull,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiSlidesDesignEditor(
            draft: original,
            state: const AiSlidesEditorState(),
            onChanged: (_) {},
            onSaveTheme: () {},
            onApplyTheme: () {},
          ),
        ),
      ),
    );
    expect(find.text('원본 배치 유지 · 운동 문구만 수정'), findsOneWidget);
    expect(find.text('배치'), findsNothing);
    expect(find.text('글씨'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('stored class style is content-free and keeps the real center ID', () {
    final design = aiSlideDesignCatalog[2].copyWith(
      id: 'class-a',
      name: '돌파',
      storeId: 'center-42',
    );
    final json = AiSlideDesignModel.fromEntity(design).toJson();
    expect(json['storeId'], 'center-42');
    final theme = json['theme'] as Map;
    expect(theme.keys, isNot(contains('lines')));
    expect(theme.keys, isNot(contains('designHeaderLabel')));
    expect(AiSlideDesignModel.fromJson(json).toEntity(design.id), design);
    expect(
      () =>
          AiSlideDesignModel.fromJson({...json, 'schemaVersion': 2})
              .toEntity(design.id),
      throwsFormatException,
    );
    expect(
      () =>
          AiSlideDesignModel.fromJson({...json, 'storeId': ''})
              .toEntity(design.id),
      throwsFormatException,
    );
  });

  test('design response requires the requested count and opaque colors', () {
    Map<String, dynamic> candidate() => {
      'name': '포스터',
      'description': '정돈된 제목',
      'family': 'editorial',
      'fontFamily': 'serif',
      'backgroundColor': 0xff111111,
      'textColor': 0xffffffff,
      'accentColor': 0xffdd4422,
      'titleColor': 0xffffffff,
      'titleWeight': 800,
      'bodyWeight': 600,
      'italic': false,
      'spacing': 1.1,
      'motif': 'CLASS',
    };
    Map<String, dynamic> response(List<Map<String, dynamic>> values) => {
      'result': {'designs': values, 'warnings': <String>[]},
      'remaining': 27,
      'cached': false,
    };
    expect(
      parseAiSlideDesignResult(
        response([candidate()]),
        reference: true,
      ).designs.single.theme.designStyle!.family,
      'editorial',
    );
    expect(
      () => parseAiSlideDesignResult(response([candidate()]), reference: false),
      throwsA(isA<AiSlidesFailure>()),
    );
    expect(
      () => parseAiSlideDesignResult(
        response([candidate()..['textColor'] = 0x00ffffff]),
        reference: true,
      ),
      throwsA(isA<AiSlidesFailure>()),
    );
  });

  test('late restore cannot replace a design selected by the user', () async {
    final repository = _DesignRepository()
      ..restoring = Completer<AiSlideDesign?>();
    final container = ProviderContainer(
      overrides: [
        aiSlideDesignOwnerIdProvider.overrideWithValue('alice'),
        aiSlideDesignStoreIdProvider.overrideWithValue('center-a'),
        aiSlideDesignRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(aiSlideDesignControllerProvider.notifier);
    await _settle();
    await controller.select(aiSlideDesignCatalog[1]);
    repository.restoring!.complete(aiSlideDesignCatalog[0]);
    await _settle();
    expect(
      container.read(aiSlideDesignControllerProvider).selected!.id,
      'catalog-focus',
    );
    expect(repository.selected['alice/center-a']!.storeId, 'center-a');
  });

  test('late AI result cannot cross account or center scope', () async {
    var owner = 'alice';
    var store = 'center-a';
    final repository = _DesignRepository()
      ..pending = Completer<AiSlideDesignResult>();
    final container = ProviderContainer(
      overrides: [
        aiSlideDesignOwnerIdProvider.overrideWith((ref) => owner),
        aiSlideDesignStoreIdProvider.overrideWith((ref) => store),
        aiSlideDesignRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(aiSlideDesignControllerProvider.notifier);
    await _settle();
    final pending = controller.generate('강렬한 디자인');
    await _settle();
    owner = 'bob';
    store = 'center-b';
    container.invalidate(aiSlideDesignOwnerIdProvider);
    container.invalidate(aiSlideDesignStoreIdProvider);
    container.read(aiSlideDesignControllerProvider);
    repository.pending!.complete(
      AiSlideDesignResult(
        designs: aiSlideDesignCatalog.take(3).toList(),
        remaining: 29,
      ),
    );
    await pending;
    expect(container.read(aiSlideDesignControllerProvider).proposals, isEmpty);
    expect(container.read(aiSlideDesignControllerProvider).generating, isFalse);
  });

  test('selected design survives daily content generation and undo', () async {
    final content = _ContentRepository()..premium = true;
    final container = ProviderContainer(
      overrides: [
        aiSlidesOwnerIdProvider.overrideWithValue('alice'),
        aiSlidesEditorRepositoryProvider.overrideWithValue(
          MemoryAiSlidesEditorRepository(),
        ),
        aiSlidesRepositoryProvider.overrideWithValue(content),
      ],
    );
    addTearDown(container.dispose);
    final editor = container.read(aiSlidesControllerProvider.notifier);
    await _settle();
    await _settle();
    editor.applyDesign(aiSlideDesignCatalog[2].theme, classLabel: 'HYROX');
    final before = container.read(aiSlidesControllerProvider).draft!;
    await editor.generate('DV Press 8 + BTP 10\nRun 250m + FMCTP 30');
    final draft = container.read(aiSlidesControllerProvider).draft!;
    expect(draft.lines, ['DV Press 8 + BTP 10', 'Run 250m + FMCTP 30']);
    expect(draft.designHeaderLabel, 'HYROX');
    expect(draft.designSubtitle, isEmpty);
    expect(aiSlideThemeFromDraft(draft), aiSlideDesignCatalog[2].theme);
    editor.undo();
    expect(container.read(aiSlidesControllerProvider).draft, before);
  });

  testWidgets(
    'free user can choose a catalog design and add editable content',
    (tester) async {
      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final content = _ContentRepository();
      final designs = _DesignRepository();
      await tester.runAsync(
        () => Future.wait(
          originalSlideTemplates.map(
            (template) => loadOriginalSlideImage(template.id),
          ),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiSlidesOwnerIdProvider.overrideWithValue('alice'),
            aiSlidesEditorRepositoryProvider.overrideWithValue(
              MemoryAiSlidesEditorRepository(),
            ),
            aiSlidesRepositoryProvider.overrideWithValue(content),
            aiSlideDesignOwnerIdProvider.overrideWithValue('alice'),
            aiSlideDesignStoreIdProvider.overrideWithValue('center-a'),
            aiSlideDesignRepositoryProvider.overrideWithValue(designs),
          ],
          child: const MaterialApp(home: Scaffold(body: AiSlidesPage())),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('템플릿'), findsOneWidget);
      expect(find.text('스타일 제안'), findsNothing);
      expect(find.text('이미지로 시작'), findsNothing);
      expect(find.textContaining('AI 토큰·생성 횟수를 사용하지 않아요'), findsOneWidget);
      expect(find.text('프리미엄 템플릿'), findsOneWidget);
      expect(find.text('7개'), findsOneWidget);
      expect(find.text('일반 템플릿'), findsOneWidget);
      expect(find.text('4개'), findsOneWidget);
      for (final design in customerReferenceDesigns) {
        final premiumCard = find.byKey(ValueKey('ai-design-${design.id}'));
        await tester.ensureVisible(premiumCard);
        await tester.pumpAndSettle();
        await tester.tap(premiumCard);
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
        final pageScope = ProviderScope.containerOf(
          tester.element(find.byType(AiSlidesContentEditor)),
        );
        expect(
          pageScope
              .read(aiSlideDesignControllerProvider)
              .selected
              ?.theme
              .designStyle
              ?.originalTemplate,
          design.theme.designStyle?.originalTemplate,
        );
        expect(designs.selected['alice/center-a'], isNull);
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: find.byKey(const ValueKey('ai-slide-title')),
                  matching: find.byType(EditableText),
                ),
              )
              .controller
              .text,
          initialAiSlideDesignDraft(design.theme).title,
        );
        await tester.tap(find.byKey(const ValueKey('ai-nav-templates')));
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
      }
      final card = find.byKey(const ValueKey('ai-design-catalog-banner'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-slide-header')), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-slide-subtitle')), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('ai-slides-add')))
            .onPressed,
        isNotNull,
      );
      expect(content.calls, 0);
      expect(designs.calls, 0);
      final title = find.byKey(const ValueKey('ai-slide-title'));
      await tester.enterText(title, '오늘의 수업');
      await tester.tap(find.byKey(const ValueKey('ai-nav-create')));
      await tester.pumpAndSettle();
      expect(find.text('스타일 제안'), findsOneWidget);
      expect(find.text('이미지로 시작'), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-generation-usage')), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      expect(find.byKey(const ValueKey('ai-nav-source')), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(AiBetaBadge),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byType(AiBetaBadge),
        ),
        findsWidgets,
      );
      expect(content.accessCalls, 1);
      expect(designs.accessCalls, 0);
      expect(
        find.byKey(const ValueKey('ai-design-catalog-banner')),
        findsNothing,
      );
      final brief = find.byKey(const ValueKey('ai-design-brief'));
      final notes = find.byKey(const ValueKey('ai-slides-prompt'));
      await tester.enterText(notes, 'WARM UP 스쿼트 10회');
      await tester.tap(find.text('스타일 제안'));
      await tester.pumpAndSettle();
      await tester.enterText(brief, '짙은 배경에 라임색 포인트');
      await tester.tap(find.byKey(const ValueKey('ai-nav-templates')));
      await tester.pumpAndSettle();
      expect(find.text('스타일 제안'), findsNothing);
      expect(designs.calls, 0);
      await tester.tap(find.byKey(const ValueKey('ai-nav-create')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(brief).controller!.text,
        '짙은 배경에 라임색 포인트',
      );
      await tester.tap(find.text('이미지로 시작'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-reference-pick')), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-generation-usage')), findsOneWidget);
      expect(
        content.accessCalls,
        1,
        reason: 'All three generation modes share one access check',
      );
      expect(designs.accessCalls, 0);
      await tester.tap(find.text('수업 메모'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(notes).controller!.text,
        'WARM UP 스쿼트 10회',
      );
      await tester.tap(find.byKey(const ValueKey('ai-nav-content')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(title).controller!.text, '오늘의 수업');
      expect(find.text('크게 보기'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('ai-slides-preview-expand')));
      await tester.pumpAndSettle();
      expect(find.text('슬라이드 미리보기'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(content.calls, 0);
      expect(
        designs.calls,
        0,
        reason:
            'Opening design tools and changing tabs must not generate anything',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
