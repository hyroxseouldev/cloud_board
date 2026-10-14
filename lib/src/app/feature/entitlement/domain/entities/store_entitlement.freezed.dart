// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'store_entitlement.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StoreEntitlement {

 String get ownerId; String get status; int get validUntilMs; int get revision; bool get serverConfirmed; bool get canPairDisplay; bool get canStartClass; String get policyVersion; String get plan; int? get maxWorkouts; bool get workoutsUnlimited; int? get maxSavedSlides; bool get savedSlidesUnlimited; String get idleScreenCustomization; bool get canHideCloudBoardLogo; bool get canUseCenterLogo; int? get aiSlidesMonthlyLimit; int? get aiTimerMonthlyLimit;
/// Create a copy of StoreEntitlement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StoreEntitlementCopyWith<StoreEntitlement> get copyWith => _$StoreEntitlementCopyWithImpl<StoreEntitlement>(this as StoreEntitlement, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StoreEntitlement;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StoreEntitlement&&(identical(other.ownerId, _this.ownerId) || other.ownerId == _this.ownerId)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.validUntilMs, _this.validUntilMs) || other.validUntilMs == _this.validUntilMs)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&(identical(other.serverConfirmed, _this.serverConfirmed) || other.serverConfirmed == _this.serverConfirmed)&&(identical(other.canPairDisplay, _this.canPairDisplay) || other.canPairDisplay == _this.canPairDisplay)&&(identical(other.canStartClass, _this.canStartClass) || other.canStartClass == _this.canStartClass)&&(identical(other.policyVersion, _this.policyVersion) || other.policyVersion == _this.policyVersion)&&(identical(other.plan, _this.plan) || other.plan == _this.plan)&&(identical(other.maxWorkouts, _this.maxWorkouts) || other.maxWorkouts == _this.maxWorkouts)&&(identical(other.workoutsUnlimited, _this.workoutsUnlimited) || other.workoutsUnlimited == _this.workoutsUnlimited)&&(identical(other.maxSavedSlides, _this.maxSavedSlides) || other.maxSavedSlides == _this.maxSavedSlides)&&(identical(other.savedSlidesUnlimited, _this.savedSlidesUnlimited) || other.savedSlidesUnlimited == _this.savedSlidesUnlimited)&&(identical(other.idleScreenCustomization, _this.idleScreenCustomization) || other.idleScreenCustomization == _this.idleScreenCustomization)&&(identical(other.canHideCloudBoardLogo, _this.canHideCloudBoardLogo) || other.canHideCloudBoardLogo == _this.canHideCloudBoardLogo)&&(identical(other.canUseCenterLogo, _this.canUseCenterLogo) || other.canUseCenterLogo == _this.canUseCenterLogo)&&(identical(other.aiSlidesMonthlyLimit, _this.aiSlidesMonthlyLimit) || other.aiSlidesMonthlyLimit == _this.aiSlidesMonthlyLimit)&&(identical(other.aiTimerMonthlyLimit, _this.aiTimerMonthlyLimit) || other.aiTimerMonthlyLimit == _this.aiTimerMonthlyLimit));
}


@override
int get hashCode {
  final _this = this as StoreEntitlement;
  return Object.hash(runtimeType,_this.ownerId,_this.status,_this.validUntilMs,_this.revision,_this.serverConfirmed,_this.canPairDisplay,_this.canStartClass,_this.policyVersion,_this.plan,_this.maxWorkouts,_this.workoutsUnlimited,_this.maxSavedSlides,_this.savedSlidesUnlimited,_this.idleScreenCustomization,_this.canHideCloudBoardLogo,_this.canUseCenterLogo,_this.aiSlidesMonthlyLimit,_this.aiTimerMonthlyLimit);
}

@override
String toString() {
  final _this = this as StoreEntitlement;
  return 'StoreEntitlement(ownerId: ${_this.ownerId}, status: ${_this.status}, validUntilMs: ${_this.validUntilMs}, revision: ${_this.revision}, serverConfirmed: ${_this.serverConfirmed}, canPairDisplay: ${_this.canPairDisplay}, canStartClass: ${_this.canStartClass}, policyVersion: ${_this.policyVersion}, plan: ${_this.plan}, maxWorkouts: ${_this.maxWorkouts}, workoutsUnlimited: ${_this.workoutsUnlimited}, maxSavedSlides: ${_this.maxSavedSlides}, savedSlidesUnlimited: ${_this.savedSlidesUnlimited}, idleScreenCustomization: ${_this.idleScreenCustomization}, canHideCloudBoardLogo: ${_this.canHideCloudBoardLogo}, canUseCenterLogo: ${_this.canUseCenterLogo}, aiSlidesMonthlyLimit: ${_this.aiSlidesMonthlyLimit}, aiTimerMonthlyLimit: ${_this.aiTimerMonthlyLimit})';
}


}

/// @nodoc
abstract mixin class $StoreEntitlementCopyWith<$Res>  {
  factory $StoreEntitlementCopyWith(StoreEntitlement value, $Res Function(StoreEntitlement) _then) = _$StoreEntitlementCopyWithImpl;
@useResult
$Res call({
 String ownerId, String status, int validUntilMs, int revision, bool serverConfirmed, bool canPairDisplay, bool canStartClass, String policyVersion, String plan, int? maxWorkouts, bool workoutsUnlimited, int? maxSavedSlides, bool savedSlidesUnlimited, String idleScreenCustomization, bool canHideCloudBoardLogo, bool canUseCenterLogo, int? aiSlidesMonthlyLimit, int? aiTimerMonthlyLimit
});




}
/// @nodoc
class _$StoreEntitlementCopyWithImpl<$Res>
    implements $StoreEntitlementCopyWith<$Res> {
  _$StoreEntitlementCopyWithImpl(this._self, this._then);

  final StoreEntitlement _self;
  final $Res Function(StoreEntitlement) _then;

/// Create a copy of StoreEntitlement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ownerId = null,Object? status = null,Object? validUntilMs = null,Object? revision = null,Object? serverConfirmed = null,Object? canPairDisplay = null,Object? canStartClass = null,Object? policyVersion = null,Object? plan = null,Object? maxWorkouts = freezed,Object? workoutsUnlimited = null,Object? maxSavedSlides = freezed,Object? savedSlidesUnlimited = null,Object? idleScreenCustomization = null,Object? canHideCloudBoardLogo = null,Object? canUseCenterLogo = null,Object? aiSlidesMonthlyLimit = freezed,Object? aiTimerMonthlyLimit = freezed,}) {
  return _then(StoreEntitlement(
ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,validUntilMs: null == validUntilMs ? _self.validUntilMs : validUntilMs // ignore: cast_nullable_to_non_nullable
as int,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,serverConfirmed: null == serverConfirmed ? _self.serverConfirmed : serverConfirmed // ignore: cast_nullable_to_non_nullable
as bool,canPairDisplay: null == canPairDisplay ? _self.canPairDisplay : canPairDisplay // ignore: cast_nullable_to_non_nullable
as bool,canStartClass: null == canStartClass ? _self.canStartClass : canStartClass // ignore: cast_nullable_to_non_nullable
as bool,policyVersion: null == policyVersion ? _self.policyVersion : policyVersion // ignore: cast_nullable_to_non_nullable
as String,plan: null == plan ? _self.plan : plan // ignore: cast_nullable_to_non_nullable
as String,maxWorkouts: freezed == maxWorkouts ? _self.maxWorkouts : maxWorkouts // ignore: cast_nullable_to_non_nullable
as int?,workoutsUnlimited: null == workoutsUnlimited ? _self.workoutsUnlimited : workoutsUnlimited // ignore: cast_nullable_to_non_nullable
as bool,maxSavedSlides: freezed == maxSavedSlides ? _self.maxSavedSlides : maxSavedSlides // ignore: cast_nullable_to_non_nullable
as int?,savedSlidesUnlimited: null == savedSlidesUnlimited ? _self.savedSlidesUnlimited : savedSlidesUnlimited // ignore: cast_nullable_to_non_nullable
as bool,idleScreenCustomization: null == idleScreenCustomization ? _self.idleScreenCustomization : idleScreenCustomization // ignore: cast_nullable_to_non_nullable
as String,canHideCloudBoardLogo: null == canHideCloudBoardLogo ? _self.canHideCloudBoardLogo : canHideCloudBoardLogo // ignore: cast_nullable_to_non_nullable
as bool,canUseCenterLogo: null == canUseCenterLogo ? _self.canUseCenterLogo : canUseCenterLogo // ignore: cast_nullable_to_non_nullable
as bool,aiSlidesMonthlyLimit: freezed == aiSlidesMonthlyLimit ? _self.aiSlidesMonthlyLimit : aiSlidesMonthlyLimit // ignore: cast_nullable_to_non_nullable
as int?,aiTimerMonthlyLimit: freezed == aiTimerMonthlyLimit ? _self.aiTimerMonthlyLimit : aiTimerMonthlyLimit // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [StoreEntitlement].
extension StoreEntitlementPatterns on StoreEntitlement {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StoreEntitlement value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StoreEntitlement() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StoreEntitlement value)  $default,){
final _that = this;
switch (_that) {
case _StoreEntitlement():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StoreEntitlement value)?  $default,){
final _that = this;
switch (_that) {
case _StoreEntitlement() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ownerId,  String status,  int validUntilMs,  int revision,  bool serverConfirmed,  bool canPairDisplay,  bool canStartClass,  String policyVersion,  String plan,  int? maxWorkouts,  bool workoutsUnlimited,  int? maxSavedSlides,  bool savedSlidesUnlimited,  String idleScreenCustomization,  bool canHideCloudBoardLogo,  bool canUseCenterLogo,  int? aiSlidesMonthlyLimit,  int? aiTimerMonthlyLimit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StoreEntitlement() when $default != null:
return $default(_that.ownerId,_that.status,_that.validUntilMs,_that.revision,_that.serverConfirmed,_that.canPairDisplay,_that.canStartClass,_that.policyVersion,_that.plan,_that.maxWorkouts,_that.workoutsUnlimited,_that.maxSavedSlides,_that.savedSlidesUnlimited,_that.idleScreenCustomization,_that.canHideCloudBoardLogo,_that.canUseCenterLogo,_that.aiSlidesMonthlyLimit,_that.aiTimerMonthlyLimit);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ownerId,  String status,  int validUntilMs,  int revision,  bool serverConfirmed,  bool canPairDisplay,  bool canStartClass,  String policyVersion,  String plan,  int? maxWorkouts,  bool workoutsUnlimited,  int? maxSavedSlides,  bool savedSlidesUnlimited,  String idleScreenCustomization,  bool canHideCloudBoardLogo,  bool canUseCenterLogo,  int? aiSlidesMonthlyLimit,  int? aiTimerMonthlyLimit)  $default,) {final _that = this;
switch (_that) {
case _StoreEntitlement():
return $default(_that.ownerId,_that.status,_that.validUntilMs,_that.revision,_that.serverConfirmed,_that.canPairDisplay,_that.canStartClass,_that.policyVersion,_that.plan,_that.maxWorkouts,_that.workoutsUnlimited,_that.maxSavedSlides,_that.savedSlidesUnlimited,_that.idleScreenCustomization,_that.canHideCloudBoardLogo,_that.canUseCenterLogo,_that.aiSlidesMonthlyLimit,_that.aiTimerMonthlyLimit);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ownerId,  String status,  int validUntilMs,  int revision,  bool serverConfirmed,  bool canPairDisplay,  bool canStartClass,  String policyVersion,  String plan,  int? maxWorkouts,  bool workoutsUnlimited,  int? maxSavedSlides,  bool savedSlidesUnlimited,  String idleScreenCustomization,  bool canHideCloudBoardLogo,  bool canUseCenterLogo,  int? aiSlidesMonthlyLimit,  int? aiTimerMonthlyLimit)?  $default,) {final _that = this;
switch (_that) {
case _StoreEntitlement() when $default != null:
return $default(_that.ownerId,_that.status,_that.validUntilMs,_that.revision,_that.serverConfirmed,_that.canPairDisplay,_that.canStartClass,_that.policyVersion,_that.plan,_that.maxWorkouts,_that.workoutsUnlimited,_that.maxSavedSlides,_that.savedSlidesUnlimited,_that.idleScreenCustomization,_that.canHideCloudBoardLogo,_that.canUseCenterLogo,_that.aiSlidesMonthlyLimit,_that.aiTimerMonthlyLimit);case _:
  return null;

}
}

}

/// @nodoc


class _StoreEntitlement extends StoreEntitlement {
  const _StoreEntitlement({required this.ownerId, this.status = 'awaiting_web', this.validUntilMs = 0, this.revision = 0, this.serverConfirmed = false, this.canPairDisplay = false, this.canStartClass = false, this.policyVersion = '', this.plan = '', this.maxWorkouts, this.workoutsUnlimited = false, this.maxSavedSlides, this.savedSlidesUnlimited = false, this.idleScreenCustomization = 'unknown', this.canHideCloudBoardLogo = false, this.canUseCenterLogo = false, this.aiSlidesMonthlyLimit, this.aiTimerMonthlyLimit}): super._();
  

@override final  String ownerId;
@override@JsonKey() final  String status;
@override@JsonKey() final  int validUntilMs;
@override@JsonKey() final  int revision;
@override@JsonKey() final  bool serverConfirmed;
@override@JsonKey() final  bool canPairDisplay;
@override@JsonKey() final  bool canStartClass;
@override@JsonKey() final  String policyVersion;
@override@JsonKey() final  String plan;
@override final  int? maxWorkouts;
@override@JsonKey() final  bool workoutsUnlimited;
@override final  int? maxSavedSlides;
@override@JsonKey() final  bool savedSlidesUnlimited;
@override@JsonKey() final  String idleScreenCustomization;
@override@JsonKey() final  bool canHideCloudBoardLogo;
@override@JsonKey() final  bool canUseCenterLogo;
@override final  int? aiSlidesMonthlyLimit;
@override final  int? aiTimerMonthlyLimit;

/// Create a copy of StoreEntitlement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StoreEntitlementCopyWith<_StoreEntitlement> get copyWith => __$StoreEntitlementCopyWithImpl<_StoreEntitlement>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StoreEntitlement&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId)&&(identical(other.status, status) || other.status == status)&&(identical(other.validUntilMs, validUntilMs) || other.validUntilMs == validUntilMs)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.serverConfirmed, serverConfirmed) || other.serverConfirmed == serverConfirmed)&&(identical(other.canPairDisplay, canPairDisplay) || other.canPairDisplay == canPairDisplay)&&(identical(other.canStartClass, canStartClass) || other.canStartClass == canStartClass)&&(identical(other.policyVersion, policyVersion) || other.policyVersion == policyVersion)&&(identical(other.plan, plan) || other.plan == plan)&&(identical(other.maxWorkouts, maxWorkouts) || other.maxWorkouts == maxWorkouts)&&(identical(other.workoutsUnlimited, workoutsUnlimited) || other.workoutsUnlimited == workoutsUnlimited)&&(identical(other.maxSavedSlides, maxSavedSlides) || other.maxSavedSlides == maxSavedSlides)&&(identical(other.savedSlidesUnlimited, savedSlidesUnlimited) || other.savedSlidesUnlimited == savedSlidesUnlimited)&&(identical(other.idleScreenCustomization, idleScreenCustomization) || other.idleScreenCustomization == idleScreenCustomization)&&(identical(other.canHideCloudBoardLogo, canHideCloudBoardLogo) || other.canHideCloudBoardLogo == canHideCloudBoardLogo)&&(identical(other.canUseCenterLogo, canUseCenterLogo) || other.canUseCenterLogo == canUseCenterLogo)&&(identical(other.aiSlidesMonthlyLimit, aiSlidesMonthlyLimit) || other.aiSlidesMonthlyLimit == aiSlidesMonthlyLimit)&&(identical(other.aiTimerMonthlyLimit, aiTimerMonthlyLimit) || other.aiTimerMonthlyLimit == aiTimerMonthlyLimit));
}


@override
int get hashCode {
    return Object.hash(runtimeType,ownerId,status,validUntilMs,revision,serverConfirmed,canPairDisplay,canStartClass,policyVersion,plan,maxWorkouts,workoutsUnlimited,maxSavedSlides,savedSlidesUnlimited,idleScreenCustomization,canHideCloudBoardLogo,canUseCenterLogo,aiSlidesMonthlyLimit,aiTimerMonthlyLimit);
}

@override
String toString() {
    return 'StoreEntitlement(ownerId: $ownerId, status: $status, validUntilMs: $validUntilMs, revision: $revision, serverConfirmed: $serverConfirmed, canPairDisplay: $canPairDisplay, canStartClass: $canStartClass, policyVersion: $policyVersion, plan: $plan, maxWorkouts: $maxWorkouts, workoutsUnlimited: $workoutsUnlimited, maxSavedSlides: $maxSavedSlides, savedSlidesUnlimited: $savedSlidesUnlimited, idleScreenCustomization: $idleScreenCustomization, canHideCloudBoardLogo: $canHideCloudBoardLogo, canUseCenterLogo: $canUseCenterLogo, aiSlidesMonthlyLimit: $aiSlidesMonthlyLimit, aiTimerMonthlyLimit: $aiTimerMonthlyLimit)';
}


}

/// @nodoc
abstract mixin class _$StoreEntitlementCopyWith<$Res> implements $StoreEntitlementCopyWith<$Res> {
  factory _$StoreEntitlementCopyWith(_StoreEntitlement value, $Res Function(_StoreEntitlement) _then) = __$StoreEntitlementCopyWithImpl;
@override @useResult
$Res call({
 String ownerId, String status, int validUntilMs, int revision, bool serverConfirmed, bool canPairDisplay, bool canStartClass, String policyVersion, String plan, int? maxWorkouts, bool workoutsUnlimited, int? maxSavedSlides, bool savedSlidesUnlimited, String idleScreenCustomization, bool canHideCloudBoardLogo, bool canUseCenterLogo, int? aiSlidesMonthlyLimit, int? aiTimerMonthlyLimit
});




}
/// @nodoc
class __$StoreEntitlementCopyWithImpl<$Res>
    implements _$StoreEntitlementCopyWith<$Res> {
  __$StoreEntitlementCopyWithImpl(this._self, this._then);

  final _StoreEntitlement _self;
  final $Res Function(_StoreEntitlement) _then;

/// Create a copy of StoreEntitlement
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ownerId = null,Object? status = null,Object? validUntilMs = null,Object? revision = null,Object? serverConfirmed = null,Object? canPairDisplay = null,Object? canStartClass = null,Object? policyVersion = null,Object? plan = null,Object? maxWorkouts = freezed,Object? workoutsUnlimited = null,Object? maxSavedSlides = freezed,Object? savedSlidesUnlimited = null,Object? idleScreenCustomization = null,Object? canHideCloudBoardLogo = null,Object? canUseCenterLogo = null,Object? aiSlidesMonthlyLimit = freezed,Object? aiTimerMonthlyLimit = freezed,}) {
  return _then(_StoreEntitlement(
ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,validUntilMs: null == validUntilMs ? _self.validUntilMs : validUntilMs // ignore: cast_nullable_to_non_nullable
as int,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,serverConfirmed: null == serverConfirmed ? _self.serverConfirmed : serverConfirmed // ignore: cast_nullable_to_non_nullable
as bool,canPairDisplay: null == canPairDisplay ? _self.canPairDisplay : canPairDisplay // ignore: cast_nullable_to_non_nullable
as bool,canStartClass: null == canStartClass ? _self.canStartClass : canStartClass // ignore: cast_nullable_to_non_nullable
as bool,policyVersion: null == policyVersion ? _self.policyVersion : policyVersion // ignore: cast_nullable_to_non_nullable
as String,plan: null == plan ? _self.plan : plan // ignore: cast_nullable_to_non_nullable
as String,maxWorkouts: freezed == maxWorkouts ? _self.maxWorkouts : maxWorkouts // ignore: cast_nullable_to_non_nullable
as int?,workoutsUnlimited: null == workoutsUnlimited ? _self.workoutsUnlimited : workoutsUnlimited // ignore: cast_nullable_to_non_nullable
as bool,maxSavedSlides: freezed == maxSavedSlides ? _self.maxSavedSlides : maxSavedSlides // ignore: cast_nullable_to_non_nullable
as int?,savedSlidesUnlimited: null == savedSlidesUnlimited ? _self.savedSlidesUnlimited : savedSlidesUnlimited // ignore: cast_nullable_to_non_nullable
as bool,idleScreenCustomization: null == idleScreenCustomization ? _self.idleScreenCustomization : idleScreenCustomization // ignore: cast_nullable_to_non_nullable
as String,canHideCloudBoardLogo: null == canHideCloudBoardLogo ? _self.canHideCloudBoardLogo : canHideCloudBoardLogo // ignore: cast_nullable_to_non_nullable
as bool,canUseCenterLogo: null == canUseCenterLogo ? _self.canUseCenterLogo : canUseCenterLogo // ignore: cast_nullable_to_non_nullable
as bool,aiSlidesMonthlyLimit: freezed == aiSlidesMonthlyLimit ? _self.aiSlidesMonthlyLimit : aiSlidesMonthlyLimit // ignore: cast_nullable_to_non_nullable
as int?,aiTimerMonthlyLimit: freezed == aiTimerMonthlyLimit ? _self.aiTimerMonthlyLimit : aiTimerMonthlyLimit // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
