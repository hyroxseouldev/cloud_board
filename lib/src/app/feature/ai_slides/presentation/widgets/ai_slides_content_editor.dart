import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';
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
    final template = originalSlideTemplate(draft.designStyle?.originalTemplate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final warning in warnings) AiSlidesNotice(warning),
        if (draft.designStyle?.originalTemplate == null)
          AiSlidesSyncedField(
            fieldKey: const ValueKey('ai-slide-header'),
            value: draft.designHeaderLabel,
            label: '클래스 이름 · 분류',
            maxLength: 60,
            onChanged: (value) =>
                onChanged(draft.copyWith(designHeaderLabel: value)),
          ),
        const SizedBox(height: 8),
        if (template?.fixedTitle == true)
          TextFormField(
            key: const ValueKey('ai-slide-title'),
            initialValue: template!.title,
            readOnly: true,
            enableInteractiveSelection: false,
            decoration: const InputDecoration(
              labelText: '원본 제목 (고정)',
              helperText: '제목과 한자 장식은 원본 그대로 유지해요.',
            ),
          )
        else
          AiSlidesSyncedField(
            fieldKey: const ValueKey('ai-slide-title'),
            value: draft.title,
            label: '슬라이드 제목',
            maxLength: 60,
            onChanged: (value) => onChanged(draft.copyWith(title: value)),
          ),
        const SizedBox(height: 8),
        AiSlidesSyncedField(
          fieldKey: const ValueKey('ai-slide-subtitle'),
          value: draft.designSubtitle,
          label: '운동 안내 · 시간 문구',
          maxLength: 120,
          onChanged: (value) =>
              onChanged(draft.copyWith(designSubtitle: value)),
        ),
        const SizedBox(height: 8),
        if (draft.designStyle?.originalTemplate != null)
          AiSlidesSyncedField(
            fieldKey: const ValueKey('ai-original-lines'),
            value: draft.lines.join('\n'),
            label: '운동 문구 (최대 ${template!.maxLines}행)',
            minLines: template.maxLines,
            maxLines: template.maxLines,
            maxLength: template.maxLines * 121 - 1,
            onChanged: (value) =>
                onChanged(draft.copyWith(lines: value.split('\n'))),
          )
        else
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
