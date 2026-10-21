// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_raster.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AiRasterGroup {

 String get heading; List<String> get lines;
/// Create a copy of AiRasterGroup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiRasterGroupCopyWith<AiRasterGroup> get copyWith => _$AiRasterGroupCopyWithImpl<AiRasterGroup>(this as AiRasterGroup, _$identity);

  /// Serializes this AiRasterGroup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AiRasterGroup;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiRasterGroup&&(identical(other.heading, _this.heading) || other.heading == _this.heading)&&const DeepCollectionEquality().equals(other.lines, _this.lines));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AiRasterGroup;
  return Object.hash(runtimeType,_this.heading,const DeepCollectionEquality().hash(_this.lines));
}

@override
String toString() {
  final _this = this as AiRasterGroup;
  return 'AiRasterGroup(heading: ${_this.heading}, lines: ${_this.lines})';
}


}

/// @nodoc
abstract mixin class $AiRasterGroupCopyWith<$Res>  {
  factory $AiRasterGroupCopyWith(AiRasterGroup value, $Res Function(AiRasterGroup) _then) = _$AiRasterGroupCopyWithImpl;
@useResult
$Res call({
 String heading, List<String> lines
});




}
/// @nodoc
class _$AiRasterGroupCopyWithImpl<$Res>
    implements $AiRasterGroupCopyWith<$Res> {
  _$AiRasterGroupCopyWithImpl(this._self, this._then);

  final AiRasterGroup _self;
  final $Res Function(AiRasterGroup) _then;

/// Create a copy of AiRasterGroup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? heading = null,Object? lines = null,}) {
  return _then(AiRasterGroup(
heading: null == heading ? _self.heading : heading // ignore: cast_nullable_to_non_nullable
as String,lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [AiRasterGroup].
extension AiRasterGroupPatterns on AiRasterGroup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiRasterGroup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiRasterGroup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiRasterGroup value)  $default,){
final _that = this;
switch (_that) {
case _AiRasterGroup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiRasterGroup value)?  $default,){
final _that = this;
switch (_that) {
case _AiRasterGroup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String heading,  List<String> lines)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiRasterGroup() when $default != null:
return $default(_that.heading,_that.lines);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String heading,  List<String> lines)  $default,) {final _that = this;
switch (_that) {
case _AiRasterGroup():
return $default(_that.heading,_that.lines);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String heading,  List<String> lines)?  $default,) {final _that = this;
switch (_that) {
case _AiRasterGroup() when $default != null:
return $default(_that.heading,_that.lines);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiRasterGroup implements AiRasterGroup {
  const _AiRasterGroup({required this.heading, required  List<String> lines}): _lines = lines;
  factory _AiRasterGroup.fromJson(Map<String, dynamic> json) => _$AiRasterGroupFromJson(json);

@override final  String heading;
 final  List<String> _lines;
@override List<String> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}


/// Create a copy of AiRasterGroup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiRasterGroupCopyWith<_AiRasterGroup> get copyWith => __$AiRasterGroupCopyWithImpl<_AiRasterGroup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiRasterGroupToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiRasterGroup&&(identical(other.heading, heading) || other.heading == heading)&&const DeepCollectionEquality().equals(other.lines, _lines));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,heading,const DeepCollectionEquality().hash(_lines));
}

@override
String toString() {
    return 'AiRasterGroup(heading: $heading, lines: $lines)';
}


}

/// @nodoc
abstract mixin class _$AiRasterGroupCopyWith<$Res> implements $AiRasterGroupCopyWith<$Res> {
  factory _$AiRasterGroupCopyWith(_AiRasterGroup value, $Res Function(_AiRasterGroup) _then) = __$AiRasterGroupCopyWithImpl;
@override @useResult
$Res call({
 String heading, List<String> lines
});




}
/// @nodoc
class __$AiRasterGroupCopyWithImpl<$Res>
    implements _$AiRasterGroupCopyWith<$Res> {
  __$AiRasterGroupCopyWithImpl(this._self, this._then);

  final _AiRasterGroup _self;
  final $Res Function(_AiRasterGroup) _then;

/// Create a copy of AiRasterGroup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? heading = null,Object? lines = null,}) {
  return _then(_AiRasterGroup(
heading: null == heading ? _self.heading : heading // ignore: cast_nullable_to_non_nullable
as String,lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$AiRasterDraft {

 String get rawWod; String get title; String get brief; double get bodyFontSize; List<AiRasterGroup> get groups;
/// Create a copy of AiRasterDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiRasterDraftCopyWith<AiRasterDraft> get copyWith => _$AiRasterDraftCopyWithImpl<AiRasterDraft>(this as AiRasterDraft, _$identity);

  /// Serializes this AiRasterDraft to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AiRasterDraft;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiRasterDraft&&(identical(other.rawWod, _this.rawWod) || other.rawWod == _this.rawWod)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.brief, _this.brief) || other.brief == _this.brief)&&(identical(other.bodyFontSize, _this.bodyFontSize) || other.bodyFontSize == _this.bodyFontSize)&&const DeepCollectionEquality().equals(other.groups, _this.groups));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AiRasterDraft;
  return Object.hash(runtimeType,_this.rawWod,_this.title,_this.brief,_this.bodyFontSize,const DeepCollectionEquality().hash(_this.groups));
}

@override
String toString() {
  final _this = this as AiRasterDraft;
  return 'AiRasterDraft(rawWod: ${_this.rawWod}, title: ${_this.title}, brief: ${_this.brief}, bodyFontSize: ${_this.bodyFontSize}, groups: ${_this.groups})';
}


}

/// @nodoc
abstract mixin class $AiRasterDraftCopyWith<$Res>  {
  factory $AiRasterDraftCopyWith(AiRasterDraft value, $Res Function(AiRasterDraft) _then) = _$AiRasterDraftCopyWithImpl;
@useResult
$Res call({
 String rawWod, String title, String brief, double bodyFontSize, List<AiRasterGroup> groups
});




}
/// @nodoc
class _$AiRasterDraftCopyWithImpl<$Res>
    implements $AiRasterDraftCopyWith<$Res> {
  _$AiRasterDraftCopyWithImpl(this._self, this._then);

  final AiRasterDraft _self;
  final $Res Function(AiRasterDraft) _then;

/// Create a copy of AiRasterDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rawWod = null,Object? title = null,Object? brief = null,Object? bodyFontSize = null,Object? groups = null,}) {
  return _then(AiRasterDraft(
rawWod: null == rawWod ? _self.rawWod : rawWod // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,brief: null == brief ? _self.brief : brief // ignore: cast_nullable_to_non_nullable
as String,bodyFontSize: null == bodyFontSize ? _self.bodyFontSize : bodyFontSize // ignore: cast_nullable_to_non_nullable
as double,groups: null == groups ? _self.groups : groups // ignore: cast_nullable_to_non_nullable
as List<AiRasterGroup>,
  ));
}

}


/// Adds pattern-matching-related methods to [AiRasterDraft].
extension AiRasterDraftPatterns on AiRasterDraft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiRasterDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiRasterDraft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiRasterDraft value)  $default,){
final _that = this;
switch (_that) {
case _AiRasterDraft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiRasterDraft value)?  $default,){
final _that = this;
switch (_that) {
case _AiRasterDraft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String rawWod,  String title,  String brief,  double bodyFontSize,  List<AiRasterGroup> groups)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiRasterDraft() when $default != null:
return $default(_that.rawWod,_that.title,_that.brief,_that.bodyFontSize,_that.groups);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String rawWod,  String title,  String brief,  double bodyFontSize,  List<AiRasterGroup> groups)  $default,) {final _that = this;
switch (_that) {
case _AiRasterDraft():
return $default(_that.rawWod,_that.title,_that.brief,_that.bodyFontSize,_that.groups);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String rawWod,  String title,  String brief,  double bodyFontSize,  List<AiRasterGroup> groups)?  $default,) {final _that = this;
switch (_that) {
case _AiRasterDraft() when $default != null:
return $default(_that.rawWod,_that.title,_that.brief,_that.bodyFontSize,_that.groups);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _AiRasterDraft implements AiRasterDraft {
  const _AiRasterDraft({this.rawWod = '', this.title = '오늘의 수업', this.brief = '', this.bodyFontSize = 42,  List<AiRasterGroup> groups = const []}): _groups = groups;
  factory _AiRasterDraft.fromJson(Map<String, dynamic> json) => _$AiRasterDraftFromJson(json);

@override@JsonKey() final  String rawWod;
@override@JsonKey() final  String title;
@override@JsonKey() final  String brief;
@override@JsonKey() final  double bodyFontSize;
 final  List<AiRasterGroup> _groups;
@override@JsonKey() List<AiRasterGroup> get groups {
  if (_groups is EqualUnmodifiableListView) return _groups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groups);
}


/// Create a copy of AiRasterDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiRasterDraftCopyWith<_AiRasterDraft> get copyWith => __$AiRasterDraftCopyWithImpl<_AiRasterDraft>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiRasterDraftToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiRasterDraft&&(identical(other.rawWod, rawWod) || other.rawWod == rawWod)&&(identical(other.title, title) || other.title == title)&&(identical(other.brief, brief) || other.brief == brief)&&(identical(other.bodyFontSize, bodyFontSize) || other.bodyFontSize == bodyFontSize)&&const DeepCollectionEquality().equals(other.groups, _groups));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,rawWod,title,brief,bodyFontSize,const DeepCollectionEquality().hash(_groups));
}

@override
String toString() {
    return 'AiRasterDraft(rawWod: $rawWod, title: $title, brief: $brief, bodyFontSize: $bodyFontSize, groups: $groups)';
}


}

/// @nodoc
abstract mixin class _$AiRasterDraftCopyWith<$Res> implements $AiRasterDraftCopyWith<$Res> {
  factory _$AiRasterDraftCopyWith(_AiRasterDraft value, $Res Function(_AiRasterDraft) _then) = __$AiRasterDraftCopyWithImpl;
@override @useResult
$Res call({
 String rawWod, String title, String brief, double bodyFontSize, List<AiRasterGroup> groups
});




}
/// @nodoc
class __$AiRasterDraftCopyWithImpl<$Res>
    implements _$AiRasterDraftCopyWith<$Res> {
  __$AiRasterDraftCopyWithImpl(this._self, this._then);

  final _AiRasterDraft _self;
  final $Res Function(_AiRasterDraft) _then;

/// Create a copy of AiRasterDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rawWod = null,Object? title = null,Object? brief = null,Object? bodyFontSize = null,Object? groups = null,}) {
  return _then(_AiRasterDraft(
rawWod: null == rawWod ? _self.rawWod : rawWod // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,brief: null == brief ? _self.brief : brief // ignore: cast_nullable_to_non_nullable
as String,bodyFontSize: null == bodyFontSize ? _self.bodyFontSize : bodyFontSize // ignore: cast_nullable_to_non_nullable
as double,groups: null == groups ? _self._groups : groups // ignore: cast_nullable_to_non_nullable
as List<AiRasterGroup>,
  ));
}


}


/// @nodoc
mixin _$AiRasterAsset {

 String get sha256; int get width; int get height; List<double> get sourceRect;
/// Create a copy of AiRasterAsset
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiRasterAssetCopyWith<AiRasterAsset> get copyWith => _$AiRasterAssetCopyWithImpl<AiRasterAsset>(this as AiRasterAsset, _$identity);

  /// Serializes this AiRasterAsset to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AiRasterAsset;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiRasterAsset&&(identical(other.sha256, _this.sha256) || other.sha256 == _this.sha256)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&const DeepCollectionEquality().equals(other.sourceRect, _this.sourceRect));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AiRasterAsset;
  return Object.hash(runtimeType,_this.sha256,_this.width,_this.height,const DeepCollectionEquality().hash(_this.sourceRect));
}

@override
String toString() {
  final _this = this as AiRasterAsset;
  return 'AiRasterAsset(sha256: ${_this.sha256}, width: ${_this.width}, height: ${_this.height}, sourceRect: ${_this.sourceRect})';
}


}

/// @nodoc
abstract mixin class $AiRasterAssetCopyWith<$Res>  {
  factory $AiRasterAssetCopyWith(AiRasterAsset value, $Res Function(AiRasterAsset) _then) = _$AiRasterAssetCopyWithImpl;
@useResult
$Res call({
 String sha256, int width, int height, List<double> sourceRect
});




}
/// @nodoc
class _$AiRasterAssetCopyWithImpl<$Res>
    implements $AiRasterAssetCopyWith<$Res> {
  _$AiRasterAssetCopyWithImpl(this._self, this._then);

  final AiRasterAsset _self;
  final $Res Function(AiRasterAsset) _then;

/// Create a copy of AiRasterAsset
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sha256 = null,Object? width = null,Object? height = null,Object? sourceRect = null,}) {
  return _then(AiRasterAsset(
sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,sourceRect: null == sourceRect ? _self.sourceRect : sourceRect // ignore: cast_nullable_to_non_nullable
as List<double>,
  ));
}

}


/// Adds pattern-matching-related methods to [AiRasterAsset].
extension AiRasterAssetPatterns on AiRasterAsset {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiRasterAsset value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiRasterAsset() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiRasterAsset value)  $default,){
final _that = this;
switch (_that) {
case _AiRasterAsset():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiRasterAsset value)?  $default,){
final _that = this;
switch (_that) {
case _AiRasterAsset() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sha256,  int width,  int height,  List<double> sourceRect)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiRasterAsset() when $default != null:
return $default(_that.sha256,_that.width,_that.height,_that.sourceRect);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sha256,  int width,  int height,  List<double> sourceRect)  $default,) {final _that = this;
switch (_that) {
case _AiRasterAsset():
return $default(_that.sha256,_that.width,_that.height,_that.sourceRect);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sha256,  int width,  int height,  List<double> sourceRect)?  $default,) {final _that = this;
switch (_that) {
case _AiRasterAsset() when $default != null:
return $default(_that.sha256,_that.width,_that.height,_that.sourceRect);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiRasterAsset implements AiRasterAsset {
  const _AiRasterAsset({required this.sha256, required this.width, required this.height,  List<double> sourceRect = const []}): _sourceRect = sourceRect;
  factory _AiRasterAsset.fromJson(Map<String, dynamic> json) => _$AiRasterAssetFromJson(json);

@override final  String sha256;
@override final  int width;
@override final  int height;
 final  List<double> _sourceRect;
@override@JsonKey() List<double> get sourceRect {
  if (_sourceRect is EqualUnmodifiableListView) return _sourceRect;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sourceRect);
}


/// Create a copy of AiRasterAsset
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiRasterAssetCopyWith<_AiRasterAsset> get copyWith => __$AiRasterAssetCopyWithImpl<_AiRasterAsset>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiRasterAssetToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiRasterAsset&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&const DeepCollectionEquality().equals(other.sourceRect, _sourceRect));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sha256,width,height,const DeepCollectionEquality().hash(_sourceRect));
}

@override
String toString() {
    return 'AiRasterAsset(sha256: $sha256, width: $width, height: $height, sourceRect: $sourceRect)';
}


}

/// @nodoc
abstract mixin class _$AiRasterAssetCopyWith<$Res> implements $AiRasterAssetCopyWith<$Res> {
  factory _$AiRasterAssetCopyWith(_AiRasterAsset value, $Res Function(_AiRasterAsset) _then) = __$AiRasterAssetCopyWithImpl;
@override @useResult
$Res call({
 String sha256, int width, int height, List<double> sourceRect
});




}
/// @nodoc
class __$AiRasterAssetCopyWithImpl<$Res>
    implements _$AiRasterAssetCopyWith<$Res> {
  __$AiRasterAssetCopyWithImpl(this._self, this._then);

  final _AiRasterAsset _self;
  final $Res Function(_AiRasterAsset) _then;

/// Create a copy of AiRasterAsset
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sha256 = null,Object? width = null,Object? height = null,Object? sourceRect = null,}) {
  return _then(_AiRasterAsset(
sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,sourceRect: null == sourceRect ? _self._sourceRect : sourceRect // ignore: cast_nullable_to_non_nullable
as List<double>,
  ));
}


}


/// @nodoc
mixin _$AiRasterBrand {

 String get key; int get revision; int get catalogRevision; int get recipeRevision; String get templateId; String get name; AiRasterAsset get reference; AiRasterAsset get logo; String get backgroundColor; String get textColor; String get accentColor;
/// Create a copy of AiRasterBrand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiRasterBrandCopyWith<AiRasterBrand> get copyWith => _$AiRasterBrandCopyWithImpl<AiRasterBrand>(this as AiRasterBrand, _$identity);

  /// Serializes this AiRasterBrand to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AiRasterBrand;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiRasterBrand&&(identical(other.key, _this.key) || other.key == _this.key)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&(identical(other.catalogRevision, _this.catalogRevision) || other.catalogRevision == _this.catalogRevision)&&(identical(other.recipeRevision, _this.recipeRevision) || other.recipeRevision == _this.recipeRevision)&&(identical(other.templateId, _this.templateId) || other.templateId == _this.templateId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.reference, _this.reference) || other.reference == _this.reference)&&(identical(other.logo, _this.logo) || other.logo == _this.logo)&&(identical(other.backgroundColor, _this.backgroundColor) || other.backgroundColor == _this.backgroundColor)&&(identical(other.textColor, _this.textColor) || other.textColor == _this.textColor)&&(identical(other.accentColor, _this.accentColor) || other.accentColor == _this.accentColor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AiRasterBrand;
  return Object.hash(runtimeType,_this.key,_this.revision,_this.catalogRevision,_this.recipeRevision,_this.templateId,_this.name,_this.reference,_this.logo,_this.backgroundColor,_this.textColor,_this.accentColor);
}

@override
String toString() {
  final _this = this as AiRasterBrand;
  return 'AiRasterBrand(key: ${_this.key}, revision: ${_this.revision}, catalogRevision: ${_this.catalogRevision}, recipeRevision: ${_this.recipeRevision}, templateId: ${_this.templateId}, name: ${_this.name}, reference: ${_this.reference}, logo: ${_this.logo}, backgroundColor: ${_this.backgroundColor}, textColor: ${_this.textColor}, accentColor: ${_this.accentColor})';
}


}

/// @nodoc
abstract mixin class $AiRasterBrandCopyWith<$Res>  {
  factory $AiRasterBrandCopyWith(AiRasterBrand value, $Res Function(AiRasterBrand) _then) = _$AiRasterBrandCopyWithImpl;
@useResult
$Res call({
 String key, int revision, int catalogRevision, int recipeRevision, String templateId, String name, AiRasterAsset reference, AiRasterAsset logo, String backgroundColor, String textColor, String accentColor
});


$AiRasterAssetCopyWith<$Res> get reference;$AiRasterAssetCopyWith<$Res> get logo;

}
/// @nodoc
class _$AiRasterBrandCopyWithImpl<$Res>
    implements $AiRasterBrandCopyWith<$Res> {
  _$AiRasterBrandCopyWithImpl(this._self, this._then);

  final AiRasterBrand _self;
  final $Res Function(AiRasterBrand) _then;

/// Create a copy of AiRasterBrand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? revision = null,Object? catalogRevision = null,Object? recipeRevision = null,Object? templateId = null,Object? name = null,Object? reference = null,Object? logo = null,Object? backgroundColor = null,Object? textColor = null,Object? accentColor = null,}) {
  return _then(AiRasterBrand(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,catalogRevision: null == catalogRevision ? _self.catalogRevision : catalogRevision // ignore: cast_nullable_to_non_nullable
as int,recipeRevision: null == recipeRevision ? _self.recipeRevision : recipeRevision // ignore: cast_nullable_to_non_nullable
as int,templateId: null == templateId ? _self.templateId : templateId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,reference: null == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as AiRasterAsset,logo: null == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as AiRasterAsset,backgroundColor: null == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as String,textColor: null == textColor ? _self.textColor : textColor // ignore: cast_nullable_to_non_nullable
as String,accentColor: null == accentColor ? _self.accentColor : accentColor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of AiRasterBrand
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiRasterAssetCopyWith<$Res> get reference {

  return $AiRasterAssetCopyWith<$Res>(_self.reference, (value) {
    return _then(_self.copyWith(reference: value));
  });
}/// Create a copy of AiRasterBrand
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiRasterAssetCopyWith<$Res> get logo {

  return $AiRasterAssetCopyWith<$Res>(_self.logo, (value) {
    return _then(_self.copyWith(logo: value));
  });
}
}


/// Adds pattern-matching-related methods to [AiRasterBrand].
extension AiRasterBrandPatterns on AiRasterBrand {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiRasterBrand value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiRasterBrand() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiRasterBrand value)  $default,){
final _that = this;
switch (_that) {
case _AiRasterBrand():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiRasterBrand value)?  $default,){
final _that = this;
switch (_that) {
case _AiRasterBrand() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  int revision,  int catalogRevision,  int recipeRevision,  String templateId,  String name,  AiRasterAsset reference,  AiRasterAsset logo,  String backgroundColor,  String textColor,  String accentColor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiRasterBrand() when $default != null:
return $default(_that.key,_that.revision,_that.catalogRevision,_that.recipeRevision,_that.templateId,_that.name,_that.reference,_that.logo,_that.backgroundColor,_that.textColor,_that.accentColor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  int revision,  int catalogRevision,  int recipeRevision,  String templateId,  String name,  AiRasterAsset reference,  AiRasterAsset logo,  String backgroundColor,  String textColor,  String accentColor)  $default,) {final _that = this;
switch (_that) {
case _AiRasterBrand():
return $default(_that.key,_that.revision,_that.catalogRevision,_that.recipeRevision,_that.templateId,_that.name,_that.reference,_that.logo,_that.backgroundColor,_that.textColor,_that.accentColor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  int revision,  int catalogRevision,  int recipeRevision,  String templateId,  String name,  AiRasterAsset reference,  AiRasterAsset logo,  String backgroundColor,  String textColor,  String accentColor)?  $default,) {final _that = this;
switch (_that) {
case _AiRasterBrand() when $default != null:
return $default(_that.key,_that.revision,_that.catalogRevision,_that.recipeRevision,_that.templateId,_that.name,_that.reference,_that.logo,_that.backgroundColor,_that.textColor,_that.accentColor);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _AiRasterBrand implements AiRasterBrand {
  const _AiRasterBrand({required this.key, required this.revision, required this.catalogRevision, required this.recipeRevision, required this.templateId, required this.name, required this.reference, required this.logo, required this.backgroundColor, required this.textColor, required this.accentColor});
  factory _AiRasterBrand.fromJson(Map<String, dynamic> json) => _$AiRasterBrandFromJson(json);

@override final  String key;
@override final  int revision;
@override final  int catalogRevision;
@override final  int recipeRevision;
@override final  String templateId;
@override final  String name;
@override final  AiRasterAsset reference;
@override final  AiRasterAsset logo;
@override final  String backgroundColor;
@override final  String textColor;
@override final  String accentColor;

/// Create a copy of AiRasterBrand
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiRasterBrandCopyWith<_AiRasterBrand> get copyWith => __$AiRasterBrandCopyWithImpl<_AiRasterBrand>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiRasterBrandToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiRasterBrand&&(identical(other.key, key) || other.key == key)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.catalogRevision, catalogRevision) || other.catalogRevision == catalogRevision)&&(identical(other.recipeRevision, recipeRevision) || other.recipeRevision == recipeRevision)&&(identical(other.templateId, templateId) || other.templateId == templateId)&&(identical(other.name, name) || other.name == name)&&(identical(other.reference, reference) || other.reference == reference)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.backgroundColor, backgroundColor) || other.backgroundColor == backgroundColor)&&(identical(other.textColor, textColor) || other.textColor == textColor)&&(identical(other.accentColor, accentColor) || other.accentColor == accentColor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,key,revision,catalogRevision,recipeRevision,templateId,name,reference,logo,backgroundColor,textColor,accentColor);
}

@override
String toString() {
    return 'AiRasterBrand(key: $key, revision: $revision, catalogRevision: $catalogRevision, recipeRevision: $recipeRevision, templateId: $templateId, name: $name, reference: $reference, logo: $logo, backgroundColor: $backgroundColor, textColor: $textColor, accentColor: $accentColor)';
}


}

/// @nodoc
abstract mixin class _$AiRasterBrandCopyWith<$Res> implements $AiRasterBrandCopyWith<$Res> {
  factory _$AiRasterBrandCopyWith(_AiRasterBrand value, $Res Function(_AiRasterBrand) _then) = __$AiRasterBrandCopyWithImpl;
@override @useResult
$Res call({
 String key, int revision, int catalogRevision, int recipeRevision, String templateId, String name, AiRasterAsset reference, AiRasterAsset logo, String backgroundColor, String textColor, String accentColor
});


@override $AiRasterAssetCopyWith<$Res> get reference;@override $AiRasterAssetCopyWith<$Res> get logo;

}
/// @nodoc
class __$AiRasterBrandCopyWithImpl<$Res>
    implements _$AiRasterBrandCopyWith<$Res> {
  __$AiRasterBrandCopyWithImpl(this._self, this._then);

  final _AiRasterBrand _self;
  final $Res Function(_AiRasterBrand) _then;

/// Create a copy of AiRasterBrand
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? revision = null,Object? catalogRevision = null,Object? recipeRevision = null,Object? templateId = null,Object? name = null,Object? reference = null,Object? logo = null,Object? backgroundColor = null,Object? textColor = null,Object? accentColor = null,}) {
  return _then(_AiRasterBrand(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,catalogRevision: null == catalogRevision ? _self.catalogRevision : catalogRevision // ignore: cast_nullable_to_non_nullable
as int,recipeRevision: null == recipeRevision ? _self.recipeRevision : recipeRevision // ignore: cast_nullable_to_non_nullable
as int,templateId: null == templateId ? _self.templateId : templateId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,reference: null == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as AiRasterAsset,logo: null == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as AiRasterAsset,backgroundColor: null == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as String,textColor: null == textColor ? _self.textColor : textColor // ignore: cast_nullable_to_non_nullable
as String,accentColor: null == accentColor ? _self.accentColor : accentColor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of AiRasterBrand
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiRasterAssetCopyWith<$Res> get reference {

  return $AiRasterAssetCopyWith<$Res>(_self.reference, (value) {
    return _then(_self.copyWith(reference: value));
  });
}/// Create a copy of AiRasterBrand
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiRasterAssetCopyWith<$Res> get logo {

  return $AiRasterAssetCopyWith<$Res>(_self.logo, (value) {
    return _then(_self.copyWith(logo: value));
  });
}
}


/// @nodoc
mixin _$AiRasterJob {

 String get requestId; String get status; String get brandKey; AiRasterDraft get draft; AiRasterAsset? get artifact; int? get expiresAtMs; String? get message;
/// Create a copy of AiRasterJob
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiRasterJobCopyWith<AiRasterJob> get copyWith => _$AiRasterJobCopyWithImpl<AiRasterJob>(this as AiRasterJob, _$identity);

  /// Serializes this AiRasterJob to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AiRasterJob;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiRasterJob&&(identical(other.requestId, _this.requestId) || other.requestId == _this.requestId)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.brandKey, _this.brandKey) || other.brandKey == _this.brandKey)&&(identical(other.draft, _this.draft) || other.draft == _this.draft)&&(identical(other.artifact, _this.artifact) || other.artifact == _this.artifact)&&(identical(other.expiresAtMs, _this.expiresAtMs) || other.expiresAtMs == _this.expiresAtMs)&&(identical(other.message, _this.message) || other.message == _this.message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AiRasterJob;
  return Object.hash(runtimeType,_this.requestId,_this.status,_this.brandKey,_this.draft,_this.artifact,_this.expiresAtMs,_this.message);
}

@override
String toString() {
  final _this = this as AiRasterJob;
  return 'AiRasterJob(requestId: ${_this.requestId}, status: ${_this.status}, brandKey: ${_this.brandKey}, draft: ${_this.draft}, artifact: ${_this.artifact}, expiresAtMs: ${_this.expiresAtMs}, message: ${_this.message})';
}


}

/// @nodoc
abstract mixin class $AiRasterJobCopyWith<$Res>  {
  factory $AiRasterJobCopyWith(AiRasterJob value, $Res Function(AiRasterJob) _then) = _$AiRasterJobCopyWithImpl;
@useResult
$Res call({
 String requestId, String status, String brandKey, AiRasterDraft draft, AiRasterAsset? artifact, int? expiresAtMs, String? message
});


$AiRasterDraftCopyWith<$Res> get draft;$AiRasterAssetCopyWith<$Res>? get artifact;

}
/// @nodoc
class _$AiRasterJobCopyWithImpl<$Res>
    implements $AiRasterJobCopyWith<$Res> {
  _$AiRasterJobCopyWithImpl(this._self, this._then);

  final AiRasterJob _self;
  final $Res Function(AiRasterJob) _then;

/// Create a copy of AiRasterJob
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? requestId = null,Object? status = null,Object? brandKey = null,Object? draft = null,Object? artifact = freezed,Object? expiresAtMs = freezed,Object? message = freezed,}) {
  return _then(AiRasterJob(
requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,brandKey: null == brandKey ? _self.brandKey : brandKey // ignore: cast_nullable_to_non_nullable
as String,draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as AiRasterDraft,artifact: freezed == artifact ? _self.artifact : artifact // ignore: cast_nullable_to_non_nullable
as AiRasterAsset?,expiresAtMs: freezed == expiresAtMs ? _self.expiresAtMs : expiresAtMs // ignore: cast_nullable_to_non_nullable
as int?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of AiRasterJob
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiRasterDraftCopyWith<$Res> get draft {

  return $AiRasterDraftCopyWith<$Res>(_self.draft, (value) {
    return _then(_self.copyWith(draft: value));
  });
}/// Create a copy of AiRasterJob
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiRasterAssetCopyWith<$Res>? get artifact {
    if (_self.artifact == null) {
    return null;
  }

  return $AiRasterAssetCopyWith<$Res>(_self.artifact!, (value) {
    return _then(_self.copyWith(artifact: value));
  });
}
}


/// Adds pattern-matching-related methods to [AiRasterJob].
extension AiRasterJobPatterns on AiRasterJob {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiRasterJob value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiRasterJob() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiRasterJob value)  $default,){
final _that = this;
switch (_that) {
case _AiRasterJob():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiRasterJob value)?  $default,){
final _that = this;
switch (_that) {
case _AiRasterJob() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String requestId,  String status,  String brandKey,  AiRasterDraft draft,  AiRasterAsset? artifact,  int? expiresAtMs,  String? message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiRasterJob() when $default != null:
return $default(_that.requestId,_that.status,_that.brandKey,_that.draft,_that.artifact,_that.expiresAtMs,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String requestId,  String status,  String brandKey,  AiRasterDraft draft,  AiRasterAsset? artifact,  int? expiresAtMs,  String? message)  $default,) {final _that = this;
switch (_that) {
case _AiRasterJob():
return $default(_that.requestId,_that.status,_that.brandKey,_that.draft,_that.artifact,_that.expiresAtMs,_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String requestId,  String status,  String brandKey,  AiRasterDraft draft,  AiRasterAsset? artifact,  int? expiresAtMs,  String? message)?  $default,) {final _that = this;
switch (_that) {
case _AiRasterJob() when $default != null:
return $default(_that.requestId,_that.status,_that.brandKey,_that.draft,_that.artifact,_that.expiresAtMs,_that.message);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _AiRasterJob implements AiRasterJob {
  const _AiRasterJob({required this.requestId, required this.status, required this.brandKey, required this.draft, this.artifact, this.expiresAtMs, this.message});
  factory _AiRasterJob.fromJson(Map<String, dynamic> json) => _$AiRasterJobFromJson(json);

@override final  String requestId;
@override final  String status;
@override final  String brandKey;
@override final  AiRasterDraft draft;
@override final  AiRasterAsset? artifact;
@override final  int? expiresAtMs;
@override final  String? message;

/// Create a copy of AiRasterJob
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiRasterJobCopyWith<_AiRasterJob> get copyWith => __$AiRasterJobCopyWithImpl<_AiRasterJob>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiRasterJobToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiRasterJob&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.status, status) || other.status == status)&&(identical(other.brandKey, brandKey) || other.brandKey == brandKey)&&(identical(other.draft, draft) || other.draft == draft)&&(identical(other.artifact, artifact) || other.artifact == artifact)&&(identical(other.expiresAtMs, expiresAtMs) || other.expiresAtMs == expiresAtMs)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,requestId,status,brandKey,draft,artifact,expiresAtMs,message);
}

@override
String toString() {
    return 'AiRasterJob(requestId: $requestId, status: $status, brandKey: $brandKey, draft: $draft, artifact: $artifact, expiresAtMs: $expiresAtMs, message: $message)';
}


}

/// @nodoc
abstract mixin class _$AiRasterJobCopyWith<$Res> implements $AiRasterJobCopyWith<$Res> {
  factory _$AiRasterJobCopyWith(_AiRasterJob value, $Res Function(_AiRasterJob) _then) = __$AiRasterJobCopyWithImpl;
@override @useResult
$Res call({
 String requestId, String status, String brandKey, AiRasterDraft draft, AiRasterAsset? artifact, int? expiresAtMs, String? message
});


@override $AiRasterDraftCopyWith<$Res> get draft;@override $AiRasterAssetCopyWith<$Res>? get artifact;

}
/// @nodoc
class __$AiRasterJobCopyWithImpl<$Res>
    implements _$AiRasterJobCopyWith<$Res> {
  __$AiRasterJobCopyWithImpl(this._self, this._then);

  final _AiRasterJob _self;
  final $Res Function(_AiRasterJob) _then;

/// Create a copy of AiRasterJob
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? requestId = null,Object? status = null,Object? brandKey = null,Object? draft = null,Object? artifact = freezed,Object? expiresAtMs = freezed,Object? message = freezed,}) {
  return _then(_AiRasterJob(
requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,brandKey: null == brandKey ? _self.brandKey : brandKey // ignore: cast_nullable_to_non_nullable
as String,draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as AiRasterDraft,artifact: freezed == artifact ? _self.artifact : artifact // ignore: cast_nullable_to_non_nullable
as AiRasterAsset?,expiresAtMs: freezed == expiresAtMs ? _self.expiresAtMs : expiresAtMs // ignore: cast_nullable_to_non_nullable
as int?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of AiRasterJob
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiRasterDraftCopyWith<$Res> get draft {

  return $AiRasterDraftCopyWith<$Res>(_self.draft, (value) {
    return _then(_self.copyWith(draft: value));
  });
}/// Create a copy of AiRasterJob
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiRasterAssetCopyWith<$Res>? get artifact {
    if (_self.artifact == null) {
    return null;
  }

  return $AiRasterAssetCopyWith<$Res>(_self.artifact!, (value) {
    return _then(_self.copyWith(artifact: value));
  });
}
}

/// @nodoc
mixin _$AiRasterState {

 bool get loading; bool get busy; bool get allowed; bool get enabled; int get remaining; int get limit; AiRasterDraft get draft; AiRasterBrand? get brand; AiRasterJob? get result; List<AiRasterJob> get history; String? get pendingRequestId; String? get pendingStatus; String? get error;
/// Create a copy of AiRasterState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiRasterStateCopyWith<AiRasterState> get copyWith => _$AiRasterStateCopyWithImpl<AiRasterState>(this as AiRasterState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AiRasterState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiRasterState&&(identical(other.loading, _this.loading) || other.loading == _this.loading)&&(identical(other.busy, _this.busy) || other.busy == _this.busy)&&(identical(other.allowed, _this.allowed) || other.allowed == _this.allowed)&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.remaining, _this.remaining) || other.remaining == _this.remaining)&&(identical(other.limit, _this.limit) || other.limit == _this.limit)&&(identical(other.draft, _this.draft) || other.draft == _this.draft)&&(identical(other.brand, _this.brand) || other.brand == _this.brand)&&(identical(other.result, _this.result) || other.result == _this.result)&&const DeepCollectionEquality().equals(other.history, _this.history)&&(identical(other.pendingRequestId, _this.pendingRequestId) || other.pendingRequestId == _this.pendingRequestId)&&(identical(other.pendingStatus, _this.pendingStatus) || other.pendingStatus == _this.pendingStatus)&&(identical(other.error, _this.error) || other.error == _this.error));
}


@override
int get hashCode {
  final _this = this as AiRasterState;
  return Object.hash(runtimeType,_this.loading,_this.busy,_this.allowed,_this.enabled,_this.remaining,_this.limit,_this.draft,_this.brand,_this.result,const DeepCollectionEquality().hash(_this.history),_this.pendingRequestId,_this.pendingStatus,_this.error);
}

@override
String toString() {
  final _this = this as AiRasterState;
  return 'AiRasterState(loading: ${_this.loading}, busy: ${_this.busy}, allowed: ${_this.allowed}, enabled: ${_this.enabled}, remaining: ${_this.remaining}, limit: ${_this.limit}, draft: ${_this.draft}, brand: ${_this.brand}, result: ${_this.result}, history: ${_this.history}, pendingRequestId: ${_this.pendingRequestId}, pendingStatus: ${_this.pendingStatus}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $AiRasterStateCopyWith<$Res>  {
  factory $AiRasterStateCopyWith(AiRasterState value, $Res Function(AiRasterState) _then) = _$AiRasterStateCopyWithImpl;
@useResult
$Res call({
 bool loading, bool busy, bool allowed, bool enabled, int remaining, int limit, AiRasterDraft draft, AiRasterBrand? brand, AiRasterJob? result, List<AiRasterJob> history, String? pendingRequestId, String? pendingStatus, String? error
});


$AiRasterDraftCopyWith<$Res> get draft;$AiRasterBrandCopyWith<$Res>? get brand;$AiRasterJobCopyWith<$Res>? get result;

}
/// @nodoc
class _$AiRasterStateCopyWithImpl<$Res>
    implements $AiRasterStateCopyWith<$Res> {
  _$AiRasterStateCopyWithImpl(this._self, this._then);

  final AiRasterState _self;
  final $Res Function(AiRasterState) _then;

/// Create a copy of AiRasterState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? loading = null,Object? busy = null,Object? allowed = null,Object? enabled = null,Object? remaining = null,Object? limit = null,Object? draft = null,Object? brand = freezed,Object? result = freezed,Object? history = null,Object? pendingRequestId = freezed,Object? pendingStatus = freezed,Object? error = freezed,}) {
  return _then(AiRasterState(
loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,allowed: null == allowed ? _self.allowed : allowed // ignore: cast_nullable_to_non_nullable
as bool,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as AiRasterDraft,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as AiRasterBrand?,result: freezed == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as AiRasterJob?,history: null == history ? _self.history : history // ignore: cast_nullable_to_non_nullable
as List<AiRasterJob>,pendingRequestId: freezed == pendingRequestId ? _self.pendingRequestId : pendingRequestId // ignore: cast_nullable_to_non_nullable
as String?,pendingStatus: freezed == pendingStatus ? _self.pendingStatus : pendingStatus // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of AiRasterState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiRasterDraftCopyWith<$Res> get draft {

  return $AiRasterDraftCopyWith<$Res>(_self.draft, (value) {
    return _then(_self.copyWith(draft: value));
  });
}/// Create a copy of AiRasterState
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
}/// Create a copy of AiRasterState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiRasterJobCopyWith<$Res>? get result {
    if (_self.result == null) {
    return null;
  }

  return $AiRasterJobCopyWith<$Res>(_self.result!, (value) {
    return _then(_self.copyWith(result: value));
  });
}
}


/// Adds pattern-matching-related methods to [AiRasterState].
extension AiRasterStatePatterns on AiRasterState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiRasterState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiRasterState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiRasterState value)  $default,){
final _that = this;
switch (_that) {
case _AiRasterState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiRasterState value)?  $default,){
final _that = this;
switch (_that) {
case _AiRasterState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool loading,  bool busy,  bool allowed,  bool enabled,  int remaining,  int limit,  AiRasterDraft draft,  AiRasterBrand? brand,  AiRasterJob? result,  List<AiRasterJob> history,  String? pendingRequestId,  String? pendingStatus,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiRasterState() when $default != null:
return $default(_that.loading,_that.busy,_that.allowed,_that.enabled,_that.remaining,_that.limit,_that.draft,_that.brand,_that.result,_that.history,_that.pendingRequestId,_that.pendingStatus,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool loading,  bool busy,  bool allowed,  bool enabled,  int remaining,  int limit,  AiRasterDraft draft,  AiRasterBrand? brand,  AiRasterJob? result,  List<AiRasterJob> history,  String? pendingRequestId,  String? pendingStatus,  String? error)  $default,) {final _that = this;
switch (_that) {
case _AiRasterState():
return $default(_that.loading,_that.busy,_that.allowed,_that.enabled,_that.remaining,_that.limit,_that.draft,_that.brand,_that.result,_that.history,_that.pendingRequestId,_that.pendingStatus,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool loading,  bool busy,  bool allowed,  bool enabled,  int remaining,  int limit,  AiRasterDraft draft,  AiRasterBrand? brand,  AiRasterJob? result,  List<AiRasterJob> history,  String? pendingRequestId,  String? pendingStatus,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _AiRasterState() when $default != null:
return $default(_that.loading,_that.busy,_that.allowed,_that.enabled,_that.remaining,_that.limit,_that.draft,_that.brand,_that.result,_that.history,_that.pendingRequestId,_that.pendingStatus,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _AiRasterState implements AiRasterState {
  const _AiRasterState({this.loading = true, this.busy = false, this.allowed = false, this.enabled = false, this.remaining = 0, this.limit = 0, this.draft = const AiRasterDraft(), this.brand, this.result,  List<AiRasterJob> history = const [], this.pendingRequestId, this.pendingStatus, this.error}): _history = history;


@override@JsonKey() final  bool loading;
@override@JsonKey() final  bool busy;
@override@JsonKey() final  bool allowed;
@override@JsonKey() final  bool enabled;
@override@JsonKey() final  int remaining;
@override@JsonKey() final  int limit;
@override@JsonKey() final  AiRasterDraft draft;
@override final  AiRasterBrand? brand;
@override final  AiRasterJob? result;
 final  List<AiRasterJob> _history;
@override@JsonKey() List<AiRasterJob> get history {
  if (_history is EqualUnmodifiableListView) return _history;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_history);
}

@override final  String? pendingRequestId;
@override final  String? pendingStatus;
@override final  String? error;

/// Create a copy of AiRasterState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiRasterStateCopyWith<_AiRasterState> get copyWith => __$AiRasterStateCopyWithImpl<_AiRasterState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiRasterState&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.allowed, allowed) || other.allowed == allowed)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.draft, draft) || other.draft == draft)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.result, result) || other.result == result)&&const DeepCollectionEquality().equals(other.history, _history)&&(identical(other.pendingRequestId, pendingRequestId) || other.pendingRequestId == pendingRequestId)&&(identical(other.pendingStatus, pendingStatus) || other.pendingStatus == pendingStatus)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,loading,busy,allowed,enabled,remaining,limit,draft,brand,result,const DeepCollectionEquality().hash(_history),pendingRequestId,pendingStatus,error);
}

@override
String toString() {
    return 'AiRasterState(loading: $loading, busy: $busy, allowed: $allowed, enabled: $enabled, remaining: $remaining, limit: $limit, draft: $draft, brand: $brand, result: $result, history: $history, pendingRequestId: $pendingRequestId, pendingStatus: $pendingStatus, error: $error)';
}


}

/// @nodoc
abstract mixin class _$AiRasterStateCopyWith<$Res> implements $AiRasterStateCopyWith<$Res> {
  factory _$AiRasterStateCopyWith(_AiRasterState value, $Res Function(_AiRasterState) _then) = __$AiRasterStateCopyWithImpl;
@override @useResult
$Res call({
 bool loading, bool busy, bool allowed, bool enabled, int remaining, int limit, AiRasterDraft draft, AiRasterBrand? brand, AiRasterJob? result, List<AiRasterJob> history, String? pendingRequestId, String? pendingStatus, String? error
});


@override $AiRasterDraftCopyWith<$Res> get draft;@override $AiRasterBrandCopyWith<$Res>? get brand;@override $AiRasterJobCopyWith<$Res>? get result;

}
/// @nodoc
class __$AiRasterStateCopyWithImpl<$Res>
    implements _$AiRasterStateCopyWith<$Res> {
  __$AiRasterStateCopyWithImpl(this._self, this._then);

  final _AiRasterState _self;
  final $Res Function(_AiRasterState) _then;

/// Create a copy of AiRasterState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? loading = null,Object? busy = null,Object? allowed = null,Object? enabled = null,Object? remaining = null,Object? limit = null,Object? draft = null,Object? brand = freezed,Object? result = freezed,Object? history = null,Object? pendingRequestId = freezed,Object? pendingStatus = freezed,Object? error = freezed,}) {
  return _then(_AiRasterState(
loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,allowed: null == allowed ? _self.allowed : allowed // ignore: cast_nullable_to_non_nullable
as bool,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as AiRasterDraft,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as AiRasterBrand?,result: freezed == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as AiRasterJob?,history: null == history ? _self._history : history // ignore: cast_nullable_to_non_nullable
as List<AiRasterJob>,pendingRequestId: freezed == pendingRequestId ? _self.pendingRequestId : pendingRequestId // ignore: cast_nullable_to_non_nullable
as String?,pendingStatus: freezed == pendingStatus ? _self.pendingStatus : pendingStatus // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of AiRasterState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiRasterDraftCopyWith<$Res> get draft {

  return $AiRasterDraftCopyWith<$Res>(_self.draft, (value) {
    return _then(_self.copyWith(draft: value));
  });
}/// Create a copy of AiRasterState
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
}/// Create a copy of AiRasterState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiRasterJobCopyWith<$Res>? get result {
    if (_self.result == null) {
    return null;
  }

  return $AiRasterJobCopyWith<$Res>(_self.result!, (value) {
    return _then(_self.copyWith(result: value));
  });
}
}

// dart format on
