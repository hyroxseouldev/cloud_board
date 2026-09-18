import 'package:freezed_annotation/freezed_annotation.dart';
part 'store_entitlement.freezed.dart';

@freezed
abstract class StoreEntitlement with _$StoreEntitlement {
  const StoreEntitlement._();
  const factory StoreEntitlement({
    required String ownerId,
    @Default('awaiting_web') String status,
    @Default(0) int validUntilMs,
    @Default(0) int revision,
    @Default(false) bool serverConfirmed,
    @Default(false) bool canPairDisplay,
    @Default(false) bool canStartClass,
  }) = _StoreEntitlement;
  bool allowsNewClass(String? uid, int serverNowMs) =>
      ownerId == uid &&
      serverConfirmed &&
      canStartClass &&
      validUntilMs > serverNowMs;
}
