// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'center_slide_recipe.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CenterSlideRecipe {

 int get schemaVersion; String get templateId; int get revision; String get centerId; int get width; int get height; int get backgroundColor; String? get backgroundPath; String? get backgroundSha256; List<CenterSlideField> get fields; CenterSlideBody? get body;
/// Create a copy of CenterSlideRecipe
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CenterSlideRecipeCopyWith<CenterSlideRecipe> get copyWith => _$CenterSlideRecipeCopyWithImpl<CenterSlideRecipe>(this as CenterSlideRecipe, _$identity);

  /// Serializes this CenterSlideRecipe to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CenterSlideRecipe;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CenterSlideRecipe&&(identical(other.schemaVersion, _this.schemaVersion) || other.schemaVersion == _this.schemaVersion)&&(identical(other.templateId, _this.templateId) || other.templateId == _this.templateId)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&(identical(other.centerId, _this.centerId) || other.centerId == _this.centerId)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&(identical(other.backgroundColor, _this.backgroundColor) || other.backgroundColor == _this.backgroundColor)&&(identical(other.backgroundPath, _this.backgroundPath) || other.backgroundPath == _this.backgroundPath)&&(identical(other.backgroundSha256, _this.backgroundSha256) || other.backgroundSha256 == _this.backgroundSha256)&&const DeepCollectionEquality().equals(other.fields, _this.fields)&&(identical(other.body, _this.body) || other.body == _this.body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CenterSlideRecipe;
  return Object.hash(runtimeType,_this.schemaVersion,_this.templateId,_this.revision,_this.centerId,_this.width,_this.height,_this.backgroundColor,_this.backgroundPath,_this.backgroundSha256,const DeepCollectionEquality().hash(_this.fields),_this.body);
}

@override
String toString() {
  final _this = this as CenterSlideRecipe;
  return 'CenterSlideRecipe(schemaVersion: ${_this.schemaVersion}, templateId: ${_this.templateId}, revision: ${_this.revision}, centerId: ${_this.centerId}, width: ${_this.width}, height: ${_this.height}, backgroundColor: ${_this.backgroundColor}, backgroundPath: ${_this.backgroundPath}, backgroundSha256: ${_this.backgroundSha256}, fields: ${_this.fields}, body: ${_this.body})';
}


}

/// @nodoc
abstract mixin class $CenterSlideRecipeCopyWith<$Res>  {
  factory $CenterSlideRecipeCopyWith(CenterSlideRecipe value, $Res Function(CenterSlideRecipe) _then) = _$CenterSlideRecipeCopyWithImpl;
@useResult
$Res call({
 int schemaVersion, String templateId, int revision, String centerId, int width, int height, int backgroundColor, String? backgroundPath, String? backgroundSha256, List<CenterSlideField> fields, CenterSlideBody? body
});


$CenterSlideBodyCopyWith<$Res>? get body;

}
/// @nodoc
class _$CenterSlideRecipeCopyWithImpl<$Res>
    implements $CenterSlideRecipeCopyWith<$Res> {
  _$CenterSlideRecipeCopyWithImpl(this._self, this._then);

  final CenterSlideRecipe _self;
  final $Res Function(CenterSlideRecipe) _then;

/// Create a copy of CenterSlideRecipe
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? schemaVersion = null,Object? templateId = null,Object? revision = null,Object? centerId = null,Object? width = null,Object? height = null,Object? backgroundColor = null,Object? backgroundPath = freezed,Object? backgroundSha256 = freezed,Object? fields = null,Object? body = freezed,}) {
  return _then(CenterSlideRecipe(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,templateId: null == templateId ? _self.templateId : templateId // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,centerId: null == centerId ? _self.centerId : centerId // ignore: cast_nullable_to_non_nullable
as String,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,backgroundColor: null == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as int,backgroundPath: freezed == backgroundPath ? _self.backgroundPath : backgroundPath // ignore: cast_nullable_to_non_nullable
as String?,backgroundSha256: freezed == backgroundSha256 ? _self.backgroundSha256 : backgroundSha256 // ignore: cast_nullable_to_non_nullable
as String?,fields: null == fields ? _self.fields : fields // ignore: cast_nullable_to_non_nullable
as List<CenterSlideField>,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as CenterSlideBody?,
  ));
}
/// Create a copy of CenterSlideRecipe
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CenterSlideBodyCopyWith<$Res>? get body {
    if (_self.body == null) {
    return null;
  }

  return $CenterSlideBodyCopyWith<$Res>(_self.body!, (value) {
    return _then(_self.copyWith(body: value));
  });
}
}


/// Adds pattern-matching-related methods to [CenterSlideRecipe].
extension CenterSlideRecipePatterns on CenterSlideRecipe {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CenterSlideRecipe value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CenterSlideRecipe() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CenterSlideRecipe value)  $default,){
final _that = this;
switch (_that) {
case _CenterSlideRecipe():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CenterSlideRecipe value)?  $default,){
final _that = this;
switch (_that) {
case _CenterSlideRecipe() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int schemaVersion,  String templateId,  int revision,  String centerId,  int width,  int height,  int backgroundColor,  String? backgroundPath,  String? backgroundSha256,  List<CenterSlideField> fields,  CenterSlideBody? body)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CenterSlideRecipe() when $default != null:
return $default(_that.schemaVersion,_that.templateId,_that.revision,_that.centerId,_that.width,_that.height,_that.backgroundColor,_that.backgroundPath,_that.backgroundSha256,_that.fields,_that.body);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int schemaVersion,  String templateId,  int revision,  String centerId,  int width,  int height,  int backgroundColor,  String? backgroundPath,  String? backgroundSha256,  List<CenterSlideField> fields,  CenterSlideBody? body)  $default,) {final _that = this;
switch (_that) {
case _CenterSlideRecipe():
return $default(_that.schemaVersion,_that.templateId,_that.revision,_that.centerId,_that.width,_that.height,_that.backgroundColor,_that.backgroundPath,_that.backgroundSha256,_that.fields,_that.body);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int schemaVersion,  String templateId,  int revision,  String centerId,  int width,  int height,  int backgroundColor,  String? backgroundPath,  String? backgroundSha256,  List<CenterSlideField> fields,  CenterSlideBody? body)?  $default,) {final _that = this;
switch (_that) {
case _CenterSlideRecipe() when $default != null:
return $default(_that.schemaVersion,_that.templateId,_that.revision,_that.centerId,_that.width,_that.height,_that.backgroundColor,_that.backgroundPath,_that.backgroundSha256,_that.fields,_that.body);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _CenterSlideRecipe implements CenterSlideRecipe {
  const _CenterSlideRecipe({this.schemaVersion = 1, required this.templateId, required this.revision, required this.centerId, required this.width, required this.height, required this.backgroundColor, this.backgroundPath, this.backgroundSha256, required  List<CenterSlideField> fields, this.body}): _fields = fields;
  factory _CenterSlideRecipe.fromJson(Map<String, dynamic> json) => _$CenterSlideRecipeFromJson(json);

@override@JsonKey() final  int schemaVersion;
@override final  String templateId;
@override final  int revision;
@override final  String centerId;
@override final  int width;
@override final  int height;
@override final  int backgroundColor;
@override final  String? backgroundPath;
@override final  String? backgroundSha256;
 final  List<CenterSlideField> _fields;
@override List<CenterSlideField> get fields {
  if (_fields is EqualUnmodifiableListView) return _fields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_fields);
}

@override final  CenterSlideBody? body;

/// Create a copy of CenterSlideRecipe
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CenterSlideRecipeCopyWith<_CenterSlideRecipe> get copyWith => __$CenterSlideRecipeCopyWithImpl<_CenterSlideRecipe>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CenterSlideRecipeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CenterSlideRecipe&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.templateId, templateId) || other.templateId == templateId)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.centerId, centerId) || other.centerId == centerId)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.backgroundColor, backgroundColor) || other.backgroundColor == backgroundColor)&&(identical(other.backgroundPath, backgroundPath) || other.backgroundPath == backgroundPath)&&(identical(other.backgroundSha256, backgroundSha256) || other.backgroundSha256 == backgroundSha256)&&const DeepCollectionEquality().equals(other.fields, _fields)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,schemaVersion,templateId,revision,centerId,width,height,backgroundColor,backgroundPath,backgroundSha256,const DeepCollectionEquality().hash(_fields),body);
}

@override
String toString() {
    return 'CenterSlideRecipe(schemaVersion: $schemaVersion, templateId: $templateId, revision: $revision, centerId: $centerId, width: $width, height: $height, backgroundColor: $backgroundColor, backgroundPath: $backgroundPath, backgroundSha256: $backgroundSha256, fields: $fields, body: $body)';
}


}

/// @nodoc
abstract mixin class _$CenterSlideRecipeCopyWith<$Res> implements $CenterSlideRecipeCopyWith<$Res> {
  factory _$CenterSlideRecipeCopyWith(_CenterSlideRecipe value, $Res Function(_CenterSlideRecipe) _then) = __$CenterSlideRecipeCopyWithImpl;
@override @useResult
$Res call({
 int schemaVersion, String templateId, int revision, String centerId, int width, int height, int backgroundColor, String? backgroundPath, String? backgroundSha256, List<CenterSlideField> fields, CenterSlideBody? body
});


@override $CenterSlideBodyCopyWith<$Res>? get body;

}
/// @nodoc
class __$CenterSlideRecipeCopyWithImpl<$Res>
    implements _$CenterSlideRecipeCopyWith<$Res> {
  __$CenterSlideRecipeCopyWithImpl(this._self, this._then);

  final _CenterSlideRecipe _self;
  final $Res Function(_CenterSlideRecipe) _then;

/// Create a copy of CenterSlideRecipe
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? schemaVersion = null,Object? templateId = null,Object? revision = null,Object? centerId = null,Object? width = null,Object? height = null,Object? backgroundColor = null,Object? backgroundPath = freezed,Object? backgroundSha256 = freezed,Object? fields = null,Object? body = freezed,}) {
  return _then(_CenterSlideRecipe(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,templateId: null == templateId ? _self.templateId : templateId // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,centerId: null == centerId ? _self.centerId : centerId // ignore: cast_nullable_to_non_nullable
as String,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,backgroundColor: null == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as int,backgroundPath: freezed == backgroundPath ? _self.backgroundPath : backgroundPath // ignore: cast_nullable_to_non_nullable
as String?,backgroundSha256: freezed == backgroundSha256 ? _self.backgroundSha256 : backgroundSha256 // ignore: cast_nullable_to_non_nullable
as String?,fields: null == fields ? _self._fields : fields // ignore: cast_nullable_to_non_nullable
as List<CenterSlideField>,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as CenterSlideBody?,
  ));
}

/// Create a copy of CenterSlideRecipe
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CenterSlideBodyCopyWith<$Res>? get body {
    if (_self.body == null) {
    return null;
  }

  return $CenterSlideBodyCopyWith<$Res>(_self.body!, (value) {
    return _then(_self.copyWith(body: value));
  });
}
}


/// @nodoc
mixin _$CenterSlideBody {

 double get x; double get y; double get width; double get height; double get fontSize; int get color; int get headingColor; String get fontFamily; int get fontWeight; String get layout; int get maxColumns;
/// Create a copy of CenterSlideBody
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CenterSlideBodyCopyWith<CenterSlideBody> get copyWith => _$CenterSlideBodyCopyWithImpl<CenterSlideBody>(this as CenterSlideBody, _$identity);

  /// Serializes this CenterSlideBody to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CenterSlideBody;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CenterSlideBody&&(identical(other.x, _this.x) || other.x == _this.x)&&(identical(other.y, _this.y) || other.y == _this.y)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&(identical(other.fontSize, _this.fontSize) || other.fontSize == _this.fontSize)&&(identical(other.color, _this.color) || other.color == _this.color)&&(identical(other.headingColor, _this.headingColor) || other.headingColor == _this.headingColor)&&(identical(other.fontFamily, _this.fontFamily) || other.fontFamily == _this.fontFamily)&&(identical(other.fontWeight, _this.fontWeight) || other.fontWeight == _this.fontWeight)&&(identical(other.layout, _this.layout) || other.layout == _this.layout)&&(identical(other.maxColumns, _this.maxColumns) || other.maxColumns == _this.maxColumns));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CenterSlideBody;
  return Object.hash(runtimeType,_this.x,_this.y,_this.width,_this.height,_this.fontSize,_this.color,_this.headingColor,_this.fontFamily,_this.fontWeight,_this.layout,_this.maxColumns);
}

@override
String toString() {
  final _this = this as CenterSlideBody;
  return 'CenterSlideBody(x: ${_this.x}, y: ${_this.y}, width: ${_this.width}, height: ${_this.height}, fontSize: ${_this.fontSize}, color: ${_this.color}, headingColor: ${_this.headingColor}, fontFamily: ${_this.fontFamily}, fontWeight: ${_this.fontWeight}, layout: ${_this.layout}, maxColumns: ${_this.maxColumns})';
}


}

/// @nodoc
abstract mixin class $CenterSlideBodyCopyWith<$Res>  {
  factory $CenterSlideBodyCopyWith(CenterSlideBody value, $Res Function(CenterSlideBody) _then) = _$CenterSlideBodyCopyWithImpl;
@useResult
$Res call({
 double x, double y, double width, double height, double fontSize, int color, int headingColor, String fontFamily, int fontWeight, String layout, int maxColumns
});




}
/// @nodoc
class _$CenterSlideBodyCopyWithImpl<$Res>
    implements $CenterSlideBodyCopyWith<$Res> {
  _$CenterSlideBodyCopyWithImpl(this._self, this._then);

  final CenterSlideBody _self;
  final $Res Function(CenterSlideBody) _then;

/// Create a copy of CenterSlideBody
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? x = null,Object? y = null,Object? width = null,Object? height = null,Object? fontSize = null,Object? color = null,Object? headingColor = null,Object? fontFamily = null,Object? fontWeight = null,Object? layout = null,Object? maxColumns = null,}) {
  return _then(CenterSlideBody(
x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,fontSize: null == fontSize ? _self.fontSize : fontSize // ignore: cast_nullable_to_non_nullable
as double,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,headingColor: null == headingColor ? _self.headingColor : headingColor // ignore: cast_nullable_to_non_nullable
as int,fontFamily: null == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String,fontWeight: null == fontWeight ? _self.fontWeight : fontWeight // ignore: cast_nullable_to_non_nullable
as int,layout: null == layout ? _self.layout : layout // ignore: cast_nullable_to_non_nullable
as String,maxColumns: null == maxColumns ? _self.maxColumns : maxColumns // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CenterSlideBody].
extension CenterSlideBodyPatterns on CenterSlideBody {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CenterSlideBody value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CenterSlideBody() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CenterSlideBody value)  $default,){
final _that = this;
switch (_that) {
case _CenterSlideBody():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CenterSlideBody value)?  $default,){
final _that = this;
switch (_that) {
case _CenterSlideBody() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double x,  double y,  double width,  double height,  double fontSize,  int color,  int headingColor,  String fontFamily,  int fontWeight,  String layout,  int maxColumns)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CenterSlideBody() when $default != null:
return $default(_that.x,_that.y,_that.width,_that.height,_that.fontSize,_that.color,_that.headingColor,_that.fontFamily,_that.fontWeight,_that.layout,_that.maxColumns);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double x,  double y,  double width,  double height,  double fontSize,  int color,  int headingColor,  String fontFamily,  int fontWeight,  String layout,  int maxColumns)  $default,) {final _that = this;
switch (_that) {
case _CenterSlideBody():
return $default(_that.x,_that.y,_that.width,_that.height,_that.fontSize,_that.color,_that.headingColor,_that.fontFamily,_that.fontWeight,_that.layout,_that.maxColumns);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double x,  double y,  double width,  double height,  double fontSize,  int color,  int headingColor,  String fontFamily,  int fontWeight,  String layout,  int maxColumns)?  $default,) {final _that = this;
switch (_that) {
case _CenterSlideBody() when $default != null:
return $default(_that.x,_that.y,_that.width,_that.height,_that.fontSize,_that.color,_that.headingColor,_that.fontFamily,_that.fontWeight,_that.layout,_that.maxColumns);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CenterSlideBody implements CenterSlideBody {
  const _CenterSlideBody({required this.x, required this.y, required this.width, required this.height, required this.fontSize, required this.color, required this.headingColor, required this.fontFamily, this.fontWeight = 600, this.layout = 'auto', this.maxColumns = 3});
  factory _CenterSlideBody.fromJson(Map<String, dynamic> json) => _$CenterSlideBodyFromJson(json);

@override final  double x;
@override final  double y;
@override final  double width;
@override final  double height;
@override final  double fontSize;
@override final  int color;
@override final  int headingColor;
@override final  String fontFamily;
@override@JsonKey() final  int fontWeight;
@override@JsonKey() final  String layout;
@override@JsonKey() final  int maxColumns;

/// Create a copy of CenterSlideBody
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CenterSlideBodyCopyWith<_CenterSlideBody> get copyWith => __$CenterSlideBodyCopyWithImpl<_CenterSlideBody>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CenterSlideBodyToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CenterSlideBody&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.fontSize, fontSize) || other.fontSize == fontSize)&&(identical(other.color, color) || other.color == color)&&(identical(other.headingColor, headingColor) || other.headingColor == headingColor)&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.fontWeight, fontWeight) || other.fontWeight == fontWeight)&&(identical(other.layout, layout) || other.layout == layout)&&(identical(other.maxColumns, maxColumns) || other.maxColumns == maxColumns));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,x,y,width,height,fontSize,color,headingColor,fontFamily,fontWeight,layout,maxColumns);
}

@override
String toString() {
    return 'CenterSlideBody(x: $x, y: $y, width: $width, height: $height, fontSize: $fontSize, color: $color, headingColor: $headingColor, fontFamily: $fontFamily, fontWeight: $fontWeight, layout: $layout, maxColumns: $maxColumns)';
}


}

/// @nodoc
abstract mixin class _$CenterSlideBodyCopyWith<$Res> implements $CenterSlideBodyCopyWith<$Res> {
  factory _$CenterSlideBodyCopyWith(_CenterSlideBody value, $Res Function(_CenterSlideBody) _then) = __$CenterSlideBodyCopyWithImpl;
@override @useResult
$Res call({
 double x, double y, double width, double height, double fontSize, int color, int headingColor, String fontFamily, int fontWeight, String layout, int maxColumns
});




}
/// @nodoc
class __$CenterSlideBodyCopyWithImpl<$Res>
    implements _$CenterSlideBodyCopyWith<$Res> {
  __$CenterSlideBodyCopyWithImpl(this._self, this._then);

  final _CenterSlideBody _self;
  final $Res Function(_CenterSlideBody) _then;

/// Create a copy of CenterSlideBody
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? x = null,Object? y = null,Object? width = null,Object? height = null,Object? fontSize = null,Object? color = null,Object? headingColor = null,Object? fontFamily = null,Object? fontWeight = null,Object? layout = null,Object? maxColumns = null,}) {
  return _then(_CenterSlideBody(
x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,fontSize: null == fontSize ? _self.fontSize : fontSize // ignore: cast_nullable_to_non_nullable
as double,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,headingColor: null == headingColor ? _self.headingColor : headingColor // ignore: cast_nullable_to_non_nullable
as int,fontFamily: null == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String,fontWeight: null == fontWeight ? _self.fontWeight : fontWeight // ignore: cast_nullable_to_non_nullable
as int,layout: null == layout ? _self.layout : layout // ignore: cast_nullable_to_non_nullable
as String,maxColumns: null == maxColumns ? _self.maxColumns : maxColumns // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$CenterSlideField {

 String get binding; int? get lineIndex; double get x; double get y; double get width; double get height; double get fontSize; int get color; String get fontFamily; int get fontWeight; bool get italic; String get align; String? get originalText; int? get clearColor;
/// Create a copy of CenterSlideField
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CenterSlideFieldCopyWith<CenterSlideField> get copyWith => _$CenterSlideFieldCopyWithImpl<CenterSlideField>(this as CenterSlideField, _$identity);

  /// Serializes this CenterSlideField to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CenterSlideField;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CenterSlideField&&(identical(other.binding, _this.binding) || other.binding == _this.binding)&&(identical(other.lineIndex, _this.lineIndex) || other.lineIndex == _this.lineIndex)&&(identical(other.x, _this.x) || other.x == _this.x)&&(identical(other.y, _this.y) || other.y == _this.y)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&(identical(other.fontSize, _this.fontSize) || other.fontSize == _this.fontSize)&&(identical(other.color, _this.color) || other.color == _this.color)&&(identical(other.fontFamily, _this.fontFamily) || other.fontFamily == _this.fontFamily)&&(identical(other.fontWeight, _this.fontWeight) || other.fontWeight == _this.fontWeight)&&(identical(other.italic, _this.italic) || other.italic == _this.italic)&&(identical(other.align, _this.align) || other.align == _this.align)&&(identical(other.originalText, _this.originalText) || other.originalText == _this.originalText)&&(identical(other.clearColor, _this.clearColor) || other.clearColor == _this.clearColor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CenterSlideField;
  return Object.hash(runtimeType,_this.binding,_this.lineIndex,_this.x,_this.y,_this.width,_this.height,_this.fontSize,_this.color,_this.fontFamily,_this.fontWeight,_this.italic,_this.align,_this.originalText,_this.clearColor);
}

@override
String toString() {
  final _this = this as CenterSlideField;
  return 'CenterSlideField(binding: ${_this.binding}, lineIndex: ${_this.lineIndex}, x: ${_this.x}, y: ${_this.y}, width: ${_this.width}, height: ${_this.height}, fontSize: ${_this.fontSize}, color: ${_this.color}, fontFamily: ${_this.fontFamily}, fontWeight: ${_this.fontWeight}, italic: ${_this.italic}, align: ${_this.align}, originalText: ${_this.originalText}, clearColor: ${_this.clearColor})';
}


}

/// @nodoc
abstract mixin class $CenterSlideFieldCopyWith<$Res>  {
  factory $CenterSlideFieldCopyWith(CenterSlideField value, $Res Function(CenterSlideField) _then) = _$CenterSlideFieldCopyWithImpl;
@useResult
$Res call({
 String binding, int? lineIndex, double x, double y, double width, double height, double fontSize, int color, String fontFamily, int fontWeight, bool italic, String align, String? originalText, int? clearColor
});




}
/// @nodoc
class _$CenterSlideFieldCopyWithImpl<$Res>
    implements $CenterSlideFieldCopyWith<$Res> {
  _$CenterSlideFieldCopyWithImpl(this._self, this._then);

  final CenterSlideField _self;
  final $Res Function(CenterSlideField) _then;

/// Create a copy of CenterSlideField
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? binding = null,Object? lineIndex = freezed,Object? x = null,Object? y = null,Object? width = null,Object? height = null,Object? fontSize = null,Object? color = null,Object? fontFamily = null,Object? fontWeight = null,Object? italic = null,Object? align = null,Object? originalText = freezed,Object? clearColor = freezed,}) {
  return _then(CenterSlideField(
binding: null == binding ? _self.binding : binding // ignore: cast_nullable_to_non_nullable
as String,lineIndex: freezed == lineIndex ? _self.lineIndex : lineIndex // ignore: cast_nullable_to_non_nullable
as int?,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,fontSize: null == fontSize ? _self.fontSize : fontSize // ignore: cast_nullable_to_non_nullable
as double,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,fontFamily: null == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String,fontWeight: null == fontWeight ? _self.fontWeight : fontWeight // ignore: cast_nullable_to_non_nullable
as int,italic: null == italic ? _self.italic : italic // ignore: cast_nullable_to_non_nullable
as bool,align: null == align ? _self.align : align // ignore: cast_nullable_to_non_nullable
as String,originalText: freezed == originalText ? _self.originalText : originalText // ignore: cast_nullable_to_non_nullable
as String?,clearColor: freezed == clearColor ? _self.clearColor : clearColor // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [CenterSlideField].
extension CenterSlideFieldPatterns on CenterSlideField {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CenterSlideField value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CenterSlideField() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CenterSlideField value)  $default,){
final _that = this;
switch (_that) {
case _CenterSlideField():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CenterSlideField value)?  $default,){
final _that = this;
switch (_that) {
case _CenterSlideField() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String binding,  int? lineIndex,  double x,  double y,  double width,  double height,  double fontSize,  int color,  String fontFamily,  int fontWeight,  bool italic,  String align,  String? originalText,  int? clearColor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CenterSlideField() when $default != null:
return $default(_that.binding,_that.lineIndex,_that.x,_that.y,_that.width,_that.height,_that.fontSize,_that.color,_that.fontFamily,_that.fontWeight,_that.italic,_that.align,_that.originalText,_that.clearColor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String binding,  int? lineIndex,  double x,  double y,  double width,  double height,  double fontSize,  int color,  String fontFamily,  int fontWeight,  bool italic,  String align,  String? originalText,  int? clearColor)  $default,) {final _that = this;
switch (_that) {
case _CenterSlideField():
return $default(_that.binding,_that.lineIndex,_that.x,_that.y,_that.width,_that.height,_that.fontSize,_that.color,_that.fontFamily,_that.fontWeight,_that.italic,_that.align,_that.originalText,_that.clearColor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String binding,  int? lineIndex,  double x,  double y,  double width,  double height,  double fontSize,  int color,  String fontFamily,  int fontWeight,  bool italic,  String align,  String? originalText,  int? clearColor)?  $default,) {final _that = this;
switch (_that) {
case _CenterSlideField() when $default != null:
return $default(_that.binding,_that.lineIndex,_that.x,_that.y,_that.width,_that.height,_that.fontSize,_that.color,_that.fontFamily,_that.fontWeight,_that.italic,_that.align,_that.originalText,_that.clearColor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CenterSlideField implements CenterSlideField {
  const _CenterSlideField({required this.binding, this.lineIndex, required this.x, required this.y, required this.width, required this.height, required this.fontSize, required this.color, required this.fontFamily, required this.fontWeight, this.italic = false, this.align = 'left', this.originalText, this.clearColor});
  factory _CenterSlideField.fromJson(Map<String, dynamic> json) => _$CenterSlideFieldFromJson(json);

@override final  String binding;
@override final  int? lineIndex;
@override final  double x;
@override final  double y;
@override final  double width;
@override final  double height;
@override final  double fontSize;
@override final  int color;
@override final  String fontFamily;
@override final  int fontWeight;
@override@JsonKey() final  bool italic;
@override@JsonKey() final  String align;
@override final  String? originalText;
@override final  int? clearColor;

/// Create a copy of CenterSlideField
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CenterSlideFieldCopyWith<_CenterSlideField> get copyWith => __$CenterSlideFieldCopyWithImpl<_CenterSlideField>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CenterSlideFieldToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CenterSlideField&&(identical(other.binding, binding) || other.binding == binding)&&(identical(other.lineIndex, lineIndex) || other.lineIndex == lineIndex)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.fontSize, fontSize) || other.fontSize == fontSize)&&(identical(other.color, color) || other.color == color)&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.fontWeight, fontWeight) || other.fontWeight == fontWeight)&&(identical(other.italic, italic) || other.italic == italic)&&(identical(other.align, align) || other.align == align)&&(identical(other.originalText, originalText) || other.originalText == originalText)&&(identical(other.clearColor, clearColor) || other.clearColor == clearColor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,binding,lineIndex,x,y,width,height,fontSize,color,fontFamily,fontWeight,italic,align,originalText,clearColor);
}

@override
String toString() {
    return 'CenterSlideField(binding: $binding, lineIndex: $lineIndex, x: $x, y: $y, width: $width, height: $height, fontSize: $fontSize, color: $color, fontFamily: $fontFamily, fontWeight: $fontWeight, italic: $italic, align: $align, originalText: $originalText, clearColor: $clearColor)';
}


}

/// @nodoc
abstract mixin class _$CenterSlideFieldCopyWith<$Res> implements $CenterSlideFieldCopyWith<$Res> {
  factory _$CenterSlideFieldCopyWith(_CenterSlideField value, $Res Function(_CenterSlideField) _then) = __$CenterSlideFieldCopyWithImpl;
@override @useResult
$Res call({
 String binding, int? lineIndex, double x, double y, double width, double height, double fontSize, int color, String fontFamily, int fontWeight, bool italic, String align, String? originalText, int? clearColor
});




}
/// @nodoc
class __$CenterSlideFieldCopyWithImpl<$Res>
    implements _$CenterSlideFieldCopyWith<$Res> {
  __$CenterSlideFieldCopyWithImpl(this._self, this._then);

  final _CenterSlideField _self;
  final $Res Function(_CenterSlideField) _then;

/// Create a copy of CenterSlideField
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? binding = null,Object? lineIndex = freezed,Object? x = null,Object? y = null,Object? width = null,Object? height = null,Object? fontSize = null,Object? color = null,Object? fontFamily = null,Object? fontWeight = null,Object? italic = null,Object? align = null,Object? originalText = freezed,Object? clearColor = freezed,}) {
  return _then(_CenterSlideField(
binding: null == binding ? _self.binding : binding // ignore: cast_nullable_to_non_nullable
as String,lineIndex: freezed == lineIndex ? _self.lineIndex : lineIndex // ignore: cast_nullable_to_non_nullable
as int?,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,fontSize: null == fontSize ? _self.fontSize : fontSize // ignore: cast_nullable_to_non_nullable
as double,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as int,fontFamily: null == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String,fontWeight: null == fontWeight ? _self.fontWeight : fontWeight // ignore: cast_nullable_to_non_nullable
as int,italic: null == italic ? _self.italic : italic // ignore: cast_nullable_to_non_nullable
as bool,align: null == align ? _self.align : align // ignore: cast_nullable_to_non_nullable
as String,originalText: freezed == originalText ? _self.originalText : originalText // ignore: cast_nullable_to_non_nullable
as String?,clearColor: freezed == clearColor ? _self.clearColor : clearColor // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
