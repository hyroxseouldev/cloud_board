import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/datasources/ai_slides_editor_data_source.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/models/ai_slides_editor_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_slides_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_slides_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_slides_editor_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_slides_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';

const example = AiSlideDraft(
  title: 'Morning workout',
  layout: 'list',
  lines: ['## WARM UP', 'Run 1 km', '## MAIN', 'Squat 10 reps'],
  workSeconds: 180,
  restSeconds: 20,
  sets: 3,
);

class MemoryEditorRepository implements AiSlidesEditorRepository {
  final drafts = <String, AiSlidesSavedDraft?>{};
  final themes = <String, AiSlideTheme?>{};
  final themeUpdates = <String, StreamController<AiSlideTheme?>>{};
  Completer<AiSlidesSavedDraft?>? loading;
  Completer<void>? savingTheme;
  Completer<void>? initialTheme;
  bool failTheme = false;
  bool failSave = false;
  @override
  Future<AiSlidesSavedDraft?> loadDraft(String ownerId) async =>
      loading?.future ?? drafts[ownerId];
  @override
  Future<void> saveDraft(String ownerId, AiSlidesSavedDraft? draft) async {
    if (failSave) throw StateError('disk failed');
    drafts[ownerId] = draft;
  }

  @override
  Stream<AiSlideTheme?> watchTheme(String ownerId) async* {
    await initialTheme?.future;
    if (failTheme) throw StateError('theme unavailable');
    yield themes[ownerId];
    yield* (themeUpdates[ownerId] ??=
            StreamController<AiSlideTheme?>.broadcast())
        .stream;
  }

  @override
  Future<void> saveTheme(String ownerId, AiSlideTheme theme) async {
    await savingTheme?.future;
    themes[ownerId] = theme;
    themeUpdates[ownerId]?.add(theme);
  }

  Future<void> dispose() async {
    for (final controller in themeUpdates.values) {
      await controller.close();
    }
  }
}

class GenerationRepository implements AiSlidesRepository {
  int calls = 0;
  Completer<AiSlidesResult>? pending;
  bool fail = false;
  @override
  Future<AiSlidesAccess> access() async => const AiSlidesAccess(
    premium: true,
    enabled: true,
    remaining: 30,
    limit: 30,
  );
  @override
  Future<AiSlidesResult> generate(String prompt) async {
    calls++;
    if (fail) throw const AiSlidesFailure('생성 실패');
    return pending?.future ??
        const AiSlidesResult(slides: [example], warnings: [], remaining: 29);
  }
}

// This storage test double deliberately exposes controllable pending writes.
// ignore: must_be_immutable
class MemoryPreferences extends Fake implements SharedPreferencesAsync {
  final data = <String, String>{};
  Completer<void>? hold;
  bool fail = false;
  @override
  Future<String?> getString(String key) async => data[key];
  @override
  Future<void> setString(String key, String value) async {
    await hold?.future;
    if (fail) {
      fail = false;
      throw StateError('disk failed');
    }
    data[key] = value;
  }

  @override
  Future<void> remove(String key) async => data.remove(key);
}

// SDK fakes exercise metadata transitions without a live Firebase connection.
// ignore: subtype_of_sealed_class
class ThemeSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  ThemeSnapshot({required this.cached, this.value});
  final bool cached;
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
  @override
  SnapshotMetadata get metadata => ThemeSnapshotMetadata(cached);
}

class ThemeSnapshotMetadata extends Fake implements SnapshotMetadata {
  ThemeSnapshotMetadata(this.cached);
  final bool cached;
  @override
  bool get isFromCache => cached;
}

// ignore: subtype_of_sealed_class
class ThemeDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final updates = StreamController<DocumentSnapshot<Map<String, dynamic>>>();
  final metadataRequests = <bool>[];
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    metadataRequests.add(includeMetadataChanges);
    return updates.stream;
  }
}

class ThemeFirestore extends Fake implements FirebaseFirestore {
  ThemeFirestore(this.document);
  final ThemeDocument document;
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) {
    expect(path, 'users/alice/settings/aiSlidesTheme');
    return document;
  }
}

class ThemeAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => ThemeUser();
}

class ThemeUser extends Fake implements User {
  @override
  String get uid => 'alice';
  @override
  bool get isAnonymous => false;
}

Future<void> settle(ProviderContainer container) async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
    await container.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryEditorRepository storage;
  late GenerationRepository generation;
  late ProviderContainer container;
  String? owner;
  setUp(() {
    owner = 'alice';
    storage = MemoryEditorRepository();
    generation = GenerationRepository();
    container = ProviderContainer(
      overrides: [
        aiSlidesOwnerIdProvider.overrideWith((ref) => owner),
        aiSlidesEditorRepositoryProvider.overrideWithValue(storage),
        aiSlidesRepositoryProvider.overrideWithValue(generation),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await storage.dispose();
  });

  test('fresh creation ignores old drafts and presets and never autosaves its session', () async {
    const oldDraft = AiSlidesSavedDraft(
      prompt: 'previous class',
      draft: example,
    );
    storage.drafts['alice'] = oldDraft;
    storage.themes['alice'] = const AiSlideTheme(designAccentColor: 0xFF123456);
    final fresh = ProviderContainer(
      parent: container,
      overrides: [
        aiSlidesControllerProvider.overrideWith(AiSlidesController.fresh),
      ],
    );
    addTearDown(fresh.dispose);
    fresh.read(aiSlidesControllerProvider);
    await settle(fresh);
    expect(fresh.read(aiSlidesControllerProvider).draft, isNull);
    expect(fresh.read(aiSlidesControllerProvider).prompt, isEmpty);
    final controller = fresh.read(aiSlidesControllerProvider.notifier);
    await controller.generate('new class');
    expect(
      fresh.read(aiSlidesControllerProvider).draft!.designAccentColor,
      example.designAccentColor,
    );
    controller.setPrompt('unsaved notes');
    await controller.flush();
    fresh.invalidate(aiSlidesControllerProvider);
    fresh.read(aiSlidesControllerProvider);
    await settle(fresh);
    expect(fresh.read(aiSlidesControllerProvider).draft, isNull);
    expect(storage.drafts['alice'], oldDraft);
  });

  test(
    'edited draft restores after flush and provider reconstruction',
    () async {
      container.read(aiSlidesControllerProvider);
      await settle(container);
      final controller = container.read(aiSlidesControllerProvider.notifier);
      await controller.generate('Run 1 km; Squat 10 reps');
      controller.updateDraft(
        example.copyWith(title: 'Edited title', designItalic: false),
      );
      controller.setPrompt('Next input, not generated');
      await controller.flush();
      container.invalidate(aiSlidesControllerProvider);
      container.read(aiSlidesControllerProvider);
      await settle(container);
      final state = container.read(aiSlidesControllerProvider);
      expect(state.draft?.title, 'Edited title');
      expect(state.draft?.designItalic, false);
      expect(state.prompt, 'Next input, not generated');
      expect(state.generatedPrompt, 'Run 1 km; Squat 10 reps');
      expect(state.generating, false);
    },
  );

  test('same input retains edits without calling AI; failed replacement retains draft', () async {
    container.read(aiSlidesControllerProvider);
    await settle(container);
    final controller = container.read(aiSlidesControllerProvider.notifier);
    await controller.generate('my lesson');
    controller.updateDraft(example.copyWith(title: 'Manual correction'));
    await controller.generate('my lesson  ');
    expect(generation.calls, 1);
    expect(
      container.read(aiSlidesControllerProvider).draft?.title,
      'Manual correction',
    );
    generation.fail = true;
    await controller.generate('new lesson');
    expect(
      container.read(aiSlidesControllerProvider).draft?.title,
      'Manual correction',
    );
    expect(container.read(aiSlidesControllerProvider).error, '생성 실패');
    controller.undo();
    expect(
      container.read(aiSlidesControllerProvider).draft?.title,
      example.title,
    );
  });

  test('generation survives closing all listeners and persists the finished result', () async {
    final listener = container.listen(aiSlidesControllerProvider, (_, _) {});
    await settle(container);
    generation.pending = Completer<AiSlidesResult>();
    final done = container
        .read(aiSlidesControllerProvider.notifier)
        .generate('close during generation');
    await settle(container);
    listener.close();
    await container.pump();
    generation.pending!.complete(
      const AiSlidesResult(slides: [example], warnings: [], remaining: 29),
    );
    await done;
    expect(container.read(aiSlidesControllerProvider).draft, example);
    expect(storage.drafts['alice']?.draft, example);
  });

  test(
    'pending AI result and theme save cannot cross an account switch',
    () async {
      container.read(aiSlidesControllerProvider);
      await settle(container);
      final controller = container.read(aiSlidesControllerProvider.notifier);
      await controller.generate('first');
      storage.savingTheme = Completer<void>();
      final saving = controller.saveTheme();
      generation.pending = Completer<AiSlidesResult>();
      final generating = controller.generate('pending');
      await settle(container);
      owner = 'bob';
      container.invalidate(aiSlidesOwnerIdProvider);
      await settle(container);
      storage.savingTheme!.complete();
      generation.pending!.complete(
        const AiSlidesResult(slides: [example], warnings: [], remaining: 28),
      );
      await Future.wait([saving, generating]);
      final state = container.read(aiSlidesControllerProvider);
      expect(state.draft, isNull);
      expect(state.theme, isNull);
      expect(state.generating, false);
      expect(storage.drafts['bob'], isNull);
      expect(storage.themes['bob'], isNull);
    },
  );

  test('late restore never overwrites new input and unauthenticated has no shared cache', () async {
    storage.loading = Completer<AiSlidesSavedDraft?>();
    container.read(aiSlidesControllerProvider);
    final controller = container.read(aiSlidesControllerProvider.notifier);
    controller.setPrompt('new input');
    await settle(container);
    storage.loading!.complete(
      const AiSlidesSavedDraft(prompt: 'old input', draft: example),
    );
    await settle(container);
    expect(container.read(aiSlidesControllerProvider).prompt, 'new input');
    await controller.flush();
    expect(storage.drafts['alice']?.prompt, 'new input');
    owner = null;
    container.invalidate(aiSlidesOwnerIdProvider);
    await settle(container);
    expect(container.read(aiSlidesControllerProvider).draft, isNull);
    await container
        .read(aiSlidesControllerProvider.notifier)
        .generate('no user');
    expect(generation.calls, 0);
    expect(container.read(aiSlidesControllerProvider).error, contains('로그인'));
    expect(storage.drafts.containsKey(''), false);
  });

  test('saved account theme is applied on generation and never copies lesson timings', () async {
    storage.themes['alice'] = const AiSlideTheme(
      designBackgroundColor: 0xFFFFFFFF,
      designAccentColor: 0xFF0055AA,
      designLayout: 'cards',
      designFontWeight: 700,
      designItalic: false,
      designSpacing: 1.15,
      showTimer: false,
      timerX: 0.16,
    );
    container.read(aiSlidesControllerProvider);
    await settle(container);
    final controller = container.read(aiSlidesControllerProvider.notifier);
    await controller.generate('lesson');
    final draft = container.read(aiSlidesControllerProvider).draft!;
    expect(draft.designLayout, 'cards');
    expect(draft.designAccentColor, 0xFF0055AA);
    expect(draft.timerX, 0.16);
    expect(draft.showTimer, false);
    expect(draft.title, example.title);
    expect(draft.lines, example.lines);
    expect(draft.workSeconds, example.workSeconds);
    controller.updateDraft(draft.copyWith(designAccentColor: 0xFFAA5500));
    await controller.saveTheme();
    expect(storage.themes['alice']?.designAccentColor, 0xFFAA5500);
    expect(container.read(aiSlidesControllerProvider).themeSaved, true);
    final json = AiSlideThemeModel.fromEntity(storage.themes['alice']!)
        .toJson();
    expect(json.keys, isNot(contains('title')));
    expect(json.keys, isNot(contains('workSeconds')));
  });

  test('theme sync does not recolor existing draft without explicit apply and undo', () async {
    container.read(aiSlidesControllerProvider);
    await settle(container);
    final controller = container.read(aiSlidesControllerProvider.notifier);
    await controller.generate('lesson');
    storage.themeUpdates['alice']!.add(
      const AiSlideTheme(designAccentColor: 0xFF123456),
    );
    await settle(container);
    expect(
      container.read(aiSlidesControllerProvider).draft!.designAccentColor,
      isNull,
    );
    controller.applyTheme();
    expect(
      container.read(aiSlidesControllerProvider).draft!.designAccentColor,
      0xFF123456,
    );
    controller.undo();
    expect(
      container.read(aiSlidesControllerProvider).draft!.designAccentColor,
      isNull,
    );
    for (var i = 0; i < 30; i++) {
      controller.updateDraft(example.copyWith(title: 'edit $i'));
    }
    for (var i = 0; i < 20; i++) {
      controller.undo();
    }
    expect(container.read(aiSlidesControllerProvider).canUndo, false);
  });

  test(
    'theme save completion does not mark later visual edits as saved',
    () async {
      container.read(aiSlidesControllerProvider);
      await settle(container);
      final controller = container.read(aiSlidesControllerProvider.notifier);
      await controller.generate('lesson');
      storage.savingTheme = Completer<void>();
      final saving = controller.saveTheme();
      controller.updateDraft(example.copyWith(designAccentColor: 0xFF991122));
      storage.savingTheme!.complete();
      await saving;
      expect(container.read(aiSlidesControllerProvider).themeSaved, false);
      expect(
        container.read(aiSlidesControllerProvider).draft!.designAccentColor,
        0xFF991122,
      );
      expect(storage.themes['alice']!.designAccentColor, isNull);
    },
  );

  test(
    'disposing before the debounce flushes the latest captured account draft',
    () async {
      container.read(aiSlidesControllerProvider);
      await settle(container);
      container
          .read(aiSlidesControllerProvider.notifier)
          .setPrompt('last typed text');
      container.invalidate(aiSlidesControllerProvider);
      await settle(container);
      expect(storage.drafts['alice']?.prompt, 'last typed text');
    },
  );

  test('first generation waits for delayed saved theme while restoring content immediately', () async {
    storage.initialTheme = Completer<void>();
    storage.drafts['alice'] = const AiSlidesSavedDraft(
      prompt: 'saved prompt',
      draft: example,
    );
    storage.themes['alice'] = const AiSlideTheme(designAccentColor: 0xFF123456);
    container.read(aiSlidesControllerProvider);
    await settle(container);
    expect(container.read(aiSlidesControllerProvider).draft, example);
    expect(container.read(aiSlidesControllerProvider).loading, true);
    final controller = container.read(aiSlidesControllerProvider.notifier);
    await controller.generate('next lesson');
    expect(generation.calls, 0);
    storage.initialTheme!.complete();
    await settle(container);
    expect(container.read(aiSlidesControllerProvider).loading, false);
    await controller.generate('next lesson');
    expect(
      container.read(aiSlidesControllerProvider).draft!.designAccentColor,
      0xFF123456,
    );
  });

  testWidgets(
    'unavailable initial theme falls back after six seconds and late arrival preserves edits',
    (tester) async {
      storage.initialTheme = Completer<void>();
      storage.themes['alice'] = const AiSlideTheme(
        designAccentColor: 0xFF123456,
      );
      container.read(aiSlidesControllerProvider);
      await tester.pump();
      expect(container.read(aiSlidesControllerProvider).loading, true);
      await tester.pump(const Duration(seconds: 6));
      expect(container.read(aiSlidesControllerProvider).loading, false);
      expect(
        container.read(aiSlidesControllerProvider).themeError,
        contains('기본 테마'),
      );
      container
          .read(aiSlidesControllerProvider.notifier)
          .updateDraft(example.copyWith(title: 'Keep edited'));
      storage.initialTheme!.complete();
      await tester.pump();
      final state = container.read(aiSlidesControllerProvider);
      expect(state.theme!.designAccentColor, 0xFF123456);
      expect(state.draft!.title, 'Keep edited');
      expect(state.draft!.designAccentColor, isNull);
      await container.read(aiSlidesControllerProvider.notifier).flush();
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  test(
    'initial theme stream failure releases loading with a recoverable notice',
    () async {
      storage.failTheme = true;
      container.read(aiSlidesControllerProvider);
      await settle(container);
      expect(container.read(aiSlidesControllerProvider).loading, false);
      expect(container.read(aiSlidesControllerProvider).themeError, isNotNull);
      await container
          .read(aiSlidesControllerProvider.notifier)
          .generate('new lesson');
      expect(container.read(aiSlidesControllerProvider).draft, example);
    },
  );

  test('Firestore ignores an absent local cache but accepts server absence and existing offline presets', () async {
    final document = ThemeDocument();
    final source = AiSlidesThemeFirestoreDataSource(
      ThemeFirestore(document),
      ThemeAuth(),
    );
    final values = <AiSlideThemeModel?>[];
    final subscription = source.watch('alice').listen(values.add);
    document.updates.add(ThemeSnapshot(cached: true));
    await Future<void>.delayed(Duration.zero);
    expect(values, isEmpty);
    expect(document.metadataRequests, [true]);
    document.updates.add(ThemeSnapshot(cached: false));
    await Future<void>.delayed(Duration.zero);
    expect(values, [null]);
    document.updates.add(
      ThemeSnapshot(
        cached: true,
        value: const AiSlideThemeModel(designLayout: 'cards').toJson(),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(values.last!.designLayout, 'cards');
    await subscription.cancel();
    await document.updates.close();
  });

  test(
    'clear during generation does not resurrect discarded content',
    () async {
      container.read(aiSlidesControllerProvider);
      await settle(container);
      generation.pending = Completer<AiSlidesResult>();
      final controller = container.read(aiSlidesControllerProvider.notifier);
      final done = controller.generate('discard');
      await settle(container);
      await controller.clearDraft();
      generation.pending!.complete(
        const AiSlidesResult(slides: [example], warnings: [], remaining: 29),
      );
      await done;
      expect(container.read(aiSlidesControllerProvider).draft, isNull);
      expect(storage.drafts['alice'], isNull);
    },
  );

  test(
    'flush reports storage failure and retries without losing edits',
    () async {
      container.read(aiSlidesControllerProvider);
      await settle(container);
      final controller = container.read(aiSlidesControllerProvider.notifier);
      controller.updateDraft(example);
      storage.failSave = true;
      await controller.flush();
      expect(
        container.read(aiSlidesControllerProvider).storageError,
        isNotNull,
      );
      expect(container.read(aiSlidesControllerProvider).draft, example);
      storage.failSave = false;
      await controller.flush();
      expect(container.read(aiSlidesControllerProvider).storageError, isNull);
      expect(storage.drafts['alice']?.draft, example);
    },
  );

  test('local queue serializes clear after a pending save and isolates account keys', () async {
    final prefs = MemoryPreferences()..hold = Completer<void>();
    final source = AiSlidesDraftLocalDataSource(preferences: prefs);
    final model = AiSlidesSavedDraftModel.fromEntity(
      const AiSlidesSavedDraft(prompt: 'private', draft: example),
    );
    final save = source.write('alice', model);
    final clear = source.write('alice', null);
    final other = source.write('bob', model);
    prefs.hold!.complete();
    await Future.wait([save, clear, other]);
    expect(await source.read('alice'), isNull);
    expect((await source.read('bob'))!.toEntity().draft, example);
    expect(() => source.write('', model), throwsA(isA<AiSlidesFailure>()));
    prefs.fail = true;
    await expectLater(source.write('bob', model), throwsStateError);
    await source.write('bob', null);
    expect(await source.read('bob'), isNull);
  });

  test('draft codec restores all visual fields and rejects corrupt theme coordinates', () {
    final draft = example.copyWith(
      designLayout: 'columns',
      designFontWeight: 700,
      designSpacing: 0.85,
      designItalic: false,
      showTimer: false,
      timerX: 0.2,
      timerY: 0.3,
      timerSize: 1.25,
      designAccentColor: 0xFF334455,
    );
    final saved = AiSlidesSavedDraft(
      prompt: 'raw notes',
      generatedPrompt: 'raw notes',
      draft: draft,
      warnings: ['Note'],
    );
    final encoded = jsonEncode(
      AiSlidesSavedDraftModel.fromEntity(saved).toJson(),
    );
    expect(
      AiSlidesSavedDraftModel.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      ).toEntity(),
      saved,
    );
    expect(
      () => const AiSlideThemeModel(timerX: 2).toEntity(),
      throwsFormatException,
    );
    expect(
      () => const AiSlideThemeModel(designSpacing: 0.7).toEntity(),
      throwsFormatException,
    );
    expect(
      () => const AiSlideThemeModel(designLayout: 'unknown').toEntity(),
      throwsFormatException,
    );
  });
}
