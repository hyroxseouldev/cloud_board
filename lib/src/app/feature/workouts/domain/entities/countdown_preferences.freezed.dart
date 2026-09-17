// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'countdown_preferences.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CountdownAppearance {

 bool get showReady; bool get showTitle; double get numberScale; CountdownNumberFormat get numberFormat; int? get numberColor; bool get numberShadow; bool get overlayEnabled; double? get overlayOpacity; int? get overlayColor;
/// Create a copy of CountdownAppearance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CountdownAppearanceCopyWith<CountdownAppearance> get copyWith => _$CountdownAppearanceCopyWithImpl<CountdownAppearance>(this as CountdownAppearance, _$identity);

  /// Serializes this CountdownAppearance to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CountdownAppearance;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CountdownAppearance&&(identical(other.showReady, _this.showReady) || other.showReady == _this.showReady)&&(identical(other.showTitle, _this.showTitle) || other.showTitle == _this.showTitle)&&(identical(other.numberScale, _this.numberScale) || other.numberScale == _this.numberScale)&&(identical(other.numberFormat, _this.numberFormat) || other.numberFormat == _this.numberFormat)&&(identical(other.numberColor, _this.numberColor) || other.numberColor == _this.numberColor)&&(identical(other.numberShadow, _this.numberShadow) || other.numberShadow == _this.numberShadow)&&(identical(other.overlayEnabled, _this.overlayEnabled) || other.overlayEnabled == _this.overlayEnabled)&&(identical(other.overlayOpacity, _this.overlayOpacity) || other.overlayOpacity == _this.overlayOpacity)&&(identical(other.overlayColor, _this.overlayColor) || other.overlayColor == _this.overlayColor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CountdownAppearance;
  return Object.hash(runtimeType,_this.showReady,_this.showTitle,_this.numberScale,_this.numberFormat,_this.numberColor,_this.numberShadow,_this.overlayEnabled,_this.overlayOpacity,_this.overlayColor);
}

@override
String toString() {
  final _this = this as CountdownAppearance;
  return 'CountdownAppearance(showReady: ${_this.showReady}, showTitle: ${_this.showTitle}, numberScale: ${_this.numberScale}, numberFormat: ${_this.numberFormat}, numberColor: ${_this.numberColor}, numberShadow: ${_this.numberShadow}, overlayEnabled: ${_this.overlayEnabled}, overlayOpacity: ${_this.overlayOpacity}, overlayColor: ${_this.overlayColor})';
}


}

/// @nodoc
abstract mixin class $CountdownAppearanceCopyWith<$Res>  {
  factory $CountdownAppearanceCopyWith(CountdownAppearance value, $Res Function(CountdownAppearance) _then) = _$CountdownAppearanceCopyWithImpl;
@useResult
$Res call({
 bool showReady, bool showTitle, double numberScale, CountdownNumberFormat numberFormat, int? numberColor, bool numberShadow, bool overlayEnabled, double? overlayOpacity, int? overlayColor
});




}
/// @nodoc
class _$CountdownAppearanceCopyWithImpl<$Res>
    implements $CountdownAppearanceCopyWith<$Res> {
  _$CountdownAppearanceCopyWithImpl(this._self, this._then);

  final CountdownAppearance _self;
  final $Res Function(CountdownAppearance) _then;

/// Create a copy of CountdownAppearance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? showReady = null,Object? showTitle = null,Object? numberScale = null,Object? numberFormat = null,Object? numberColor = freezed,Object? numberShadow = null,Object? overlayEnabled = null,Object? overlayOpacity = freezed,Object? overlayColor = freezed,}) {
  return _then(CountdownAppearance(
showReady: null == showReady ? _self.showReady : showReady // ignore: cast_nullable_to_non_nullable
as bool,showTitle: null == showTitle ? _self.showTitle : showTitle // ignore: cast_nullable_to_non_nullable
as bool,numberScale: null == numberScale ? _self.numberScale : numberScale // ignore: cast_nullable_to_non_nullable
as double,numberFormat: null == numberFormat ? _self.numberFormat : numberFormat // ignore: cast_nullable_to_non_nullable
as CountdownNumberFormat,numberColor: freezed == numberColor ? _self.numberColor : numberColor // ignore: cast_nullable_to_non_nullable
as int?,numberShadow: null == numberShadow ? _self.numberShadow : numberShadow // ignore: cast_nullable_to_non_nullable
as bool,overlayEnabled: null == overlayEnabled ? _self.overlayEnabled : overlayEnabled // ignore: cast_nullable_to_non_nullable
as bool,overlayOpacity: freezed == overlayOpacity ? _self.overlayOpacity : overlayOpacity // ignore: cast_nullable_to_non_nullable
as double?,overlayColor: freezed == overlayColor ? _self.overlayColor : overlayColor // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [CountdownAppearance].
extension CountdownAppearancePatterns on CountdownAppearance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CountdownAppearance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CountdownAppearance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CountdownAppearance value)  $default,){
final _that = this;
switch (_that) {
case _CountdownAppearance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CountdownAppearance value)?  $default,){
final _that = this;
switch (_that) {
case _CountdownAppearance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool showReady,  bool showTitle,  double numberScale,  CountdownNumberFormat numberFormat,  int? numberColor,  bool numberShadow,  bool overlayEnabled,  double? overlayOpacity,  int? overlayColor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CountdownAppearance() when $default != null:
return $default(_that.showReady,_that.showTitle,_that.numberScale,_that.numberFormat,_that.numberColor,_that.numberShadow,_that.overlayEnabled,_that.overlayOpacity,_that.overlayColor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool showReady,  bool showTitle,  double numberScale,  CountdownNumberFormat numberFormat,  int? numberColor,  bool numberShadow,  bool overlayEnabled,  double? overlayOpacity,  int? overlayColor)  $default,) {final _that = this;
switch (_that) {
case _CountdownAppearance():
return $default(_that.showReady,_that.showTitle,_that.numberScale,_that.numberFormat,_that.numberColor,_that.numberShadow,_that.overlayEnabled,_that.overlayOpacity,_that.overlayColor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool showReady,  bool showTitle,  double numberScale,  CountdownNumberFormat numberFormat,  int? numberColor,  bool numberShadow,  bool overlayEnabled,  double? overlayOpacity,  int? overlayColor)?  $default,) {final _that = this;
switch (_that) {
case _CountdownAppearance() when $default != null:
return $default(_that.showReady,_that.showTitle,_that.numberScale,_that.numberFormat,_that.numberColor,_that.numberShadow,_that.overlayEnabled,_that.overlayOpacity,_that.overlayColor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CountdownAppearance implements CountdownAppearance {
  const _CountdownAppearance({this.showReady = true, this.showTitle = true, this.numberScale = 1.0, this.numberFormat = CountdownNumberFormat.seconds, this.numberColor, this.numberShadow = false, this.overlayEnabled = true, this.overlayOpacity, this.overlayColor});
  factory _CountdownAppearance.fromJson(Map<String, dynamic> json) => _$CountdownAppearanceFromJson(json);

@override@JsonKey() final  bool showReady;
@override@JsonKey() final  bool showTitle;
@override@JsonKey() final  double numberScale;
@override@JsonKey() final  CountdownNumberFormat numberFormat;
@override final  int? numberColor;
@override@JsonKey() final  bool numberShadow;
@override@JsonKey() final  bool overlayEnabled;
@override final  double? overlayOpacity;
@override final  int? overlayColor;

/// Create a copy of CountdownAppearance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CountdownAppearanceCopyWith<_CountdownAppearance> get copyWith => __$CountdownAppearanceCopyWithImpl<_CountdownAppearance>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CountdownAppearanceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CountdownAppearance&&(identical(other.showReady, showReady) || other.showReady == showReady)&&(identical(other.showTitle, showTitle) || other.showTitle == showTitle)&&(identical(other.numberScale, numberScale) || other.numberScale == numberScale)&&(identical(other.numberFormat, numberFormat) || other.numberFormat == numberFormat)&&(identical(other.numberColor, numberColor) || other.numberColor == numberColor)&&(identical(other.numberShadow, numberShadow) || other.numberShadow == numberShadow)&&(identical(other.overlayEnabled, overlayEnabled) || other.overlayEnabled == overlayEnabled)&&(identical(other.overlayOpacity, overlayOpacity) || other.overlayOpacity == overlayOpacity)&&(identical(other.overlayColor, overlayColor) || other.overlayColor == overlayColor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,showReady,showTitle,numberScale,numberFormat,numberColor,numberShadow,overlayEnabled,overlayOpacity,overlayColor);
}

@override
String toString() {
    return 'CountdownAppearance(showReady: $showReady, showTitle: $showTitle, numberScale: $numberScale, numberFormat: $numberFormat, numberColor: $numberColor, numberShadow: $numberShadow, overlayEnabled: $overlayEnabled, overlayOpacity: $overlayOpacity, overlayColor: $overlayColor)';
}


}

/// @nodoc
abstract mixin class _$CountdownAppearanceCopyWith<$Res> implements $CountdownAppearanceCopyWith<$Res> {
  factory _$CountdownAppearanceCopyWith(_CountdownAppearance value, $Res Function(_CountdownAppearance) _then) = __$CountdownAppearanceCopyWithImpl;
@override @useResult
$Res call({
 bool showReady, bool showTitle, double numberScale, CountdownNumberFormat numberFormat, int? numberColor, bool numberShadow, bool overlayEnabled, double? overlayOpacity, int? overlayColor
});




}
/// @nodoc
class __$CountdownAppearanceCopyWithImpl<$Res>
    implements _$CountdownAppearanceCopyWith<$Res> {
  __$CountdownAppearanceCopyWithImpl(this._self, this._then);

  final _CountdownAppearance _self;
  final $Res Function(_CountdownAppearance) _then;

/// Create a copy of CountdownAppearance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? showReady = null,Object? showTitle = null,Object? numberScale = null,Object? numberFormat = null,Object? numberColor = freezed,Object? numberShadow = null,Object? overlayEnabled = null,Object? overlayOpacity = freezed,Object? overlayColor = freezed,}) {
  return _then(_CountdownAppearance(
showReady: null == showReady ? _self.showReady : showReady // ignore: cast_nullable_to_non_nullable
as bool,showTitle: null == showTitle ? _self.showTitle : showTitle // ignore: cast_nullable_to_non_nullable
as bool,numberScale: null == numberScale ? _self.numberScale : numberScale // ignore: cast_nullable_to_non_nullable
as double,numberFormat: null == numberFormat ? _self.numberFormat : numberFormat // ignore: cast_nullable_to_non_nullable
as CountdownNumberFormat,numberColor: freezed == numberColor ? _self.numberColor : numberColor // ignore: cast_nullable_to_non_nullable
as int?,numberShadow: null == numberShadow ? _self.numberShadow : numberShadow // ignore: cast_nullable_to_non_nullable
as bool,overlayEnabled: null == overlayEnabled ? _self.overlayEnabled : overlayEnabled // ignore: cast_nullable_to_non_nullable
as bool,overlayOpacity: freezed == overlayOpacity ? _self.overlayOpacity : overlayOpacity // ignore: cast_nullable_to_non_nullable
as double?,overlayColor: freezed == overlayColor ? _self.overlayColor : overlayColor // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$CountdownPreferences {

 int get seconds; int get backgroundColor; String get imageSource; CountdownAppearance get appearance;
/// Create a copy of CountdownPreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CountdownPreferencesCopyWith<CountdownPreferences> get copyWith => _$CountdownPreferencesCopyWithImpl<CountdownPreferences>(this as CountdownPreferences, _$identity);

  /// Serializes this CountdownPreferences to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CountdownPreferences;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CountdownPreferences&&(identical(other.seconds, _this.seconds) || other.seconds == _this.seconds)&&(identical(other.backgroundColor, _this.backgroundColor) || other.backgroundColor == _this.backgroundColor)&&(identical(other.imageSource, _this.imageSource) || other.imageSource == _this.imageSource)&&(identical(other.appearance, _this.appearance) || other.appearance == _this.appearance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CountdownPreferences;
  return Object.hash(runtimeType,_this.seconds,_this.backgroundColor,_this.imageSource,_this.appearance);
}

@override
String toString() {
  final _this = this as CountdownPreferences;
  return 'CountdownPreferences(seconds: ${_this.seconds}, backgroundColor: ${_this.backgroundColor}, imageSource: ${_this.imageSource}, appearance: ${_this.appearance})';
}


}

/// @nodoc
abstract mixin class $CountdownPreferencesCopyWith<$Res>  {
  factory $CountdownPreferencesCopyWith(CountdownPreferences value, $Res Function(CountdownPreferences) _then) = _$CountdownPreferencesCopyWithImpl;
@useResult
$Res call({
 int seconds, int backgroundColor, String imageSource, CountdownAppearance appearance
});


$CountdownAppearanceCopyWith<$Res> get appearance;

}
/// @nodoc
class _$CountdownPreferencesCopyWithImpl<$Res>
    implements $CountdownPreferencesCopyWith<$Res> {
  _$CountdownPreferencesCopyWithImpl(this._self, this._then);

  final CountdownPreferences _self;
  final $Res Function(CountdownPreferences) _then;

/// Create a copy of CountdownPreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? seconds = null,Object? backgroundColor = null,Object? imageSource = null,Object? appearance = null,}) {
  return _then(CountdownPreferences(
seconds: null == seconds ? _self.seconds : seconds // ignore: cast_nullable_to_non_nullable
as int,backgroundColor: null == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as int,imageSource: null == imageSource ? _self.imageSource : imageSource // ignore: cast_nullable_to_non_nullable
as String,appearance: null == appearance ? _self.appearance : appearance // ignore: cast_nullable_to_non_nullable
as CountdownAppearance,
  ));
}
/// Create a copy of CountdownPreferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CountdownAppearanceCopyWith<$Res> get appearance {
  
  return $CountdownAppearanceCopyWith<$Res>(_self.appearance, (value) {
    return _then(_self.copyWith(appearance: value));
  });
}
}


/// Adds pattern-matching-related methods to [CountdownPreferences].
extension CountdownPreferencesPatterns on CountdownPreferences {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CountdownPreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CountdownPreferences() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CountdownPreferences value)  $default,){
final _that = this;
switch (_that) {
case _CountdownPreferences():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CountdownPreferences value)?  $default,){
final _that = this;
switch (_that) {
case _CountdownPreferences() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int seconds,  int backgroundColor,  String imageSource,  CountdownAppearance appearance)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CountdownPreferences() when $default != null:
return $default(_that.seconds,_that.backgroundColor,_that.imageSource,_that.appearance);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int seconds,  int backgroundColor,  String imageSource,  CountdownAppearance appearance)  $default,) {final _that = this;
switch (_that) {
case _CountdownPreferences():
return $default(_that.seconds,_that.backgroundColor,_that.imageSource,_that.appearance);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int seconds,  int backgroundColor,  String imageSource,  CountdownAppearance appearance)?  $default,) {final _that = this;
switch (_that) {
case _CountdownPreferences() when $default != null:
return $default(_that.seconds,_that.backgroundColor,_that.imageSource,_that.appearance);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _CountdownPreferences extends CountdownPreferences {
  const _CountdownPreferences({this.seconds = 3, this.backgroundColor = 0xFF000000, this.imageSource = '', this.appearance = const CountdownAppearance()}): super._();
  factory _CountdownPreferences.fromJson(Map<String, dynamic> json) => _$CountdownPreferencesFromJson(json);

@override@JsonKey() final  int seconds;
@override@JsonKey() final  int backgroundColor;
@override@JsonKey() final  String imageSource;
@override@JsonKey() final  CountdownAppearance appearance;

/// Create a copy of CountdownPreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CountdownPreferencesCopyWith<_CountdownPreferences> get copyWith => __$CountdownPreferencesCopyWithImpl<_CountdownPreferences>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CountdownPreferencesToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CountdownPreferences&&(identical(other.seconds, seconds) || other.seconds == seconds)&&(identical(other.backgroundColor, backgroundColor) || other.backgroundColor == backgroundColor)&&(identical(other.imageSource, imageSource) || other.imageSource == imageSource)&&(identical(other.appearance, appearance) || other.appearance == appearance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,seconds,backgroundColor,imageSource,appearance);
}

@override
String toString() {
    return 'CountdownPreferences(seconds: $seconds, backgroundColor: $backgroundColor, imageSource: $imageSource, appearance: $appearance)';
}


}

/// @nodoc
abstract mixin class _$CountdownPreferencesCopyWith<$Res> implements $CountdownPreferencesCopyWith<$Res> {
  factory _$CountdownPreferencesCopyWith(_CountdownPreferences value, $Res Function(_CountdownPreferences) _then) = __$CountdownPreferencesCopyWithImpl;
@override @useResult
$Res call({
 int seconds, int backgroundColor, String imageSource, CountdownAppearance appearance
});


@override $CountdownAppearanceCopyWith<$Res> get appearance;

}
/// @nodoc
class __$CountdownPreferencesCopyWithImpl<$Res>
    implements _$CountdownPreferencesCopyWith<$Res> {
  __$CountdownPreferencesCopyWithImpl(this._self, this._then);

  final _CountdownPreferences _self;
  final $Res Function(_CountdownPreferences) _then;

/// Create a copy of CountdownPreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? seconds = null,Object? backgroundColor = null,Object? imageSource = null,Object? appearance = null,}) {
  return _then(_CountdownPreferences(
seconds: null == seconds ? _self.seconds : seconds // ignore: cast_nullable_to_non_nullable
as int,backgroundColor: null == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as int,imageSource: null == imageSource ? _self.imageSource : imageSource // ignore: cast_nullable_to_non_nullable
as String,appearance: null == appearance ? _self.appearance : appearance // ignore: cast_nullable_to_non_nullable
as CountdownAppearance,
  ));
}

/// Create a copy of CountdownPreferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CountdownAppearanceCopyWith<$Res> get appearance {
  
  return $CountdownAppearanceCopyWith<$Res>(_self.appearance, (value) {
    return _then(_self.copyWith(appearance: value));
  });
}
}

// dart format on
