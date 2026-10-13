import 'package:cloud_board/src/app/core/config/app_brand.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BrandingPlanNotice extends StatelessWidget {
  const BrandingPlanNotice({super.key});
  @override
  Widget build(BuildContext context) => Card(
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
          const Text(
            'Free에서는 기본 대기 화면과 ${AppBrand.name} 로고를 표시합니다. Plus부터 배경·안내 문구·센터 로고를 설정하고 ${AppBrand.name} 로고를 숨길 수 있어요.',
          ),
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
