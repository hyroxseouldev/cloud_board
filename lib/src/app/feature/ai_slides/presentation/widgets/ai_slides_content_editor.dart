import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_editor_controls.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_design_section_editor.dart';

class AiSlidesContentEditor extends StatelessWidget {
  const AiSlidesContentEditor({
    super.key,
    required this.draft,
    required this.warnings,
    required this.onChanged,
  });
  final AiSlideDraft draft;
  final List<String> warnings;
  final ValueChanged<AiSlideDraft> onChanged;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final warning in warnings) AiSlidesNotice(warning),
        AiSlidesSyncedField(
          fieldKey: const ValueKey('ai-slide-title'),
          value: draft.title,
          label: '슬라이드 제목',
          maxLength: 60,
          onChanged: (value) => onChanged(draft.copyWith(title: value)),
        ),
        const SizedBox(height: 8),
        SlideDesignSectionEditor(
          keyPrefix: 'ai-section',
          text: draft.lines.join('\n'),
          onChanged: (value) =>
              onChanged(draft.copyWith(lines: value.split('\n'))),
        ),
        const SizedBox(height: 8),
        const Text(
          '운동 순서·횟수·단위를 확인해 주세요. 타이머는 슬라이드를 추가한 뒤에도 설정할 수 있어요.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
