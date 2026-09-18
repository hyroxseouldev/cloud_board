import 'package:json_annotation/json_annotation.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/entities/store_entitlement.dart';
part 'store_entitlement_model.g.dart';

@JsonSerializable()
class StoreEntitlementModel {
  const StoreEntitlementModel({
    this.status = 'awaiting_web',
    this.validUntilMs = 0,
    this.revision = 0,
    this.canPairDisplay = false,
    this.canStartClass = false,
  });
  @JsonKey(defaultValue: 'awaiting_web')
  final String status;
  @JsonKey(defaultValue: 0)
  final int validUntilMs;
  @JsonKey(defaultValue: 0)
  final int revision;
  @JsonKey(defaultValue: false)
  final bool canPairDisplay;
  @JsonKey(defaultValue: false)
  final bool canStartClass;
  factory StoreEntitlementModel.fromJson(Map<String, dynamic> json) =>
      _$StoreEntitlementModelFromJson(json);
  Map<String, dynamic> toJson() => _$StoreEntitlementModelToJson(this);
  StoreEntitlement toEntity(String uid, bool confirmed, int now) =>
      StoreEntitlement(
        ownerId: uid,
        status: status,
        validUntilMs: validUntilMs,
        revision: revision,
        serverConfirmed: confirmed,
        canPairDisplay:
            canPairDisplay &&
            (status == 'pending_connection' || validUntilMs > now),
        canStartClass: canStartClass && validUntilMs > now,
      );
}
