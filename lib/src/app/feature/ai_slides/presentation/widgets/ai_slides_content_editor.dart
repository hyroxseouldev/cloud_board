import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_editor_controls.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_design_section_editor.dart';

class AiSlidesContentEditor extends StatelessWidget {
  const AiSlidesContentEditor({
    super.key,
    required this.draft,
    required this.warnings,
    required this.onChanged,
    this.validationMessage,
  });
  final AiSlideDraft draft;
  final List<String> warnings;
  final ValueChanged<AiSlideDraft> onChanged;
  final String? validationMessage;
  @override
  Widget build(BuildContext context) {
    if (draft.centerRecipe != null) return _centerEditor();
    final template = originalSlideTemplate(draft.designStyle?.originalTemplate);
    final title = draft.title.trim();
    final titleError = title.isEmpty
        ? '제목을 입력해 주세요.'
        : title.length > 60
        ? '제목은 60자 이내로 적어 주세요.'
        : null;
    final subtitleError = draft.designSubtitle.length > 120
        ? '시간 안내는 120자 이내로 적어 주세요.'
        : null;
    final lines = template != null
        ? originalSlideLines(draft.lines.join('\n'))
        : parseSlideDesignSections(draft.lines.join('\n'))
              .expand(
                (section) => [
                  if (section.heading.isNotEmpty) section.heading,
                  ...section.lines,
                ],
              )
              .toList();
    final maxLines = template?.maxLines ?? slideDesignMaxLines;
    final bodyError = lines.length > maxLines
        ? '운동은 최대 $maxLines줄까지 넣을 수 있어요.'
        : template != null &&
              lines.any((line) => line == '##' || line.startsWith('## '))
        ? '섹션 제목을 빼고 운동 내용만 적어 주세요.'
        : lines.any((line) => line.length > slideDesignMaxLineLength)
        ? '긴 문장은 나누어 한 줄에 120자 이내로 적어 주세요.'
        : null;
    final hasFieldError =
        titleError != null || subtitleError != null || bodyError != null;
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
        AiSlidesSyncedField(
          fieldKey: const ValueKey('ai-slide-title'),
          value: draft.title,
          label: '슬라이드 제목',
          maxLength: 60,
          errorText: titleError,
          onChanged: (value) => onChanged(draft.copyWith(title: value)),
        ),
        const SizedBox(height: 8),
        AiSlidesSyncedField(
          fieldKey: const ValueKey('ai-slide-subtitle'),
          value: draft.designSubtitle,
          label: '운동 안내 · 시간 문구',
          maxLength: 120,
          errorText: subtitleError,
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
            errorText: bodyError,
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
        if (template == null && bodyError != null)
          AiSlidesNotice(bodyError, error: true),
        if (!hasFieldError && validationMessage != null)
          AiSlidesNotice(validationMessage!, error: true),
        const SizedBox(height: 8),
        const Text(
          '운동 순서·횟수·단위를 확인해 주세요. 타이머는 슬라이드를 추가한 뒤에도 설정할 수 있어요.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _centerEditor() {
    final fields = draft.centerRecipe!.fields;
    final indexes = {
      ...fields
          .where((field) => field.binding == 'line')
          .map((field) => field.lineIndex!),
      for (var i = 0; i < draft.lines.length; i++)
        if (draft.lines[i].isNotEmpty) i,
    }.toList()..sort();
    void updateLine(int index, String value) {
      final lines = [...draft.lines];
      while (lines.length <= index) {
        lines.add('');
      }
      lines[index] = value;
      onChanged(draft.copyWith(lines: lines));
    }

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
        if (fields.any((field) => field.binding == 'header')) ...[
          const SizedBox(height: 8),
          AiSlidesSyncedField(
            fieldKey: const ValueKey('ai-slide-header'),
            value: draft.designHeaderLabel,
            label: '클래스 이름 · 분류',
            maxLength: 120,
            onChanged: (value) =>
                onChanged(draft.copyWith(designHeaderLabel: value)),
          ),
        ],
        if (fields.any((field) => field.binding == 'subtitle')) ...[
          const SizedBox(height: 8),
          AiSlidesSyncedField(
            fieldKey: const ValueKey('ai-slide-subtitle'),
            value: draft.designSubtitle,
            label: '운동 안내 · 시간 문구',
            maxLength: 120,
            onChanged: (value) =>
                onChanged(draft.copyWith(designSubtitle: value)),
          ),
        ],
        for (final index in indexes) ...[
          const SizedBox(height: 8),
          AiSlidesSyncedField(
            fieldKey: ValueKey('ai-center-line-$index'),
            value: index < draft.lines.length ? draft.lines[index] : '',
            label: '운동 문구 ${index + 1}',
            maxLength: 120,
            onChanged: (value) => updateLine(index, value),
          ),
        ],
        if (validationMessage != null)
          AiSlidesNotice(validationMessage!, error: true),
        const SizedBox(height: 8),
        const Text(
          '빈 문구는 해당 위치에서 지워져요. 타이머는 슬라이드를 추가한 뒤 설정할 수 있어요.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
