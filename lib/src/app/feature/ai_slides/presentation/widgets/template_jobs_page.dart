import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/template_job.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/template_jobs_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/center_slide_catalog_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/template_jobs_panel.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/template_job_image.dart';

/// Only server template jobs establish AI provenance. General saved images and
/// free templates remain in the existing library and are never reclassified.
class TemplateJobsPage extends ConsumerWidget {
  const TemplateJobsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ProviderScope(
    key: ValueKey((
      ref.watch(aiSlidesOwnerIdProvider),
      ref.watch(centerSlideCatalogScopeProvider),
    )),
    overrides: [
      templateJobsControllerProvider.overrideWith(TemplateJobsController.new),
    ],
    child: const _TemplateJobsPage(),
  );
}

class _TemplateJobsPage extends HookConsumerWidget {
  const _TemplateJobsPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(templateJobsControllerProvider);
    final controller = ref.read(templateJobsControllerProvider.notifier);
    final selected = useState<TemplateJob?>(null);
    final bytes = useState<Uint8List?>(null);
    ref.listen(templateJobsControllerProvider, (previous, next) {
      if (next.authorityDenied) {
        bytes.value = null;
        selected.value = null;
      }
    });
    final owner = ref.watch(aiSlidesOwnerIdProvider),
        scope = ref.watch(centerSlideCatalogScopeProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: (MediaQuery.textScalerOf(context).scale(18) * 2.4 + 12)
            .clamp(56, 120),
        title: const Text(
          'AI 생성 슬라이드 관리',
          maxLines: 2,
          style: TextStyle(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('센터 AI 생성 작업만 표시해요. 기본 템플릿과 일반 저장 이미지는 기존 라이브러리에 있어요.'),
            TemplateJobsPanel(
              state: state,
              showAll: true,
              onRefresh: controller.refresh,
              onRecover: controller.recover,
              onRetry: controller.retry,
              onLoadMore: controller.loadMore,
              onOpen: (job) async {
                final result = await controller.open(job);
                if (!context.mounted ||
                    result == null ||
                    ref.read(aiSlidesOwnerIdProvider) != owner ||
                    ref.read(centerSlideCatalogScopeProvider) != scope) {
                  return;
                }
                selected.value = job;
                bytes.value = result;
              },
            ),
            if (bytes.value != null) ...[
              Text(
                selected.value!.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: TemplateJobImage(bytes: bytes.value!),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => context.pop(selected.value),
                icon: const Icon(Icons.open_in_new),
                label: const Text('이 이미지를 열어 저장 / 수업에 사용'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
