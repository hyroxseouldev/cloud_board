// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audience_branding.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AudienceBranding {

 String get ownerId; int get revision; int get projectionRevision; int get appliedAtMs; int get validUntilMs; AudienceLogoScope get scope; bool get showCloudBoardLogo;
/// Create a copy of AudienceBranding
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudienceBrandingCopyWith<AudienceBranding> get copyWith => _$AudienceBrandingCopyWithImpl<AudienceBranding>(this as AudienceBranding, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AudienceBranding;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudienceBranding&&(identical(other.ownerId, _this.ownerId) || other.ownerId == _this.ownerId)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&(identical(other.projectionRevision, _this.projectionRevision) || other.projectionRevision == _this.projectionRevision)&&(identical(other.appliedAtMs, _this.appliedAtMs) || other.appliedAtMs == _this.appliedAtMs)&&(identical(other.validUntilMs, _this.validUntilMs) || other.validUntilMs == _this.validUntilMs)&&(identical(other.scope, _this.scope) || other.scope == _this.scope)&&(identical(other.showCloudBoardLogo, _this.showCloudBoardLogo) || other.showCloudBoardLogo == _this.showCloudBoardLogo));
}


@override
int get hashCode {
  final _this = this as AudienceBranding;
  return Object.hash(runtimeType,_this.ownerId,_this.revision,_this.projectionRevision,_this.appliedAtMs,_this.validUntilMs,_this.scope,_this.showCloudBoardLogo);
}

@override
String toString() {
  final _this = this as AudienceBranding;
  return 'AudienceBranding(ownerId: ${_this.ownerId}, revision: ${_this.revision}, projectionRevision: ${_this.projectionRevision}, appliedAtMs: ${_this.appliedAtMs}, validUntilMs: ${_this.validUntilMs}, scope: ${_this.scope}, showCloudBoardLogo: ${_this.showCloudBoardLogo})';
}


}

/// @nodoc
abstract mixin class $AudienceBrandingCopyWith<$Res>  {
  factory $AudienceBrandingCopyWith(AudienceBranding value, $Res Function(AudienceBranding) _then) = _$AudienceBrandingCopyWithImpl;
@useResult
$Res call({
 String ownerId, int revision, int projectionRevision, int appliedAtMs, int validUntilMs, AudienceLogoScope scope, bool showCloudBoardLogo
});




}
/// @nodoc
class _$AudienceBrandingCopyWithImpl<$Res>
    implements $AudienceBrandingCopyWith<$Res> {
  _$AudienceBrandingCopyWithImpl(this._self, this._then);

  final AudienceBranding _self;
  final $Res Function(AudienceBranding) _then;

/// Create a copy of AudienceBranding
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ownerId = null,Object? revision = null,Object? projectionRevision = null,Object? appliedAtMs = null,Object? validUntilMs = null,Object? scope = null,Object? showCloudBoardLogo = null,}) {
  return _then(AudienceBranding(
ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,projectionRevision: null == projectionRevision ? _self.projectionRevision : projectionRevision // ignore: cast_nullable_to_non_nullable
as int,appliedAtMs: null == appliedAtMs ? _self.appliedAtMs : appliedAtMs // ignore: cast_nullable_to_non_nullable
as int,validUntilMs: null == validUntilMs ? _self.validUntilMs : validUntilMs // ignore: cast_nullable_to_non_nullable
as int,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as AudienceLogoScope,showCloudBoardLogo: null == showCloudBoardLogo ? _self.showCloudBoardLogo : showCloudBoardLogo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AudienceBranding].
extension AudienceBrandingPatterns on AudienceBranding {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudienceBranding value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudienceBranding() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudienceBranding value)  $default,){
final _that = this;
switch (_that) {
case _AudienceBranding():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudienceBranding value)?  $default,){
final _that = this;
switch (_that) {
case _AudienceBranding() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ownerId,  int revision,  int projectionRevision,  int appliedAtMs,  int validUntilMs,  AudienceLogoScope scope,  bool showCloudBoardLogo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudienceBranding() when $default != null:
return $default(_that.ownerId,_that.revision,_that.projectionRevision,_that.appliedAtMs,_that.validUntilMs,_that.scope,_that.showCloudBoardLogo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ownerId,  int revision,  int projectionRevision,  int appliedAtMs,  int validUntilMs,  AudienceLogoScope scope,  bool showCloudBoardLogo)  $default,) {final _that = this;
switch (_that) {
case _AudienceBranding():
return $default(_that.ownerId,_that.revision,_that.projectionRevision,_that.appliedAtMs,_that.validUntilMs,_that.scope,_that.showCloudBoardLogo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ownerId,  int revision,  int projectionRevision,  int appliedAtMs,  int validUntilMs,  AudienceLogoScope scope,  bool showCloudBoardLogo)?  $default,) {final _that = this;
switch (_that) {
case _AudienceBranding() when $default != null:
return $default(_that.ownerId,_that.revision,_that.projectionRevision,_that.appliedAtMs,_that.validUntilMs,_that.scope,_that.showCloudBoardLogo);case _:
  return null;

}
}

}

/// @nodoc


class _AudienceBranding extends AudienceBranding {
  const _AudienceBranding({required this.ownerId, required this.revision, required this.projectionRevision, required this.appliedAtMs, required this.validUntilMs, required this.scope, required this.showCloudBoardLogo}): super._();


@override final  String ownerId;
@override final  int revision;
@override final  int projectionRevision;
@override final  int appliedAtMs;
@override final  int validUntilMs;
@override final  AudienceLogoScope scope;
@override final  bool showCloudBoardLogo;

/// Create a copy of AudienceBranding
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudienceBrandingCopyWith<_AudienceBranding> get copyWith => __$AudienceBrandingCopyWithImpl<_AudienceBranding>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudienceBranding&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.projectionRevision, projectionRevision) || other.projectionRevision == projectionRevision)&&(identical(other.appliedAtMs, appliedAtMs) || other.appliedAtMs == appliedAtMs)&&(identical(other.validUntilMs, validUntilMs) || other.validUntilMs == validUntilMs)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.showCloudBoardLogo, showCloudBoardLogo) || other.showCloudBoardLogo == showCloudBoardLogo));
}


@override
int get hashCode {
    return Object.hash(runtimeType,ownerId,revision,projectionRevision,appliedAtMs,validUntilMs,scope,showCloudBoardLogo);
}

@override
String toString() {
    return 'AudienceBranding(ownerId: $ownerId, revision: $revision, projectionRevision: $projectionRevision, appliedAtMs: $appliedAtMs, validUntilMs: $validUntilMs, scope: $scope, showCloudBoardLogo: $showCloudBoardLogo)';
}


}

/// @nodoc
abstract mixin class _$AudienceBrandingCopyWith<$Res> implements $AudienceBrandingCopyWith<$Res> {
  factory _$AudienceBrandingCopyWith(_AudienceBranding value, $Res Function(_AudienceBranding) _then) = __$AudienceBrandingCopyWithImpl;
@override @useResult
$Res call({
 String ownerId, int revision, int projectionRevision, int appliedAtMs, int validUntilMs, AudienceLogoScope scope, bool showCloudBoardLogo
});




}
/// @nodoc
class __$AudienceBrandingCopyWithImpl<$Res>
    implements _$AudienceBrandingCopyWith<$Res> {
  __$AudienceBrandingCopyWithImpl(this._self, this._then);

  final _AudienceBranding _self;
  final $Res Function(_AudienceBranding) _then;

/// Create a copy of AudienceBranding
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ownerId = null,Object? revision = null,Object? projectionRevision = null,Object? appliedAtMs = null,Object? validUntilMs = null,Object? scope = null,Object? showCloudBoardLogo = null,}) {
  return _then(_AudienceBranding(
ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,projectionRevision: null == projectionRevision ? _self.projectionRevision : projectionRevision // ignore: cast_nullable_to_non_nullable
as int,appliedAtMs: null == appliedAtMs ? _self.appliedAtMs : appliedAtMs // ignore: cast_nullable_to_non_nullable
as int,validUntilMs: null == validUntilMs ? _self.validUntilMs : validUntilMs // ignore: cast_nullable_to_non_nullable
as int,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as AudienceLogoScope,showCloudBoardLogo: null == showCloudBoardLogo ? _self.showCloudBoardLogo : showCloudBoardLogo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
