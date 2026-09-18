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

 String get ownerId; String get status; int get validUntilMs; int get revision; bool get serverConfirmed; bool get canPairDisplay; bool get canStartClass;
/// Create a copy of StoreEntitlement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StoreEntitlementCopyWith<StoreEntitlement> get copyWith => _$StoreEntitlementCopyWithImpl<StoreEntitlement>(this as StoreEntitlement, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StoreEntitlement;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StoreEntitlement&&(identical(other.ownerId, _this.ownerId) || other.ownerId == _this.ownerId)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.validUntilMs, _this.validUntilMs) || other.validUntilMs == _this.validUntilMs)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&(identical(other.serverConfirmed, _this.serverConfirmed) || other.serverConfirmed == _this.serverConfirmed)&&(identical(other.canPairDisplay, _this.canPairDisplay) || other.canPairDisplay == _this.canPairDisplay)&&(identical(other.canStartClass, _this.canStartClass) || other.canStartClass == _this.canStartClass));
}


@override
int get hashCode {
  final _this = this as StoreEntitlement;
  return Object.hash(runtimeType,_this.ownerId,_this.status,_this.validUntilMs,_this.revision,_this.serverConfirmed,_this.canPairDisplay,_this.canStartClass);
}

@override
String toString() {
  final _this = this as StoreEntitlement;
  return 'StoreEntitlement(ownerId: ${_this.ownerId}, status: ${_this.status}, validUntilMs: ${_this.validUntilMs}, revision: ${_this.revision}, serverConfirmed: ${_this.serverConfirmed}, canPairDisplay: ${_this.canPairDisplay}, canStartClass: ${_this.canStartClass})';
}


}

/// @nodoc
abstract mixin class $StoreEntitlementCopyWith<$Res>  {
  factory $StoreEntitlementCopyWith(StoreEntitlement value, $Res Function(StoreEntitlement) _then) = _$StoreEntitlementCopyWithImpl;
@useResult
$Res call({
 String ownerId, String status, int validUntilMs, int revision, bool serverConfirmed, bool canPairDisplay, bool canStartClass
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
@pragma('vm:prefer-inline') @override $Res call({Object? ownerId = null,Object? status = null,Object? validUntilMs = null,Object? revision = null,Object? serverConfirmed = null,Object? canPairDisplay = null,Object? canStartClass = null,}) {
  return _then(StoreEntitlement(
ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,validUntilMs: null == validUntilMs ? _self.validUntilMs : validUntilMs // ignore: cast_nullable_to_non_nullable
as int,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,serverConfirmed: null == serverConfirmed ? _self.serverConfirmed : serverConfirmed // ignore: cast_nullable_to_non_nullable
as bool,canPairDisplay: null == canPairDisplay ? _self.canPairDisplay : canPairDisplay // ignore: cast_nullable_to_non_nullable
as bool,canStartClass: null == canStartClass ? _self.canStartClass : canStartClass // ignore: cast_nullable_to_non_nullable
as bool,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ownerId,  String status,  int validUntilMs,  int revision,  bool serverConfirmed,  bool canPairDisplay,  bool canStartClass)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StoreEntitlement() when $default != null:
return $default(_that.ownerId,_that.status,_that.validUntilMs,_that.revision,_that.serverConfirmed,_that.canPairDisplay,_that.canStartClass);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ownerId,  String status,  int validUntilMs,  int revision,  bool serverConfirmed,  bool canPairDisplay,  bool canStartClass)  $default,) {final _that = this;
switch (_that) {
case _StoreEntitlement():
return $default(_that.ownerId,_that.status,_that.validUntilMs,_that.revision,_that.serverConfirmed,_that.canPairDisplay,_that.canStartClass);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ownerId,  String status,  int validUntilMs,  int revision,  bool serverConfirmed,  bool canPairDisplay,  bool canStartClass)?  $default,) {final _that = this;
switch (_that) {
case _StoreEntitlement() when $default != null:
return $default(_that.ownerId,_that.status,_that.validUntilMs,_that.revision,_that.serverConfirmed,_that.canPairDisplay,_that.canStartClass);case _:
  return null;

}
}

}

/// @nodoc


class _StoreEntitlement extends StoreEntitlement {
  const _StoreEntitlement({required this.ownerId, this.status = 'awaiting_web', this.validUntilMs = 0, this.revision = 0, this.serverConfirmed = false, this.canPairDisplay = false, this.canStartClass = false}): super._();


@override final  String ownerId;
@override@JsonKey() final  String status;
@override@JsonKey() final  int validUntilMs;
@override@JsonKey() final  int revision;
@override@JsonKey() final  bool serverConfirmed;
@override@JsonKey() final  bool canPairDisplay;
@override@JsonKey() final  bool canStartClass;

/// Create a copy of StoreEntitlement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StoreEntitlementCopyWith<_StoreEntitlement> get copyWith => __$StoreEntitlementCopyWithImpl<_StoreEntitlement>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StoreEntitlement&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId)&&(identical(other.status, status) || other.status == status)&&(identical(other.validUntilMs, validUntilMs) || other.validUntilMs == validUntilMs)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.serverConfirmed, serverConfirmed) || other.serverConfirmed == serverConfirmed)&&(identical(other.canPairDisplay, canPairDisplay) || other.canPairDisplay == canPairDisplay)&&(identical(other.canStartClass, canStartClass) || other.canStartClass == canStartClass));
}


@override
int get hashCode {
    return Object.hash(runtimeType,ownerId,status,validUntilMs,revision,serverConfirmed,canPairDisplay,canStartClass);
}

@override
String toString() {
    return 'StoreEntitlement(ownerId: $ownerId, status: $status, validUntilMs: $validUntilMs, revision: $revision, serverConfirmed: $serverConfirmed, canPairDisplay: $canPairDisplay, canStartClass: $canStartClass)';
}


}

/// @nodoc
abstract mixin class _$StoreEntitlementCopyWith<$Res> implements $StoreEntitlementCopyWith<$Res> {
  factory _$StoreEntitlementCopyWith(_StoreEntitlement value, $Res Function(_StoreEntitlement) _then) = __$StoreEntitlementCopyWithImpl;
@override @useResult
$Res call({
 String ownerId, String status, int validUntilMs, int revision, bool serverConfirmed, bool canPairDisplay, bool canStartClass
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
@override @pragma('vm:prefer-inline') $Res call({Object? ownerId = null,Object? status = null,Object? validUntilMs = null,Object? revision = null,Object? serverConfirmed = null,Object? canPairDisplay = null,Object? canStartClass = null,}) {
  return _then(_StoreEntitlement(
ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,validUntilMs: null == validUntilMs ? _self.validUntilMs : validUntilMs // ignore: cast_nullable_to_non_nullable
as int,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,serverConfirmed: null == serverConfirmed ? _self.serverConfirmed : serverConfirmed // ignore: cast_nullable_to_non_nullable
as bool,canPairDisplay: null == canPairDisplay ? _self.canPairDisplay : canPairDisplay // ignore: cast_nullable_to_non_nullable
as bool,canStartClass: null == canStartClass ? _self.canStartClass : canStartClass // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
