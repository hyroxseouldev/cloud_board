import 'dart:async';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/onboarding_controller.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slide_design_actions.dart';

part 'ai_slide_design_controller.g.dart';

@riverpod
String? aiSlideDesignOwnerId(Ref ref) {
  final user = ref.watch(firebaseAccountUserProvider).value;
  return user == null || user.isAnonymous ? null : user.uid;
}

/// An absent onboarding record keeps the existing owner's library usable.
/// A real center ID is never replaced with the owner's UID.
@riverpod
String? aiSlideDesignStoreId(Ref ref) {
  final id = ref.watch(
    onboardingControllerProvider.select((value) => value.value?.storeId),
  );
  return id == null || id.isEmpty ? null : id;
}

@riverpod
Future<AiSlidesAccess> aiSlideDesignAccess(Ref ref) {
  final owner = ref.watch(aiSlideDesignOwnerIdProvider);
  if (owner == null) {
    return Future.value(
      const AiSlidesAccess(
        premium: false,
        enabled: false,
        remaining: 0,
        limit: 0,
      ),
    );
  }
  return ref.watch(aiSlideDesignActionsProvider).access(owner);
}

@Riverpod(keepAlive: true)
class AiSlideDesignController extends _$AiSlideDesignController {
  late _DesignSession _session;
  @override
  AiSlideDesignStudioState build() {
    final owner = ref.watch(aiSlideDesignOwnerIdProvider);
    final store = ref.watch(aiSlideDesignStoreIdProvider);
    final session = _DesignSession(owner, store);
    _session = session;
    ref.onDispose(() {
      session.disposed = true;
      unawaited(session.subscription?.cancel());
    });
    if (owner != null) {
      session.actions = ref.watch(aiSlideDesignActionsProvider);
      Future.microtask(() => _restore(session));
    }
    return AiSlideDesignStudioState(templatesLoading: owner != null);
  }

  bool _current(_DesignSession session) =>
      ref.mounted && !session.disposed && identical(_session, session);

  Future<void> _restore(_DesignSession session) async {
    if (!_current(session)) return;
    try {
      session.subscription = session.actions!
          .watchTemplates(session.ownerId!, session.storeId)
          .listen(
            (templates) {
              if (_current(session)) {
                state = state.copyWith(
                  templates: templates,
                  templatesLoading: false,
                  templateError: null,
                );
              }
            },
            onError: (Object error) {
              if (_current(session)) {
                state = state.copyWith(
                  templatesLoading: false,
                  templateError: _message(
                    error,
                    '저장한 클래스를 불러오지 못했어요. 기본 디자인은 계속 사용할 수 있어요.',
                  ),
                );
              }
            },
          );
      final selected = await session.actions!.loadSelected(
        session.ownerId!,
        session.storeId,
      );
      if (_current(session) && !session.selectedByUser && selected != null) {
        state = state.copyWith(
          selected: selected.copyWith(storeId: session.storeId),
        );
      }
    } catch (error) {
      if (_current(session)) {
        state = state.copyWith(
          templatesLoading: false,
          templateError: _message(error, '최근 디자인을 불러오지 못했어요. 다시 선택해 주세요.'),
        );
      }
    }
  }

  void dismissError() => state = state.copyWith(error: null);

  Future<void> select(AiSlideDesign design) async {
    final session = _session;
    session.selectedByUser = true;
    final selected = design.copyWith(storeId: session.storeId);
    state = state.copyWith(selected: selected, saved: false, error: null);
    if (session.ownerId == null) return;
    try {
      await session.actions!.saveSelected(
        session.ownerId!,
        session.storeId,
        selected,
      );
    } catch (error) {
      if (_current(session)) {
        state = state.copyWith(
          error: _message(error, '최근 디자인을 이 기기에 저장하지 못했어요.'),
        );
      }
    }
  }

  Future<void> generate(String prompt, {Uint8List? reference}) async {
    if (state.generating) return;
    final session = _session;
    if (session.ownerId == null) {
      state = state.copyWith(error: '로그인 후 디자인 추천을 이용해 주세요.');
      return;
    }
    state = state.copyWith(generating: true, error: null, warnings: []);
    final result = await AsyncValue.guard(
      () => session.actions!.generate(
        session.ownerId!,
        prompt,
        reference: reference,
      ),
    );
    if (!_current(session)) return;
    ref.invalidate(aiSlideDesignAccessProvider);
    final value = result.asData?.value;
    state = value == null
        ? state.copyWith(
            generating: false,
            error: _message(result.error, '디자인을 만들지 못했어요. 다시 시도해 주세요.'),
          )
        : state.copyWith(
            generating: false,
            proposals: value.designs,
            warnings: value.warnings,
            remaining: value.remaining,
          );
  }

  Future<bool> saveClass(String name, AiSlideTheme theme) async {
    if (state.saving) return false;
    final session = _session;
    if (session.ownerId == null) {
      state = state.copyWith(error: '로그인 후 클래스 디자인을 저장해 주세요.');
      return false;
    }
    final design = AiSlideDesign(
      id: 'ai-design-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      description: '클래스 기본 디자인',
      storeId: session.storeId,
      theme: theme,
    );
    state = state.copyWith(saving: true, saved: false, error: null);
    final result = await AsyncValue.guard(
      () => session.actions!.saveTemplate(session.ownerId!, design),
    );
    if (!_current(session)) return false;
    state = state.copyWith(
      saving: false,
      saved: !result.hasError,
      error: result.hasError
          ? _message(result.error, '클래스 디자인을 저장하지 못했어요. 연결을 확인하고 다시 시도해 주세요.')
          : null,
    );
    if (result.hasError) return false;
    await select(design);
    if (_current(session)) state = state.copyWith(saved: true);
    return true;
  }

  String _message(Object? error, String fallback) =>
      error is AiSlidesFailure ? error.message : fallback;
}

class _DesignSession {
  _DesignSession(this.ownerId, this.storeId);
  final String? ownerId, storeId;
  AiSlideDesignActions? actions;
  StreamSubscription<List<AiSlideDesign>>? subscription;
  bool disposed = false, selectedByUser = false;
}
