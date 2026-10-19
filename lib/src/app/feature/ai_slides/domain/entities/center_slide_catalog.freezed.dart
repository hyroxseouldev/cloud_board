// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'center_slide_catalog.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CenterSlideCatalog {

 int get revision; String get centerId; String get centerName; List<AiSlideDesign> get templates;
/// Create a copy of CenterSlideCatalog
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CenterSlideCatalogCopyWith<CenterSlideCatalog> get copyWith => _$CenterSlideCatalogCopyWithImpl<CenterSlideCatalog>(this as CenterSlideCatalog, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CenterSlideCatalog;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CenterSlideCatalog&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&(identical(other.centerId, _this.centerId) || other.centerId == _this.centerId)&&(identical(other.centerName, _this.centerName) || other.centerName == _this.centerName)&&const DeepCollectionEquality().equals(other.templates, _this.templates));
}


@override
int get hashCode {
  final _this = this as CenterSlideCatalog;
  return Object.hash(runtimeType,_this.revision,_this.centerId,_this.centerName,const DeepCollectionEquality().hash(_this.templates));
}

@override
String toString() {
  final _this = this as CenterSlideCatalog;
  return 'CenterSlideCatalog(revision: ${_this.revision}, centerId: ${_this.centerId}, centerName: ${_this.centerName}, templates: ${_this.templates})';
}


}

/// @nodoc
abstract mixin class $CenterSlideCatalogCopyWith<$Res>  {
  factory $CenterSlideCatalogCopyWith(CenterSlideCatalog value, $Res Function(CenterSlideCatalog) _then) = _$CenterSlideCatalogCopyWithImpl;
@useResult
$Res call({
 int revision, String centerId, String centerName, List<AiSlideDesign> templates
});




}
/// @nodoc
class _$CenterSlideCatalogCopyWithImpl<$Res>
    implements $CenterSlideCatalogCopyWith<$Res> {
  _$CenterSlideCatalogCopyWithImpl(this._self, this._then);

  final CenterSlideCatalog _self;
  final $Res Function(CenterSlideCatalog) _then;

/// Create a copy of CenterSlideCatalog
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? revision = null,Object? centerId = null,Object? centerName = null,Object? templates = null,}) {
  return _then(CenterSlideCatalog(
revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,centerId: null == centerId ? _self.centerId : centerId // ignore: cast_nullable_to_non_nullable
as String,centerName: null == centerName ? _self.centerName : centerName // ignore: cast_nullable_to_non_nullable
as String,templates: null == templates ? _self.templates : templates // ignore: cast_nullable_to_non_nullable
as List<AiSlideDesign>,
  ));
}

}


/// Adds pattern-matching-related methods to [CenterSlideCatalog].
extension CenterSlideCatalogPatterns on CenterSlideCatalog {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CenterSlideCatalog value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CenterSlideCatalog() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CenterSlideCatalog value)  $default,){
final _that = this;
switch (_that) {
case _CenterSlideCatalog():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CenterSlideCatalog value)?  $default,){
final _that = this;
switch (_that) {
case _CenterSlideCatalog() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int revision,  String centerId,  String centerName,  List<AiSlideDesign> templates)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CenterSlideCatalog() when $default != null:
return $default(_that.revision,_that.centerId,_that.centerName,_that.templates);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int revision,  String centerId,  String centerName,  List<AiSlideDesign> templates)  $default,) {final _that = this;
switch (_that) {
case _CenterSlideCatalog():
return $default(_that.revision,_that.centerId,_that.centerName,_that.templates);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int revision,  String centerId,  String centerName,  List<AiSlideDesign> templates)?  $default,) {final _that = this;
switch (_that) {
case _CenterSlideCatalog() when $default != null:
return $default(_that.revision,_that.centerId,_that.centerName,_that.templates);case _:
  return null;

}
}

}

/// @nodoc


class _CenterSlideCatalog implements CenterSlideCatalog {
  const _CenterSlideCatalog({required this.revision, required this.centerId, required this.centerName, required  List<AiSlideDesign> templates}): _templates = templates;
  

@override final  int revision;
@override final  String centerId;
@override final  String centerName;
 final  List<AiSlideDesign> _templates;
@override List<AiSlideDesign> get templates {
  if (_templates is EqualUnmodifiableListView) return _templates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_templates);
}


/// Create a copy of CenterSlideCatalog
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CenterSlideCatalogCopyWith<_CenterSlideCatalog> get copyWith => __$CenterSlideCatalogCopyWithImpl<_CenterSlideCatalog>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CenterSlideCatalog&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.centerId, centerId) || other.centerId == centerId)&&(identical(other.centerName, centerName) || other.centerName == centerName)&&const DeepCollectionEquality().equals(other.templates, _templates));
}


@override
int get hashCode {
    return Object.hash(runtimeType,revision,centerId,centerName,const DeepCollectionEquality().hash(_templates));
}

@override
String toString() {
    return 'CenterSlideCatalog(revision: $revision, centerId: $centerId, centerName: $centerName, templates: $templates)';
}


}

/// @nodoc
abstract mixin class _$CenterSlideCatalogCopyWith<$Res> implements $CenterSlideCatalogCopyWith<$Res> {
  factory _$CenterSlideCatalogCopyWith(_CenterSlideCatalog value, $Res Function(_CenterSlideCatalog) _then) = __$CenterSlideCatalogCopyWithImpl;
@override @useResult
$Res call({
 int revision, String centerId, String centerName, List<AiSlideDesign> templates
});




}
/// @nodoc
class __$CenterSlideCatalogCopyWithImpl<$Res>
    implements _$CenterSlideCatalogCopyWith<$Res> {
  __$CenterSlideCatalogCopyWithImpl(this._self, this._then);

  final _CenterSlideCatalog _self;
  final $Res Function(_CenterSlideCatalog) _then;

/// Create a copy of CenterSlideCatalog
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? revision = null,Object? centerId = null,Object? centerName = null,Object? templates = null,}) {
  return _then(_CenterSlideCatalog(
revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,centerId: null == centerId ? _self.centerId : centerId // ignore: cast_nullable_to_non_nullable
as String,centerName: null == centerName ? _self.centerName : centerName // ignore: cast_nullable_to_non_nullable
as String,templates: null == templates ? _self._templates : templates // ignore: cast_nullable_to_non_nullable
as List<AiSlideDesign>,
  ));
}


}

/// @nodoc
mixin _$CenterSlideCatalogScope {

 String get ownerId; String get centerId;
/// Create a copy of CenterSlideCatalogScope
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CenterSlideCatalogScopeCopyWith<CenterSlideCatalogScope> get copyWith => _$CenterSlideCatalogScopeCopyWithImpl<CenterSlideCatalogScope>(this as CenterSlideCatalogScope, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CenterSlideCatalogScope;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CenterSlideCatalogScope&&(identical(other.ownerId, _this.ownerId) || other.ownerId == _this.ownerId)&&(identical(other.centerId, _this.centerId) || other.centerId == _this.centerId));
}


@override
int get hashCode {
  final _this = this as CenterSlideCatalogScope;
  return Object.hash(runtimeType,_this.ownerId,_this.centerId);
}

@override
String toString() {
  final _this = this as CenterSlideCatalogScope;
  return 'CenterSlideCatalogScope(ownerId: ${_this.ownerId}, centerId: ${_this.centerId})';
}


}

/// @nodoc
abstract mixin class $CenterSlideCatalogScopeCopyWith<$Res>  {
  factory $CenterSlideCatalogScopeCopyWith(CenterSlideCatalogScope value, $Res Function(CenterSlideCatalogScope) _then) = _$CenterSlideCatalogScopeCopyWithImpl;
@useResult
$Res call({
 String ownerId, String centerId
});




}
/// @nodoc
class _$CenterSlideCatalogScopeCopyWithImpl<$Res>
    implements $CenterSlideCatalogScopeCopyWith<$Res> {
  _$CenterSlideCatalogScopeCopyWithImpl(this._self, this._then);

  final CenterSlideCatalogScope _self;
  final $Res Function(CenterSlideCatalogScope) _then;

/// Create a copy of CenterSlideCatalogScope
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ownerId = null,Object? centerId = null,}) {
  return _then(CenterSlideCatalogScope(
ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,centerId: null == centerId ? _self.centerId : centerId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CenterSlideCatalogScope].
extension CenterSlideCatalogScopePatterns on CenterSlideCatalogScope {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CenterSlideCatalogScope value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CenterSlideCatalogScope() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CenterSlideCatalogScope value)  $default,){
final _that = this;
switch (_that) {
case _CenterSlideCatalogScope():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CenterSlideCatalogScope value)?  $default,){
final _that = this;
switch (_that) {
case _CenterSlideCatalogScope() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ownerId,  String centerId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CenterSlideCatalogScope() when $default != null:
return $default(_that.ownerId,_that.centerId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ownerId,  String centerId)  $default,) {final _that = this;
switch (_that) {
case _CenterSlideCatalogScope():
return $default(_that.ownerId,_that.centerId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ownerId,  String centerId)?  $default,) {final _that = this;
switch (_that) {
case _CenterSlideCatalogScope() when $default != null:
return $default(_that.ownerId,_that.centerId);case _:
  return null;

}
}

}

/// @nodoc


class _CenterSlideCatalogScope implements CenterSlideCatalogScope {
  const _CenterSlideCatalogScope({required this.ownerId, required this.centerId});
  

@override final  String ownerId;
@override final  String centerId;

/// Create a copy of CenterSlideCatalogScope
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CenterSlideCatalogScopeCopyWith<_CenterSlideCatalogScope> get copyWith => __$CenterSlideCatalogScopeCopyWithImpl<_CenterSlideCatalogScope>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CenterSlideCatalogScope&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId)&&(identical(other.centerId, centerId) || other.centerId == centerId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,ownerId,centerId);
}

@override
String toString() {
    return 'CenterSlideCatalogScope(ownerId: $ownerId, centerId: $centerId)';
}


}

/// @nodoc
abstract mixin class _$CenterSlideCatalogScopeCopyWith<$Res> implements $CenterSlideCatalogScopeCopyWith<$Res> {
  factory _$CenterSlideCatalogScopeCopyWith(_CenterSlideCatalogScope value, $Res Function(_CenterSlideCatalogScope) _then) = __$CenterSlideCatalogScopeCopyWithImpl;
@override @useResult
$Res call({
 String ownerId, String centerId
});




}
/// @nodoc
class __$CenterSlideCatalogScopeCopyWithImpl<$Res>
    implements _$CenterSlideCatalogScopeCopyWith<$Res> {
  __$CenterSlideCatalogScopeCopyWithImpl(this._self, this._then);

  final _CenterSlideCatalogScope _self;
  final $Res Function(_CenterSlideCatalogScope) _then;

/// Create a copy of CenterSlideCatalogScope
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ownerId = null,Object? centerId = null,}) {
  return _then(_CenterSlideCatalogScope(
ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,centerId: null == centerId ? _self.centerId : centerId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
