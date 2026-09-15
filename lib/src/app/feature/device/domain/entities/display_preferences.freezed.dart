// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'display_preferences.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DisplayPreferences {

 bool get enabled; bool get cover; double get zoom; double get offsetX; double get offsetY; double get safeInset;
/// Create a copy of DisplayPreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DisplayPreferencesCopyWith<DisplayPreferences> get copyWith => _$DisplayPreferencesCopyWithImpl<DisplayPreferences>(this as DisplayPreferences, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as DisplayPreferences;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DisplayPreferences&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.cover, _this.cover) || other.cover == _this.cover)&&(identical(other.zoom, _this.zoom) || other.zoom == _this.zoom)&&(identical(other.offsetX, _this.offsetX) || other.offsetX == _this.offsetX)&&(identical(other.offsetY, _this.offsetY) || other.offsetY == _this.offsetY)&&(identical(other.safeInset, _this.safeInset) || other.safeInset == _this.safeInset));
}


@override
int get hashCode {
  final _this = this as DisplayPreferences;
  return Object.hash(runtimeType,_this.enabled,_this.cover,_this.zoom,_this.offsetX,_this.offsetY,_this.safeInset);
}

@override
String toString() {
  final _this = this as DisplayPreferences;
  return 'DisplayPreferences(enabled: ${_this.enabled}, cover: ${_this.cover}, zoom: ${_this.zoom}, offsetX: ${_this.offsetX}, offsetY: ${_this.offsetY}, safeInset: ${_this.safeInset})';
}


}

/// @nodoc
abstract mixin class $DisplayPreferencesCopyWith<$Res>  {
  factory $DisplayPreferencesCopyWith(DisplayPreferences value, $Res Function(DisplayPreferences) _then) = _$DisplayPreferencesCopyWithImpl;
@useResult
$Res call({
 bool enabled, bool cover, double zoom, double offsetX, double offsetY, double safeInset
});




}
/// @nodoc
class _$DisplayPreferencesCopyWithImpl<$Res>
    implements $DisplayPreferencesCopyWith<$Res> {
  _$DisplayPreferencesCopyWithImpl(this._self, this._then);

  final DisplayPreferences _self;
  final $Res Function(DisplayPreferences) _then;

/// Create a copy of DisplayPreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? cover = null,Object? zoom = null,Object? offsetX = null,Object? offsetY = null,Object? safeInset = null,}) {
  return _then(DisplayPreferences(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,cover: null == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as bool,zoom: null == zoom ? _self.zoom : zoom // ignore: cast_nullable_to_non_nullable
as double,offsetX: null == offsetX ? _self.offsetX : offsetX // ignore: cast_nullable_to_non_nullable
as double,offsetY: null == offsetY ? _self.offsetY : offsetY // ignore: cast_nullable_to_non_nullable
as double,safeInset: null == safeInset ? _self.safeInset : safeInset // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [DisplayPreferences].
extension DisplayPreferencesPatterns on DisplayPreferences {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DisplayPreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DisplayPreferences() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DisplayPreferences value)  $default,){
final _that = this;
switch (_that) {
case _DisplayPreferences():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DisplayPreferences value)?  $default,){
final _that = this;
switch (_that) {
case _DisplayPreferences() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  bool cover,  double zoom,  double offsetX,  double offsetY,  double safeInset)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DisplayPreferences() when $default != null:
return $default(_that.enabled,_that.cover,_that.zoom,_that.offsetX,_that.offsetY,_that.safeInset);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  bool cover,  double zoom,  double offsetX,  double offsetY,  double safeInset)  $default,) {final _that = this;
switch (_that) {
case _DisplayPreferences():
return $default(_that.enabled,_that.cover,_that.zoom,_that.offsetX,_that.offsetY,_that.safeInset);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  bool cover,  double zoom,  double offsetX,  double offsetY,  double safeInset)?  $default,) {final _that = this;
switch (_that) {
case _DisplayPreferences() when $default != null:
return $default(_that.enabled,_that.cover,_that.zoom,_that.offsetX,_that.offsetY,_that.safeInset);case _:
  return null;

}
}

}

/// @nodoc


class _DisplayPreferences implements DisplayPreferences {
  const _DisplayPreferences({this.enabled = false, this.cover = false, this.zoom = 1.0, this.offsetX = 0.0, this.offsetY = 0.0, this.safeInset = 0.0});
  

@override@JsonKey() final  bool enabled;
@override@JsonKey() final  bool cover;
@override@JsonKey() final  double zoom;
@override@JsonKey() final  double offsetX;
@override@JsonKey() final  double offsetY;
@override@JsonKey() final  double safeInset;

/// Create a copy of DisplayPreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DisplayPreferencesCopyWith<_DisplayPreferences> get copyWith => __$DisplayPreferencesCopyWithImpl<_DisplayPreferences>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DisplayPreferences&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.zoom, zoom) || other.zoom == zoom)&&(identical(other.offsetX, offsetX) || other.offsetX == offsetX)&&(identical(other.offsetY, offsetY) || other.offsetY == offsetY)&&(identical(other.safeInset, safeInset) || other.safeInset == safeInset));
}


@override
int get hashCode {
    return Object.hash(runtimeType,enabled,cover,zoom,offsetX,offsetY,safeInset);
}

@override
String toString() {
    return 'DisplayPreferences(enabled: $enabled, cover: $cover, zoom: $zoom, offsetX: $offsetX, offsetY: $offsetY, safeInset: $safeInset)';
}


}

/// @nodoc
abstract mixin class _$DisplayPreferencesCopyWith<$Res> implements $DisplayPreferencesCopyWith<$Res> {
  factory _$DisplayPreferencesCopyWith(_DisplayPreferences value, $Res Function(_DisplayPreferences) _then) = __$DisplayPreferencesCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, bool cover, double zoom, double offsetX, double offsetY, double safeInset
});




}
/// @nodoc
class __$DisplayPreferencesCopyWithImpl<$Res>
    implements _$DisplayPreferencesCopyWith<$Res> {
  __$DisplayPreferencesCopyWithImpl(this._self, this._then);

  final _DisplayPreferences _self;
  final $Res Function(_DisplayPreferences) _then;

/// Create a copy of DisplayPreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? cover = null,Object? zoom = null,Object? offsetX = null,Object? offsetY = null,Object? safeInset = null,}) {
  return _then(_DisplayPreferences(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,cover: null == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as bool,zoom: null == zoom ? _self.zoom : zoom // ignore: cast_nullable_to_non_nullable
as double,offsetX: null == offsetX ? _self.offsetX : offsetX // ignore: cast_nullable_to_non_nullable
as double,offsetY: null == offsetY ? _self.offsetY : offsetY // ignore: cast_nullable_to_non_nullable
as double,safeInset: null == safeInset ? _self.safeInset : safeInset // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
