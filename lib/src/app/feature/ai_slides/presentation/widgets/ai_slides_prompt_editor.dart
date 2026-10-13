import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_editor_controls.dart';

class AiSlidesPromptEditor extends StatelessWidget {
  const AiSlidesPromptEditor({
    super.key,
    required this.state,
    required this.allowed,
    required this.onChanged,
    required this.onGenerate,
  });
  final AiSlidesEditorState state;
  final bool allowed;
  final ValueChanged<String> onChanged;
  final VoidCallback onGenerate;
  @override
  Widget build(BuildContext context) {
    final unchanged =
        state.draft != null &&
        state.prompt.trim() == state.generatedPrompt?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.themeError != null) AiSlidesNotice(state.themeError!),
        AiSlidesSyncedField(
          fieldKey: const ValueKey('ai-slides-prompt'),
          value: state.prompt,
          label: '수업 메모',
          minLines: 7,
          maxLines: 12,
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
          label: Text(state.generating ? '수업 내용 정리 중…' : '수업 내용 정리하기'),
        ),
        if (state.generating)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '수업 내용을 정리하고 있어요. 창을 닫아도 다시 이어서 편집할 수 있어요.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        if (state.draft == null && state.error != null)
          AiSlidesNotice(state.error!, error: true),
      ],
    );
  }
}
