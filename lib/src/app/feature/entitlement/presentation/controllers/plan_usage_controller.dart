import 'package:firebase_core/firebase_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/plan_usage.dart';
import 'package:cloud_board/src/app/feature/entitlement/data/repositories/plan_usage_repository_impl.dart';
part 'plan_usage_controller.g.dart';

@Riverpod(keepAlive: true)
PlanUsageRepository planUsageRepository(Ref ref) =>
    FirebasePlanUsageRepository.create();

@Riverpod(keepAlive: true)
Stream<PlanUsage?> planUsage(Ref ref) {
  if (Firebase.apps.isEmpty) return Stream.value(null);
  final owner = ref.watch(accountOwnerIdProvider).value;
  if (owner == null) return Stream.value(null);
  return ref.watch(planUsageRepositoryProvider).watch(owner);
}
