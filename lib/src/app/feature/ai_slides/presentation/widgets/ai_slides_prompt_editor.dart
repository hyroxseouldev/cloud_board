import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_editor_controls.dart';

class AiSlidesPromptEditor extends StatelessWidget {
  const AiSlidesPromptEditor({
    super.key,
    required this.state,
    required this.access,
    required this.allowed,
    required this.onChanged,
    required this.onGenerate,
    required this.onRetryAccess,
  });
  final AiSlidesEditorState state;
  final AsyncValue<AiSlidesAccess> access;
  final bool allowed;
  final ValueChanged<String> onChanged;
  final VoidCallback onGenerate, onRetryAccess;
  @override
  Widget build(BuildContext context) {
    final unchanged =
        state.draft != null &&
        state.prompt.trim() == state.generatedPrompt?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          state.draft == null ? '오늘 수업을 한 장으로' : '원문에서 새 초안 만들기',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          state.draft == null
              ? '수업 내용을 붙여넣으면 섹션별로 정리해요. 색상과 배치는 자유롭게 바꿀 수 있어요.'
              : '원문을 바꾸면 새 초안을 만들어요. 배치만 바꾸려면 디자인 탭을 이용하세요.',
        ),
        const SizedBox(height: 12),
        if (state.themeError != null) AiSlidesNotice(state.themeError!),
        access.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Row(
            children: [
              Expanded(child: Text('$error')),
              TextButton(onPressed: onRetryAccess, child: const Text('다시 확인')),
            ],
          ),
          data: (value) => Text(
            !value.premium
                ? '프리미엄 전용 기능이에요.'
                : !value.enabled
                ? 'AI 기능을 준비 중이에요.'
                : '이번 달 ${state.remaining ?? value.remaining}/${value.limit}회 남음',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        AiSlidesSyncedField(
          fieldKey: const ValueKey('ai-slides-prompt'),
          value: state.prompt,
          label: '수업 내용',
          minLines: 5,
          maxLines: 10,
          maxLength: 6000,
          onChanged: onChanged,
          hint: 'WARM UP\n스쿼트 10회 / 런지 10회\n\nMAIN\nRUN 1km\nROW 500m',
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const ValueKey('ai-slides-generate'),
          onPressed:
              !allowed ||
                  state.loading ||
                  state.generating ||
                  state.prompt.trim().isEmpty ||
                  unchanged
              ? null
              : onGenerate,
          icon: state.generating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_rounded, size: 18),
          label: Text(
            state.generating
                ? '슬라이드 구성 중…'
                : state.draft == null
                ? '초안 만들기'
                : '변경한 내용으로 생성',
          ),
        ),
        if (state.generating)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '초안을 만들고 있어요. 창을 닫아도 다시 이어서 편집할 수 있어요.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        if (state.draft == null && state.error != null)
          AiSlidesNotice(state.error!, error: true),
      ],
    );
  }
}
