// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'billing_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BillingStatus {

 String get appAccountToken; bool get purchasesEnabled; List<String> get productIds; String get plan; String get status; int get validUntilMs; String? get grantSource; String? get paidStatus; String? get paidPlan; String? get paidSource; List<String> get paidStores; String? get nextProductId; bool get autoRenew; int get paidExpiresAtMs;
/// Create a copy of BillingStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BillingStatusCopyWith<BillingStatus> get copyWith => _$BillingStatusCopyWithImpl<BillingStatus>(this as BillingStatus, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as BillingStatus;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BillingStatus&&(identical(other.appAccountToken, _this.appAccountToken) || other.appAccountToken == _this.appAccountToken)&&(identical(other.purchasesEnabled, _this.purchasesEnabled) || other.purchasesEnabled == _this.purchasesEnabled)&&const DeepCollectionEquality().equals(other.productIds, _this.productIds)&&(identical(other.plan, _this.plan) || other.plan == _this.plan)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.validUntilMs, _this.validUntilMs) || other.validUntilMs == _this.validUntilMs)&&(identical(other.grantSource, _this.grantSource) || other.grantSource == _this.grantSource)&&(identical(other.paidStatus, _this.paidStatus) || other.paidStatus == _this.paidStatus)&&(identical(other.paidPlan, _this.paidPlan) || other.paidPlan == _this.paidPlan)&&(identical(other.paidSource, _this.paidSource) || other.paidSource == _this.paidSource)&&const DeepCollectionEquality().equals(other.paidStores, _this.paidStores)&&(identical(other.nextProductId, _this.nextProductId) || other.nextProductId == _this.nextProductId)&&(identical(other.autoRenew, _this.autoRenew) || other.autoRenew == _this.autoRenew)&&(identical(other.paidExpiresAtMs, _this.paidExpiresAtMs) || other.paidExpiresAtMs == _this.paidExpiresAtMs));
}


@override
int get hashCode {
  final _this = this as BillingStatus;
  return Object.hash(runtimeType,_this.appAccountToken,_this.purchasesEnabled,const DeepCollectionEquality().hash(_this.productIds),_this.plan,_this.status,_this.validUntilMs,_this.grantSource,_this.paidStatus,_this.paidPlan,_this.paidSource,const DeepCollectionEquality().hash(_this.paidStores),_this.nextProductId,_this.autoRenew,_this.paidExpiresAtMs);
}

@override
String toString() {
  final _this = this as BillingStatus;
  return 'BillingStatus(appAccountToken: ${_this.appAccountToken}, purchasesEnabled: ${_this.purchasesEnabled}, productIds: ${_this.productIds}, plan: ${_this.plan}, status: ${_this.status}, validUntilMs: ${_this.validUntilMs}, grantSource: ${_this.grantSource}, paidStatus: ${_this.paidStatus}, paidPlan: ${_this.paidPlan}, paidSource: ${_this.paidSource}, paidStores: ${_this.paidStores}, nextProductId: ${_this.nextProductId}, autoRenew: ${_this.autoRenew}, paidExpiresAtMs: ${_this.paidExpiresAtMs})';
}


}

/// @nodoc
abstract mixin class $BillingStatusCopyWith<$Res>  {
  factory $BillingStatusCopyWith(BillingStatus value, $Res Function(BillingStatus) _then) = _$BillingStatusCopyWithImpl;
@useResult
$Res call({
 String appAccountToken, bool purchasesEnabled, List<String> productIds, String plan, String status, int validUntilMs, String? grantSource, String? paidStatus, String? paidPlan, String? paidSource, List<String> paidStores, String? nextProductId, bool autoRenew, int paidExpiresAtMs
});




}
/// @nodoc
class _$BillingStatusCopyWithImpl<$Res>
    implements $BillingStatusCopyWith<$Res> {
  _$BillingStatusCopyWithImpl(this._self, this._then);

  final BillingStatus _self;
  final $Res Function(BillingStatus) _then;

/// Create a copy of BillingStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? appAccountToken = null,Object? purchasesEnabled = null,Object? productIds = null,Object? plan = null,Object? status = null,Object? validUntilMs = null,Object? grantSource = freezed,Object? paidStatus = freezed,Object? paidPlan = freezed,Object? paidSource = freezed,Object? paidStores = null,Object? nextProductId = freezed,Object? autoRenew = null,Object? paidExpiresAtMs = null,}) {
  return _then(BillingStatus(
appAccountToken: null == appAccountToken ? _self.appAccountToken : appAccountToken // ignore: cast_nullable_to_non_nullable
as String,purchasesEnabled: null == purchasesEnabled ? _self.purchasesEnabled : purchasesEnabled // ignore: cast_nullable_to_non_nullable
as bool,productIds: null == productIds ? _self.productIds : productIds // ignore: cast_nullable_to_non_nullable
as List<String>,plan: null == plan ? _self.plan : plan // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,validUntilMs: null == validUntilMs ? _self.validUntilMs : validUntilMs // ignore: cast_nullable_to_non_nullable
as int,grantSource: freezed == grantSource ? _self.grantSource : grantSource // ignore: cast_nullable_to_non_nullable
as String?,paidStatus: freezed == paidStatus ? _self.paidStatus : paidStatus // ignore: cast_nullable_to_non_nullable
as String?,paidPlan: freezed == paidPlan ? _self.paidPlan : paidPlan // ignore: cast_nullable_to_non_nullable
as String?,paidSource: freezed == paidSource ? _self.paidSource : paidSource // ignore: cast_nullable_to_non_nullable
as String?,paidStores: null == paidStores ? _self.paidStores : paidStores // ignore: cast_nullable_to_non_nullable
as List<String>,nextProductId: freezed == nextProductId ? _self.nextProductId : nextProductId // ignore: cast_nullable_to_non_nullable
as String?,autoRenew: null == autoRenew ? _self.autoRenew : autoRenew // ignore: cast_nullable_to_non_nullable
as bool,paidExpiresAtMs: null == paidExpiresAtMs ? _self.paidExpiresAtMs : paidExpiresAtMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BillingStatus].
extension BillingStatusPatterns on BillingStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BillingStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BillingStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BillingStatus value)  $default,){
final _that = this;
switch (_that) {
case _BillingStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BillingStatus value)?  $default,){
final _that = this;
switch (_that) {
case _BillingStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String appAccountToken,  bool purchasesEnabled,  List<String> productIds,  String plan,  String status,  int validUntilMs,  String? grantSource,  String? paidStatus,  String? paidPlan,  String? paidSource,  List<String> paidStores,  String? nextProductId,  bool autoRenew,  int paidExpiresAtMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BillingStatus() when $default != null:
return $default(_that.appAccountToken,_that.purchasesEnabled,_that.productIds,_that.plan,_that.status,_that.validUntilMs,_that.grantSource,_that.paidStatus,_that.paidPlan,_that.paidSource,_that.paidStores,_that.nextProductId,_that.autoRenew,_that.paidExpiresAtMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String appAccountToken,  bool purchasesEnabled,  List<String> productIds,  String plan,  String status,  int validUntilMs,  String? grantSource,  String? paidStatus,  String? paidPlan,  String? paidSource,  List<String> paidStores,  String? nextProductId,  bool autoRenew,  int paidExpiresAtMs)  $default,) {final _that = this;
switch (_that) {
case _BillingStatus():
return $default(_that.appAccountToken,_that.purchasesEnabled,_that.productIds,_that.plan,_that.status,_that.validUntilMs,_that.grantSource,_that.paidStatus,_that.paidPlan,_that.paidSource,_that.paidStores,_that.nextProductId,_that.autoRenew,_that.paidExpiresAtMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String appAccountToken,  bool purchasesEnabled,  List<String> productIds,  String plan,  String status,  int validUntilMs,  String? grantSource,  String? paidStatus,  String? paidPlan,  String? paidSource,  List<String> paidStores,  String? nextProductId,  bool autoRenew,  int paidExpiresAtMs)?  $default,) {final _that = this;
switch (_that) {
case _BillingStatus() when $default != null:
return $default(_that.appAccountToken,_that.purchasesEnabled,_that.productIds,_that.plan,_that.status,_that.validUntilMs,_that.grantSource,_that.paidStatus,_that.paidPlan,_that.paidSource,_that.paidStores,_that.nextProductId,_that.autoRenew,_that.paidExpiresAtMs);case _:
  return null;

}
}

}

/// @nodoc


class _BillingStatus extends BillingStatus {
  const _BillingStatus({this.appAccountToken = '', this.purchasesEnabled = false,  List<String> productIds = const [], this.plan = 'free', this.status = 'expired', this.validUntilMs = 0, this.grantSource, this.paidStatus, this.paidPlan, this.paidSource,  List<String> paidStores = const [], this.nextProductId, this.autoRenew = false, this.paidExpiresAtMs = 0}): _productIds = productIds,_paidStores = paidStores,super._();
  

@override@JsonKey() final  String appAccountToken;
@override@JsonKey() final  bool purchasesEnabled;
 final  List<String> _productIds;
@override@JsonKey() List<String> get productIds {
  if (_productIds is EqualUnmodifiableListView) return _productIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_productIds);
}

@override@JsonKey() final  String plan;
@override@JsonKey() final  String status;
@override@JsonKey() final  int validUntilMs;
@override final  String? grantSource;
@override final  String? paidStatus;
@override final  String? paidPlan;
@override final  String? paidSource;
 final  List<String> _paidStores;
@override@JsonKey() List<String> get paidStores {
  if (_paidStores is EqualUnmodifiableListView) return _paidStores;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_paidStores);
}

@override final  String? nextProductId;
@override@JsonKey() final  bool autoRenew;
@override@JsonKey() final  int paidExpiresAtMs;

/// Create a copy of BillingStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BillingStatusCopyWith<_BillingStatus> get copyWith => __$BillingStatusCopyWithImpl<_BillingStatus>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BillingStatus&&(identical(other.appAccountToken, appAccountToken) || other.appAccountToken == appAccountToken)&&(identical(other.purchasesEnabled, purchasesEnabled) || other.purchasesEnabled == purchasesEnabled)&&const DeepCollectionEquality().equals(other.productIds, _productIds)&&(identical(other.plan, plan) || other.plan == plan)&&(identical(other.status, status) || other.status == status)&&(identical(other.validUntilMs, validUntilMs) || other.validUntilMs == validUntilMs)&&(identical(other.grantSource, grantSource) || other.grantSource == grantSource)&&(identical(other.paidStatus, paidStatus) || other.paidStatus == paidStatus)&&(identical(other.paidPlan, paidPlan) || other.paidPlan == paidPlan)&&(identical(other.paidSource, paidSource) || other.paidSource == paidSource)&&const DeepCollectionEquality().equals(other.paidStores, _paidStores)&&(identical(other.nextProductId, nextProductId) || other.nextProductId == nextProductId)&&(identical(other.autoRenew, autoRenew) || other.autoRenew == autoRenew)&&(identical(other.paidExpiresAtMs, paidExpiresAtMs) || other.paidExpiresAtMs == paidExpiresAtMs));
}


@override
int get hashCode {
    return Object.hash(runtimeType,appAccountToken,purchasesEnabled,const DeepCollectionEquality().hash(_productIds),plan,status,validUntilMs,grantSource,paidStatus,paidPlan,paidSource,const DeepCollectionEquality().hash(_paidStores),nextProductId,autoRenew,paidExpiresAtMs);
}

@override
String toString() {
    return 'BillingStatus(appAccountToken: $appAccountToken, purchasesEnabled: $purchasesEnabled, productIds: $productIds, plan: $plan, status: $status, validUntilMs: $validUntilMs, grantSource: $grantSource, paidStatus: $paidStatus, paidPlan: $paidPlan, paidSource: $paidSource, paidStores: $paidStores, nextProductId: $nextProductId, autoRenew: $autoRenew, paidExpiresAtMs: $paidExpiresAtMs)';
}


}

/// @nodoc
abstract mixin class _$BillingStatusCopyWith<$Res> implements $BillingStatusCopyWith<$Res> {
  factory _$BillingStatusCopyWith(_BillingStatus value, $Res Function(_BillingStatus) _then) = __$BillingStatusCopyWithImpl;
@override @useResult
$Res call({
 String appAccountToken, bool purchasesEnabled, List<String> productIds, String plan, String status, int validUntilMs, String? grantSource, String? paidStatus, String? paidPlan, String? paidSource, List<String> paidStores, String? nextProductId, bool autoRenew, int paidExpiresAtMs
});




}
/// @nodoc
class __$BillingStatusCopyWithImpl<$Res>
    implements _$BillingStatusCopyWith<$Res> {
  __$BillingStatusCopyWithImpl(this._self, this._then);

  final _BillingStatus _self;
  final $Res Function(_BillingStatus) _then;

/// Create a copy of BillingStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? appAccountToken = null,Object? purchasesEnabled = null,Object? productIds = null,Object? plan = null,Object? status = null,Object? validUntilMs = null,Object? grantSource = freezed,Object? paidStatus = freezed,Object? paidPlan = freezed,Object? paidSource = freezed,Object? paidStores = null,Object? nextProductId = freezed,Object? autoRenew = null,Object? paidExpiresAtMs = null,}) {
  return _then(_BillingStatus(
appAccountToken: null == appAccountToken ? _self.appAccountToken : appAccountToken // ignore: cast_nullable_to_non_nullable
as String,purchasesEnabled: null == purchasesEnabled ? _self.purchasesEnabled : purchasesEnabled // ignore: cast_nullable_to_non_nullable
as bool,productIds: null == productIds ? _self._productIds : productIds // ignore: cast_nullable_to_non_nullable
as List<String>,plan: null == plan ? _self.plan : plan // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,validUntilMs: null == validUntilMs ? _self.validUntilMs : validUntilMs // ignore: cast_nullable_to_non_nullable
as int,grantSource: freezed == grantSource ? _self.grantSource : grantSource // ignore: cast_nullable_to_non_nullable
as String?,paidStatus: freezed == paidStatus ? _self.paidStatus : paidStatus // ignore: cast_nullable_to_non_nullable
as String?,paidPlan: freezed == paidPlan ? _self.paidPlan : paidPlan // ignore: cast_nullable_to_non_nullable
as String?,paidSource: freezed == paidSource ? _self.paidSource : paidSource // ignore: cast_nullable_to_non_nullable
as String?,paidStores: null == paidStores ? _self._paidStores : paidStores // ignore: cast_nullable_to_non_nullable
as List<String>,nextProductId: freezed == nextProductId ? _self.nextProductId : nextProductId // ignore: cast_nullable_to_non_nullable
as String?,autoRenew: null == autoRenew ? _self.autoRenew : autoRenew // ignore: cast_nullable_to_non_nullable
as bool,paidExpiresAtMs: null == paidExpiresAtMs ? _self.paidExpiresAtMs : paidExpiresAtMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$BillingOffer {

 String get id; String get price;
/// Create a copy of BillingOffer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BillingOfferCopyWith<BillingOffer> get copyWith => _$BillingOfferCopyWithImpl<BillingOffer>(this as BillingOffer, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as BillingOffer;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BillingOffer&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.price, _this.price) || other.price == _this.price));
}


@override
int get hashCode {
  final _this = this as BillingOffer;
  return Object.hash(runtimeType,_this.id,_this.price);
}

@override
String toString() {
  final _this = this as BillingOffer;
  return 'BillingOffer(id: ${_this.id}, price: ${_this.price})';
}


}

/// @nodoc
abstract mixin class $BillingOfferCopyWith<$Res>  {
  factory $BillingOfferCopyWith(BillingOffer value, $Res Function(BillingOffer) _then) = _$BillingOfferCopyWithImpl;
@useResult
$Res call({
 String id, String price
});




}
/// @nodoc
class _$BillingOfferCopyWithImpl<$Res>
    implements $BillingOfferCopyWith<$Res> {
  _$BillingOfferCopyWithImpl(this._self, this._then);

  final BillingOffer _self;
  final $Res Function(BillingOffer) _then;

/// Create a copy of BillingOffer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? price = null,}) {
  return _then(BillingOffer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BillingOffer].
extension BillingOfferPatterns on BillingOffer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BillingOffer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BillingOffer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BillingOffer value)  $default,){
final _that = this;
switch (_that) {
case _BillingOffer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BillingOffer value)?  $default,){
final _that = this;
switch (_that) {
case _BillingOffer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String price)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BillingOffer() when $default != null:
return $default(_that.id,_that.price);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String price)  $default,) {final _that = this;
switch (_that) {
case _BillingOffer():
return $default(_that.id,_that.price);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String price)?  $default,) {final _that = this;
switch (_that) {
case _BillingOffer() when $default != null:
return $default(_that.id,_that.price);case _:
  return null;

}
}

}

/// @nodoc


class _BillingOffer implements BillingOffer {
  const _BillingOffer({required this.id, required this.price});
  

@override final  String id;
@override final  String price;

/// Create a copy of BillingOffer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BillingOfferCopyWith<_BillingOffer> get copyWith => __$BillingOfferCopyWithImpl<_BillingOffer>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BillingOffer&&(identical(other.id, id) || other.id == id)&&(identical(other.price, price) || other.price == price));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,price);
}

@override
String toString() {
    return 'BillingOffer(id: $id, price: $price)';
}


}

/// @nodoc
abstract mixin class _$BillingOfferCopyWith<$Res> implements $BillingOfferCopyWith<$Res> {
  factory _$BillingOfferCopyWith(_BillingOffer value, $Res Function(_BillingOffer) _then) = __$BillingOfferCopyWithImpl;
@override @useResult
$Res call({
 String id, String price
});




}
/// @nodoc
class __$BillingOfferCopyWithImpl<$Res>
    implements _$BillingOfferCopyWith<$Res> {
  __$BillingOfferCopyWithImpl(this._self, this._then);

  final _BillingOffer _self;
  final $Res Function(_BillingOffer) _then;

/// Create a copy of BillingOffer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? price = null,}) {
  return _then(_BillingOffer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$StorePurchase {

 String get key; StorePurchasePhase get phase; String get signedTransaction; String get store; String? get error;
/// Create a copy of StorePurchase
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorePurchaseCopyWith<StorePurchase> get copyWith => _$StorePurchaseCopyWithImpl<StorePurchase>(this as StorePurchase, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StorePurchase;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorePurchase&&(identical(other.key, _this.key) || other.key == _this.key)&&(identical(other.phase, _this.phase) || other.phase == _this.phase)&&(identical(other.signedTransaction, _this.signedTransaction) || other.signedTransaction == _this.signedTransaction)&&(identical(other.store, _this.store) || other.store == _this.store)&&(identical(other.error, _this.error) || other.error == _this.error));
}


@override
int get hashCode {
  final _this = this as StorePurchase;
  return Object.hash(runtimeType,_this.key,_this.phase,_this.signedTransaction,_this.store,_this.error);
}

@override
String toString() {
  final _this = this as StorePurchase;
  return 'StorePurchase(key: ${_this.key}, phase: ${_this.phase}, signedTransaction: ${_this.signedTransaction}, store: ${_this.store}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $StorePurchaseCopyWith<$Res>  {
  factory $StorePurchaseCopyWith(StorePurchase value, $Res Function(StorePurchase) _then) = _$StorePurchaseCopyWithImpl;
@useResult
$Res call({
 String key, StorePurchasePhase phase, String signedTransaction, String store, String? error
});




}
/// @nodoc
class _$StorePurchaseCopyWithImpl<$Res>
    implements $StorePurchaseCopyWith<$Res> {
  _$StorePurchaseCopyWithImpl(this._self, this._then);

  final StorePurchase _self;
  final $Res Function(StorePurchase) _then;

/// Create a copy of StorePurchase
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? phase = null,Object? signedTransaction = null,Object? store = null,Object? error = freezed,}) {
  return _then(StorePurchase(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as StorePurchasePhase,signedTransaction: null == signedTransaction ? _self.signedTransaction : signedTransaction // ignore: cast_nullable_to_non_nullable
as String,store: null == store ? _self.store : store // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [StorePurchase].
extension StorePurchasePatterns on StorePurchase {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StorePurchase value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StorePurchase() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StorePurchase value)  $default,){
final _that = this;
switch (_that) {
case _StorePurchase():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StorePurchase value)?  $default,){
final _that = this;
switch (_that) {
case _StorePurchase() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  StorePurchasePhase phase,  String signedTransaction,  String store,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StorePurchase() when $default != null:
return $default(_that.key,_that.phase,_that.signedTransaction,_that.store,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  StorePurchasePhase phase,  String signedTransaction,  String store,  String? error)  $default,) {final _that = this;
switch (_that) {
case _StorePurchase():
return $default(_that.key,_that.phase,_that.signedTransaction,_that.store,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  StorePurchasePhase phase,  String signedTransaction,  String store,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _StorePurchase() when $default != null:
return $default(_that.key,_that.phase,_that.signedTransaction,_that.store,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _StorePurchase implements StorePurchase {
  const _StorePurchase({required this.key, required this.phase, required this.signedTransaction, this.store = 'app_store', this.error});
  

@override final  String key;
@override final  StorePurchasePhase phase;
@override final  String signedTransaction;
@override@JsonKey() final  String store;
@override final  String? error;

/// Create a copy of StorePurchase
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StorePurchaseCopyWith<_StorePurchase> get copyWith => __$StorePurchaseCopyWithImpl<_StorePurchase>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StorePurchase&&(identical(other.key, key) || other.key == key)&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.signedTransaction, signedTransaction) || other.signedTransaction == signedTransaction)&&(identical(other.store, store) || other.store == store)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,key,phase,signedTransaction,store,error);
}

@override
String toString() {
    return 'StorePurchase(key: $key, phase: $phase, signedTransaction: $signedTransaction, store: $store, error: $error)';
}


}

/// @nodoc
abstract mixin class _$StorePurchaseCopyWith<$Res> implements $StorePurchaseCopyWith<$Res> {
  factory _$StorePurchaseCopyWith(_StorePurchase value, $Res Function(_StorePurchase) _then) = __$StorePurchaseCopyWithImpl;
@override @useResult
$Res call({
 String key, StorePurchasePhase phase, String signedTransaction, String store, String? error
});




}
/// @nodoc
class __$StorePurchaseCopyWithImpl<$Res>
    implements _$StorePurchaseCopyWith<$Res> {
  __$StorePurchaseCopyWithImpl(this._self, this._then);

  final _StorePurchase _self;
  final $Res Function(_StorePurchase) _then;

/// Create a copy of StorePurchase
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? phase = null,Object? signedTransaction = null,Object? store = null,Object? error = freezed,}) {
  return _then(_StorePurchase(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as StorePurchasePhase,signedTransaction: null == signedTransaction ? _self.signedTransaction : signedTransaction // ignore: cast_nullable_to_non_nullable
as String,store: null == store ? _self.store : store // ignore: cast_nullable_to_non_nullable
as String,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$BillingActivity {

 bool get busy; bool get needsVerification; String? get message; bool get error;
/// Create a copy of BillingActivity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BillingActivityCopyWith<BillingActivity> get copyWith => _$BillingActivityCopyWithImpl<BillingActivity>(this as BillingActivity, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as BillingActivity;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BillingActivity&&(identical(other.busy, _this.busy) || other.busy == _this.busy)&&(identical(other.needsVerification, _this.needsVerification) || other.needsVerification == _this.needsVerification)&&(identical(other.message, _this.message) || other.message == _this.message)&&(identical(other.error, _this.error) || other.error == _this.error));
}


@override
int get hashCode {
  final _this = this as BillingActivity;
  return Object.hash(runtimeType,_this.busy,_this.needsVerification,_this.message,_this.error);
}

@override
String toString() {
  final _this = this as BillingActivity;
  return 'BillingActivity(busy: ${_this.busy}, needsVerification: ${_this.needsVerification}, message: ${_this.message}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $BillingActivityCopyWith<$Res>  {
  factory $BillingActivityCopyWith(BillingActivity value, $Res Function(BillingActivity) _then) = _$BillingActivityCopyWithImpl;
@useResult
$Res call({
 bool busy, bool needsVerification, String? message, bool error
});




}
/// @nodoc
class _$BillingActivityCopyWithImpl<$Res>
    implements $BillingActivityCopyWith<$Res> {
  _$BillingActivityCopyWithImpl(this._self, this._then);

  final BillingActivity _self;
  final $Res Function(BillingActivity) _then;

/// Create a copy of BillingActivity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? busy = null,Object? needsVerification = null,Object? message = freezed,Object? error = null,}) {
  return _then(BillingActivity(
busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,needsVerification: null == needsVerification ? _self.needsVerification : needsVerification // ignore: cast_nullable_to_non_nullable
as bool,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [BillingActivity].
extension BillingActivityPatterns on BillingActivity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BillingActivity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BillingActivity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BillingActivity value)  $default,){
final _that = this;
switch (_that) {
case _BillingActivity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BillingActivity value)?  $default,){
final _that = this;
switch (_that) {
case _BillingActivity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool busy,  bool needsVerification,  String? message,  bool error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BillingActivity() when $default != null:
return $default(_that.busy,_that.needsVerification,_that.message,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool busy,  bool needsVerification,  String? message,  bool error)  $default,) {final _that = this;
switch (_that) {
case _BillingActivity():
return $default(_that.busy,_that.needsVerification,_that.message,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool busy,  bool needsVerification,  String? message,  bool error)?  $default,) {final _that = this;
switch (_that) {
case _BillingActivity() when $default != null:
return $default(_that.busy,_that.needsVerification,_that.message,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _BillingActivity implements BillingActivity {
  const _BillingActivity({this.busy = false, this.needsVerification = false, this.message, this.error = false});
  

@override@JsonKey() final  bool busy;
@override@JsonKey() final  bool needsVerification;
@override final  String? message;
@override@JsonKey() final  bool error;

/// Create a copy of BillingActivity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BillingActivityCopyWith<_BillingActivity> get copyWith => __$BillingActivityCopyWithImpl<_BillingActivity>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BillingActivity&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.needsVerification, needsVerification) || other.needsVerification == needsVerification)&&(identical(other.message, message) || other.message == message)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,busy,needsVerification,message,error);
}

@override
String toString() {
    return 'BillingActivity(busy: $busy, needsVerification: $needsVerification, message: $message, error: $error)';
}


}

/// @nodoc
abstract mixin class _$BillingActivityCopyWith<$Res> implements $BillingActivityCopyWith<$Res> {
  factory _$BillingActivityCopyWith(_BillingActivity value, $Res Function(_BillingActivity) _then) = __$BillingActivityCopyWithImpl;
@override @useResult
$Res call({
 bool busy, bool needsVerification, String? message, bool error
});




}
/// @nodoc
class __$BillingActivityCopyWithImpl<$Res>
    implements _$BillingActivityCopyWith<$Res> {
  __$BillingActivityCopyWithImpl(this._self, this._then);

  final _BillingActivity _self;
  final $Res Function(_BillingActivity) _then;

/// Create a copy of BillingActivity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? busy = null,Object? needsVerification = null,Object? message = freezed,Object? error = null,}) {
  return _then(_BillingActivity(
busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,needsVerification: null == needsVerification ? _self.needsVerification : needsVerification // ignore: cast_nullable_to_non_nullable
as bool,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
