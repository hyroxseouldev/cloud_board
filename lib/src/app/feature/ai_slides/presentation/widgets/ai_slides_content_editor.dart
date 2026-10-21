import 'dart:convert';

import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/center_slide_flow_renderer.dart';

import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_line_groups.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_flow.dart';

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
    final flow = draft.centerRecipe!.body != null;
    final groups = centerSlideLineGroups(draft.centerRecipe!);
    final assigned = groups.expand((group) => group).toSet();
    final extra = [
      for (var index = 0; index < draft.lines.length; index++)
        if (!assigned.contains(index) && draft.lines[index].isNotEmpty) index,
    ];

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
        if (flow) ...[
          const SizedBox(height: 12),
          AiSlidesSyncedField(
            fieldKey: const ValueKey('ai-center-wod'),
            exactTextSync: true,
            value: draft.lines.join('\n'),
            label: '와드 내용',
            hint: 'A. Running\n• Run 90s\n\nB. Strength\n1. Bench Press\n• 80% · 5 sets',
            minLines: 12,
            maxLines: 24,
            errorText: centerSlideFlowContentError(draft.lines),
            onChanged: (value) => onChanged(
              draft.copyWith(
                lines: value
                    .replaceAll('\r\n', '\n')
                    .replaceAll('\r', '\n')
                    .split('\n'),
              ),
            ),
          ),
        ],
        if (flow)
          Builder(
            builder: (context) => Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('ai-center-auto-fit'),
                icon: const Icon(Icons.format_size),
                label: const Text('본문 자동 맞춤 · 되돌리기 가능'),
                onPressed: () {
                  try {
                    final layout = layoutCenterSlideFlow(
                      recipe: draft.centerRecipe!,
                      lines: draft.lines,
                      outputScale: 1920 / draft.centerRecipe!.width,
                      fixedColumns: draft.centerColumns,
                      autoFit: true,
                    );
                    final size = layout.fontSize;
                    layout.dispose();
                    onChanged(draft.copyWith(centerFontSize: size));
                  } on FormatException catch (error) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(error.message)));
                  }
                },
              ),
            ),
          ),
        if (!flow)
          for (final (position, indexes) in groups.indexed) ...[
            const SizedBox(height: 12),
            _CenterColumnField(
              key: ValueKey((draft.centerRecipe, position)),
              fieldKey: ValueKey('ai-center-column-$position'),
              draft: draft,
              indexes: indexes,
              label: groups.length == 1
                  ? '운동 내용'
                  : '${String.fromCharCode(65 + position)} 영역',
              onChanged: onChanged,
            ),
          ],
        if (!flow && extra.isNotEmpty) ...[
          const SizedBox(height: 12),
          _CenterColumnField(
            key: ValueKey((draft.centerRecipe, 'extra')),
            fieldKey: const ValueKey('ai-center-extra-lines'),
            draft: draft,
            indexes: extra,
            label: '템플릿에 없는 내용',
            unmapped: true,
            onChanged: onChanged,
          ),
        ],
        if (validationMessage != null)
          AiSlidesNotice(validationMessage!, error: true),
        const SizedBox(height: 8),
        Text(
          flow
              ? '선택한 열과 글자 크기를 유지해요. A. / B. 또는 ## 제목으로 구역을 나눌 수 있어요. 넘치는 내용은 줄이거나 슬라이드를 나눠 주세요.'
              : '영역별로 내용을 붙여넣고 줄바꿈으로 나눠 주세요. 빈 줄은 해당 위치를 비워 둬요.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class _CenterColumnField extends HookWidget {
  const _CenterColumnField({
    super.key,
    required this.fieldKey,
    required this.draft,
    required this.indexes,
    required this.label,
    required this.onChanged,
    this.unmapped = false,
  });
  final Key fieldKey;
  final AiSlideDraft draft;
  final List<int> indexes;
  final String label;
  final ValueChanged<AiSlideDraft> onChanged;
  final bool unmapped;

  @override
  Widget build(BuildContext context) {
    final values = centerSlideGroupValues(draft.lines, indexes);
    final projection = jsonEncode(values);
    // Keep the exact typed text (including trailing blank lines) while its
    // mapped slots are current. Undo or an external edit restores source text.
    final editing = useState<(String, String)?>(null);
    final value = editing.value?.$1 == projection
        ? editing.value!.$2
        : values.join('\n');
    final rows = value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final error = unmapped
        ? '이 내용은 템플릿에 표시되지 않아요. 다른 영역으로 옮기거나 지워 주세요.'
        : rows.length > indexes.length
        ? '$label은 최대 ${indexes.length}줄까지 넣을 수 있어요. 입력한 내용은 그대로 보관했어요.'
        : rows.any((row) => row.length > 120)
        ? '한 줄에 120자 이내로 입력해 주세요.'
        : null;
    return AiSlidesSyncedField(
      fieldKey: fieldKey,
      value: value,
      label: '$label (최대 ${indexes.length}줄)',
      minLines: indexes.length.clamp(2, 6),
      maxLines: 12,
      // No input formatter truncates pasted content. The error blocks adding.
      errorText: error,
      onChanged: (text) {
        final lines = replaceCenterSlideGroup(draft.lines, indexes, text);
        editing.value = (
          jsonEncode(centerSlideGroupValues(lines, indexes)),
          text,
        );
        onChanged(draft.copyWith(lines: lines));
      },
    );
  }
}
