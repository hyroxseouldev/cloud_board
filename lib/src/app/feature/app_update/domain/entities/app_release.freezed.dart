// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_release.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppRelease {

 int get latestBuild; int get minimumBuild; int get publishedBuild; String get version; String get storeUrl; String get message; bool get enabled; bool get published;
/// Create a copy of AppRelease
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppReleaseCopyWith<AppRelease> get copyWith => _$AppReleaseCopyWithImpl<AppRelease>(this as AppRelease, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AppRelease;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppRelease&&(identical(other.latestBuild, _this.latestBuild) || other.latestBuild == _this.latestBuild)&&(identical(other.minimumBuild, _this.minimumBuild) || other.minimumBuild == _this.minimumBuild)&&(identical(other.publishedBuild, _this.publishedBuild) || other.publishedBuild == _this.publishedBuild)&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.storeUrl, _this.storeUrl) || other.storeUrl == _this.storeUrl)&&(identical(other.message, _this.message) || other.message == _this.message)&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.published, _this.published) || other.published == _this.published));
}


@override
int get hashCode {
  final _this = this as AppRelease;
  return Object.hash(runtimeType,_this.latestBuild,_this.minimumBuild,_this.publishedBuild,_this.version,_this.storeUrl,_this.message,_this.enabled,_this.published);
}

@override
String toString() {
  final _this = this as AppRelease;
  return 'AppRelease(latestBuild: ${_this.latestBuild}, minimumBuild: ${_this.minimumBuild}, publishedBuild: ${_this.publishedBuild}, version: ${_this.version}, storeUrl: ${_this.storeUrl}, message: ${_this.message}, enabled: ${_this.enabled}, published: ${_this.published})';
}


}

/// @nodoc
abstract mixin class $AppReleaseCopyWith<$Res>  {
  factory $AppReleaseCopyWith(AppRelease value, $Res Function(AppRelease) _then) = _$AppReleaseCopyWithImpl;
@useResult
$Res call({
 int latestBuild, int minimumBuild, int publishedBuild, String version, String storeUrl, String message, bool enabled, bool published
});




}
/// @nodoc
class _$AppReleaseCopyWithImpl<$Res>
    implements $AppReleaseCopyWith<$Res> {
  _$AppReleaseCopyWithImpl(this._self, this._then);

  final AppRelease _self;
  final $Res Function(AppRelease) _then;

/// Create a copy of AppRelease
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? latestBuild = null,Object? minimumBuild = null,Object? publishedBuild = null,Object? version = null,Object? storeUrl = null,Object? message = null,Object? enabled = null,Object? published = null,}) {
  return _then(AppRelease(
latestBuild: null == latestBuild ? _self.latestBuild : latestBuild // ignore: cast_nullable_to_non_nullable
as int,minimumBuild: null == minimumBuild ? _self.minimumBuild : minimumBuild // ignore: cast_nullable_to_non_nullable
as int,publishedBuild: null == publishedBuild ? _self.publishedBuild : publishedBuild // ignore: cast_nullable_to_non_nullable
as int,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,storeUrl: null == storeUrl ? _self.storeUrl : storeUrl // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,published: null == published ? _self.published : published // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AppRelease].
extension AppReleasePatterns on AppRelease {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppRelease value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppRelease() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppRelease value)  $default,){
final _that = this;
switch (_that) {
case _AppRelease():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppRelease value)?  $default,){
final _that = this;
switch (_that) {
case _AppRelease() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int latestBuild,  int minimumBuild,  int publishedBuild,  String version,  String storeUrl,  String message,  bool enabled,  bool published)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppRelease() when $default != null:
return $default(_that.latestBuild,_that.minimumBuild,_that.publishedBuild,_that.version,_that.storeUrl,_that.message,_that.enabled,_that.published);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int latestBuild,  int minimumBuild,  int publishedBuild,  String version,  String storeUrl,  String message,  bool enabled,  bool published)  $default,) {final _that = this;
switch (_that) {
case _AppRelease():
return $default(_that.latestBuild,_that.minimumBuild,_that.publishedBuild,_that.version,_that.storeUrl,_that.message,_that.enabled,_that.published);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int latestBuild,  int minimumBuild,  int publishedBuild,  String version,  String storeUrl,  String message,  bool enabled,  bool published)?  $default,) {final _that = this;
switch (_that) {
case _AppRelease() when $default != null:
return $default(_that.latestBuild,_that.minimumBuild,_that.publishedBuild,_that.version,_that.storeUrl,_that.message,_that.enabled,_that.published);case _:
  return null;

}
}

}

/// @nodoc


class _AppRelease extends AppRelease {
  const _AppRelease({required this.latestBuild, required this.minimumBuild, required this.publishedBuild, required this.version, required this.storeUrl, this.message = '더 편리하고 안정적인 수업을 위해 최신 버전으로 업데이트해 주세요.', this.enabled = false, this.published = false}): super._();
  

@override final  int latestBuild;
@override final  int minimumBuild;
@override final  int publishedBuild;
@override final  String version;
@override final  String storeUrl;
@override@JsonKey() final  String message;
@override@JsonKey() final  bool enabled;
@override@JsonKey() final  bool published;

/// Create a copy of AppRelease
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppReleaseCopyWith<_AppRelease> get copyWith => __$AppReleaseCopyWithImpl<_AppRelease>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppRelease&&(identical(other.latestBuild, latestBuild) || other.latestBuild == latestBuild)&&(identical(other.minimumBuild, minimumBuild) || other.minimumBuild == minimumBuild)&&(identical(other.publishedBuild, publishedBuild) || other.publishedBuild == publishedBuild)&&(identical(other.version, version) || other.version == version)&&(identical(other.storeUrl, storeUrl) || other.storeUrl == storeUrl)&&(identical(other.message, message) || other.message == message)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.published, published) || other.published == published));
}


@override
int get hashCode {
    return Object.hash(runtimeType,latestBuild,minimumBuild,publishedBuild,version,storeUrl,message,enabled,published);
}

@override
String toString() {
    return 'AppRelease(latestBuild: $latestBuild, minimumBuild: $minimumBuild, publishedBuild: $publishedBuild, version: $version, storeUrl: $storeUrl, message: $message, enabled: $enabled, published: $published)';
}


}

/// @nodoc
abstract mixin class _$AppReleaseCopyWith<$Res> implements $AppReleaseCopyWith<$Res> {
  factory _$AppReleaseCopyWith(_AppRelease value, $Res Function(_AppRelease) _then) = __$AppReleaseCopyWithImpl;
@override @useResult
$Res call({
 int latestBuild, int minimumBuild, int publishedBuild, String version, String storeUrl, String message, bool enabled, bool published
});




}
/// @nodoc
class __$AppReleaseCopyWithImpl<$Res>
    implements _$AppReleaseCopyWith<$Res> {
  __$AppReleaseCopyWithImpl(this._self, this._then);

  final _AppRelease _self;
  final $Res Function(_AppRelease) _then;

/// Create a copy of AppRelease
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? latestBuild = null,Object? minimumBuild = null,Object? publishedBuild = null,Object? version = null,Object? storeUrl = null,Object? message = null,Object? enabled = null,Object? published = null,}) {
  return _then(_AppRelease(
latestBuild: null == latestBuild ? _self.latestBuild : latestBuild // ignore: cast_nullable_to_non_nullable
as int,minimumBuild: null == minimumBuild ? _self.minimumBuild : minimumBuild // ignore: cast_nullable_to_non_nullable
as int,publishedBuild: null == publishedBuild ? _self.publishedBuild : publishedBuild // ignore: cast_nullable_to_non_nullable
as int,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,storeUrl: null == storeUrl ? _self.storeUrl : storeUrl // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,published: null == published ? _self.published : published // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
