import 'package:cloud_board/src/app/core/config/app_brand.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/audience_branding_copy.dart';

class BrandingPlanNotice extends ConsumerWidget {
  const BrandingPlanNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = audienceClassBrandingAvailable(
      ref.watch(audienceBrandingProvider),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '센터 브랜딩은 Plus부터',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Free는 ${available ? '대기·수업 화면' : '대기 화면'}에 ${AppBrand.name} 로고를 표시합니다. Plus부터 제품 로고를 숨길 수 있어요.',
            ),
            const SizedBox(height: 8),
            const Text('대기 화면의 배경·안내 문구·센터 로고도 Plus부터 설정할 수 있어요.'),
            const SizedBox(height: 8),
            const Text('기존 설정과 로고는 보관되어 있어요. 다시 업그레이드하면 그대로 복원됩니다.'),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.push('/subscription'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Plus 알아보기'),
            ),
          ],
        ),
      ),
    );
  }
}
