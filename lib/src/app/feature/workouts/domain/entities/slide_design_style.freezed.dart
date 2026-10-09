// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'slide_design_style.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SlideDesignStyle {

 int get version; String get family; String get fontFamily; int? get titleColor; int get titleWeight; String get motif;/// A customer-provided, fixed original artwork recipe; never AI-generated.
 String? get originalTemplate;
/// Create a copy of SlideDesignStyle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SlideDesignStyleCopyWith<SlideDesignStyle> get copyWith => _$SlideDesignStyleCopyWithImpl<SlideDesignStyle>(this as SlideDesignStyle, _$identity);

  /// Serializes this SlideDesignStyle to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SlideDesignStyle;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SlideDesignStyle&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.family, _this.family) || other.family == _this.family)&&(identical(other.fontFamily, _this.fontFamily) || other.fontFamily == _this.fontFamily)&&(identical(other.titleColor, _this.titleColor) || other.titleColor == _this.titleColor)&&(identical(other.titleWeight, _this.titleWeight) || other.titleWeight == _this.titleWeight)&&(identical(other.motif, _this.motif) || other.motif == _this.motif)&&(identical(other.originalTemplate, _this.originalTemplate) || other.originalTemplate == _this.originalTemplate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SlideDesignStyle;
  return Object.hash(runtimeType,_this.version,_this.family,_this.fontFamily,_this.titleColor,_this.titleWeight,_this.motif,_this.originalTemplate);
}

@override
String toString() {
  final _this = this as SlideDesignStyle;
  return 'SlideDesignStyle(version: ${_this.version}, family: ${_this.family}, fontFamily: ${_this.fontFamily}, titleColor: ${_this.titleColor}, titleWeight: ${_this.titleWeight}, motif: ${_this.motif}, originalTemplate: ${_this.originalTemplate})';
}


}

/// @nodoc
abstract mixin class $SlideDesignStyleCopyWith<$Res>  {
  factory $SlideDesignStyleCopyWith(SlideDesignStyle value, $Res Function(SlideDesignStyle) _then) = _$SlideDesignStyleCopyWithImpl;
@useResult
$Res call({
 int version, String family, String fontFamily, int? titleColor, int titleWeight, String motif, String? originalTemplate
});




}
/// @nodoc
class _$SlideDesignStyleCopyWithImpl<$Res>
    implements $SlideDesignStyleCopyWith<$Res> {
  _$SlideDesignStyleCopyWithImpl(this._self, this._then);

  final SlideDesignStyle _self;
  final $Res Function(SlideDesignStyle) _then;

/// Create a copy of SlideDesignStyle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? family = null,Object? fontFamily = null,Object? titleColor = freezed,Object? titleWeight = null,Object? motif = null,Object? originalTemplate = freezed,}) {
  return _then(SlideDesignStyle(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,family: null == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as String,fontFamily: null == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String,titleColor: freezed == titleColor ? _self.titleColor : titleColor // ignore: cast_nullable_to_non_nullable
as int?,titleWeight: null == titleWeight ? _self.titleWeight : titleWeight // ignore: cast_nullable_to_non_nullable
as int,motif: null == motif ? _self.motif : motif // ignore: cast_nullable_to_non_nullable
as String,originalTemplate: freezed == originalTemplate ? _self.originalTemplate : originalTemplate // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SlideDesignStyle].
extension SlideDesignStylePatterns on SlideDesignStyle {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SlideDesignStyle value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SlideDesignStyle() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SlideDesignStyle value)  $default,){
final _that = this;
switch (_that) {
case _SlideDesignStyle():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SlideDesignStyle value)?  $default,){
final _that = this;
switch (_that) {
case _SlideDesignStyle() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int version,  String family,  String fontFamily,  int? titleColor,  int titleWeight,  String motif,  String? originalTemplate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SlideDesignStyle() when $default != null:
return $default(_that.version,_that.family,_that.fontFamily,_that.titleColor,_that.titleWeight,_that.motif,_that.originalTemplate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int version,  String family,  String fontFamily,  int? titleColor,  int titleWeight,  String motif,  String? originalTemplate)  $default,) {final _that = this;
switch (_that) {
case _SlideDesignStyle():
return $default(_that.version,_that.family,_that.fontFamily,_that.titleColor,_that.titleWeight,_that.motif,_that.originalTemplate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int version,  String family,  String fontFamily,  int? titleColor,  int titleWeight,  String motif,  String? originalTemplate)?  $default,) {final _that = this;
switch (_that) {
case _SlideDesignStyle() when $default != null:
return $default(_that.version,_that.family,_that.fontFamily,_that.titleColor,_that.titleWeight,_that.motif,_that.originalTemplate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SlideDesignStyle implements SlideDesignStyle {
  const _SlideDesignStyle({this.version = 1, this.family = 'banner', this.fontFamily = 'sans', this.titleColor, this.titleWeight = 900, this.motif = '', this.originalTemplate});
  factory _SlideDesignStyle.fromJson(Map<String, dynamic> json) => _$SlideDesignStyleFromJson(json);

@override@JsonKey() final  int version;
@override@JsonKey() final  String family;
@override@JsonKey() final  String fontFamily;
@override final  int? titleColor;
@override@JsonKey() final  int titleWeight;
@override@JsonKey() final  String motif;
/// A customer-provided, fixed original artwork recipe; never AI-generated.
@override final  String? originalTemplate;

/// Create a copy of SlideDesignStyle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SlideDesignStyleCopyWith<_SlideDesignStyle> get copyWith => __$SlideDesignStyleCopyWithImpl<_SlideDesignStyle>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SlideDesignStyleToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SlideDesignStyle&&(identical(other.version, version) || other.version == version)&&(identical(other.family, family) || other.family == family)&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.titleColor, titleColor) || other.titleColor == titleColor)&&(identical(other.titleWeight, titleWeight) || other.titleWeight == titleWeight)&&(identical(other.motif, motif) || other.motif == motif)&&(identical(other.originalTemplate, originalTemplate) || other.originalTemplate == originalTemplate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,version,family,fontFamily,titleColor,titleWeight,motif,originalTemplate);
}

@override
String toString() {
    return 'SlideDesignStyle(version: $version, family: $family, fontFamily: $fontFamily, titleColor: $titleColor, titleWeight: $titleWeight, motif: $motif, originalTemplate: $originalTemplate)';
}


}

/// @nodoc
abstract mixin class _$SlideDesignStyleCopyWith<$Res> implements $SlideDesignStyleCopyWith<$Res> {
  factory _$SlideDesignStyleCopyWith(_SlideDesignStyle value, $Res Function(_SlideDesignStyle) _then) = __$SlideDesignStyleCopyWithImpl;
@override @useResult
$Res call({
 int version, String family, String fontFamily, int? titleColor, int titleWeight, String motif, String? originalTemplate
});




}
/// @nodoc
class __$SlideDesignStyleCopyWithImpl<$Res>
    implements _$SlideDesignStyleCopyWith<$Res> {
  __$SlideDesignStyleCopyWithImpl(this._self, this._then);

  final _SlideDesignStyle _self;
  final $Res Function(_SlideDesignStyle) _then;

/// Create a copy of SlideDesignStyle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? family = null,Object? fontFamily = null,Object? titleColor = freezed,Object? titleWeight = null,Object? motif = null,Object? originalTemplate = freezed,}) {
  return _then(_SlideDesignStyle(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,family: null == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as String,fontFamily: null == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String,titleColor: freezed == titleColor ? _self.titleColor : titleColor // ignore: cast_nullable_to_non_nullable
as int?,titleWeight: null == titleWeight ? _self.titleWeight : titleWeight // ignore: cast_nullable_to_non_nullable
as int,motif: null == motif ? _self.motif : motif // ignore: cast_nullable_to_non_nullable
as String,originalTemplate: freezed == originalTemplate ? _self.originalTemplate : originalTemplate // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
