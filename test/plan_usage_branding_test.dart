import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';

import 'dart:async';

import 'package:cloud_board/src/app/core/config/app_brand.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/entities/store_entitlement.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/plan_limit_failure.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/plan_usage.dart';
import 'package:cloud_board/src/app/feature/entitlement/presentation/controllers/entitlement_controller.dart';
import 'package:cloud_board/src/app/feature/entitlement/presentation/controllers/plan_usage_controller.dart';
import 'package:cloud_board/src/app/feature/entitlement/presentation/widgets/plan_usage_notice.dart';
import 'package:cloud_board/src/app/feature/operations/data/datasources/store_operations_local_data_source.dart';
import 'package:cloud_board/src/app/feature/operations/data/datasources/store_operations_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/operations/data/models/store_operations_models.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/standby_branding.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/store_welcome_board.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/library_failure.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/workout_error_message.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

StoreEntitlement planFixture(String plan, {bool confirmed = true}) =>
    StoreEntitlement(
      ownerId: 'owner',
      status: 'active',
      serverConfirmed: confirmed,
      policyVersion: 'plan-entitlements-v2',
      plan: plan,
      maxWorkouts: plan == 'free' ? 7 : null,
      workoutsUnlimited: plan != 'free',
      maxSavedSlides: plan == 'free' ? 3 : (plan == 'plus' ? 30 : null),
      savedSlidesUnlimited: plan == 'premium',
      idleScreenCustomization: plan == 'free' ? 'basic' : 'custom',
      canUseCenterLogo: plan != 'free',
      canHideCloudBoardLogo: plan != 'free',
      aiSlidesMonthlyLimit: plan == 'free' ? 0 : 10,
      aiTimerMonthlyLimit: 0,
    );

void main() {
  testWidgets('compact usage exposes the count and scrollable actions at 2x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: XonTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          // A route-local account scope must survive opening the root dialog.
          home: ProviderScope(
            overrides: [
              planAccessProvider.overrideWith(
                (_) => Stream.value(planFixture('free')),
              ),
              planUsageProvider.overrideWith(
                (_) => Stream.value(
                  const PlanUsage(workoutCount: 7, savedSlideCount: 3),
                ),
              ),
            ],
            child: const Scaffold(body: PlanUsageNotice(compact: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final notice = find.byTooltip('저장 수업 7 / 7 · 사용량 안내');
      expect(notice.hitTestable(), findsOneWidget);
      expect(find.bySemanticsLabel('저장 수업 7 / 7 · 사용량 안내'), findsOneWidget);
      await tester.tap(notice);
      await tester.pumpAndSettle();
      expect(find.text('저장 수업 7 / 7'), findsOneWidget);
      expect(find.text('닫기').hitTestable(), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Plus 알아보기'),
        100,
        scrollable: find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Plus 알아보기').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    } finally {
      semantics.dispose();
    }
  });
  test('quota is distinct from network/storage/unavailable and unwraps library cause', () {
    final error = FirebaseFunctionsException(
      message: 'test',
      code: 'resource-exhausted',
      details: {
        'reason': 'plan-limit',
        'resource': 'savedSlides',
        'limit': 30,
        'used': 30,
      },
    );
    expect(
      PlanLimitFailure.from(LibraryFailure('save', cause: error))!.limit,
      30,
    );
    expect(workoutErrorMessage(error), contains('30개'));
    expect(
      PlanLimitFailure.from(
        FirebaseFunctionsException(code: 'unavailable', message: 'test'),
      ),
      isNull,
    );
    expect(
      PlanLimitFailure.from(
        FirebaseFunctionsException(code: 'resource-exhausted', message: 'test'),
      ),
      isNull,
    );
    expect(PlanLimitFailure.from(StateError('disk')), isNull);
  });

  test(
    'branding policy sanitizes only known Free and preserves upgrade original',
    () {
      final original = BrandTemplate.initial().copyWith(
        storeName: '센터',
        logoUrl: 'https://example.com/logo.png',
        promotionImageUrls: ['https://example.com/bg.png'],
        standbyMessage: '준비하세요',
        showCloudBoardLogo: false,
      );
      final free = brandPreviewForPlan(original, planFixture('free'));
      expect(free.storeName, AppBrand.name);
      expect(free.showCloudBoardLogo, isTrue);
      expect(free.logoUrl, isNull);
      expect(free.promotionImageUrls, isEmpty);
      expect(brandPreviewForPlan(original, planFixture('plus')), original);
      expect(brandPreviewForPlan(original, planFixture('premium')), original);
      expect(brandPreviewForPlan(original, null), original);
      expect(brandingLocked(null), isFalse);
      expect(BrandTemplateModel.fromJson({}).showCloudBoardLogo, isFalse);
      expect(
        BrandTemplateModel.fromEntity(free).toJson()['showCloudBoardLogo'],
        isTrue,
      );
    },
  );

  test(
    'brand originals/effective caches are separate and account scoped',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final prefs = SharedPreferencesAsync();
      final owner = StoreOperationsLocalDataSource(prefs, ownerId: 'owner');
      final other = StoreOperationsLocalDataSource(prefs, ownerId: 'other');
      final original = BrandTemplateModel.fromEntity(
        BrandTemplate.initial().copyWith(storeName: '원본'),
      );
      final applied = BrandTemplateModel.fromEntity(
        brandPreviewForPlan(original.toEntity(), planFixture('free')),
      );
      await owner.saveBrandTemplate(original);
      await owner.saveBrandTemplate(applied, effective: true);
      expect((await owner.loadBrandTemplate())!.storeName, '원본');
      expect(
        (await owner.loadBrandTemplate(effective: true))!.storeName,
        AppBrand.name,
      );
      expect(await other.loadBrandTemplate(), isNull);
      expect(await other.loadBrandTemplate(effective: true), isNull);
      expect(
        await StoreOperationsLocalDataSource(prefs).loadBrandTemplate(),
        isNull,
      );
    },
  );

  test('legacy brand stays live until original exists, then detaches; disposal cancels both', () async {
    var legacyCancels = 0, configCancels = 0;
    final config = StreamController<Object?>(onCancel: () => configCancels++);
    final legacy = StreamController<Object?>(onCancel: () => legacyCancels++);
    final values = <Object?>[];
    final sub = configuredBrandValues(
      config.stream,
      () => legacy.stream,
    ).listen(values.add);
    config.add(null);
    await Future<void>.delayed(Duration.zero);
    legacy.add('old');
    legacy.add('legacy edit');
    await Future<void>.delayed(Duration.zero);
    expect(values, ['old', 'legacy edit']);
    config.add('original');
    await Future<void>.delayed(Duration.zero);
    legacy.add('effective Free');
    config.add('paid edit');
    await Future<void>.delayed(Duration.zero);
    expect(values, ['old', 'legacy edit', 'original', 'paid edit']);
    expect(legacyCancels, 1);
    await sub.cancel();
    expect(configCancels, 1);
    await config.close();
    await legacy.close();
  });

  testWidgets(
    'usage rebuilds dedupe impressions and limit cancel emits one terminal',
    (tester) async {
      final events = <Map<String, dynamic>>[];
      final telemetry = OperationTelemetry(
        readAccount: () => 'owner',
        emit: (event, _) async => events.add(event),
      );
      final counts = StreamController<PlanUsage?>();
      addTearDown(counts.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            operationTelemetryProvider.overrideWithValue(telemetry),
            planAccessProvider.overrideWith(
              (_) => Stream.value(planFixture('free')),
            ),
            planUsageProvider.overrideWith((_) => counts.stream),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => Column(
                  children: [
                    const PlanUsageNotice(),
                    TextButton(
                      onPressed: () => showPlanLimitNotice(
                        context,
                        const PlanLimitFailure(
                          resource: 'workouts',
                          limit: 7,
                          used: 7,
                        ),
                      ),
                      child: const Text('한도 보기'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      counts.add(const PlanUsage(workoutCount: 6, savedSlideCount: 0));
      await tester.pumpAndSettle();
      counts.add(const PlanUsage(workoutCount: 7, savedSlideCount: 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('한도 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('계속 편집'));
      await tester.pumpAndSettle();
      await telemetry.flush();
      expect(
        events
            .where((e) => e['action'] == 'plan.workouts.usage')
            .map((e) => e['outcome']),
        ['attempt', 'success'],
      );
      expect(
        events
            .where((e) => e['action'] == 'plan.workouts.limit')
            .map((e) => e['outcome']),
        ['attempt', 'cancelled'],
      );
    },
  );

  for (final plan in ['free', 'plus', 'premium']) {
    testWidgets(
      '$plan counts show actual cap without counting internal slides',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              planAccessProvider.overrideWith(
                (ref) => Stream.value(planFixture(plan)),
              ),
              planUsageProvider.overrideWith(
                (ref) => Stream.value(
                  const PlanUsage(
                    workoutCount: 7,
                    savedSlideCount: 3,
                    serverConfirmed: true,
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              theme: XonTheme.light,
              home: const Scaffold(
                body: Column(
                  children: [
                    PlanUsageNotice(),
                    PlanUsageNotice(resource: 'savedSlides'),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('저장 수업 7 / ${plan == 'free' ? '7' : '무제한'}'),
          findsOneWidget,
        );
        expect(
          find.text(
            '재사용 저장 슬라이드 3 / ${plan == 'free'
                ? '3'
                : plan == 'plus'
                ? '30'
                : '무제한'}',
          ),
          findsOneWidget,
        );
        expect(find.text('수업 안의 슬라이드는 이 한도를 사용하지 않습니다.'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'server-confirmed 6→7 cap, cached unknown allowed, downgrade excess preserved',
    (tester) async {
      final access = StreamController<StoreEntitlement?>();
      final usage = StreamController<PlanUsage?>();
      addTearDown(access.close);
      addTearDown(usage.close);
      var allowed = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            planAccessProvider.overrideWith((ref) => access.stream),
            planUsageProvider.overrideWith((ref) => usage.stream),
          ],
          child: MaterialApp(
            theme: XonTheme.light,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => Column(
                  children: [
                    const PlanUsageNotice(),
                    FilledButton(
                      onPressed: () async {
                        if (await allowPlanAddition(context, ref, 'workouts')) {
                          allowed++;
                        }
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
      access.add(planFixture('free'));
      usage.add(
        const PlanUsage(
          workoutCount: 6,
          savedSlideCount: 0,
          serverConfirmed: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(allowed, 1);
      usage.add(
        const PlanUsage(
          workoutCount: 7,
          savedSlideCount: 0,
          serverConfirmed: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(allowed, 1);
      expect(find.text('수업 저장 한도에 도달했어요'), findsOneWidget);
      await tester.tap(find.text('계속 편집'));
      await tester.pumpAndSettle();
      usage.add(
        const PlanUsage(
          workoutCount: 10,
          savedSlideCount: 0,
          serverConfirmed: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(allowed, 2);
      access.add(planFixture('plus'));
      usage.add(
        const PlanUsage(
          workoutCount: 10,
          savedSlideCount: 0,
          serverConfirmed: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(allowed, 3);
      access.add(null);
      await tester.pumpAndSettle();
      expect(find.text('저장 수업 10 / 확인 중'), findsOneWidget);
    },
  );

  testWidgets(
    'quota dialog pricing cancel/back preserves typed draft and selection',
    (tester) async {
      final draft = TextEditingController();
      addTearDown(draft.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: Column(
                children: [
                  TextField(controller: draft),
                  FilledButton(
                    onPressed: () => showPlanLimitNotice(
                      context,
                      const PlanLimitFailure(
                        resource: 'workouts',
                        limit: 7,
                        used: 7,
                      ),
                    ),
                    child: const Text('저장'),
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/subscription',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.pop(),
                child: const Text('취소'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: XonTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '내 수업 초안');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plus 알아보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(draft.text, '내 수업 초안');
      expect(find.byType(TextField), findsOneWidget);
    },
  );

  testWidgets(
    'Free idle product mark fixed; paid hidden; small preview uses same aspect scaling',
    (tester) async {
      final original = BrandTemplate.initial().copyWith(
        storeName: '센터',
        showCloudBoardLogo: false,
      );
      Future<void> show(BrandTemplate brand) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: 180,
                child: StoreWelcomeBoard(
                  brand: brand,
                  now: DateTime(2026, 10, 13),
                ),
              ),
            ),
          ),
        ),
      );
      await show(brandPreviewForPlan(original, planFixture('free')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('standby-cloudboard-logo')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await show(brandPreviewForPlan(original, planFixture('plus')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('standby-cloudboard-logo')),
        findsNothing,
      );
      expect(find.text('센터'), findsWidgets);
    },
  );
}
