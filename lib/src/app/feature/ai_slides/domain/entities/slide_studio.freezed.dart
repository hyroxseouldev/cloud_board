// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'slide_studio.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StudioInput {

 AiSlideDesign get design; String get raw; String get title; String get subtitle; String get brief; StudioMode get mode; int get artworkGroups; double get artworkFontSize; String? get referenceHash;
/// Create a copy of StudioInput
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StudioInputCopyWith<StudioInput> get copyWith => _$StudioInputCopyWithImpl<StudioInput>(this as StudioInput, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StudioInput;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StudioInput&&(identical(other.design, _this.design) || other.design == _this.design)&&(identical(other.raw, _this.raw) || other.raw == _this.raw)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.subtitle, _this.subtitle) || other.subtitle == _this.subtitle)&&(identical(other.brief, _this.brief) || other.brief == _this.brief)&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.artworkGroups, _this.artworkGroups) || other.artworkGroups == _this.artworkGroups)&&(identical(other.artworkFontSize, _this.artworkFontSize) || other.artworkFontSize == _this.artworkFontSize)&&(identical(other.referenceHash, _this.referenceHash) || other.referenceHash == _this.referenceHash));
}


@override
int get hashCode {
  final _this = this as StudioInput;
  return Object.hash(runtimeType,_this.design,_this.raw,_this.title,_this.subtitle,_this.brief,_this.mode,_this.artworkGroups,_this.artworkFontSize,_this.referenceHash);
}

@override
String toString() {
  final _this = this as StudioInput;
  return 'StudioInput(design: ${_this.design}, raw: ${_this.raw}, title: ${_this.title}, subtitle: ${_this.subtitle}, brief: ${_this.brief}, mode: ${_this.mode}, artworkGroups: ${_this.artworkGroups}, artworkFontSize: ${_this.artworkFontSize}, referenceHash: ${_this.referenceHash})';
}


}

/// @nodoc
abstract mixin class $StudioInputCopyWith<$Res>  {
  factory $StudioInputCopyWith(StudioInput value, $Res Function(StudioInput) _then) = _$StudioInputCopyWithImpl;
@useResult
$Res call({
 AiSlideDesign design, String raw, String title, String subtitle, String brief, StudioMode mode, int artworkGroups, double artworkFontSize, String? referenceHash
});


$AiSlideDesignCopyWith<$Res> get design;

}
/// @nodoc
class _$StudioInputCopyWithImpl<$Res>
    implements $StudioInputCopyWith<$Res> {
  _$StudioInputCopyWithImpl(this._self, this._then);

  final StudioInput _self;
  final $Res Function(StudioInput) _then;

/// Create a copy of StudioInput
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? design = null,Object? raw = null,Object? title = null,Object? subtitle = null,Object? brief = null,Object? mode = null,Object? artworkGroups = null,Object? artworkFontSize = null,Object? referenceHash = freezed,}) {
  return _then(StudioInput(
design: null == design ? _self.design : design // ignore: cast_nullable_to_non_nullable
as AiSlideDesign,raw: null == raw ? _self.raw : raw // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,subtitle: null == subtitle ? _self.subtitle : subtitle // ignore: cast_nullable_to_non_nullable
as String,brief: null == brief ? _self.brief : brief // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as StudioMode,artworkGroups: null == artworkGroups ? _self.artworkGroups : artworkGroups // ignore: cast_nullable_to_non_nullable
as int,artworkFontSize: null == artworkFontSize ? _self.artworkFontSize : artworkFontSize // ignore: cast_nullable_to_non_nullable
as double,referenceHash: freezed == referenceHash ? _self.referenceHash : referenceHash // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of StudioInput
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiSlideDesignCopyWith<$Res> get design {

  return $AiSlideDesignCopyWith<$Res>(_self.design, (value) {
    return _then(_self.copyWith(design: value));
  });
}
}


/// Adds pattern-matching-related methods to [StudioInput].
extension StudioInputPatterns on StudioInput {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StudioInput value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StudioInput() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StudioInput value)  $default,){
final _that = this;
switch (_that) {
case _StudioInput():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StudioInput value)?  $default,){
final _that = this;
switch (_that) {
case _StudioInput() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AiSlideDesign design,  String raw,  String title,  String subtitle,  String brief,  StudioMode mode,  int artworkGroups,  double artworkFontSize,  String? referenceHash)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StudioInput() when $default != null:
return $default(_that.design,_that.raw,_that.title,_that.subtitle,_that.brief,_that.mode,_that.artworkGroups,_that.artworkFontSize,_that.referenceHash);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AiSlideDesign design,  String raw,  String title,  String subtitle,  String brief,  StudioMode mode,  int artworkGroups,  double artworkFontSize,  String? referenceHash)  $default,) {final _that = this;
switch (_that) {
case _StudioInput():
return $default(_that.design,_that.raw,_that.title,_that.subtitle,_that.brief,_that.mode,_that.artworkGroups,_that.artworkFontSize,_that.referenceHash);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AiSlideDesign design,  String raw,  String title,  String subtitle,  String brief,  StudioMode mode,  int artworkGroups,  double artworkFontSize,  String? referenceHash)?  $default,) {final _that = this;
switch (_that) {
case _StudioInput() when $default != null:
return $default(_that.design,_that.raw,_that.title,_that.subtitle,_that.brief,_that.mode,_that.artworkGroups,_that.artworkFontSize,_that.referenceHash);case _:
  return null;

}
}

}

/// @nodoc


class _StudioInput implements StudioInput {
  const _StudioInput({required this.design, this.raw = '', this.title = '오늘의 수업', this.subtitle = '', this.brief = '', this.mode = StudioMode.template, this.artworkGroups = 1, this.artworkFontSize = 42, this.referenceHash});


@override final  AiSlideDesign design;
@override@JsonKey() final  String raw;
@override@JsonKey() final  String title;
@override@JsonKey() final  String subtitle;
@override@JsonKey() final  String brief;
@override@JsonKey() final  StudioMode mode;
@override@JsonKey() final  int artworkGroups;
@override@JsonKey() final  double artworkFontSize;
@override final  String? referenceHash;

/// Create a copy of StudioInput
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StudioInputCopyWith<_StudioInput> get copyWith => __$StudioInputCopyWithImpl<_StudioInput>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StudioInput&&(identical(other.design, design) || other.design == design)&&(identical(other.raw, raw) || other.raw == raw)&&(identical(other.title, title) || other.title == title)&&(identical(other.subtitle, subtitle) || other.subtitle == subtitle)&&(identical(other.brief, brief) || other.brief == brief)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.artworkGroups, artworkGroups) || other.artworkGroups == artworkGroups)&&(identical(other.artworkFontSize, artworkFontSize) || other.artworkFontSize == artworkFontSize)&&(identical(other.referenceHash, referenceHash) || other.referenceHash == referenceHash));
}


@override
int get hashCode {
    return Object.hash(runtimeType,design,raw,title,subtitle,brief,mode,artworkGroups,artworkFontSize,referenceHash);
}

@override
String toString() {
    return 'StudioInput(design: $design, raw: $raw, title: $title, subtitle: $subtitle, brief: $brief, mode: $mode, artworkGroups: $artworkGroups, artworkFontSize: $artworkFontSize, referenceHash: $referenceHash)';
}


}

/// @nodoc
abstract mixin class _$StudioInputCopyWith<$Res> implements $StudioInputCopyWith<$Res> {
  factory _$StudioInputCopyWith(_StudioInput value, $Res Function(_StudioInput) _then) = __$StudioInputCopyWithImpl;
@override @useResult
$Res call({
 AiSlideDesign design, String raw, String title, String subtitle, String brief, StudioMode mode, int artworkGroups, double artworkFontSize, String? referenceHash
});


@override $AiSlideDesignCopyWith<$Res> get design;

}
/// @nodoc
class __$StudioInputCopyWithImpl<$Res>
    implements _$StudioInputCopyWith<$Res> {
  __$StudioInputCopyWithImpl(this._self, this._then);

  final _StudioInput _self;
  final $Res Function(_StudioInput) _then;

/// Create a copy of StudioInput
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? design = null,Object? raw = null,Object? title = null,Object? subtitle = null,Object? brief = null,Object? mode = null,Object? artworkGroups = null,Object? artworkFontSize = null,Object? referenceHash = freezed,}) {
  return _then(_StudioInput(
design: null == design ? _self.design : design // ignore: cast_nullable_to_non_nullable
as AiSlideDesign,raw: null == raw ? _self.raw : raw // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,subtitle: null == subtitle ? _self.subtitle : subtitle // ignore: cast_nullable_to_non_nullable
as String,brief: null == brief ? _self.brief : brief // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as StudioMode,artworkGroups: null == artworkGroups ? _self.artworkGroups : artworkGroups // ignore: cast_nullable_to_non_nullable
as int,artworkFontSize: null == artworkFontSize ? _self.artworkFontSize : artworkFontSize // ignore: cast_nullable_to_non_nullable
as double,referenceHash: freezed == referenceHash ? _self.referenceHash : referenceHash // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of StudioInput
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiSlideDesignCopyWith<$Res> get design {

  return $AiSlideDesignCopyWith<$Res>(_self.design, (value) {
    return _then(_self.copyWith(design: value));
  });
}
}

/// @nodoc
mixin _$StudioUsage {

 bool get allowed; bool get enabled; int get used; int? get remaining; int? get limit; bool get unlimited; bool get tokenContractAvailable; int? get lastInputTokens; int? get lastOutputTokens; String? get lastRequestId; DateTime? get resetsAt; String? get availabilityReason;
/// Create a copy of StudioUsage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StudioUsageCopyWith<StudioUsage> get copyWith => _$StudioUsageCopyWithImpl<StudioUsage>(this as StudioUsage, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StudioUsage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StudioUsage&&(identical(other.allowed, _this.allowed) || other.allowed == _this.allowed)&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.used, _this.used) || other.used == _this.used)&&(identical(other.remaining, _this.remaining) || other.remaining == _this.remaining)&&(identical(other.limit, _this.limit) || other.limit == _this.limit)&&(identical(other.unlimited, _this.unlimited) || other.unlimited == _this.unlimited)&&(identical(other.tokenContractAvailable, _this.tokenContractAvailable) || other.tokenContractAvailable == _this.tokenContractAvailable)&&(identical(other.lastInputTokens, _this.lastInputTokens) || other.lastInputTokens == _this.lastInputTokens)&&(identical(other.lastOutputTokens, _this.lastOutputTokens) || other.lastOutputTokens == _this.lastOutputTokens)&&(identical(other.lastRequestId, _this.lastRequestId) || other.lastRequestId == _this.lastRequestId)&&(identical(other.resetsAt, _this.resetsAt) || other.resetsAt == _this.resetsAt)&&(identical(other.availabilityReason, _this.availabilityReason) || other.availabilityReason == _this.availabilityReason));
}


@override
int get hashCode {
  final _this = this as StudioUsage;
  return Object.hash(runtimeType,_this.allowed,_this.enabled,_this.used,_this.remaining,_this.limit,_this.unlimited,_this.tokenContractAvailable,_this.lastInputTokens,_this.lastOutputTokens,_this.lastRequestId,_this.resetsAt,_this.availabilityReason);
}

@override
String toString() {
  final _this = this as StudioUsage;
  return 'StudioUsage(allowed: ${_this.allowed}, enabled: ${_this.enabled}, used: ${_this.used}, remaining: ${_this.remaining}, limit: ${_this.limit}, unlimited: ${_this.unlimited}, tokenContractAvailable: ${_this.tokenContractAvailable}, lastInputTokens: ${_this.lastInputTokens}, lastOutputTokens: ${_this.lastOutputTokens}, lastRequestId: ${_this.lastRequestId}, resetsAt: ${_this.resetsAt}, availabilityReason: ${_this.availabilityReason})';
}


}

/// @nodoc
abstract mixin class $StudioUsageCopyWith<$Res>  {
  factory $StudioUsageCopyWith(StudioUsage value, $Res Function(StudioUsage) _then) = _$StudioUsageCopyWithImpl;
@useResult
$Res call({
 bool allowed, bool enabled, int used, int? remaining, int? limit, bool unlimited, bool tokenContractAvailable, int? lastInputTokens, int? lastOutputTokens, String? lastRequestId, DateTime? resetsAt, String? availabilityReason
});




}
/// @nodoc
class _$StudioUsageCopyWithImpl<$Res>
    implements $StudioUsageCopyWith<$Res> {
  _$StudioUsageCopyWithImpl(this._self, this._then);

  final StudioUsage _self;
  final $Res Function(StudioUsage) _then;

/// Create a copy of StudioUsage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? allowed = null,Object? enabled = null,Object? used = null,Object? remaining = freezed,Object? limit = freezed,Object? unlimited = null,Object? tokenContractAvailable = null,Object? lastInputTokens = freezed,Object? lastOutputTokens = freezed,Object? lastRequestId = freezed,Object? resetsAt = freezed,Object? availabilityReason = freezed,}) {
  return _then(StudioUsage(
allowed: null == allowed ? _self.allowed : allowed // ignore: cast_nullable_to_non_nullable
as bool,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,used: null == used ? _self.used : used // ignore: cast_nullable_to_non_nullable
as int,remaining: freezed == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int?,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int?,unlimited: null == unlimited ? _self.unlimited : unlimited // ignore: cast_nullable_to_non_nullable
as bool,tokenContractAvailable: null == tokenContractAvailable ? _self.tokenContractAvailable : tokenContractAvailable // ignore: cast_nullable_to_non_nullable
as bool,lastInputTokens: freezed == lastInputTokens ? _self.lastInputTokens : lastInputTokens // ignore: cast_nullable_to_non_nullable
as int?,lastOutputTokens: freezed == lastOutputTokens ? _self.lastOutputTokens : lastOutputTokens // ignore: cast_nullable_to_non_nullable
as int?,lastRequestId: freezed == lastRequestId ? _self.lastRequestId : lastRequestId // ignore: cast_nullable_to_non_nullable
as String?,resetsAt: freezed == resetsAt ? _self.resetsAt : resetsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,availabilityReason: freezed == availabilityReason ? _self.availabilityReason : availabilityReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [StudioUsage].
extension StudioUsagePatterns on StudioUsage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StudioUsage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StudioUsage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StudioUsage value)  $default,){
final _that = this;
switch (_that) {
case _StudioUsage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StudioUsage value)?  $default,){
final _that = this;
switch (_that) {
case _StudioUsage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool allowed,  bool enabled,  int used,  int? remaining,  int? limit,  bool unlimited,  bool tokenContractAvailable,  int? lastInputTokens,  int? lastOutputTokens,  String? lastRequestId,  DateTime? resetsAt,  String? availabilityReason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StudioUsage() when $default != null:
return $default(_that.allowed,_that.enabled,_that.used,_that.remaining,_that.limit,_that.unlimited,_that.tokenContractAvailable,_that.lastInputTokens,_that.lastOutputTokens,_that.lastRequestId,_that.resetsAt,_that.availabilityReason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool allowed,  bool enabled,  int used,  int? remaining,  int? limit,  bool unlimited,  bool tokenContractAvailable,  int? lastInputTokens,  int? lastOutputTokens,  String? lastRequestId,  DateTime? resetsAt,  String? availabilityReason)  $default,) {final _that = this;
switch (_that) {
case _StudioUsage():
return $default(_that.allowed,_that.enabled,_that.used,_that.remaining,_that.limit,_that.unlimited,_that.tokenContractAvailable,_that.lastInputTokens,_that.lastOutputTokens,_that.lastRequestId,_that.resetsAt,_that.availabilityReason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool allowed,  bool enabled,  int used,  int? remaining,  int? limit,  bool unlimited,  bool tokenContractAvailable,  int? lastInputTokens,  int? lastOutputTokens,  String? lastRequestId,  DateTime? resetsAt,  String? availabilityReason)?  $default,) {final _that = this;
switch (_that) {
case _StudioUsage() when $default != null:
return $default(_that.allowed,_that.enabled,_that.used,_that.remaining,_that.limit,_that.unlimited,_that.tokenContractAvailable,_that.lastInputTokens,_that.lastOutputTokens,_that.lastRequestId,_that.resetsAt,_that.availabilityReason);case _:
  return null;

}
}

}

/// @nodoc


class _StudioUsage implements StudioUsage {
  const _StudioUsage({required this.allowed, required this.enabled, required this.used, this.remaining, this.limit, this.unlimited = false, this.tokenContractAvailable = false, this.lastInputTokens, this.lastOutputTokens, this.lastRequestId, this.resetsAt, this.availabilityReason});


@override final  bool allowed;
@override final  bool enabled;
@override final  int used;
@override final  int? remaining;
@override final  int? limit;
@override@JsonKey() final  bool unlimited;
@override@JsonKey() final  bool tokenContractAvailable;
@override final  int? lastInputTokens;
@override final  int? lastOutputTokens;
@override final  String? lastRequestId;
@override final  DateTime? resetsAt;
@override final  String? availabilityReason;

/// Create a copy of StudioUsage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StudioUsageCopyWith<_StudioUsage> get copyWith => __$StudioUsageCopyWithImpl<_StudioUsage>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StudioUsage&&(identical(other.allowed, allowed) || other.allowed == allowed)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.used, used) || other.used == used)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.unlimited, unlimited) || other.unlimited == unlimited)&&(identical(other.tokenContractAvailable, tokenContractAvailable) || other.tokenContractAvailable == tokenContractAvailable)&&(identical(other.lastInputTokens, lastInputTokens) || other.lastInputTokens == lastInputTokens)&&(identical(other.lastOutputTokens, lastOutputTokens) || other.lastOutputTokens == lastOutputTokens)&&(identical(other.lastRequestId, lastRequestId) || other.lastRequestId == lastRequestId)&&(identical(other.resetsAt, resetsAt) || other.resetsAt == resetsAt)&&(identical(other.availabilityReason, availabilityReason) || other.availabilityReason == availabilityReason));
}


@override
int get hashCode {
    return Object.hash(runtimeType,allowed,enabled,used,remaining,limit,unlimited,tokenContractAvailable,lastInputTokens,lastOutputTokens,lastRequestId,resetsAt,availabilityReason);
}

@override
String toString() {
    return 'StudioUsage(allowed: $allowed, enabled: $enabled, used: $used, remaining: $remaining, limit: $limit, unlimited: $unlimited, tokenContractAvailable: $tokenContractAvailable, lastInputTokens: $lastInputTokens, lastOutputTokens: $lastOutputTokens, lastRequestId: $lastRequestId, resetsAt: $resetsAt, availabilityReason: $availabilityReason)';
}


}

/// @nodoc
abstract mixin class _$StudioUsageCopyWith<$Res> implements $StudioUsageCopyWith<$Res> {
  factory _$StudioUsageCopyWith(_StudioUsage value, $Res Function(_StudioUsage) _then) = __$StudioUsageCopyWithImpl;
@override @useResult
$Res call({
 bool allowed, bool enabled, int used, int? remaining, int? limit, bool unlimited, bool tokenContractAvailable, int? lastInputTokens, int? lastOutputTokens, String? lastRequestId, DateTime? resetsAt, String? availabilityReason
});




}
/// @nodoc
class __$StudioUsageCopyWithImpl<$Res>
    implements _$StudioUsageCopyWith<$Res> {
  __$StudioUsageCopyWithImpl(this._self, this._then);

  final _StudioUsage _self;
  final $Res Function(_StudioUsage) _then;

/// Create a copy of StudioUsage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? allowed = null,Object? enabled = null,Object? used = null,Object? remaining = freezed,Object? limit = freezed,Object? unlimited = null,Object? tokenContractAvailable = null,Object? lastInputTokens = freezed,Object? lastOutputTokens = freezed,Object? lastRequestId = freezed,Object? resetsAt = freezed,Object? availabilityReason = freezed,}) {
  return _then(_StudioUsage(
allowed: null == allowed ? _self.allowed : allowed // ignore: cast_nullable_to_non_nullable
as bool,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,used: null == used ? _self.used : used // ignore: cast_nullable_to_non_nullable
as int,remaining: freezed == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int?,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int?,unlimited: null == unlimited ? _self.unlimited : unlimited // ignore: cast_nullable_to_non_nullable
as bool,tokenContractAvailable: null == tokenContractAvailable ? _self.tokenContractAvailable : tokenContractAvailable // ignore: cast_nullable_to_non_nullable
as bool,lastInputTokens: freezed == lastInputTokens ? _self.lastInputTokens : lastInputTokens // ignore: cast_nullable_to_non_nullable
as int?,lastOutputTokens: freezed == lastOutputTokens ? _self.lastOutputTokens : lastOutputTokens // ignore: cast_nullable_to_non_nullable
as int?,lastRequestId: freezed == lastRequestId ? _self.lastRequestId : lastRequestId // ignore: cast_nullable_to_non_nullable
as String?,resetsAt: freezed == resetsAt ? _self.resetsAt : resetsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,availabilityReason: freezed == availabilityReason ? _self.availabilityReason : availabilityReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$StudioOperation {

 String get requestId; String get status; List<AiRasterGroup> get groups; List<AiSlideDesign> get designs; List<String> get warnings; String? get message;
/// Create a copy of StudioOperation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StudioOperationCopyWith<StudioOperation> get copyWith => _$StudioOperationCopyWithImpl<StudioOperation>(this as StudioOperation, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StudioOperation;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StudioOperation&&(identical(other.requestId, _this.requestId) || other.requestId == _this.requestId)&&(identical(other.status, _this.status) || other.status == _this.status)&&const DeepCollectionEquality().equals(other.groups, _this.groups)&&const DeepCollectionEquality().equals(other.designs, _this.designs)&&const DeepCollectionEquality().equals(other.warnings, _this.warnings)&&(identical(other.message, _this.message) || other.message == _this.message));
}


@override
int get hashCode {
  final _this = this as StudioOperation;
  return Object.hash(runtimeType,_this.requestId,_this.status,const DeepCollectionEquality().hash(_this.groups),const DeepCollectionEquality().hash(_this.designs),const DeepCollectionEquality().hash(_this.warnings),_this.message);
}

@override
String toString() {
  final _this = this as StudioOperation;
  return 'StudioOperation(requestId: ${_this.requestId}, status: ${_this.status}, groups: ${_this.groups}, designs: ${_this.designs}, warnings: ${_this.warnings}, message: ${_this.message})';
}


}

/// @nodoc
abstract mixin class $StudioOperationCopyWith<$Res>  {
  factory $StudioOperationCopyWith(StudioOperation value, $Res Function(StudioOperation) _then) = _$StudioOperationCopyWithImpl;
@useResult
$Res call({
 String requestId, String status, List<AiRasterGroup> groups, List<AiSlideDesign> designs, List<String> warnings, String? message
});




}
/// @nodoc
class _$StudioOperationCopyWithImpl<$Res>
    implements $StudioOperationCopyWith<$Res> {
  _$StudioOperationCopyWithImpl(this._self, this._then);

  final StudioOperation _self;
  final $Res Function(StudioOperation) _then;

/// Create a copy of StudioOperation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? requestId = null,Object? status = null,Object? groups = null,Object? designs = null,Object? warnings = null,Object? message = freezed,}) {
  return _then(StudioOperation(
requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,groups: null == groups ? _self.groups : groups // ignore: cast_nullable_to_non_nullable
as List<AiRasterGroup>,designs: null == designs ? _self.designs : designs // ignore: cast_nullable_to_non_nullable
as List<AiSlideDesign>,warnings: null == warnings ? _self.warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [StudioOperation].
extension StudioOperationPatterns on StudioOperation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StudioOperation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StudioOperation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StudioOperation value)  $default,){
final _that = this;
switch (_that) {
case _StudioOperation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StudioOperation value)?  $default,){
final _that = this;
switch (_that) {
case _StudioOperation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String requestId,  String status,  List<AiRasterGroup> groups,  List<AiSlideDesign> designs,  List<String> warnings,  String? message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StudioOperation() when $default != null:
return $default(_that.requestId,_that.status,_that.groups,_that.designs,_that.warnings,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String requestId,  String status,  List<AiRasterGroup> groups,  List<AiSlideDesign> designs,  List<String> warnings,  String? message)  $default,) {final _that = this;
switch (_that) {
case _StudioOperation():
return $default(_that.requestId,_that.status,_that.groups,_that.designs,_that.warnings,_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String requestId,  String status,  List<AiRasterGroup> groups,  List<AiSlideDesign> designs,  List<String> warnings,  String? message)?  $default,) {final _that = this;
switch (_that) {
case _StudioOperation() when $default != null:
return $default(_that.requestId,_that.status,_that.groups,_that.designs,_that.warnings,_that.message);case _:
  return null;

}
}

}

/// @nodoc


class _StudioOperation implements StudioOperation {
  const _StudioOperation({required this.requestId, required this.status,  List<AiRasterGroup> groups = const [],  List<AiSlideDesign> designs = const [],  List<String> warnings = const [], this.message}): _groups = groups,_designs = designs,_warnings = warnings;


@override final  String requestId;
@override final  String status;
 final  List<AiRasterGroup> _groups;
@override@JsonKey() List<AiRasterGroup> get groups {
  if (_groups is EqualUnmodifiableListView) return _groups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groups);
}

 final  List<AiSlideDesign> _designs;
@override@JsonKey() List<AiSlideDesign> get designs {
  if (_designs is EqualUnmodifiableListView) return _designs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_designs);
}

 final  List<String> _warnings;
@override@JsonKey() List<String> get warnings {
  if (_warnings is EqualUnmodifiableListView) return _warnings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_warnings);
}

@override final  String? message;

/// Create a copy of StudioOperation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StudioOperationCopyWith<_StudioOperation> get copyWith => __$StudioOperationCopyWithImpl<_StudioOperation>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StudioOperation&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.groups, _groups)&&const DeepCollectionEquality().equals(other.designs, _designs)&&const DeepCollectionEquality().equals(other.warnings, _warnings)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,requestId,status,const DeepCollectionEquality().hash(_groups),const DeepCollectionEquality().hash(_designs),const DeepCollectionEquality().hash(_warnings),message);
}

@override
String toString() {
    return 'StudioOperation(requestId: $requestId, status: $status, groups: $groups, designs: $designs, warnings: $warnings, message: $message)';
}


}

/// @nodoc
abstract mixin class _$StudioOperationCopyWith<$Res> implements $StudioOperationCopyWith<$Res> {
  factory _$StudioOperationCopyWith(_StudioOperation value, $Res Function(_StudioOperation) _then) = __$StudioOperationCopyWithImpl;
@override @useResult
$Res call({
 String requestId, String status, List<AiRasterGroup> groups, List<AiSlideDesign> designs, List<String> warnings, String? message
});




}
/// @nodoc
class __$StudioOperationCopyWithImpl<$Res>
    implements _$StudioOperationCopyWith<$Res> {
  __$StudioOperationCopyWithImpl(this._self, this._then);

  final _StudioOperation _self;
  final $Res Function(_StudioOperation) _then;

/// Create a copy of StudioOperation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? requestId = null,Object? status = null,Object? groups = null,Object? designs = null,Object? warnings = null,Object? message = freezed,}) {
  return _then(_StudioOperation(
requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,groups: null == groups ? _self._groups : groups // ignore: cast_nullable_to_non_nullable
as List<AiRasterGroup>,designs: null == designs ? _self._designs : designs // ignore: cast_nullable_to_non_nullable
as List<AiSlideDesign>,warnings: null == warnings ? _self._warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$StudioResult {

 String get id; StudioInput get input; Uint8List? get reference; AiSlideDraft? get draft; AiRasterBrand? get brand; AiRasterJob? get job; WorkoutModule? get savedModule; List<String> get warnings;
/// Create a copy of StudioResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StudioResultCopyWith<StudioResult> get copyWith => _$StudioResultCopyWithImpl<StudioResult>(this as StudioResult, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StudioResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StudioResult&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.input, _this.input) || other.input == _this.input)&&const DeepCollectionEquality().equals(other.reference, _this.reference)&&(identical(other.draft, _this.draft) || other.draft == _this.draft)&&(identical(other.brand, _this.brand) || other.brand == _this.brand)&&(identical(other.job, _this.job) || other.job == _this.job)&&(identical(other.savedModule, _this.savedModule) || other.savedModule == _this.savedModule)&&const DeepCollectionEquality().equals(other.warnings, _this.warnings));
}


@override
int get hashCode {
  final _this = this as StudioResult;
  return Object.hash(runtimeType,_this.id,_this.input,const DeepCollectionEquality().hash(_this.reference),_this.draft,_this.brand,_this.job,_this.savedModule,const DeepCollectionEquality().hash(_this.warnings));
}

@override
String toString() {
  final _this = this as StudioResult;
  return 'StudioResult(id: ${_this.id}, input: ${_this.input}, reference: ${_this.reference}, draft: ${_this.draft}, brand: ${_this.brand}, job: ${_this.job}, savedModule: ${_this.savedModule}, warnings: ${_this.warnings})';
}


}

/// @nodoc
abstract mixin class $StudioResultCopyWith<$Res>  {
  factory $StudioResultCopyWith(StudioResult value, $Res Function(StudioResult) _then) = _$StudioResultCopyWithImpl;
@useResult
$Res call({
 String id, StudioInput input, Uint8List? reference, AiSlideDraft? draft, AiRasterBrand? brand, AiRasterJob? job, WorkoutModule? savedModule, List<String> warnings
});


$StudioInputCopyWith<$Res> get input;$AiSlideDraftCopyWith<$Res>? get draft;$AiRasterBrandCopyWith<$Res>? get brand;$AiRasterJobCopyWith<$Res>? get job;$WorkoutModuleCopyWith<$Res>? get savedModule;

}
/// @nodoc
class _$StudioResultCopyWithImpl<$Res>
    implements $StudioResultCopyWith<$Res> {
  _$StudioResultCopyWithImpl(this._self, this._then);

  final StudioResult _self;
  final $Res Function(StudioResult) _then;

/// Create a copy of StudioResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? input = null,Object? reference = freezed,Object? draft = freezed,Object? brand = freezed,Object? job = freezed,Object? savedModule = freezed,Object? warnings = null,}) {
  return _then(StudioResult(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as StudioInput,reference: freezed == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as Uint8List?,draft: freezed == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as AiSlideDraft?,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as AiRasterBrand?,job: freezed == job ? _self.job : job // ignore: cast_nullable_to_non_nullable
as AiRasterJob?,savedModule: freezed == savedModule ? _self.savedModule : savedModule // ignore: cast_nullable_to_non_nullable
as WorkoutModule?,warnings: null == warnings ? _self.warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of StudioResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioInputCopyWith<$Res> get input {

  return $StudioInputCopyWith<$Res>(_self.input, (value) {
    return _then(_self.copyWith(input: value));
  });
}/// Create a copy of StudioResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiSlideDraftCopyWith<$Res>? get draft {
    if (_self.draft == null) {
    return null;
  }

  return $AiSlideDraftCopyWith<$Res>(_self.draft!, (value) {
    return _then(_self.copyWith(draft: value));
  });
}/// Create a copy of StudioResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiRasterBrandCopyWith<$Res>? get brand {
    if (_self.brand == null) {
    return null;
  }

  return $AiRasterBrandCopyWith<$Res>(_self.brand!, (value) {
    return _then(_self.copyWith(brand: value));
  });
}/// Create a copy of StudioResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiRasterJobCopyWith<$Res>? get job {
    if (_self.job == null) {
    return null;
  }

  return $AiRasterJobCopyWith<$Res>(_self.job!, (value) {
    return _then(_self.copyWith(job: value));
  });
}/// Create a copy of StudioResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutModuleCopyWith<$Res>? get savedModule {
    if (_self.savedModule == null) {
    return null;
  }

  return $WorkoutModuleCopyWith<$Res>(_self.savedModule!, (value) {
    return _then(_self.copyWith(savedModule: value));
  });
}
}


/// Adds pattern-matching-related methods to [StudioResult].
extension StudioResultPatterns on StudioResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StudioResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StudioResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StudioResult value)  $default,){
final _that = this;
switch (_that) {
case _StudioResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StudioResult value)?  $default,){
final _that = this;
switch (_that) {
case _StudioResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  StudioInput input,  Uint8List? reference,  AiSlideDraft? draft,  AiRasterBrand? brand,  AiRasterJob? job,  WorkoutModule? savedModule,  List<String> warnings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StudioResult() when $default != null:
return $default(_that.id,_that.input,_that.reference,_that.draft,_that.brand,_that.job,_that.savedModule,_that.warnings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  StudioInput input,  Uint8List? reference,  AiSlideDraft? draft,  AiRasterBrand? brand,  AiRasterJob? job,  WorkoutModule? savedModule,  List<String> warnings)  $default,) {final _that = this;
switch (_that) {
case _StudioResult():
return $default(_that.id,_that.input,_that.reference,_that.draft,_that.brand,_that.job,_that.savedModule,_that.warnings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  StudioInput input,  Uint8List? reference,  AiSlideDraft? draft,  AiRasterBrand? brand,  AiRasterJob? job,  WorkoutModule? savedModule,  List<String> warnings)?  $default,) {final _that = this;
switch (_that) {
case _StudioResult() when $default != null:
return $default(_that.id,_that.input,_that.reference,_that.draft,_that.brand,_that.job,_that.savedModule,_that.warnings);case _:
  return null;

}
}

}

/// @nodoc


class _StudioResult implements StudioResult {
  const _StudioResult({required this.id, required this.input, this.reference, this.draft, this.brand, this.job, this.savedModule,  List<String> warnings = const []}): _warnings = warnings;


@override final  String id;
@override final  StudioInput input;
@override final  Uint8List? reference;
@override final  AiSlideDraft? draft;
@override final  AiRasterBrand? brand;
@override final  AiRasterJob? job;
@override final  WorkoutModule? savedModule;
 final  List<String> _warnings;
@override@JsonKey() List<String> get warnings {
  if (_warnings is EqualUnmodifiableListView) return _warnings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_warnings);
}


/// Create a copy of StudioResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StudioResultCopyWith<_StudioResult> get copyWith => __$StudioResultCopyWithImpl<_StudioResult>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StudioResult&&(identical(other.id, id) || other.id == id)&&(identical(other.input, input) || other.input == input)&&const DeepCollectionEquality().equals(other.reference, reference)&&(identical(other.draft, draft) || other.draft == draft)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.job, job) || other.job == job)&&(identical(other.savedModule, savedModule) || other.savedModule == savedModule)&&const DeepCollectionEquality().equals(other.warnings, _warnings));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,input,const DeepCollectionEquality().hash(reference),draft,brand,job,savedModule,const DeepCollectionEquality().hash(_warnings));
}

@override
String toString() {
    return 'StudioResult(id: $id, input: $input, reference: $reference, draft: $draft, brand: $brand, job: $job, savedModule: $savedModule, warnings: $warnings)';
}


}

/// @nodoc
abstract mixin class _$StudioResultCopyWith<$Res> implements $StudioResultCopyWith<$Res> {
  factory _$StudioResultCopyWith(_StudioResult value, $Res Function(_StudioResult) _then) = __$StudioResultCopyWithImpl;
@override @useResult
$Res call({
 String id, StudioInput input, Uint8List? reference, AiSlideDraft? draft, AiRasterBrand? brand, AiRasterJob? job, WorkoutModule? savedModule, List<String> warnings
});


@override $StudioInputCopyWith<$Res> get input;@override $AiSlideDraftCopyWith<$Res>? get draft;@override $AiRasterBrandCopyWith<$Res>? get brand;@override $AiRasterJobCopyWith<$Res>? get job;@override $WorkoutModuleCopyWith<$Res>? get savedModule;

}
/// @nodoc
class __$StudioResultCopyWithImpl<$Res>
    implements _$StudioResultCopyWith<$Res> {
  __$StudioResultCopyWithImpl(this._self, this._then);

  final _StudioResult _self;
  final $Res Function(_StudioResult) _then;

/// Create a copy of StudioResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? input = null,Object? reference = freezed,Object? draft = freezed,Object? brand = freezed,Object? job = freezed,Object? savedModule = freezed,Object? warnings = null,}) {
  return _then(_StudioResult(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as StudioInput,reference: freezed == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as Uint8List?,draft: freezed == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as AiSlideDraft?,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as AiRasterBrand?,job: freezed == job ? _self.job : job // ignore: cast_nullable_to_non_nullable
as AiRasterJob?,savedModule: freezed == savedModule ? _self.savedModule : savedModule // ignore: cast_nullable_to_non_nullable
as WorkoutModule?,warnings: null == warnings ? _self._warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of StudioResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioInputCopyWith<$Res> get input {

  return $StudioInputCopyWith<$Res>(_self.input, (value) {
    return _then(_self.copyWith(input: value));
  });
}/// Create a copy of StudioResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiSlideDraftCopyWith<$Res>? get draft {
    if (_self.draft == null) {
    return null;
  }

  return $AiSlideDraftCopyWith<$Res>(_self.draft!, (value) {
    return _then(_self.copyWith(draft: value));
  });
}/// Create a copy of StudioResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiRasterBrandCopyWith<$Res>? get brand {
    if (_self.brand == null) {
    return null;
  }

  return $AiRasterBrandCopyWith<$Res>(_self.brand!, (value) {
    return _then(_self.copyWith(brand: value));
  });
}/// Create a copy of StudioResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiRasterJobCopyWith<$Res>? get job {
    if (_self.job == null) {
    return null;
  }

  return $AiRasterJobCopyWith<$Res>(_self.job!, (value) {
    return _then(_self.copyWith(job: value));
  });
}/// Create a copy of StudioResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutModuleCopyWith<$Res>? get savedModule {
    if (_self.savedModule == null) {
    return null;
  }

  return $WorkoutModuleCopyWith<$Res>(_self.savedModule!, (value) {
    return _then(_self.copyWith(savedModule: value));
  });
}
}

/// @nodoc
mixin _$SlideStudioState {

 StudioInput get input; Uint8List? get reference; bool get busy; bool get saving; bool get usageLoading; StudioUsage? get usage; String? get usageError; AiRasterBrand? get brand; String? get brandError; StudioResult? get result; List<StudioResult> get history; List<AiSlideDesign> get proposals; String? get pendingId; StudioInput? get pendingInput; StudioOperation? get completedOperation; bool get pendingRaster; String? get error; bool get leaving;
/// Create a copy of SlideStudioState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SlideStudioStateCopyWith<SlideStudioState> get copyWith => _$SlideStudioStateCopyWithImpl<SlideStudioState>(this as SlideStudioState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SlideStudioState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SlideStudioState&&(identical(other.input, _this.input) || other.input == _this.input)&&const DeepCollectionEquality().equals(other.reference, _this.reference)&&(identical(other.busy, _this.busy) || other.busy == _this.busy)&&(identical(other.saving, _this.saving) || other.saving == _this.saving)&&(identical(other.usageLoading, _this.usageLoading) || other.usageLoading == _this.usageLoading)&&(identical(other.usage, _this.usage) || other.usage == _this.usage)&&(identical(other.usageError, _this.usageError) || other.usageError == _this.usageError)&&(identical(other.brand, _this.brand) || other.brand == _this.brand)&&(identical(other.brandError, _this.brandError) || other.brandError == _this.brandError)&&(identical(other.result, _this.result) || other.result == _this.result)&&const DeepCollectionEquality().equals(other.history, _this.history)&&const DeepCollectionEquality().equals(other.proposals, _this.proposals)&&(identical(other.pendingId, _this.pendingId) || other.pendingId == _this.pendingId)&&(identical(other.pendingInput, _this.pendingInput) || other.pendingInput == _this.pendingInput)&&(identical(other.completedOperation, _this.completedOperation) || other.completedOperation == _this.completedOperation)&&(identical(other.pendingRaster, _this.pendingRaster) || other.pendingRaster == _this.pendingRaster)&&(identical(other.error, _this.error) || other.error == _this.error)&&(identical(other.leaving, _this.leaving) || other.leaving == _this.leaving));
}


@override
int get hashCode {
  final _this = this as SlideStudioState;
  return Object.hash(runtimeType,_this.input,const DeepCollectionEquality().hash(_this.reference),_this.busy,_this.saving,_this.usageLoading,_this.usage,_this.usageError,_this.brand,_this.brandError,_this.result,const DeepCollectionEquality().hash(_this.history),const DeepCollectionEquality().hash(_this.proposals),_this.pendingId,_this.pendingInput,_this.completedOperation,_this.pendingRaster,_this.error,_this.leaving);
}

@override
String toString() {
  final _this = this as SlideStudioState;
  return 'SlideStudioState(input: ${_this.input}, reference: ${_this.reference}, busy: ${_this.busy}, saving: ${_this.saving}, usageLoading: ${_this.usageLoading}, usage: ${_this.usage}, usageError: ${_this.usageError}, brand: ${_this.brand}, brandError: ${_this.brandError}, result: ${_this.result}, history: ${_this.history}, proposals: ${_this.proposals}, pendingId: ${_this.pendingId}, pendingInput: ${_this.pendingInput}, completedOperation: ${_this.completedOperation}, pendingRaster: ${_this.pendingRaster}, error: ${_this.error}, leaving: ${_this.leaving})';
}


}

/// @nodoc
abstract mixin class $SlideStudioStateCopyWith<$Res>  {
  factory $SlideStudioStateCopyWith(SlideStudioState value, $Res Function(SlideStudioState) _then) = _$SlideStudioStateCopyWithImpl;
@useResult
$Res call({
 StudioInput input, Uint8List? reference, bool busy, bool saving, bool usageLoading, StudioUsage? usage, String? usageError, AiRasterBrand? brand, String? brandError, StudioResult? result, List<StudioResult> history, List<AiSlideDesign> proposals, String? pendingId, StudioInput? pendingInput, StudioOperation? completedOperation, bool pendingRaster, String? error, bool leaving
});


$StudioInputCopyWith<$Res> get input;$StudioUsageCopyWith<$Res>? get usage;$AiRasterBrandCopyWith<$Res>? get brand;$StudioResultCopyWith<$Res>? get result;$StudioInputCopyWith<$Res>? get pendingInput;$StudioOperationCopyWith<$Res>? get completedOperation;

}
/// @nodoc
class _$SlideStudioStateCopyWithImpl<$Res>
    implements $SlideStudioStateCopyWith<$Res> {
  _$SlideStudioStateCopyWithImpl(this._self, this._then);

  final SlideStudioState _self;
  final $Res Function(SlideStudioState) _then;

/// Create a copy of SlideStudioState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? input = null,Object? reference = freezed,Object? busy = null,Object? saving = null,Object? usageLoading = null,Object? usage = freezed,Object? usageError = freezed,Object? brand = freezed,Object? brandError = freezed,Object? result = freezed,Object? history = null,Object? proposals = null,Object? pendingId = freezed,Object? pendingInput = freezed,Object? completedOperation = freezed,Object? pendingRaster = null,Object? error = freezed,Object? leaving = null,}) {
  return _then(SlideStudioState(
input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as StudioInput,reference: freezed == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as Uint8List?,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,saving: null == saving ? _self.saving : saving // ignore: cast_nullable_to_non_nullable
as bool,usageLoading: null == usageLoading ? _self.usageLoading : usageLoading // ignore: cast_nullable_to_non_nullable
as bool,usage: freezed == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as StudioUsage?,usageError: freezed == usageError ? _self.usageError : usageError // ignore: cast_nullable_to_non_nullable
as String?,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as AiRasterBrand?,brandError: freezed == brandError ? _self.brandError : brandError // ignore: cast_nullable_to_non_nullable
as String?,result: freezed == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as StudioResult?,history: null == history ? _self.history : history // ignore: cast_nullable_to_non_nullable
as List<StudioResult>,proposals: null == proposals ? _self.proposals : proposals // ignore: cast_nullable_to_non_nullable
as List<AiSlideDesign>,pendingId: freezed == pendingId ? _self.pendingId : pendingId // ignore: cast_nullable_to_non_nullable
as String?,pendingInput: freezed == pendingInput ? _self.pendingInput : pendingInput // ignore: cast_nullable_to_non_nullable
as StudioInput?,completedOperation: freezed == completedOperation ? _self.completedOperation : completedOperation // ignore: cast_nullable_to_non_nullable
as StudioOperation?,pendingRaster: null == pendingRaster ? _self.pendingRaster : pendingRaster // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,leaving: null == leaving ? _self.leaving : leaving // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of SlideStudioState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioInputCopyWith<$Res> get input {

  return $StudioInputCopyWith<$Res>(_self.input, (value) {
    return _then(_self.copyWith(input: value));
  });
}/// Create a copy of SlideStudioState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioUsageCopyWith<$Res>? get usage {
    if (_self.usage == null) {
    return null;
  }

  return $StudioUsageCopyWith<$Res>(_self.usage!, (value) {
    return _then(_self.copyWith(usage: value));
  });
}/// Create a copy of SlideStudioState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiRasterBrandCopyWith<$Res>? get brand {
    if (_self.brand == null) {
    return null;
  }

  return $AiRasterBrandCopyWith<$Res>(_self.brand!, (value) {
    return _then(_self.copyWith(brand: value));
  });
}/// Create a copy of SlideStudioState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioResultCopyWith<$Res>? get result {
    if (_self.result == null) {
    return null;
  }

  return $StudioResultCopyWith<$Res>(_self.result!, (value) {
    return _then(_self.copyWith(result: value));
  });
}/// Create a copy of SlideStudioState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioInputCopyWith<$Res>? get pendingInput {
    if (_self.pendingInput == null) {
    return null;
  }

  return $StudioInputCopyWith<$Res>(_self.pendingInput!, (value) {
    return _then(_self.copyWith(pendingInput: value));
  });
}/// Create a copy of SlideStudioState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioOperationCopyWith<$Res>? get completedOperation {
    if (_self.completedOperation == null) {
    return null;
  }

  return $StudioOperationCopyWith<$Res>(_self.completedOperation!, (value) {
    return _then(_self.copyWith(completedOperation: value));
  });
}
}


/// Adds pattern-matching-related methods to [SlideStudioState].
extension SlideStudioStatePatterns on SlideStudioState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SlideStudioState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SlideStudioState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SlideStudioState value)  $default,){
final _that = this;
switch (_that) {
case _SlideStudioState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SlideStudioState value)?  $default,){
final _that = this;
switch (_that) {
case _SlideStudioState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( StudioInput input,  Uint8List? reference,  bool busy,  bool saving,  bool usageLoading,  StudioUsage? usage,  String? usageError,  AiRasterBrand? brand,  String? brandError,  StudioResult? result,  List<StudioResult> history,  List<AiSlideDesign> proposals,  String? pendingId,  StudioInput? pendingInput,  StudioOperation? completedOperation,  bool pendingRaster,  String? error,  bool leaving)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SlideStudioState() when $default != null:
return $default(_that.input,_that.reference,_that.busy,_that.saving,_that.usageLoading,_that.usage,_that.usageError,_that.brand,_that.brandError,_that.result,_that.history,_that.proposals,_that.pendingId,_that.pendingInput,_that.completedOperation,_that.pendingRaster,_that.error,_that.leaving);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( StudioInput input,  Uint8List? reference,  bool busy,  bool saving,  bool usageLoading,  StudioUsage? usage,  String? usageError,  AiRasterBrand? brand,  String? brandError,  StudioResult? result,  List<StudioResult> history,  List<AiSlideDesign> proposals,  String? pendingId,  StudioInput? pendingInput,  StudioOperation? completedOperation,  bool pendingRaster,  String? error,  bool leaving)  $default,) {final _that = this;
switch (_that) {
case _SlideStudioState():
return $default(_that.input,_that.reference,_that.busy,_that.saving,_that.usageLoading,_that.usage,_that.usageError,_that.brand,_that.brandError,_that.result,_that.history,_that.proposals,_that.pendingId,_that.pendingInput,_that.completedOperation,_that.pendingRaster,_that.error,_that.leaving);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( StudioInput input,  Uint8List? reference,  bool busy,  bool saving,  bool usageLoading,  StudioUsage? usage,  String? usageError,  AiRasterBrand? brand,  String? brandError,  StudioResult? result,  List<StudioResult> history,  List<AiSlideDesign> proposals,  String? pendingId,  StudioInput? pendingInput,  StudioOperation? completedOperation,  bool pendingRaster,  String? error,  bool leaving)?  $default,) {final _that = this;
switch (_that) {
case _SlideStudioState() when $default != null:
return $default(_that.input,_that.reference,_that.busy,_that.saving,_that.usageLoading,_that.usage,_that.usageError,_that.brand,_that.brandError,_that.result,_that.history,_that.proposals,_that.pendingId,_that.pendingInput,_that.completedOperation,_that.pendingRaster,_that.error,_that.leaving);case _:
  return null;

}
}

}

/// @nodoc


class _SlideStudioState extends SlideStudioState {
  const _SlideStudioState({required this.input, this.reference, this.busy = false, this.saving = false, this.usageLoading = true, this.usage, this.usageError, this.brand, this.brandError, this.result,  List<StudioResult> history = const [],  List<AiSlideDesign> proposals = const [], this.pendingId, this.pendingInput, this.completedOperation, this.pendingRaster = false, this.error, this.leaving = false}): _history = history,_proposals = proposals,super._();


@override final  StudioInput input;
@override final  Uint8List? reference;
@override@JsonKey() final  bool busy;
@override@JsonKey() final  bool saving;
@override@JsonKey() final  bool usageLoading;
@override final  StudioUsage? usage;
@override final  String? usageError;
@override final  AiRasterBrand? brand;
@override final  String? brandError;
@override final  StudioResult? result;
 final  List<StudioResult> _history;
@override@JsonKey() List<StudioResult> get history {
  if (_history is EqualUnmodifiableListView) return _history;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_history);
}

 final  List<AiSlideDesign> _proposals;
@override@JsonKey() List<AiSlideDesign> get proposals {
  if (_proposals is EqualUnmodifiableListView) return _proposals;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_proposals);
}

@override final  String? pendingId;
@override final  StudioInput? pendingInput;
@override final  StudioOperation? completedOperation;
@override@JsonKey() final  bool pendingRaster;
@override final  String? error;
@override@JsonKey() final  bool leaving;

/// Create a copy of SlideStudioState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SlideStudioStateCopyWith<_SlideStudioState> get copyWith => __$SlideStudioStateCopyWithImpl<_SlideStudioState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SlideStudioState&&(identical(other.input, input) || other.input == input)&&const DeepCollectionEquality().equals(other.reference, reference)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.saving, saving) || other.saving == saving)&&(identical(other.usageLoading, usageLoading) || other.usageLoading == usageLoading)&&(identical(other.usage, usage) || other.usage == usage)&&(identical(other.usageError, usageError) || other.usageError == usageError)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.brandError, brandError) || other.brandError == brandError)&&(identical(other.result, result) || other.result == result)&&const DeepCollectionEquality().equals(other.history, _history)&&const DeepCollectionEquality().equals(other.proposals, _proposals)&&(identical(other.pendingId, pendingId) || other.pendingId == pendingId)&&(identical(other.pendingInput, pendingInput) || other.pendingInput == pendingInput)&&(identical(other.completedOperation, completedOperation) || other.completedOperation == completedOperation)&&(identical(other.pendingRaster, pendingRaster) || other.pendingRaster == pendingRaster)&&(identical(other.error, error) || other.error == error)&&(identical(other.leaving, leaving) || other.leaving == leaving));
}


@override
int get hashCode {
    return Object.hash(runtimeType,input,const DeepCollectionEquality().hash(reference),busy,saving,usageLoading,usage,usageError,brand,brandError,result,const DeepCollectionEquality().hash(_history),const DeepCollectionEquality().hash(_proposals),pendingId,pendingInput,completedOperation,pendingRaster,error,leaving);
}

@override
String toString() {
    return 'SlideStudioState(input: $input, reference: $reference, busy: $busy, saving: $saving, usageLoading: $usageLoading, usage: $usage, usageError: $usageError, brand: $brand, brandError: $brandError, result: $result, history: $history, proposals: $proposals, pendingId: $pendingId, pendingInput: $pendingInput, completedOperation: $completedOperation, pendingRaster: $pendingRaster, error: $error, leaving: $leaving)';
}


}

/// @nodoc
abstract mixin class _$SlideStudioStateCopyWith<$Res> implements $SlideStudioStateCopyWith<$Res> {
  factory _$SlideStudioStateCopyWith(_SlideStudioState value, $Res Function(_SlideStudioState) _then) = __$SlideStudioStateCopyWithImpl;
@override @useResult
$Res call({
 StudioInput input, Uint8List? reference, bool busy, bool saving, bool usageLoading, StudioUsage? usage, String? usageError, AiRasterBrand? brand, String? brandError, StudioResult? result, List<StudioResult> history, List<AiSlideDesign> proposals, String? pendingId, StudioInput? pendingInput, StudioOperation? completedOperation, bool pendingRaster, String? error, bool leaving
});


@override $StudioInputCopyWith<$Res> get input;@override $StudioUsageCopyWith<$Res>? get usage;@override $AiRasterBrandCopyWith<$Res>? get brand;@override $StudioResultCopyWith<$Res>? get result;@override $StudioInputCopyWith<$Res>? get pendingInput;@override $StudioOperationCopyWith<$Res>? get completedOperation;

}
/// @nodoc
class __$SlideStudioStateCopyWithImpl<$Res>
    implements _$SlideStudioStateCopyWith<$Res> {
  __$SlideStudioStateCopyWithImpl(this._self, this._then);

  final _SlideStudioState _self;
  final $Res Function(_SlideStudioState) _then;

/// Create a copy of SlideStudioState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? input = null,Object? reference = freezed,Object? busy = null,Object? saving = null,Object? usageLoading = null,Object? usage = freezed,Object? usageError = freezed,Object? brand = freezed,Object? brandError = freezed,Object? result = freezed,Object? history = null,Object? proposals = null,Object? pendingId = freezed,Object? pendingInput = freezed,Object? completedOperation = freezed,Object? pendingRaster = null,Object? error = freezed,Object? leaving = null,}) {
  return _then(_SlideStudioState(
input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as StudioInput,reference: freezed == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as Uint8List?,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,saving: null == saving ? _self.saving : saving // ignore: cast_nullable_to_non_nullable
as bool,usageLoading: null == usageLoading ? _self.usageLoading : usageLoading // ignore: cast_nullable_to_non_nullable
as bool,usage: freezed == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as StudioUsage?,usageError: freezed == usageError ? _self.usageError : usageError // ignore: cast_nullable_to_non_nullable
as String?,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as AiRasterBrand?,brandError: freezed == brandError ? _self.brandError : brandError // ignore: cast_nullable_to_non_nullable
as String?,result: freezed == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as StudioResult?,history: null == history ? _self._history : history // ignore: cast_nullable_to_non_nullable
as List<StudioResult>,proposals: null == proposals ? _self._proposals : proposals // ignore: cast_nullable_to_non_nullable
as List<AiSlideDesign>,pendingId: freezed == pendingId ? _self.pendingId : pendingId // ignore: cast_nullable_to_non_nullable
as String?,pendingInput: freezed == pendingInput ? _self.pendingInput : pendingInput // ignore: cast_nullable_to_non_nullable
as StudioInput?,completedOperation: freezed == completedOperation ? _self.completedOperation : completedOperation // ignore: cast_nullable_to_non_nullable
as StudioOperation?,pendingRaster: null == pendingRaster ? _self.pendingRaster : pendingRaster // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,leaving: null == leaving ? _self.leaving : leaving // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of SlideStudioState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioInputCopyWith<$Res> get input {

  return $StudioInputCopyWith<$Res>(_self.input, (value) {
    return _then(_self.copyWith(input: value));
  });
}/// Create a copy of SlideStudioState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioUsageCopyWith<$Res>? get usage {
    if (_self.usage == null) {
    return null;
  }

  return $StudioUsageCopyWith<$Res>(_self.usage!, (value) {
    return _then(_self.copyWith(usage: value));
  });
}/// Create a copy of SlideStudioState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiRasterBrandCopyWith<$Res>? get brand {
    if (_self.brand == null) {
    return null;
  }

  return $AiRasterBrandCopyWith<$Res>(_self.brand!, (value) {
    return _then(_self.copyWith(brand: value));
  });
}/// Create a copy of SlideStudioState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioResultCopyWith<$Res>? get result {
    if (_self.result == null) {
    return null;
  }

  return $StudioResultCopyWith<$Res>(_self.result!, (value) {
    return _then(_self.copyWith(result: value));
  });
}/// Create a copy of SlideStudioState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioInputCopyWith<$Res>? get pendingInput {
    if (_self.pendingInput == null) {
    return null;
  }

  return $StudioInputCopyWith<$Res>(_self.pendingInput!, (value) {
    return _then(_self.copyWith(pendingInput: value));
  });
}/// Create a copy of SlideStudioState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioOperationCopyWith<$Res>? get completedOperation {
    if (_self.completedOperation == null) {
    return null;
  }

  return $StudioOperationCopyWith<$Res>(_self.completedOperation!, (value) {
    return _then(_self.copyWith(completedOperation: value));
  });
}
}

// dart format on
