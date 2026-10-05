// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_slides.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AiSlidesAccess {

 bool get premium; bool get enabled; int get remaining; int get limit;
/// Create a copy of AiSlidesAccess
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiSlidesAccessCopyWith<AiSlidesAccess> get copyWith => _$AiSlidesAccessCopyWithImpl<AiSlidesAccess>(this as AiSlidesAccess, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AiSlidesAccess;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiSlidesAccess&&(identical(other.premium, _this.premium) || other.premium == _this.premium)&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.remaining, _this.remaining) || other.remaining == _this.remaining)&&(identical(other.limit, _this.limit) || other.limit == _this.limit));
}


@override
int get hashCode {
  final _this = this as AiSlidesAccess;
  return Object.hash(runtimeType,_this.premium,_this.enabled,_this.remaining,_this.limit);
}

@override
String toString() {
  final _this = this as AiSlidesAccess;
  return 'AiSlidesAccess(premium: ${_this.premium}, enabled: ${_this.enabled}, remaining: ${_this.remaining}, limit: ${_this.limit})';
}


}

/// @nodoc
abstract mixin class $AiSlidesAccessCopyWith<$Res>  {
  factory $AiSlidesAccessCopyWith(AiSlidesAccess value, $Res Function(AiSlidesAccess) _then) = _$AiSlidesAccessCopyWithImpl;
@useResult
$Res call({
 bool premium, bool enabled, int remaining, int limit
});




}
/// @nodoc
class _$AiSlidesAccessCopyWithImpl<$Res>
    implements $AiSlidesAccessCopyWith<$Res> {
  _$AiSlidesAccessCopyWithImpl(this._self, this._then);

  final AiSlidesAccess _self;
  final $Res Function(AiSlidesAccess) _then;

/// Create a copy of AiSlidesAccess
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? premium = null,Object? enabled = null,Object? remaining = null,Object? limit = null,}) {
  return _then(AiSlidesAccess(
premium: null == premium ? _self.premium : premium // ignore: cast_nullable_to_non_nullable
as bool,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AiSlidesAccess].
extension AiSlidesAccessPatterns on AiSlidesAccess {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiSlidesAccess value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiSlidesAccess() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiSlidesAccess value)  $default,){
final _that = this;
switch (_that) {
case _AiSlidesAccess():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiSlidesAccess value)?  $default,){
final _that = this;
switch (_that) {
case _AiSlidesAccess() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool premium,  bool enabled,  int remaining,  int limit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiSlidesAccess() when $default != null:
return $default(_that.premium,_that.enabled,_that.remaining,_that.limit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool premium,  bool enabled,  int remaining,  int limit)  $default,) {final _that = this;
switch (_that) {
case _AiSlidesAccess():
return $default(_that.premium,_that.enabled,_that.remaining,_that.limit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool premium,  bool enabled,  int remaining,  int limit)?  $default,) {final _that = this;
switch (_that) {
case _AiSlidesAccess() when $default != null:
return $default(_that.premium,_that.enabled,_that.remaining,_that.limit);case _:
  return null;

}
}

}

/// @nodoc


class _AiSlidesAccess implements AiSlidesAccess {
  const _AiSlidesAccess({required this.premium, required this.enabled, required this.remaining, required this.limit});
  

@override final  bool premium;
@override final  bool enabled;
@override final  int remaining;
@override final  int limit;

/// Create a copy of AiSlidesAccess
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiSlidesAccessCopyWith<_AiSlidesAccess> get copyWith => __$AiSlidesAccessCopyWithImpl<_AiSlidesAccess>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiSlidesAccess&&(identical(other.premium, premium) || other.premium == premium)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.limit, limit) || other.limit == limit));
}


@override
int get hashCode {
    return Object.hash(runtimeType,premium,enabled,remaining,limit);
}

@override
String toString() {
    return 'AiSlidesAccess(premium: $premium, enabled: $enabled, remaining: $remaining, limit: $limit)';
}


}

/// @nodoc
abstract mixin class _$AiSlidesAccessCopyWith<$Res> implements $AiSlidesAccessCopyWith<$Res> {
  factory _$AiSlidesAccessCopyWith(_AiSlidesAccess value, $Res Function(_AiSlidesAccess) _then) = __$AiSlidesAccessCopyWithImpl;
@override @useResult
$Res call({
 bool premium, bool enabled, int remaining, int limit
});




}
/// @nodoc
class __$AiSlidesAccessCopyWithImpl<$Res>
    implements _$AiSlidesAccessCopyWith<$Res> {
  __$AiSlidesAccessCopyWithImpl(this._self, this._then);

  final _AiSlidesAccess _self;
  final $Res Function(_AiSlidesAccess) _then;

/// Create a copy of AiSlidesAccess
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? premium = null,Object? enabled = null,Object? remaining = null,Object? limit = null,}) {
  return _then(_AiSlidesAccess(
premium: null == premium ? _self.premium : premium // ignore: cast_nullable_to_non_nullable
as bool,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$AiSlideDraft {

 String get title; String get layout; List<String> get lines; int? get designBackgroundColor; int? get designTextColor; int? get designAccentColor; String get designLayout; int get designFontWeight; bool get designItalic; double get designSpacing; bool get showTimer; double get timerX; double get timerY; double get timerSize; int? get workSeconds; int? get restSeconds; int? get sets;
/// Create a copy of AiSlideDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiSlideDraftCopyWith<AiSlideDraft> get copyWith => _$AiSlideDraftCopyWithImpl<AiSlideDraft>(this as AiSlideDraft, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AiSlideDraft;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiSlideDraft&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.layout, _this.layout) || other.layout == _this.layout)&&const DeepCollectionEquality().equals(other.lines, _this.lines)&&(identical(other.designBackgroundColor, _this.designBackgroundColor) || other.designBackgroundColor == _this.designBackgroundColor)&&(identical(other.designTextColor, _this.designTextColor) || other.designTextColor == _this.designTextColor)&&(identical(other.designAccentColor, _this.designAccentColor) || other.designAccentColor == _this.designAccentColor)&&(identical(other.designLayout, _this.designLayout) || other.designLayout == _this.designLayout)&&(identical(other.designFontWeight, _this.designFontWeight) || other.designFontWeight == _this.designFontWeight)&&(identical(other.designItalic, _this.designItalic) || other.designItalic == _this.designItalic)&&(identical(other.designSpacing, _this.designSpacing) || other.designSpacing == _this.designSpacing)&&(identical(other.showTimer, _this.showTimer) || other.showTimer == _this.showTimer)&&(identical(other.timerX, _this.timerX) || other.timerX == _this.timerX)&&(identical(other.timerY, _this.timerY) || other.timerY == _this.timerY)&&(identical(other.timerSize, _this.timerSize) || other.timerSize == _this.timerSize)&&(identical(other.workSeconds, _this.workSeconds) || other.workSeconds == _this.workSeconds)&&(identical(other.restSeconds, _this.restSeconds) || other.restSeconds == _this.restSeconds)&&(identical(other.sets, _this.sets) || other.sets == _this.sets));
}


@override
int get hashCode {
  final _this = this as AiSlideDraft;
  return Object.hash(runtimeType,_this.title,_this.layout,const DeepCollectionEquality().hash(_this.lines),_this.designBackgroundColor,_this.designTextColor,_this.designAccentColor,_this.designLayout,_this.designFontWeight,_this.designItalic,_this.designSpacing,_this.showTimer,_this.timerX,_this.timerY,_this.timerSize,_this.workSeconds,_this.restSeconds,_this.sets);
}

@override
String toString() {
  final _this = this as AiSlideDraft;
  return 'AiSlideDraft(title: ${_this.title}, layout: ${_this.layout}, lines: ${_this.lines}, designBackgroundColor: ${_this.designBackgroundColor}, designTextColor: ${_this.designTextColor}, designAccentColor: ${_this.designAccentColor}, designLayout: ${_this.designLayout}, designFontWeight: ${_this.designFontWeight}, designItalic: ${_this.designItalic}, designSpacing: ${_this.designSpacing}, showTimer: ${_this.showTimer}, timerX: ${_this.timerX}, timerY: ${_this.timerY}, timerSize: ${_this.timerSize}, workSeconds: ${_this.workSeconds}, restSeconds: ${_this.restSeconds}, sets: ${_this.sets})';
}


}

/// @nodoc
abstract mixin class $AiSlideDraftCopyWith<$Res>  {
  factory $AiSlideDraftCopyWith(AiSlideDraft value, $Res Function(AiSlideDraft) _then) = _$AiSlideDraftCopyWithImpl;
@useResult
$Res call({
 String title, String layout, List<String> lines, int? designBackgroundColor, int? designTextColor, int? designAccentColor, String designLayout, int designFontWeight, bool designItalic, double designSpacing, bool showTimer, double timerX, double timerY, double timerSize, int? workSeconds, int? restSeconds, int? sets
});




}
/// @nodoc
class _$AiSlideDraftCopyWithImpl<$Res>
    implements $AiSlideDraftCopyWith<$Res> {
  _$AiSlideDraftCopyWithImpl(this._self, this._then);

  final AiSlideDraft _self;
  final $Res Function(AiSlideDraft) _then;

/// Create a copy of AiSlideDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? layout = null,Object? lines = null,Object? designBackgroundColor = freezed,Object? designTextColor = freezed,Object? designAccentColor = freezed,Object? designLayout = null,Object? designFontWeight = null,Object? designItalic = null,Object? designSpacing = null,Object? showTimer = null,Object? timerX = null,Object? timerY = null,Object? timerSize = null,Object? workSeconds = freezed,Object? restSeconds = freezed,Object? sets = freezed,}) {
  return _then(AiSlideDraft(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,layout: null == layout ? _self.layout : layout // ignore: cast_nullable_to_non_nullable
as String,lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<String>,designBackgroundColor: freezed == designBackgroundColor ? _self.designBackgroundColor : designBackgroundColor // ignore: cast_nullable_to_non_nullable
as int?,designTextColor: freezed == designTextColor ? _self.designTextColor : designTextColor // ignore: cast_nullable_to_non_nullable
as int?,designAccentColor: freezed == designAccentColor ? _self.designAccentColor : designAccentColor // ignore: cast_nullable_to_non_nullable
as int?,designLayout: null == designLayout ? _self.designLayout : designLayout // ignore: cast_nullable_to_non_nullable
as String,designFontWeight: null == designFontWeight ? _self.designFontWeight : designFontWeight // ignore: cast_nullable_to_non_nullable
as int,designItalic: null == designItalic ? _self.designItalic : designItalic // ignore: cast_nullable_to_non_nullable
as bool,designSpacing: null == designSpacing ? _self.designSpacing : designSpacing // ignore: cast_nullable_to_non_nullable
as double,showTimer: null == showTimer ? _self.showTimer : showTimer // ignore: cast_nullable_to_non_nullable
as bool,timerX: null == timerX ? _self.timerX : timerX // ignore: cast_nullable_to_non_nullable
as double,timerY: null == timerY ? _self.timerY : timerY // ignore: cast_nullable_to_non_nullable
as double,timerSize: null == timerSize ? _self.timerSize : timerSize // ignore: cast_nullable_to_non_nullable
as double,workSeconds: freezed == workSeconds ? _self.workSeconds : workSeconds // ignore: cast_nullable_to_non_nullable
as int?,restSeconds: freezed == restSeconds ? _self.restSeconds : restSeconds // ignore: cast_nullable_to_non_nullable
as int?,sets: freezed == sets ? _self.sets : sets // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [AiSlideDraft].
extension AiSlideDraftPatterns on AiSlideDraft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiSlideDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiSlideDraft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiSlideDraft value)  $default,){
final _that = this;
switch (_that) {
case _AiSlideDraft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiSlideDraft value)?  $default,){
final _that = this;
switch (_that) {
case _AiSlideDraft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String layout,  List<String> lines,  int? designBackgroundColor,  int? designTextColor,  int? designAccentColor,  String designLayout,  int designFontWeight,  bool designItalic,  double designSpacing,  bool showTimer,  double timerX,  double timerY,  double timerSize,  int? workSeconds,  int? restSeconds,  int? sets)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiSlideDraft() when $default != null:
return $default(_that.title,_that.layout,_that.lines,_that.designBackgroundColor,_that.designTextColor,_that.designAccentColor,_that.designLayout,_that.designFontWeight,_that.designItalic,_that.designSpacing,_that.showTimer,_that.timerX,_that.timerY,_that.timerSize,_that.workSeconds,_that.restSeconds,_that.sets);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String layout,  List<String> lines,  int? designBackgroundColor,  int? designTextColor,  int? designAccentColor,  String designLayout,  int designFontWeight,  bool designItalic,  double designSpacing,  bool showTimer,  double timerX,  double timerY,  double timerSize,  int? workSeconds,  int? restSeconds,  int? sets)  $default,) {final _that = this;
switch (_that) {
case _AiSlideDraft():
return $default(_that.title,_that.layout,_that.lines,_that.designBackgroundColor,_that.designTextColor,_that.designAccentColor,_that.designLayout,_that.designFontWeight,_that.designItalic,_that.designSpacing,_that.showTimer,_that.timerX,_that.timerY,_that.timerSize,_that.workSeconds,_that.restSeconds,_that.sets);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String layout,  List<String> lines,  int? designBackgroundColor,  int? designTextColor,  int? designAccentColor,  String designLayout,  int designFontWeight,  bool designItalic,  double designSpacing,  bool showTimer,  double timerX,  double timerY,  double timerSize,  int? workSeconds,  int? restSeconds,  int? sets)?  $default,) {final _that = this;
switch (_that) {
case _AiSlideDraft() when $default != null:
return $default(_that.title,_that.layout,_that.lines,_that.designBackgroundColor,_that.designTextColor,_that.designAccentColor,_that.designLayout,_that.designFontWeight,_that.designItalic,_that.designSpacing,_that.showTimer,_that.timerX,_that.timerY,_that.timerSize,_that.workSeconds,_that.restSeconds,_that.sets);case _:
  return null;

}
}

}

/// @nodoc


class _AiSlideDraft implements AiSlideDraft {
  const _AiSlideDraft({required this.title, required this.layout, required  List<String> lines, this.designBackgroundColor, this.designTextColor, this.designAccentColor, this.designLayout = 'auto', this.designFontWeight = 900, this.designItalic = true, this.designSpacing = 1.0, this.showTimer = true, this.timerX = 0.84, this.timerY = 0.5, this.timerSize = 1.0, this.workSeconds, this.restSeconds, this.sets}): _lines = lines;
  

@override final  String title;
@override final  String layout;
 final  List<String> _lines;
@override List<String> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}

@override final  int? designBackgroundColor;
@override final  int? designTextColor;
@override final  int? designAccentColor;
@override@JsonKey() final  String designLayout;
@override@JsonKey() final  int designFontWeight;
@override@JsonKey() final  bool designItalic;
@override@JsonKey() final  double designSpacing;
@override@JsonKey() final  bool showTimer;
@override@JsonKey() final  double timerX;
@override@JsonKey() final  double timerY;
@override@JsonKey() final  double timerSize;
@override final  int? workSeconds;
@override final  int? restSeconds;
@override final  int? sets;

/// Create a copy of AiSlideDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiSlideDraftCopyWith<_AiSlideDraft> get copyWith => __$AiSlideDraftCopyWithImpl<_AiSlideDraft>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiSlideDraft&&(identical(other.title, title) || other.title == title)&&(identical(other.layout, layout) || other.layout == layout)&&const DeepCollectionEquality().equals(other.lines, _lines)&&(identical(other.designBackgroundColor, designBackgroundColor) || other.designBackgroundColor == designBackgroundColor)&&(identical(other.designTextColor, designTextColor) || other.designTextColor == designTextColor)&&(identical(other.designAccentColor, designAccentColor) || other.designAccentColor == designAccentColor)&&(identical(other.designLayout, designLayout) || other.designLayout == designLayout)&&(identical(other.designFontWeight, designFontWeight) || other.designFontWeight == designFontWeight)&&(identical(other.designItalic, designItalic) || other.designItalic == designItalic)&&(identical(other.designSpacing, designSpacing) || other.designSpacing == designSpacing)&&(identical(other.showTimer, showTimer) || other.showTimer == showTimer)&&(identical(other.timerX, timerX) || other.timerX == timerX)&&(identical(other.timerY, timerY) || other.timerY == timerY)&&(identical(other.timerSize, timerSize) || other.timerSize == timerSize)&&(identical(other.workSeconds, workSeconds) || other.workSeconds == workSeconds)&&(identical(other.restSeconds, restSeconds) || other.restSeconds == restSeconds)&&(identical(other.sets, sets) || other.sets == sets));
}


@override
int get hashCode {
    return Object.hash(runtimeType,title,layout,const DeepCollectionEquality().hash(_lines),designBackgroundColor,designTextColor,designAccentColor,designLayout,designFontWeight,designItalic,designSpacing,showTimer,timerX,timerY,timerSize,workSeconds,restSeconds,sets);
}

@override
String toString() {
    return 'AiSlideDraft(title: $title, layout: $layout, lines: $lines, designBackgroundColor: $designBackgroundColor, designTextColor: $designTextColor, designAccentColor: $designAccentColor, designLayout: $designLayout, designFontWeight: $designFontWeight, designItalic: $designItalic, designSpacing: $designSpacing, showTimer: $showTimer, timerX: $timerX, timerY: $timerY, timerSize: $timerSize, workSeconds: $workSeconds, restSeconds: $restSeconds, sets: $sets)';
}


}

/// @nodoc
abstract mixin class _$AiSlideDraftCopyWith<$Res> implements $AiSlideDraftCopyWith<$Res> {
  factory _$AiSlideDraftCopyWith(_AiSlideDraft value, $Res Function(_AiSlideDraft) _then) = __$AiSlideDraftCopyWithImpl;
@override @useResult
$Res call({
 String title, String layout, List<String> lines, int? designBackgroundColor, int? designTextColor, int? designAccentColor, String designLayout, int designFontWeight, bool designItalic, double designSpacing, bool showTimer, double timerX, double timerY, double timerSize, int? workSeconds, int? restSeconds, int? sets
});




}
/// @nodoc
class __$AiSlideDraftCopyWithImpl<$Res>
    implements _$AiSlideDraftCopyWith<$Res> {
  __$AiSlideDraftCopyWithImpl(this._self, this._then);

  final _AiSlideDraft _self;
  final $Res Function(_AiSlideDraft) _then;

/// Create a copy of AiSlideDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? layout = null,Object? lines = null,Object? designBackgroundColor = freezed,Object? designTextColor = freezed,Object? designAccentColor = freezed,Object? designLayout = null,Object? designFontWeight = null,Object? designItalic = null,Object? designSpacing = null,Object? showTimer = null,Object? timerX = null,Object? timerY = null,Object? timerSize = null,Object? workSeconds = freezed,Object? restSeconds = freezed,Object? sets = freezed,}) {
  return _then(_AiSlideDraft(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,layout: null == layout ? _self.layout : layout // ignore: cast_nullable_to_non_nullable
as String,lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<String>,designBackgroundColor: freezed == designBackgroundColor ? _self.designBackgroundColor : designBackgroundColor // ignore: cast_nullable_to_non_nullable
as int?,designTextColor: freezed == designTextColor ? _self.designTextColor : designTextColor // ignore: cast_nullable_to_non_nullable
as int?,designAccentColor: freezed == designAccentColor ? _self.designAccentColor : designAccentColor // ignore: cast_nullable_to_non_nullable
as int?,designLayout: null == designLayout ? _self.designLayout : designLayout // ignore: cast_nullable_to_non_nullable
as String,designFontWeight: null == designFontWeight ? _self.designFontWeight : designFontWeight // ignore: cast_nullable_to_non_nullable
as int,designItalic: null == designItalic ? _self.designItalic : designItalic // ignore: cast_nullable_to_non_nullable
as bool,designSpacing: null == designSpacing ? _self.designSpacing : designSpacing // ignore: cast_nullable_to_non_nullable
as double,showTimer: null == showTimer ? _self.showTimer : showTimer // ignore: cast_nullable_to_non_nullable
as bool,timerX: null == timerX ? _self.timerX : timerX // ignore: cast_nullable_to_non_nullable
as double,timerY: null == timerY ? _self.timerY : timerY // ignore: cast_nullable_to_non_nullable
as double,timerSize: null == timerSize ? _self.timerSize : timerSize // ignore: cast_nullable_to_non_nullable
as double,workSeconds: freezed == workSeconds ? _self.workSeconds : workSeconds // ignore: cast_nullable_to_non_nullable
as int?,restSeconds: freezed == restSeconds ? _self.restSeconds : restSeconds // ignore: cast_nullable_to_non_nullable
as int?,sets: freezed == sets ? _self.sets : sets // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$AiSlidesResult {

 List<AiSlideDraft> get slides; List<String> get warnings; int get remaining; bool get cached;
/// Create a copy of AiSlidesResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiSlidesResultCopyWith<AiSlidesResult> get copyWith => _$AiSlidesResultCopyWithImpl<AiSlidesResult>(this as AiSlidesResult, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AiSlidesResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiSlidesResult&&const DeepCollectionEquality().equals(other.slides, _this.slides)&&const DeepCollectionEquality().equals(other.warnings, _this.warnings)&&(identical(other.remaining, _this.remaining) || other.remaining == _this.remaining)&&(identical(other.cached, _this.cached) || other.cached == _this.cached));
}


@override
int get hashCode {
  final _this = this as AiSlidesResult;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.slides),const DeepCollectionEquality().hash(_this.warnings),_this.remaining,_this.cached);
}

@override
String toString() {
  final _this = this as AiSlidesResult;
  return 'AiSlidesResult(slides: ${_this.slides}, warnings: ${_this.warnings}, remaining: ${_this.remaining}, cached: ${_this.cached})';
}


}

/// @nodoc
abstract mixin class $AiSlidesResultCopyWith<$Res>  {
  factory $AiSlidesResultCopyWith(AiSlidesResult value, $Res Function(AiSlidesResult) _then) = _$AiSlidesResultCopyWithImpl;
@useResult
$Res call({
 List<AiSlideDraft> slides, List<String> warnings, int remaining, bool cached
});




}
/// @nodoc
class _$AiSlidesResultCopyWithImpl<$Res>
    implements $AiSlidesResultCopyWith<$Res> {
  _$AiSlidesResultCopyWithImpl(this._self, this._then);

  final AiSlidesResult _self;
  final $Res Function(AiSlidesResult) _then;

/// Create a copy of AiSlidesResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? slides = null,Object? warnings = null,Object? remaining = null,Object? cached = null,}) {
  return _then(AiSlidesResult(
slides: null == slides ? _self.slides : slides // ignore: cast_nullable_to_non_nullable
as List<AiSlideDraft>,warnings: null == warnings ? _self.warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,cached: null == cached ? _self.cached : cached // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AiSlidesResult].
extension AiSlidesResultPatterns on AiSlidesResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiSlidesResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiSlidesResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiSlidesResult value)  $default,){
final _that = this;
switch (_that) {
case _AiSlidesResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiSlidesResult value)?  $default,){
final _that = this;
switch (_that) {
case _AiSlidesResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AiSlideDraft> slides,  List<String> warnings,  int remaining,  bool cached)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiSlidesResult() when $default != null:
return $default(_that.slides,_that.warnings,_that.remaining,_that.cached);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AiSlideDraft> slides,  List<String> warnings,  int remaining,  bool cached)  $default,) {final _that = this;
switch (_that) {
case _AiSlidesResult():
return $default(_that.slides,_that.warnings,_that.remaining,_that.cached);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AiSlideDraft> slides,  List<String> warnings,  int remaining,  bool cached)?  $default,) {final _that = this;
switch (_that) {
case _AiSlidesResult() when $default != null:
return $default(_that.slides,_that.warnings,_that.remaining,_that.cached);case _:
  return null;

}
}

}

/// @nodoc


class _AiSlidesResult implements AiSlidesResult {
  const _AiSlidesResult({required  List<AiSlideDraft> slides, required  List<String> warnings, required this.remaining, this.cached = false}): _slides = slides,_warnings = warnings;
  

 final  List<AiSlideDraft> _slides;
@override List<AiSlideDraft> get slides {
  if (_slides is EqualUnmodifiableListView) return _slides;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_slides);
}

 final  List<String> _warnings;
@override List<String> get warnings {
  if (_warnings is EqualUnmodifiableListView) return _warnings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_warnings);
}

@override final  int remaining;
@override@JsonKey() final  bool cached;

/// Create a copy of AiSlidesResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiSlidesResultCopyWith<_AiSlidesResult> get copyWith => __$AiSlidesResultCopyWithImpl<_AiSlidesResult>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiSlidesResult&&const DeepCollectionEquality().equals(other.slides, _slides)&&const DeepCollectionEquality().equals(other.warnings, _warnings)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.cached, cached) || other.cached == cached));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_slides),const DeepCollectionEquality().hash(_warnings),remaining,cached);
}

@override
String toString() {
    return 'AiSlidesResult(slides: $slides, warnings: $warnings, remaining: $remaining, cached: $cached)';
}


}

/// @nodoc
abstract mixin class _$AiSlidesResultCopyWith<$Res> implements $AiSlidesResultCopyWith<$Res> {
  factory _$AiSlidesResultCopyWith(_AiSlidesResult value, $Res Function(_AiSlidesResult) _then) = __$AiSlidesResultCopyWithImpl;
@override @useResult
$Res call({
 List<AiSlideDraft> slides, List<String> warnings, int remaining, bool cached
});




}
/// @nodoc
class __$AiSlidesResultCopyWithImpl<$Res>
    implements _$AiSlidesResultCopyWith<$Res> {
  __$AiSlidesResultCopyWithImpl(this._self, this._then);

  final _AiSlidesResult _self;
  final $Res Function(_AiSlidesResult) _then;

/// Create a copy of AiSlidesResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? slides = null,Object? warnings = null,Object? remaining = null,Object? cached = null,}) {
  return _then(_AiSlidesResult(
slides: null == slides ? _self._slides : slides // ignore: cast_nullable_to_non_nullable
as List<AiSlideDraft>,warnings: null == warnings ? _self._warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,cached: null == cached ? _self.cached : cached // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
