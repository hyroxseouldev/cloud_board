// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'store_operations.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BrandTemplate {

 String get storeName; String get standbyMessage; String? get logoUrl; List<String> get promotionImageUrls; int get primaryColorValue; int get blackScreenStartMinutes; int get blackScreenEndMinutes; List<int> get promotionDurationMinutes; StandbyTransition get standbyTransition; StandbyImageFit get standbyImageFit;
/// Create a copy of BrandTemplate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BrandTemplateCopyWith<BrandTemplate> get copyWith => _$BrandTemplateCopyWithImpl<BrandTemplate>(this as BrandTemplate, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as BrandTemplate;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BrandTemplate&&(identical(other.storeName, _this.storeName) || other.storeName == _this.storeName)&&(identical(other.standbyMessage, _this.standbyMessage) || other.standbyMessage == _this.standbyMessage)&&(identical(other.logoUrl, _this.logoUrl) || other.logoUrl == _this.logoUrl)&&const DeepCollectionEquality().equals(other.promotionImageUrls, _this.promotionImageUrls)&&(identical(other.primaryColorValue, _this.primaryColorValue) || other.primaryColorValue == _this.primaryColorValue)&&(identical(other.blackScreenStartMinutes, _this.blackScreenStartMinutes) || other.blackScreenStartMinutes == _this.blackScreenStartMinutes)&&(identical(other.blackScreenEndMinutes, _this.blackScreenEndMinutes) || other.blackScreenEndMinutes == _this.blackScreenEndMinutes)&&const DeepCollectionEquality().equals(other.promotionDurationMinutes, _this.promotionDurationMinutes)&&(identical(other.standbyTransition, _this.standbyTransition) || other.standbyTransition == _this.standbyTransition)&&(identical(other.standbyImageFit, _this.standbyImageFit) || other.standbyImageFit == _this.standbyImageFit));
}


@override
int get hashCode {
  final _this = this as BrandTemplate;
  return Object.hash(runtimeType,_this.storeName,_this.standbyMessage,_this.logoUrl,const DeepCollectionEquality().hash(_this.promotionImageUrls),_this.primaryColorValue,_this.blackScreenStartMinutes,_this.blackScreenEndMinutes,const DeepCollectionEquality().hash(_this.promotionDurationMinutes),_this.standbyTransition,_this.standbyImageFit);
}

@override
String toString() {
  final _this = this as BrandTemplate;
  return 'BrandTemplate(storeName: ${_this.storeName}, standbyMessage: ${_this.standbyMessage}, logoUrl: ${_this.logoUrl}, promotionImageUrls: ${_this.promotionImageUrls}, primaryColorValue: ${_this.primaryColorValue}, blackScreenStartMinutes: ${_this.blackScreenStartMinutes}, blackScreenEndMinutes: ${_this.blackScreenEndMinutes}, promotionDurationMinutes: ${_this.promotionDurationMinutes}, standbyTransition: ${_this.standbyTransition}, standbyImageFit: ${_this.standbyImageFit})';
}


}

/// @nodoc
abstract mixin class $BrandTemplateCopyWith<$Res>  {
  factory $BrandTemplateCopyWith(BrandTemplate value, $Res Function(BrandTemplate) _then) = _$BrandTemplateCopyWithImpl;
@useResult
$Res call({
 String storeName, String standbyMessage, String? logoUrl, List<String> promotionImageUrls, int primaryColorValue, int blackScreenStartMinutes, int blackScreenEndMinutes, List<int> promotionDurationMinutes, StandbyTransition standbyTransition, StandbyImageFit standbyImageFit
});




}
/// @nodoc
class _$BrandTemplateCopyWithImpl<$Res>
    implements $BrandTemplateCopyWith<$Res> {
  _$BrandTemplateCopyWithImpl(this._self, this._then);

  final BrandTemplate _self;
  final $Res Function(BrandTemplate) _then;

/// Create a copy of BrandTemplate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? storeName = null,Object? standbyMessage = null,Object? logoUrl = freezed,Object? promotionImageUrls = null,Object? primaryColorValue = null,Object? blackScreenStartMinutes = null,Object? blackScreenEndMinutes = null,Object? promotionDurationMinutes = null,Object? standbyTransition = null,Object? standbyImageFit = null,}) {
  return _then(BrandTemplate(
storeName: null == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String,standbyMessage: null == standbyMessage ? _self.standbyMessage : standbyMessage // ignore: cast_nullable_to_non_nullable
as String,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,promotionImageUrls: null == promotionImageUrls ? _self.promotionImageUrls : promotionImageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,primaryColorValue: null == primaryColorValue ? _self.primaryColorValue : primaryColorValue // ignore: cast_nullable_to_non_nullable
as int,blackScreenStartMinutes: null == blackScreenStartMinutes ? _self.blackScreenStartMinutes : blackScreenStartMinutes // ignore: cast_nullable_to_non_nullable
as int,blackScreenEndMinutes: null == blackScreenEndMinutes ? _self.blackScreenEndMinutes : blackScreenEndMinutes // ignore: cast_nullable_to_non_nullable
as int,promotionDurationMinutes: null == promotionDurationMinutes ? _self.promotionDurationMinutes : promotionDurationMinutes // ignore: cast_nullable_to_non_nullable
as List<int>,standbyTransition: null == standbyTransition ? _self.standbyTransition : standbyTransition // ignore: cast_nullable_to_non_nullable
as StandbyTransition,standbyImageFit: null == standbyImageFit ? _self.standbyImageFit : standbyImageFit // ignore: cast_nullable_to_non_nullable
as StandbyImageFit,
  ));
}

}


/// Adds pattern-matching-related methods to [BrandTemplate].
extension BrandTemplatePatterns on BrandTemplate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BrandTemplate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BrandTemplate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BrandTemplate value)  $default,){
final _that = this;
switch (_that) {
case _BrandTemplate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BrandTemplate value)?  $default,){
final _that = this;
switch (_that) {
case _BrandTemplate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String storeName,  String standbyMessage,  String? logoUrl,  List<String> promotionImageUrls,  int primaryColorValue,  int blackScreenStartMinutes,  int blackScreenEndMinutes,  List<int> promotionDurationMinutes,  StandbyTransition standbyTransition,  StandbyImageFit standbyImageFit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BrandTemplate() when $default != null:
return $default(_that.storeName,_that.standbyMessage,_that.logoUrl,_that.promotionImageUrls,_that.primaryColorValue,_that.blackScreenStartMinutes,_that.blackScreenEndMinutes,_that.promotionDurationMinutes,_that.standbyTransition,_that.standbyImageFit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String storeName,  String standbyMessage,  String? logoUrl,  List<String> promotionImageUrls,  int primaryColorValue,  int blackScreenStartMinutes,  int blackScreenEndMinutes,  List<int> promotionDurationMinutes,  StandbyTransition standbyTransition,  StandbyImageFit standbyImageFit)  $default,) {final _that = this;
switch (_that) {
case _BrandTemplate():
return $default(_that.storeName,_that.standbyMessage,_that.logoUrl,_that.promotionImageUrls,_that.primaryColorValue,_that.blackScreenStartMinutes,_that.blackScreenEndMinutes,_that.promotionDurationMinutes,_that.standbyTransition,_that.standbyImageFit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String storeName,  String standbyMessage,  String? logoUrl,  List<String> promotionImageUrls,  int primaryColorValue,  int blackScreenStartMinutes,  int blackScreenEndMinutes,  List<int> promotionDurationMinutes,  StandbyTransition standbyTransition,  StandbyImageFit standbyImageFit)?  $default,) {final _that = this;
switch (_that) {
case _BrandTemplate() when $default != null:
return $default(_that.storeName,_that.standbyMessage,_that.logoUrl,_that.promotionImageUrls,_that.primaryColorValue,_that.blackScreenStartMinutes,_that.blackScreenEndMinutes,_that.promotionDurationMinutes,_that.standbyTransition,_that.standbyImageFit);case _:
  return null;

}
}

}

/// @nodoc


class _BrandTemplate implements BrandTemplate {
  const _BrandTemplate({required this.storeName, required this.standbyMessage, required this.logoUrl, required  List<String> promotionImageUrls, required this.primaryColorValue, required this.blackScreenStartMinutes, required this.blackScreenEndMinutes,  List<int> promotionDurationMinutes = const <int>[], this.standbyTransition = StandbyTransition.fade, this.standbyImageFit = StandbyImageFit.contain}): _promotionImageUrls = promotionImageUrls,_promotionDurationMinutes = promotionDurationMinutes;
  

@override final  String storeName;
@override final  String standbyMessage;
@override final  String? logoUrl;
 final  List<String> _promotionImageUrls;
@override List<String> get promotionImageUrls {
  if (_promotionImageUrls is EqualUnmodifiableListView) return _promotionImageUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_promotionImageUrls);
}

@override final  int primaryColorValue;
@override final  int blackScreenStartMinutes;
@override final  int blackScreenEndMinutes;
 final  List<int> _promotionDurationMinutes;
@override@JsonKey() List<int> get promotionDurationMinutes {
  if (_promotionDurationMinutes is EqualUnmodifiableListView) return _promotionDurationMinutes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_promotionDurationMinutes);
}

@override@JsonKey() final  StandbyTransition standbyTransition;
@override@JsonKey() final  StandbyImageFit standbyImageFit;

/// Create a copy of BrandTemplate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BrandTemplateCopyWith<_BrandTemplate> get copyWith => __$BrandTemplateCopyWithImpl<_BrandTemplate>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BrandTemplate&&(identical(other.storeName, storeName) || other.storeName == storeName)&&(identical(other.standbyMessage, standbyMessage) || other.standbyMessage == standbyMessage)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl)&&const DeepCollectionEquality().equals(other.promotionImageUrls, _promotionImageUrls)&&(identical(other.primaryColorValue, primaryColorValue) || other.primaryColorValue == primaryColorValue)&&(identical(other.blackScreenStartMinutes, blackScreenStartMinutes) || other.blackScreenStartMinutes == blackScreenStartMinutes)&&(identical(other.blackScreenEndMinutes, blackScreenEndMinutes) || other.blackScreenEndMinutes == blackScreenEndMinutes)&&const DeepCollectionEquality().equals(other.promotionDurationMinutes, _promotionDurationMinutes)&&(identical(other.standbyTransition, standbyTransition) || other.standbyTransition == standbyTransition)&&(identical(other.standbyImageFit, standbyImageFit) || other.standbyImageFit == standbyImageFit));
}


@override
int get hashCode {
    return Object.hash(runtimeType,storeName,standbyMessage,logoUrl,const DeepCollectionEquality().hash(_promotionImageUrls),primaryColorValue,blackScreenStartMinutes,blackScreenEndMinutes,const DeepCollectionEquality().hash(_promotionDurationMinutes),standbyTransition,standbyImageFit);
}

@override
String toString() {
    return 'BrandTemplate(storeName: $storeName, standbyMessage: $standbyMessage, logoUrl: $logoUrl, promotionImageUrls: $promotionImageUrls, primaryColorValue: $primaryColorValue, blackScreenStartMinutes: $blackScreenStartMinutes, blackScreenEndMinutes: $blackScreenEndMinutes, promotionDurationMinutes: $promotionDurationMinutes, standbyTransition: $standbyTransition, standbyImageFit: $standbyImageFit)';
}


}

/// @nodoc
abstract mixin class _$BrandTemplateCopyWith<$Res> implements $BrandTemplateCopyWith<$Res> {
  factory _$BrandTemplateCopyWith(_BrandTemplate value, $Res Function(_BrandTemplate) _then) = __$BrandTemplateCopyWithImpl;
@override @useResult
$Res call({
 String storeName, String standbyMessage, String? logoUrl, List<String> promotionImageUrls, int primaryColorValue, int blackScreenStartMinutes, int blackScreenEndMinutes, List<int> promotionDurationMinutes, StandbyTransition standbyTransition, StandbyImageFit standbyImageFit
});




}
/// @nodoc
class __$BrandTemplateCopyWithImpl<$Res>
    implements _$BrandTemplateCopyWith<$Res> {
  __$BrandTemplateCopyWithImpl(this._self, this._then);

  final _BrandTemplate _self;
  final $Res Function(_BrandTemplate) _then;

/// Create a copy of BrandTemplate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? storeName = null,Object? standbyMessage = null,Object? logoUrl = freezed,Object? promotionImageUrls = null,Object? primaryColorValue = null,Object? blackScreenStartMinutes = null,Object? blackScreenEndMinutes = null,Object? promotionDurationMinutes = null,Object? standbyTransition = null,Object? standbyImageFit = null,}) {
  return _then(_BrandTemplate(
storeName: null == storeName ? _self.storeName : storeName // ignore: cast_nullable_to_non_nullable
as String,standbyMessage: null == standbyMessage ? _self.standbyMessage : standbyMessage // ignore: cast_nullable_to_non_nullable
as String,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,promotionImageUrls: null == promotionImageUrls ? _self._promotionImageUrls : promotionImageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,primaryColorValue: null == primaryColorValue ? _self.primaryColorValue : primaryColorValue // ignore: cast_nullable_to_non_nullable
as int,blackScreenStartMinutes: null == blackScreenStartMinutes ? _self.blackScreenStartMinutes : blackScreenStartMinutes // ignore: cast_nullable_to_non_nullable
as int,blackScreenEndMinutes: null == blackScreenEndMinutes ? _self.blackScreenEndMinutes : blackScreenEndMinutes // ignore: cast_nullable_to_non_nullable
as int,promotionDurationMinutes: null == promotionDurationMinutes ? _self._promotionDurationMinutes : promotionDurationMinutes // ignore: cast_nullable_to_non_nullable
as List<int>,standbyTransition: null == standbyTransition ? _self.standbyTransition : standbyTransition // ignore: cast_nullable_to_non_nullable
as StandbyTransition,standbyImageFit: null == standbyImageFit ? _self.standbyImageFit : standbyImageFit // ignore: cast_nullable_to_non_nullable
as StandbyImageFit,
  ));
}


}

/// @nodoc
mixin _$WorkoutSchedule {

 String get id; String get workoutId; String get workoutName; List<int> get weekdays; int get hour; int get minute; List<String> get targetDeviceIds; bool get enabled; String? get lastOccurrenceKey; int get createdAtMs;
/// Create a copy of WorkoutSchedule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkoutScheduleCopyWith<WorkoutSchedule> get copyWith => _$WorkoutScheduleCopyWithImpl<WorkoutSchedule>(this as WorkoutSchedule, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WorkoutSchedule;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkoutSchedule&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.workoutId, _this.workoutId) || other.workoutId == _this.workoutId)&&(identical(other.workoutName, _this.workoutName) || other.workoutName == _this.workoutName)&&const DeepCollectionEquality().equals(other.weekdays, _this.weekdays)&&(identical(other.hour, _this.hour) || other.hour == _this.hour)&&(identical(other.minute, _this.minute) || other.minute == _this.minute)&&const DeepCollectionEquality().equals(other.targetDeviceIds, _this.targetDeviceIds)&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.lastOccurrenceKey, _this.lastOccurrenceKey) || other.lastOccurrenceKey == _this.lastOccurrenceKey)&&(identical(other.createdAtMs, _this.createdAtMs) || other.createdAtMs == _this.createdAtMs));
}


@override
int get hashCode {
  final _this = this as WorkoutSchedule;
  return Object.hash(runtimeType,_this.id,_this.workoutId,_this.workoutName,const DeepCollectionEquality().hash(_this.weekdays),_this.hour,_this.minute,const DeepCollectionEquality().hash(_this.targetDeviceIds),_this.enabled,_this.lastOccurrenceKey,_this.createdAtMs);
}

@override
String toString() {
  final _this = this as WorkoutSchedule;
  return 'WorkoutSchedule(id: ${_this.id}, workoutId: ${_this.workoutId}, workoutName: ${_this.workoutName}, weekdays: ${_this.weekdays}, hour: ${_this.hour}, minute: ${_this.minute}, targetDeviceIds: ${_this.targetDeviceIds}, enabled: ${_this.enabled}, lastOccurrenceKey: ${_this.lastOccurrenceKey}, createdAtMs: ${_this.createdAtMs})';
}


}

/// @nodoc
abstract mixin class $WorkoutScheduleCopyWith<$Res>  {
  factory $WorkoutScheduleCopyWith(WorkoutSchedule value, $Res Function(WorkoutSchedule) _then) = _$WorkoutScheduleCopyWithImpl;
@useResult
$Res call({
 String id, String workoutId, String workoutName, List<int> weekdays, int hour, int minute, List<String> targetDeviceIds, bool enabled, String? lastOccurrenceKey, int createdAtMs
});




}
/// @nodoc
class _$WorkoutScheduleCopyWithImpl<$Res>
    implements $WorkoutScheduleCopyWith<$Res> {
  _$WorkoutScheduleCopyWithImpl(this._self, this._then);

  final WorkoutSchedule _self;
  final $Res Function(WorkoutSchedule) _then;

/// Create a copy of WorkoutSchedule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workoutId = null,Object? workoutName = null,Object? weekdays = null,Object? hour = null,Object? minute = null,Object? targetDeviceIds = null,Object? enabled = null,Object? lastOccurrenceKey = freezed,Object? createdAtMs = null,}) {
  return _then(WorkoutSchedule(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workoutId: null == workoutId ? _self.workoutId : workoutId // ignore: cast_nullable_to_non_nullable
as String,workoutName: null == workoutName ? _self.workoutName : workoutName // ignore: cast_nullable_to_non_nullable
as String,weekdays: null == weekdays ? _self.weekdays : weekdays // ignore: cast_nullable_to_non_nullable
as List<int>,hour: null == hour ? _self.hour : hour // ignore: cast_nullable_to_non_nullable
as int,minute: null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int,targetDeviceIds: null == targetDeviceIds ? _self.targetDeviceIds : targetDeviceIds // ignore: cast_nullable_to_non_nullable
as List<String>,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,lastOccurrenceKey: freezed == lastOccurrenceKey ? _self.lastOccurrenceKey : lastOccurrenceKey // ignore: cast_nullable_to_non_nullable
as String?,createdAtMs: null == createdAtMs ? _self.createdAtMs : createdAtMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkoutSchedule].
extension WorkoutSchedulePatterns on WorkoutSchedule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkoutSchedule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkoutSchedule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkoutSchedule value)  $default,){
final _that = this;
switch (_that) {
case _WorkoutSchedule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkoutSchedule value)?  $default,){
final _that = this;
switch (_that) {
case _WorkoutSchedule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workoutId,  String workoutName,  List<int> weekdays,  int hour,  int minute,  List<String> targetDeviceIds,  bool enabled,  String? lastOccurrenceKey,  int createdAtMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkoutSchedule() when $default != null:
return $default(_that.id,_that.workoutId,_that.workoutName,_that.weekdays,_that.hour,_that.minute,_that.targetDeviceIds,_that.enabled,_that.lastOccurrenceKey,_that.createdAtMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workoutId,  String workoutName,  List<int> weekdays,  int hour,  int minute,  List<String> targetDeviceIds,  bool enabled,  String? lastOccurrenceKey,  int createdAtMs)  $default,) {final _that = this;
switch (_that) {
case _WorkoutSchedule():
return $default(_that.id,_that.workoutId,_that.workoutName,_that.weekdays,_that.hour,_that.minute,_that.targetDeviceIds,_that.enabled,_that.lastOccurrenceKey,_that.createdAtMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workoutId,  String workoutName,  List<int> weekdays,  int hour,  int minute,  List<String> targetDeviceIds,  bool enabled,  String? lastOccurrenceKey,  int createdAtMs)?  $default,) {final _that = this;
switch (_that) {
case _WorkoutSchedule() when $default != null:
return $default(_that.id,_that.workoutId,_that.workoutName,_that.weekdays,_that.hour,_that.minute,_that.targetDeviceIds,_that.enabled,_that.lastOccurrenceKey,_that.createdAtMs);case _:
  return null;

}
}

}

/// @nodoc


class _WorkoutSchedule implements WorkoutSchedule {
  const _WorkoutSchedule({required this.id, required this.workoutId, required this.workoutName, required  List<int> weekdays, required this.hour, required this.minute, required  List<String> targetDeviceIds, required this.enabled, required this.lastOccurrenceKey, required this.createdAtMs}): _weekdays = weekdays,_targetDeviceIds = targetDeviceIds;
  

@override final  String id;
@override final  String workoutId;
@override final  String workoutName;
 final  List<int> _weekdays;
@override List<int> get weekdays {
  if (_weekdays is EqualUnmodifiableListView) return _weekdays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_weekdays);
}

@override final  int hour;
@override final  int minute;
 final  List<String> _targetDeviceIds;
@override List<String> get targetDeviceIds {
  if (_targetDeviceIds is EqualUnmodifiableListView) return _targetDeviceIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_targetDeviceIds);
}

@override final  bool enabled;
@override final  String? lastOccurrenceKey;
@override final  int createdAtMs;

/// Create a copy of WorkoutSchedule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkoutScheduleCopyWith<_WorkoutSchedule> get copyWith => __$WorkoutScheduleCopyWithImpl<_WorkoutSchedule>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkoutSchedule&&(identical(other.id, id) || other.id == id)&&(identical(other.workoutId, workoutId) || other.workoutId == workoutId)&&(identical(other.workoutName, workoutName) || other.workoutName == workoutName)&&const DeepCollectionEquality().equals(other.weekdays, _weekdays)&&(identical(other.hour, hour) || other.hour == hour)&&(identical(other.minute, minute) || other.minute == minute)&&const DeepCollectionEquality().equals(other.targetDeviceIds, _targetDeviceIds)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.lastOccurrenceKey, lastOccurrenceKey) || other.lastOccurrenceKey == lastOccurrenceKey)&&(identical(other.createdAtMs, createdAtMs) || other.createdAtMs == createdAtMs));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,workoutId,workoutName,const DeepCollectionEquality().hash(_weekdays),hour,minute,const DeepCollectionEquality().hash(_targetDeviceIds),enabled,lastOccurrenceKey,createdAtMs);
}

@override
String toString() {
    return 'WorkoutSchedule(id: $id, workoutId: $workoutId, workoutName: $workoutName, weekdays: $weekdays, hour: $hour, minute: $minute, targetDeviceIds: $targetDeviceIds, enabled: $enabled, lastOccurrenceKey: $lastOccurrenceKey, createdAtMs: $createdAtMs)';
}


}

/// @nodoc
abstract mixin class _$WorkoutScheduleCopyWith<$Res> implements $WorkoutScheduleCopyWith<$Res> {
  factory _$WorkoutScheduleCopyWith(_WorkoutSchedule value, $Res Function(_WorkoutSchedule) _then) = __$WorkoutScheduleCopyWithImpl;
@override @useResult
$Res call({
 String id, String workoutId, String workoutName, List<int> weekdays, int hour, int minute, List<String> targetDeviceIds, bool enabled, String? lastOccurrenceKey, int createdAtMs
});




}
/// @nodoc
class __$WorkoutScheduleCopyWithImpl<$Res>
    implements _$WorkoutScheduleCopyWith<$Res> {
  __$WorkoutScheduleCopyWithImpl(this._self, this._then);

  final _WorkoutSchedule _self;
  final $Res Function(_WorkoutSchedule) _then;

/// Create a copy of WorkoutSchedule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workoutId = null,Object? workoutName = null,Object? weekdays = null,Object? hour = null,Object? minute = null,Object? targetDeviceIds = null,Object? enabled = null,Object? lastOccurrenceKey = freezed,Object? createdAtMs = null,}) {
  return _then(_WorkoutSchedule(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workoutId: null == workoutId ? _self.workoutId : workoutId // ignore: cast_nullable_to_non_nullable
as String,workoutName: null == workoutName ? _self.workoutName : workoutName // ignore: cast_nullable_to_non_nullable
as String,weekdays: null == weekdays ? _self._weekdays : weekdays // ignore: cast_nullable_to_non_nullable
as List<int>,hour: null == hour ? _self.hour : hour // ignore: cast_nullable_to_non_nullable
as int,minute: null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int,targetDeviceIds: null == targetDeviceIds ? _self._targetDeviceIds : targetDeviceIds // ignore: cast_nullable_to_non_nullable
as List<String>,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,lastOccurrenceKey: freezed == lastOccurrenceKey ? _self.lastOccurrenceKey : lastOccurrenceKey // ignore: cast_nullable_to_non_nullable
as String?,createdAtMs: null == createdAtMs ? _self.createdAtMs : createdAtMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$OperationEvent {

 String get id; String get type; int get occurredAtMs; String? get deviceId; String? get workoutId; String? get workoutName; bool get scheduled; int? get scheduledAtMs;
/// Create a copy of OperationEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OperationEventCopyWith<OperationEvent> get copyWith => _$OperationEventCopyWithImpl<OperationEvent>(this as OperationEvent, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as OperationEvent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OperationEvent&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.occurredAtMs, _this.occurredAtMs) || other.occurredAtMs == _this.occurredAtMs)&&(identical(other.deviceId, _this.deviceId) || other.deviceId == _this.deviceId)&&(identical(other.workoutId, _this.workoutId) || other.workoutId == _this.workoutId)&&(identical(other.workoutName, _this.workoutName) || other.workoutName == _this.workoutName)&&(identical(other.scheduled, _this.scheduled) || other.scheduled == _this.scheduled)&&(identical(other.scheduledAtMs, _this.scheduledAtMs) || other.scheduledAtMs == _this.scheduledAtMs));
}


@override
int get hashCode {
  final _this = this as OperationEvent;
  return Object.hash(runtimeType,_this.id,_this.type,_this.occurredAtMs,_this.deviceId,_this.workoutId,_this.workoutName,_this.scheduled,_this.scheduledAtMs);
}

@override
String toString() {
  final _this = this as OperationEvent;
  return 'OperationEvent(id: ${_this.id}, type: ${_this.type}, occurredAtMs: ${_this.occurredAtMs}, deviceId: ${_this.deviceId}, workoutId: ${_this.workoutId}, workoutName: ${_this.workoutName}, scheduled: ${_this.scheduled}, scheduledAtMs: ${_this.scheduledAtMs})';
}


}

/// @nodoc
abstract mixin class $OperationEventCopyWith<$Res>  {
  factory $OperationEventCopyWith(OperationEvent value, $Res Function(OperationEvent) _then) = _$OperationEventCopyWithImpl;
@useResult
$Res call({
 String id, String type, int occurredAtMs, String? deviceId, String? workoutId, String? workoutName, bool scheduled, int? scheduledAtMs
});




}
/// @nodoc
class _$OperationEventCopyWithImpl<$Res>
    implements $OperationEventCopyWith<$Res> {
  _$OperationEventCopyWithImpl(this._self, this._then);

  final OperationEvent _self;
  final $Res Function(OperationEvent) _then;

/// Create a copy of OperationEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? occurredAtMs = null,Object? deviceId = freezed,Object? workoutId = freezed,Object? workoutName = freezed,Object? scheduled = null,Object? scheduledAtMs = freezed,}) {
  return _then(OperationEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,occurredAtMs: null == occurredAtMs ? _self.occurredAtMs : occurredAtMs // ignore: cast_nullable_to_non_nullable
as int,deviceId: freezed == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String?,workoutId: freezed == workoutId ? _self.workoutId : workoutId // ignore: cast_nullable_to_non_nullable
as String?,workoutName: freezed == workoutName ? _self.workoutName : workoutName // ignore: cast_nullable_to_non_nullable
as String?,scheduled: null == scheduled ? _self.scheduled : scheduled // ignore: cast_nullable_to_non_nullable
as bool,scheduledAtMs: freezed == scheduledAtMs ? _self.scheduledAtMs : scheduledAtMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [OperationEvent].
extension OperationEventPatterns on OperationEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OperationEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OperationEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OperationEvent value)  $default,){
final _that = this;
switch (_that) {
case _OperationEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OperationEvent value)?  $default,){
final _that = this;
switch (_that) {
case _OperationEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String type,  int occurredAtMs,  String? deviceId,  String? workoutId,  String? workoutName,  bool scheduled,  int? scheduledAtMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OperationEvent() when $default != null:
return $default(_that.id,_that.type,_that.occurredAtMs,_that.deviceId,_that.workoutId,_that.workoutName,_that.scheduled,_that.scheduledAtMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String type,  int occurredAtMs,  String? deviceId,  String? workoutId,  String? workoutName,  bool scheduled,  int? scheduledAtMs)  $default,) {final _that = this;
switch (_that) {
case _OperationEvent():
return $default(_that.id,_that.type,_that.occurredAtMs,_that.deviceId,_that.workoutId,_that.workoutName,_that.scheduled,_that.scheduledAtMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String type,  int occurredAtMs,  String? deviceId,  String? workoutId,  String? workoutName,  bool scheduled,  int? scheduledAtMs)?  $default,) {final _that = this;
switch (_that) {
case _OperationEvent() when $default != null:
return $default(_that.id,_that.type,_that.occurredAtMs,_that.deviceId,_that.workoutId,_that.workoutName,_that.scheduled,_that.scheduledAtMs);case _:
  return null;

}
}

}

/// @nodoc


class _OperationEvent implements OperationEvent {
  const _OperationEvent({required this.id, required this.type, required this.occurredAtMs, required this.deviceId, required this.workoutId, required this.workoutName, required this.scheduled, required this.scheduledAtMs});
  

@override final  String id;
@override final  String type;
@override final  int occurredAtMs;
@override final  String? deviceId;
@override final  String? workoutId;
@override final  String? workoutName;
@override final  bool scheduled;
@override final  int? scheduledAtMs;

/// Create a copy of OperationEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OperationEventCopyWith<_OperationEvent> get copyWith => __$OperationEventCopyWithImpl<_OperationEvent>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OperationEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.occurredAtMs, occurredAtMs) || other.occurredAtMs == occurredAtMs)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.workoutId, workoutId) || other.workoutId == workoutId)&&(identical(other.workoutName, workoutName) || other.workoutName == workoutName)&&(identical(other.scheduled, scheduled) || other.scheduled == scheduled)&&(identical(other.scheduledAtMs, scheduledAtMs) || other.scheduledAtMs == scheduledAtMs));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,type,occurredAtMs,deviceId,workoutId,workoutName,scheduled,scheduledAtMs);
}

@override
String toString() {
    return 'OperationEvent(id: $id, type: $type, occurredAtMs: $occurredAtMs, deviceId: $deviceId, workoutId: $workoutId, workoutName: $workoutName, scheduled: $scheduled, scheduledAtMs: $scheduledAtMs)';
}


}

/// @nodoc
abstract mixin class _$OperationEventCopyWith<$Res> implements $OperationEventCopyWith<$Res> {
  factory _$OperationEventCopyWith(_OperationEvent value, $Res Function(_OperationEvent) _then) = __$OperationEventCopyWithImpl;
@override @useResult
$Res call({
 String id, String type, int occurredAtMs, String? deviceId, String? workoutId, String? workoutName, bool scheduled, int? scheduledAtMs
});




}
/// @nodoc
class __$OperationEventCopyWithImpl<$Res>
    implements _$OperationEventCopyWith<$Res> {
  __$OperationEventCopyWithImpl(this._self, this._then);

  final _OperationEvent _self;
  final $Res Function(_OperationEvent) _then;

/// Create a copy of OperationEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? occurredAtMs = null,Object? deviceId = freezed,Object? workoutId = freezed,Object? workoutName = freezed,Object? scheduled = null,Object? scheduledAtMs = freezed,}) {
  return _then(_OperationEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,occurredAtMs: null == occurredAtMs ? _self.occurredAtMs : occurredAtMs // ignore: cast_nullable_to_non_nullable
as int,deviceId: freezed == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String?,workoutId: freezed == workoutId ? _self.workoutId : workoutId // ignore: cast_nullable_to_non_nullable
as String?,workoutName: freezed == workoutName ? _self.workoutName : workoutName // ignore: cast_nullable_to_non_nullable
as String?,scheduled: null == scheduled ? _self.scheduled : scheduled // ignore: cast_nullable_to_non_nullable
as bool,scheduledAtMs: freezed == scheduledAtMs ? _self.scheduledAtMs : scheduledAtMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$OperationsReport {

 int get todayPlaybackCount; int get monthPlaybackCount; int get scheduledPlaybackCount; int get onTimePlaybackCount; int get disconnectCount; Duration get onlineDuration; String? get mostPlayedWorkoutName; int get mostPlayedWorkoutCount;
/// Create a copy of OperationsReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OperationsReportCopyWith<OperationsReport> get copyWith => _$OperationsReportCopyWithImpl<OperationsReport>(this as OperationsReport, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as OperationsReport;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OperationsReport&&(identical(other.todayPlaybackCount, _this.todayPlaybackCount) || other.todayPlaybackCount == _this.todayPlaybackCount)&&(identical(other.monthPlaybackCount, _this.monthPlaybackCount) || other.monthPlaybackCount == _this.monthPlaybackCount)&&(identical(other.scheduledPlaybackCount, _this.scheduledPlaybackCount) || other.scheduledPlaybackCount == _this.scheduledPlaybackCount)&&(identical(other.onTimePlaybackCount, _this.onTimePlaybackCount) || other.onTimePlaybackCount == _this.onTimePlaybackCount)&&(identical(other.disconnectCount, _this.disconnectCount) || other.disconnectCount == _this.disconnectCount)&&(identical(other.onlineDuration, _this.onlineDuration) || other.onlineDuration == _this.onlineDuration)&&(identical(other.mostPlayedWorkoutName, _this.mostPlayedWorkoutName) || other.mostPlayedWorkoutName == _this.mostPlayedWorkoutName)&&(identical(other.mostPlayedWorkoutCount, _this.mostPlayedWorkoutCount) || other.mostPlayedWorkoutCount == _this.mostPlayedWorkoutCount));
}


@override
int get hashCode {
  final _this = this as OperationsReport;
  return Object.hash(runtimeType,_this.todayPlaybackCount,_this.monthPlaybackCount,_this.scheduledPlaybackCount,_this.onTimePlaybackCount,_this.disconnectCount,_this.onlineDuration,_this.mostPlayedWorkoutName,_this.mostPlayedWorkoutCount);
}

@override
String toString() {
  final _this = this as OperationsReport;
  return 'OperationsReport(todayPlaybackCount: ${_this.todayPlaybackCount}, monthPlaybackCount: ${_this.monthPlaybackCount}, scheduledPlaybackCount: ${_this.scheduledPlaybackCount}, onTimePlaybackCount: ${_this.onTimePlaybackCount}, disconnectCount: ${_this.disconnectCount}, onlineDuration: ${_this.onlineDuration}, mostPlayedWorkoutName: ${_this.mostPlayedWorkoutName}, mostPlayedWorkoutCount: ${_this.mostPlayedWorkoutCount})';
}


}

/// @nodoc
abstract mixin class $OperationsReportCopyWith<$Res>  {
  factory $OperationsReportCopyWith(OperationsReport value, $Res Function(OperationsReport) _then) = _$OperationsReportCopyWithImpl;
@useResult
$Res call({
 int todayPlaybackCount, int monthPlaybackCount, int scheduledPlaybackCount, int onTimePlaybackCount, int disconnectCount, Duration onlineDuration, String? mostPlayedWorkoutName, int mostPlayedWorkoutCount
});




}
/// @nodoc
class _$OperationsReportCopyWithImpl<$Res>
    implements $OperationsReportCopyWith<$Res> {
  _$OperationsReportCopyWithImpl(this._self, this._then);

  final OperationsReport _self;
  final $Res Function(OperationsReport) _then;

/// Create a copy of OperationsReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? todayPlaybackCount = null,Object? monthPlaybackCount = null,Object? scheduledPlaybackCount = null,Object? onTimePlaybackCount = null,Object? disconnectCount = null,Object? onlineDuration = null,Object? mostPlayedWorkoutName = freezed,Object? mostPlayedWorkoutCount = null,}) {
  return _then(OperationsReport(
todayPlaybackCount: null == todayPlaybackCount ? _self.todayPlaybackCount : todayPlaybackCount // ignore: cast_nullable_to_non_nullable
as int,monthPlaybackCount: null == monthPlaybackCount ? _self.monthPlaybackCount : monthPlaybackCount // ignore: cast_nullable_to_non_nullable
as int,scheduledPlaybackCount: null == scheduledPlaybackCount ? _self.scheduledPlaybackCount : scheduledPlaybackCount // ignore: cast_nullable_to_non_nullable
as int,onTimePlaybackCount: null == onTimePlaybackCount ? _self.onTimePlaybackCount : onTimePlaybackCount // ignore: cast_nullable_to_non_nullable
as int,disconnectCount: null == disconnectCount ? _self.disconnectCount : disconnectCount // ignore: cast_nullable_to_non_nullable
as int,onlineDuration: null == onlineDuration ? _self.onlineDuration : onlineDuration // ignore: cast_nullable_to_non_nullable
as Duration,mostPlayedWorkoutName: freezed == mostPlayedWorkoutName ? _self.mostPlayedWorkoutName : mostPlayedWorkoutName // ignore: cast_nullable_to_non_nullable
as String?,mostPlayedWorkoutCount: null == mostPlayedWorkoutCount ? _self.mostPlayedWorkoutCount : mostPlayedWorkoutCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [OperationsReport].
extension OperationsReportPatterns on OperationsReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OperationsReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OperationsReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OperationsReport value)  $default,){
final _that = this;
switch (_that) {
case _OperationsReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OperationsReport value)?  $default,){
final _that = this;
switch (_that) {
case _OperationsReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int todayPlaybackCount,  int monthPlaybackCount,  int scheduledPlaybackCount,  int onTimePlaybackCount,  int disconnectCount,  Duration onlineDuration,  String? mostPlayedWorkoutName,  int mostPlayedWorkoutCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OperationsReport() when $default != null:
return $default(_that.todayPlaybackCount,_that.monthPlaybackCount,_that.scheduledPlaybackCount,_that.onTimePlaybackCount,_that.disconnectCount,_that.onlineDuration,_that.mostPlayedWorkoutName,_that.mostPlayedWorkoutCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int todayPlaybackCount,  int monthPlaybackCount,  int scheduledPlaybackCount,  int onTimePlaybackCount,  int disconnectCount,  Duration onlineDuration,  String? mostPlayedWorkoutName,  int mostPlayedWorkoutCount)  $default,) {final _that = this;
switch (_that) {
case _OperationsReport():
return $default(_that.todayPlaybackCount,_that.monthPlaybackCount,_that.scheduledPlaybackCount,_that.onTimePlaybackCount,_that.disconnectCount,_that.onlineDuration,_that.mostPlayedWorkoutName,_that.mostPlayedWorkoutCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int todayPlaybackCount,  int monthPlaybackCount,  int scheduledPlaybackCount,  int onTimePlaybackCount,  int disconnectCount,  Duration onlineDuration,  String? mostPlayedWorkoutName,  int mostPlayedWorkoutCount)?  $default,) {final _that = this;
switch (_that) {
case _OperationsReport() when $default != null:
return $default(_that.todayPlaybackCount,_that.monthPlaybackCount,_that.scheduledPlaybackCount,_that.onTimePlaybackCount,_that.disconnectCount,_that.onlineDuration,_that.mostPlayedWorkoutName,_that.mostPlayedWorkoutCount);case _:
  return null;

}
}

}

/// @nodoc


class _OperationsReport implements OperationsReport {
  const _OperationsReport({required this.todayPlaybackCount, required this.monthPlaybackCount, required this.scheduledPlaybackCount, required this.onTimePlaybackCount, required this.disconnectCount, required this.onlineDuration, required this.mostPlayedWorkoutName, required this.mostPlayedWorkoutCount});
  

@override final  int todayPlaybackCount;
@override final  int monthPlaybackCount;
@override final  int scheduledPlaybackCount;
@override final  int onTimePlaybackCount;
@override final  int disconnectCount;
@override final  Duration onlineDuration;
@override final  String? mostPlayedWorkoutName;
@override final  int mostPlayedWorkoutCount;

/// Create a copy of OperationsReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OperationsReportCopyWith<_OperationsReport> get copyWith => __$OperationsReportCopyWithImpl<_OperationsReport>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OperationsReport&&(identical(other.todayPlaybackCount, todayPlaybackCount) || other.todayPlaybackCount == todayPlaybackCount)&&(identical(other.monthPlaybackCount, monthPlaybackCount) || other.monthPlaybackCount == monthPlaybackCount)&&(identical(other.scheduledPlaybackCount, scheduledPlaybackCount) || other.scheduledPlaybackCount == scheduledPlaybackCount)&&(identical(other.onTimePlaybackCount, onTimePlaybackCount) || other.onTimePlaybackCount == onTimePlaybackCount)&&(identical(other.disconnectCount, disconnectCount) || other.disconnectCount == disconnectCount)&&(identical(other.onlineDuration, onlineDuration) || other.onlineDuration == onlineDuration)&&(identical(other.mostPlayedWorkoutName, mostPlayedWorkoutName) || other.mostPlayedWorkoutName == mostPlayedWorkoutName)&&(identical(other.mostPlayedWorkoutCount, mostPlayedWorkoutCount) || other.mostPlayedWorkoutCount == mostPlayedWorkoutCount));
}


@override
int get hashCode {
    return Object.hash(runtimeType,todayPlaybackCount,monthPlaybackCount,scheduledPlaybackCount,onTimePlaybackCount,disconnectCount,onlineDuration,mostPlayedWorkoutName,mostPlayedWorkoutCount);
}

@override
String toString() {
    return 'OperationsReport(todayPlaybackCount: $todayPlaybackCount, monthPlaybackCount: $monthPlaybackCount, scheduledPlaybackCount: $scheduledPlaybackCount, onTimePlaybackCount: $onTimePlaybackCount, disconnectCount: $disconnectCount, onlineDuration: $onlineDuration, mostPlayedWorkoutName: $mostPlayedWorkoutName, mostPlayedWorkoutCount: $mostPlayedWorkoutCount)';
}


}

/// @nodoc
abstract mixin class _$OperationsReportCopyWith<$Res> implements $OperationsReportCopyWith<$Res> {
  factory _$OperationsReportCopyWith(_OperationsReport value, $Res Function(_OperationsReport) _then) = __$OperationsReportCopyWithImpl;
@override @useResult
$Res call({
 int todayPlaybackCount, int monthPlaybackCount, int scheduledPlaybackCount, int onTimePlaybackCount, int disconnectCount, Duration onlineDuration, String? mostPlayedWorkoutName, int mostPlayedWorkoutCount
});




}
/// @nodoc
class __$OperationsReportCopyWithImpl<$Res>
    implements _$OperationsReportCopyWith<$Res> {
  __$OperationsReportCopyWithImpl(this._self, this._then);

  final _OperationsReport _self;
  final $Res Function(_OperationsReport) _then;

/// Create a copy of OperationsReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? todayPlaybackCount = null,Object? monthPlaybackCount = null,Object? scheduledPlaybackCount = null,Object? onTimePlaybackCount = null,Object? disconnectCount = null,Object? onlineDuration = null,Object? mostPlayedWorkoutName = freezed,Object? mostPlayedWorkoutCount = null,}) {
  return _then(_OperationsReport(
todayPlaybackCount: null == todayPlaybackCount ? _self.todayPlaybackCount : todayPlaybackCount // ignore: cast_nullable_to_non_nullable
as int,monthPlaybackCount: null == monthPlaybackCount ? _self.monthPlaybackCount : monthPlaybackCount // ignore: cast_nullable_to_non_nullable
as int,scheduledPlaybackCount: null == scheduledPlaybackCount ? _self.scheduledPlaybackCount : scheduledPlaybackCount // ignore: cast_nullable_to_non_nullable
as int,onTimePlaybackCount: null == onTimePlaybackCount ? _self.onTimePlaybackCount : onTimePlaybackCount // ignore: cast_nullable_to_non_nullable
as int,disconnectCount: null == disconnectCount ? _self.disconnectCount : disconnectCount // ignore: cast_nullable_to_non_nullable
as int,onlineDuration: null == onlineDuration ? _self.onlineDuration : onlineDuration // ignore: cast_nullable_to_non_nullable
as Duration,mostPlayedWorkoutName: freezed == mostPlayedWorkoutName ? _self.mostPlayedWorkoutName : mostPlayedWorkoutName // ignore: cast_nullable_to_non_nullable
as String?,mostPlayedWorkoutCount: null == mostPlayedWorkoutCount ? _self.mostPlayedWorkoutCount : mostPlayedWorkoutCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
