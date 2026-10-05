import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_editor_actions.dart';
part 'ai_slides_controller.g.dart';

@riverpod
Future<AiSlidesAccess> aiSlidesAccess(Ref ref) {
  ref.watch(aiSlidesOwnerIdProvider);
  return ref.watch(aiSlidesActionsProvider).access();
}

/// An anonymous display must never share its linked account's editing cache.
@riverpod
String? aiSlidesOwnerId(Ref ref) {
  final user = ref.watch(firebaseAccountUserProvider).value;
  return user == null || user.isAnonymous ? null : user.uid;
}

@Riverpod(keepAlive: true)
class AiSlidesController extends _$AiSlidesController {
  late _EditorSession _session;

  @override
  AiSlidesEditorState build() {
    final ownerId = ref.watch(aiSlidesOwnerIdProvider);
    final session = _EditorSession(ownerId);
    _session = session;
    ref.onDispose(() {
      session.disposed = true;
      session.debounce?.cancel();
      session.finishThemeLoading();
      unawaited(session.themeSubscription?.cancel());
      // Use only the captured account/snapshot, never a new account's state.
      if (session.ready && session.changed && session.ownerId != null) {
        unawaited(
          session.actions!
              .saveDraft(session.ownerId!, session.snapshot)
              .catchError((Object _) {}),
        );
      }
    });
    if (ownerId == null) return const AiSlidesEditorState(loading: false);
    session.actions = ref.watch(aiSlidesEditorActionsProvider);
    Future.microtask(() => _restore(session));
    return const AiSlidesEditorState();
  }

  bool _current(_EditorSession session) =>
      ref.mounted &&
      !session.disposed &&
      ref.read(aiSlidesOwnerIdProvider) == session.ownerId &&
      !session.disposed &&
      identical(_session, session);

  Future<void> _restore(_EditorSession session) async {
    if (!_current(session)) return;
    final actions = session.actions!;
    session.themeTimeout = Timer(const Duration(seconds: 6), () {
      if (_current(session)) {
        state = state.copyWith(
          themeError: '센터 테마를 확인하지 못해 기본 테마로 시작해요. 연결되면 저장한 테마를 적용할 수 있어요.',
        );
      }
      session.finishThemeLoading();
    });
    try {
      session.themeSubscription = actions
          .watchTheme(session.ownerId!)
          .listen(
            (theme) {
              if (!_current(session)) return;
              // Sync the saved preset without silently recoloring an edited lesson.
              state = state.copyWith(theme: theme, themeError: null);
              session.finishThemeLoading();
            },
            onError: (Object _) {
              if (_current(session)) {
                state = state.copyWith(
                  themeError: '센터 테마를 불러오지 못했어요. 연결을 확인해 주세요.',
                );
              }
              session.finishThemeLoading();
            },
            onDone: session.finishThemeLoading,
          );
    } catch (_) {
      if (_current(session)) {
        state = state.copyWith(themeError: '센터 테마를 불러오지 못했어요. 연결을 확인해 주세요.');
      }
      session.finishThemeLoading();
    }
    try {
      final saved = await actions.loadDraft(session.ownerId!);
      if (!_current(session)) return;
      if (!session.changed && saved != null) {
        state = state.copyWith(
          prompt: saved.prompt,
          generatedPrompt: saved.generatedPrompt,
          draft: saved.draft,
          warnings: saved.warnings,
        );
        session.snapshot = saved;
      }
    } catch (_) {
      if (_current(session)) {
        state = state.copyWith(storageError: '이 기기의 임시저장을 불러오지 못했어요.');
      }
    } finally {
      if (_current(session)) {
        session.ready = true;
        if (session.changed) _schedule();
      }
    }
    // A cached generation can finish faster than the first remote preset read.
    // Restore content immediately, but wait briefly before enabling generation.
    await session.initialTheme.future;
    if (_current(session)) state = state.copyWith(loading: false);
  }

  AiSlidesSavedDraft _snapshot() => AiSlidesSavedDraft(
    prompt: state.prompt,
    generatedPrompt: state.generatedPrompt,
    draft: state.draft,
    warnings: state.warnings,
  );

  void setPrompt(String prompt) {
    if (state.prompt == prompt) return;
    state = state.copyWith(prompt: prompt, error: null);
    _schedule();
  }

  void _remember() {
    _session.history.add(_snapshot());
    if (_session.history.length > 20) _session.history.removeAt(0);
  }

  void updateDraft(AiSlideDraft draft) {
    if (draft == state.draft) return;
    _remember();
    _session.draftRevision++;
    state = state.copyWith(
      draft: draft,
      canUndo: true,
      themeSaved: false,
      error: null,
    );
    _schedule();
  }

  void undo() {
    if (_session.history.isEmpty) return;
    final previous = _session.history.removeLast();
    _session.draftRevision++;
    state = state.copyWith(
      prompt: previous.prompt,
      generatedPrompt: previous.generatedPrompt,
      draft: previous.draft,
      warnings: previous.warnings,
      canUndo: _session.history.isNotEmpty,
      error: null,
      themeSaved: false,
    );
    _schedule();
  }

  void dismissError() => state = state.copyWith(error: null);

  Future<void> generate(String prompt) async {
    if (state.generating || state.loading) return;
    final session = _session;
    if (session.ownerId == null) {
      state = state.copyWith(error: '로그인 후 이용해 주세요.');
      return;
    }
    setPrompt(prompt);
    final normalized = prompt.replaceAll('\r\n', '\n').trim();
    // The server returns the same cached draft for this input. Retain local edits.
    if (state.draft != null && state.generatedPrompt == normalized) return;
    final revision = session.draftRevision;
    final actions = ref.read(aiSlidesActionsProvider);
    state = state.copyWith(generating: true, error: null);
    await flush();
    if (!_current(session)) return;
    final result = await AsyncValue.guard(() => actions.generate(normalized));
    if (!_current(session)) return;
    ref.invalidate(aiSlidesAccessProvider);
    final generated = result.asData?.value;
    if (generated == null) {
      final error = result.error;
      state = state.copyWith(
        generating: false,
        error: error is AiSlidesFailure
            ? error.message
            : '초안을 만들지 못했어요. 잠시 후 다시 시도해 주세요.',
      );
      return;
    }
    if (generated.slides.length != 1) {
      state = state.copyWith(
        generating: false,
        error: '슬라이드 응답을 읽지 못했어요. 다시 시도해 주세요.',
      );
      return;
    }
    if (revision != session.draftRevision) {
      state = state.copyWith(
        generating: false,
        remaining: generated.remaining,
        error: '생성 중 수정한 내용이 있어 현재 초안을 유지했어요.',
      );
      return;
    }
    _remember();
    final theme = state.theme;
    final draft = generated.slides.single;
    state = state.copyWith(
      generatedPrompt: normalized,
      draft: theme == null ? draft : applyAiSlideTheme(draft, theme),
      warnings: generated.warnings,
      generating: false,
      canUndo: true,
      remaining: generated.remaining,
      cached: generated.cached,
      themeSaved: false,
    );
    session.draftRevision++;
    _schedule();
    await flush();
  }

  void _schedule() {
    final session = _session;
    session.snapshot = _snapshot();
    session.changed = true;
    session.debounce?.cancel();
    if (!session.ready || session.ownerId == null) return;
    session.debounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(flush()),
    );
  }

  /// Call on sheet dismissal and app lifecycle changes to flush the debounce.
  Future<void> flush() async {
    final session = _session;
    session.debounce?.cancel();
    if (!session.ready || session.ownerId == null || !session.changed) return;
    final snapshot = session.snapshot;
    try {
      await session.actions!.saveDraft(session.ownerId!, snapshot);
      if (_current(session) && session.snapshot == snapshot) {
        session.changed = false;
        state = state.copyWith(storageError: null);
      }
    } catch (_) {
      if (_current(session)) {
        state = state.copyWith(
          storageError: '임시저장에 실패했어요. 앱을 닫기 전에 다시 시도해 주세요.',
        );
      }
    }
  }

  Future<void> clearDraft() async {
    final session = _session;
    // A completion from an earlier request must not recreate a discarded draft.
    session.draftRevision++;
    session.history.clear();
    state = state.copyWith(
      prompt: '',
      generatedPrompt: null,
      draft: null,
      warnings: [],
      canUndo: false,
      error: null,
      themeSaved: false,
    );
    _schedule();
    session.snapshot = null;
    await flush();
  }

  Future<void> saveTheme() async {
    final session = _session;
    final draft = state.draft;
    if (draft == null || session.ownerId == null || state.themeSaving) return;
    final theme = aiSlideThemeFromDraft(draft);
    state = state.copyWith(
      themeSaving: true,
      themeSaved: false,
      themeError: null,
    );
    final result = await AsyncValue.guard(
      () => session.actions!.saveTheme(session.ownerId!, theme),
    );
    if (!_current(session)) return;
    state = state.copyWith(
      themeSaving: false,
      theme: result.hasError ? state.theme : theme,
      themeSaved:
          !result.hasError &&
          state.draft != null &&
          aiSlideThemeFromDraft(state.draft!) == theme,
      themeError: result.hasError
          ? '센터 테마를 저장하지 못했어요. 연결을 확인한 뒤 다시 시도해 주세요.'
          : null,
    );
  }

  void applyTheme() {
    final draft = state.draft;
    final theme = state.theme;
    if (draft != null && theme != null) {
      updateDraft(applyAiSlideTheme(draft, theme));
    }
  }
}

class _EditorSession {
  _EditorSession(this.ownerId);
  final String? ownerId;
  AiSlidesEditorActions? actions;
  AiSlidesSavedDraft? snapshot;
  bool ready = false, changed = false, disposed = false;
  int draftRevision = 0;
  Timer? debounce;
  Timer? themeTimeout;
  final initialTheme = Completer<void>();
  StreamSubscription<AiSlideTheme?>? themeSubscription;
  final List<AiSlidesSavedDraft> history = [];

  void finishThemeLoading() {
    themeTimeout?.cancel();
    if (!initialTheme.isCompleted) initialTheme.complete();
  }
}
