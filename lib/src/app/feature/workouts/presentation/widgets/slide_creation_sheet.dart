import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/core/theme/app_style.dart';

enum SlideCreationMethod { blank, design }

Future<SlideCreationMethod?> showSlideCreationSheet(BuildContext context) =>
    showModalBottomSheet<SlideCreationMethod>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: AppStyle.fullWidth),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .8,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '슬라이드 추가',
                          style: AppStyle.of(sheetContext).subText2,
                        ),
                      ),
                      CloseButton(onPressed: () => Navigator.pop(sheetContext)),
                    ],
                  ),
                  Text(
                    '만드는 방법을 선택해 주세요.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  for (final option in const [
                    (
                      method: SlideCreationMethod.blank,
                      icon: Icons.note_add_outlined,
                      title: '빈 슬라이드 추가',
                      description: '운동 내용과 타이머를 직접 설정해요.',
                    ),
                    (
                      method: SlideCreationMethod.design,
                      icon: Icons.auto_awesome_rounded,
                      title: '템플릿·AI로 만들기',
                      description: '템플릿을 고르거나 AI로 수업 이미지를 만들어요.',
                    ),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: theme.colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppStyle.controlRadius,
                          ),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          key: ValueKey('create-slide-${option.method.name}'),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          leading: Icon(
                            option.icon,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(
                            option.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(option.description),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () =>
                              Navigator.pop(sheetContext, option.method),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
