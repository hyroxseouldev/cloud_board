import 'dart:async';

import 'package:cloud_board/src/app/feature/entitlement/data/models/store_entitlement_model.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/entities/store_entitlement.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/plan_usage.dart';
import 'package:cloud_board/src/app/feature/entitlement/presentation/controllers/entitlement_controller.dart';
import 'package:cloud_board/src/app/feature/entitlement/presentation/controllers/plan_usage_controller.dart';
import 'package:cloud_board/src/app/feature/entitlement/presentation/widgets/plan_usage_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

StoreEntitlement storageAccess({
  String version = 'plan-entitlements-v1',
  String status = 'trialing',
  int? limit,
  bool unlimited = true,
}) => StoreEntitlementModel.fromJson({
  'policyVersion': version,
  'status': status,
  'plan': 'premium',
  'validUntilMs': 32503647600000,
  'maxWorkouts': limit,
  'workoutsUnlimited': unlimited,
  'maxSavedSlides': null,
  'savedSlidesUnlimited': true,
}).toEntity('owner', true, 1000);

const count = PlanUsage(
  workoutCount: 7,
  savedSlideCount: 3,
  serverConfirmed: true,
);

void main() {
  testWidgets('loading becomes explicit v1 unlimited without deletion advice', (
    tester,
  ) async {
    final access = StreamController<StoreEntitlement?>();
    addTearDown(access.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planAccessProvider.overrideWith((_) => access.stream),
          planUsageProvider.overrideWith((_) => Stream.value(count)),
        ],
        child: const MaterialApp(home: Scaffold(body: PlanUsageNotice())),
      ),
    );
    await tester.pump();
    expect(find.text('저장 수업 7 / 확인 중'), findsOneWidget);
    expect(find.text('저장 한도를 불러오는 중이에요.'), findsOneWidget);
    expect(find.text('사용량 다시 확인'), findsNothing);
    access.add(storageAccess());
    await tester.pumpAndSettle();
    expect(find.text('저장 수업 7 / 무제한'), findsOneWidget);
    expect(find.textContaining('삭제하면 새 수업'), findsNothing);
    expect(find.text('저장 한도를 불러오는 중이에요.'), findsNothing);
  });

  testWidgets('query failure retries and recovers the limit', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planAccessProvider.overrideWith(
            (_) => ++attempts == 1
                ? Stream.error(StateError('offline'))
                : Stream.value(storageAccess()),
          ),
          planUsageProvider.overrideWith((_) => Stream.value(count)),
        ],
        child: const MaterialApp(home: Scaffold(body: PlanUsageNotice())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('저장 수업 7 / 조회 실패'), findsOneWidget);
    expect(find.text('저장 한도를 불러오지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    await tester.tap(find.text('사용량 다시 확인'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('저장 수업 7 / 무제한'), findsOneWidget);
    expect(find.text('사용량 다시 확인'), findsNothing);
  });

  for (final (label, grant) in [
    ('missing', null),
    ('unsupported', storageAccess(version: 'future-policy')),
    ('revoked', storageAccess(status: 'revoked')),
    ('expired', storageAccess(version: '')),
    ('conflicting', storageAccess(limit: 7)),
  ]) {
    testWidgets('$label policy is unavailable, distinguishable from loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            planAccessProvider.overrideWith((_) => Stream.value(grant)),
            planUsageProvider.overrideWith((_) => Stream.value(count)),
          ],
          child: const MaterialApp(home: Scaffold(body: PlanUsageNotice())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('저장 수업 7 / 정책 확인 불가'), findsOneWidget);
      expect(find.text('사용량 다시 확인'), findsOneWidget);
      expect(find.textContaining('삭제하면 새 수업'), findsNothing);
      expect(find.text('저장 한도를 불러오는 중이에요.'), findsNothing);
    });
  }

  testWidgets('usage failure remains separate from a valid unlimited policy', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planAccessProvider.overrideWith((_) => Stream.value(storageAccess())),
          planUsageProvider.overrideWith(
            (_) => ++attempts == 1
                ? Stream.error(StateError('offline'))
                : Stream.value(count),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: PlanUsageNotice())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('저장 수업 — / 무제한'), findsOneWidget);
    expect(find.text('사용량을 불러오지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    await tester.tap(find.text('사용량 다시 확인'));
    await tester.pumpAndSettle();
    expect(find.text('저장 수업 7 / 무제한'), findsOneWidget);
  });

  for (final resource in ['workouts', 'savedSlides']) {
    testWidgets(
      '$resource compact notice shares the resolved policy in dialog',
      (tester) async {
        final name = resource == 'workouts' ? '저장 수업 7' : '재사용 저장 슬라이드 3';
        await tester.pumpWidget(
          MaterialApp(
            home: ProviderScope(
              overrides: [
                planAccessProvider.overrideWith(
                  (_) => Stream.value(storageAccess()),
                ),
                planUsageProvider.overrideWith((_) => Stream.value(count)),
              ],
              child: Scaffold(
                body: PlanUsageNotice(resource: resource, compact: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('$name / 무제한 · 사용량 안내'));
        await tester.pumpAndSettle();
        expect(find.text('$name / 무제한'), findsOneWidget);
        expect(find.textContaining('삭제하면 새 수업'), findsNothing);
        expect(find.text('Plus 알아보기'), findsNothing);
      },
    );
  }

  testWidgets('finite resource guard works without unrelated policy fields', (
    tester,
  ) async {
    var allowed = false;
    final grant = storageAccess(
      version: 'plan-entitlements-v2',
      limit: 7,
      unlimited: false,
    ).copyWith(plan: 'free');
    expect(grant.policyKnown, isFalse);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planAccessProvider.overrideWith((_) => Stream.value(grant)),
          planUsageProvider.overrideWith((_) => Stream.value(count)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Column(
                children: [
                  const PlanUsageNotice(),
                  TextButton(
                    onPressed: () async {
                      allowed = await allowPlanAddition(
                        context,
                        ref,
                        'workouts',
                      );
                    },
                    child: const Text('저장'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('저장 수업 7 / 7'), findsOneWidget);
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('수업 저장 한도에 도달했어요'), findsOneWidget);
    await tester.tap(find.text('계속 편집'));
    await tester.pumpAndSettle();
    expect(allowed, isFalse);
  });
}
