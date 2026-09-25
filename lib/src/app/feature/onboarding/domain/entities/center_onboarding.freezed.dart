// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'center_onboarding.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CenterProfile {

 String? get purpose; String? get role; String get centerName; List<String> get centerTypes; String get province; String get district; bool get undecidedName; bool get undecidedRegion; Map<String, String> get environment; bool get environmentSkipped; List<String> get classTypes; List<String> get guidance; List<String> get priorities; List<String> get controllers; String get floorArea;
/// Create a copy of CenterProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CenterProfileCopyWith<CenterProfile> get copyWith => _$CenterProfileCopyWithImpl<CenterProfile>(this as CenterProfile, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CenterProfile;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CenterProfile&&(identical(other.purpose, _this.purpose) || other.purpose == _this.purpose)&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.centerName, _this.centerName) || other.centerName == _this.centerName)&&const DeepCollectionEquality().equals(other.centerTypes, _this.centerTypes)&&(identical(other.province, _this.province) || other.province == _this.province)&&(identical(other.district, _this.district) || other.district == _this.district)&&(identical(other.undecidedName, _this.undecidedName) || other.undecidedName == _this.undecidedName)&&(identical(other.undecidedRegion, _this.undecidedRegion) || other.undecidedRegion == _this.undecidedRegion)&&const DeepCollectionEquality().equals(other.environment, _this.environment)&&(identical(other.environmentSkipped, _this.environmentSkipped) || other.environmentSkipped == _this.environmentSkipped)&&const DeepCollectionEquality().equals(other.classTypes, _this.classTypes)&&const DeepCollectionEquality().equals(other.guidance, _this.guidance)&&const DeepCollectionEquality().equals(other.priorities, _this.priorities)&&const DeepCollectionEquality().equals(other.controllers, _this.controllers)&&(identical(other.floorArea, _this.floorArea) || other.floorArea == _this.floorArea));
}


@override
int get hashCode {
  final _this = this as CenterProfile;
  return Object.hash(runtimeType,_this.purpose,_this.role,_this.centerName,const DeepCollectionEquality().hash(_this.centerTypes),_this.province,_this.district,_this.undecidedName,_this.undecidedRegion,const DeepCollectionEquality().hash(_this.environment),_this.environmentSkipped,const DeepCollectionEquality().hash(_this.classTypes),const DeepCollectionEquality().hash(_this.guidance),const DeepCollectionEquality().hash(_this.priorities),const DeepCollectionEquality().hash(_this.controllers),_this.floorArea);
}

@override
String toString() {
  final _this = this as CenterProfile;
  return 'CenterProfile(purpose: ${_this.purpose}, role: ${_this.role}, centerName: ${_this.centerName}, centerTypes: ${_this.centerTypes}, province: ${_this.province}, district: ${_this.district}, undecidedName: ${_this.undecidedName}, undecidedRegion: ${_this.undecidedRegion}, environment: ${_this.environment}, environmentSkipped: ${_this.environmentSkipped}, classTypes: ${_this.classTypes}, guidance: ${_this.guidance}, priorities: ${_this.priorities}, controllers: ${_this.controllers}, floorArea: ${_this.floorArea})';
}


}

/// @nodoc
abstract mixin class $CenterProfileCopyWith<$Res>  {
  factory $CenterProfileCopyWith(CenterProfile value, $Res Function(CenterProfile) _then) = _$CenterProfileCopyWithImpl;
@useResult
$Res call({
 String? purpose, String? role, String centerName, List<String> centerTypes, String province, String district, bool undecidedName, bool undecidedRegion, Map<String, String> environment, bool environmentSkipped, List<String> classTypes, List<String> guidance, List<String> priorities, List<String> controllers, String floorArea
});




}
/// @nodoc
class _$CenterProfileCopyWithImpl<$Res>
    implements $CenterProfileCopyWith<$Res> {
  _$CenterProfileCopyWithImpl(this._self, this._then);

  final CenterProfile _self;
  final $Res Function(CenterProfile) _then;

/// Create a copy of CenterProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? purpose = freezed,Object? role = freezed,Object? centerName = null,Object? centerTypes = null,Object? province = null,Object? district = null,Object? undecidedName = null,Object? undecidedRegion = null,Object? environment = null,Object? environmentSkipped = null,Object? classTypes = null,Object? guidance = null,Object? priorities = null,Object? controllers = null,Object? floorArea = null,}) {
  return _then(CenterProfile(
purpose: freezed == purpose ? _self.purpose : purpose // ignore: cast_nullable_to_non_nullable
as String?,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,centerName: null == centerName ? _self.centerName : centerName // ignore: cast_nullable_to_non_nullable
as String,centerTypes: null == centerTypes ? _self.centerTypes : centerTypes // ignore: cast_nullable_to_non_nullable
as List<String>,province: null == province ? _self.province : province // ignore: cast_nullable_to_non_nullable
as String,district: null == district ? _self.district : district // ignore: cast_nullable_to_non_nullable
as String,undecidedName: null == undecidedName ? _self.undecidedName : undecidedName // ignore: cast_nullable_to_non_nullable
as bool,undecidedRegion: null == undecidedRegion ? _self.undecidedRegion : undecidedRegion // ignore: cast_nullable_to_non_nullable
as bool,environment: null == environment ? _self.environment : environment // ignore: cast_nullable_to_non_nullable
as Map<String, String>,environmentSkipped: null == environmentSkipped ? _self.environmentSkipped : environmentSkipped // ignore: cast_nullable_to_non_nullable
as bool,classTypes: null == classTypes ? _self.classTypes : classTypes // ignore: cast_nullable_to_non_nullable
as List<String>,guidance: null == guidance ? _self.guidance : guidance // ignore: cast_nullable_to_non_nullable
as List<String>,priorities: null == priorities ? _self.priorities : priorities // ignore: cast_nullable_to_non_nullable
as List<String>,controllers: null == controllers ? _self.controllers : controllers // ignore: cast_nullable_to_non_nullable
as List<String>,floorArea: null == floorArea ? _self.floorArea : floorArea // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CenterProfile].
extension CenterProfilePatterns on CenterProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CenterProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CenterProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CenterProfile value)  $default,){
final _that = this;
switch (_that) {
case _CenterProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CenterProfile value)?  $default,){
final _that = this;
switch (_that) {
case _CenterProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? purpose,  String? role,  String centerName,  List<String> centerTypes,  String province,  String district,  bool undecidedName,  bool undecidedRegion,  Map<String, String> environment,  bool environmentSkipped,  List<String> classTypes,  List<String> guidance,  List<String> priorities,  List<String> controllers,  String floorArea)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CenterProfile() when $default != null:
return $default(_that.purpose,_that.role,_that.centerName,_that.centerTypes,_that.province,_that.district,_that.undecidedName,_that.undecidedRegion,_that.environment,_that.environmentSkipped,_that.classTypes,_that.guidance,_that.priorities,_that.controllers,_that.floorArea);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? purpose,  String? role,  String centerName,  List<String> centerTypes,  String province,  String district,  bool undecidedName,  bool undecidedRegion,  Map<String, String> environment,  bool environmentSkipped,  List<String> classTypes,  List<String> guidance,  List<String> priorities,  List<String> controllers,  String floorArea)  $default,) {final _that = this;
switch (_that) {
case _CenterProfile():
return $default(_that.purpose,_that.role,_that.centerName,_that.centerTypes,_that.province,_that.district,_that.undecidedName,_that.undecidedRegion,_that.environment,_that.environmentSkipped,_that.classTypes,_that.guidance,_that.priorities,_that.controllers,_that.floorArea);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? purpose,  String? role,  String centerName,  List<String> centerTypes,  String province,  String district,  bool undecidedName,  bool undecidedRegion,  Map<String, String> environment,  bool environmentSkipped,  List<String> classTypes,  List<String> guidance,  List<String> priorities,  List<String> controllers,  String floorArea)?  $default,) {final _that = this;
switch (_that) {
case _CenterProfile() when $default != null:
return $default(_that.purpose,_that.role,_that.centerName,_that.centerTypes,_that.province,_that.district,_that.undecidedName,_that.undecidedRegion,_that.environment,_that.environmentSkipped,_that.classTypes,_that.guidance,_that.priorities,_that.controllers,_that.floorArea);case _:
  return null;

}
}

}

/// @nodoc


class _CenterProfile extends CenterProfile {
  const _CenterProfile({this.purpose, this.role, this.centerName = '',  List<String> centerTypes = const [], this.province = '', this.district = '', this.undecidedName = false, this.undecidedRegion = false,  Map<String, String> environment = const {}, this.environmentSkipped = false,  List<String> classTypes = const [],  List<String> guidance = const [],  List<String> priorities = const [],  List<String> controllers = const [], this.floorArea = ''}): _centerTypes = centerTypes,_environment = environment,_classTypes = classTypes,_guidance = guidance,_priorities = priorities,_controllers = controllers,super._();
  

@override final  String? purpose;
@override final  String? role;
@override@JsonKey() final  String centerName;
 final  List<String> _centerTypes;
@override@JsonKey() List<String> get centerTypes {
  if (_centerTypes is EqualUnmodifiableListView) return _centerTypes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_centerTypes);
}

@override@JsonKey() final  String province;
@override@JsonKey() final  String district;
@override@JsonKey() final  bool undecidedName;
@override@JsonKey() final  bool undecidedRegion;
 final  Map<String, String> _environment;
@override@JsonKey() Map<String, String> get environment {
  if (_environment is EqualUnmodifiableMapView) return _environment;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_environment);
}

@override@JsonKey() final  bool environmentSkipped;
 final  List<String> _classTypes;
@override@JsonKey() List<String> get classTypes {
  if (_classTypes is EqualUnmodifiableListView) return _classTypes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_classTypes);
}

 final  List<String> _guidance;
@override@JsonKey() List<String> get guidance {
  if (_guidance is EqualUnmodifiableListView) return _guidance;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_guidance);
}

 final  List<String> _priorities;
@override@JsonKey() List<String> get priorities {
  if (_priorities is EqualUnmodifiableListView) return _priorities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_priorities);
}

 final  List<String> _controllers;
@override@JsonKey() List<String> get controllers {
  if (_controllers is EqualUnmodifiableListView) return _controllers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_controllers);
}

@override@JsonKey() final  String floorArea;

/// Create a copy of CenterProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CenterProfileCopyWith<_CenterProfile> get copyWith => __$CenterProfileCopyWithImpl<_CenterProfile>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CenterProfile&&(identical(other.purpose, purpose) || other.purpose == purpose)&&(identical(other.role, role) || other.role == role)&&(identical(other.centerName, centerName) || other.centerName == centerName)&&const DeepCollectionEquality().equals(other.centerTypes, _centerTypes)&&(identical(other.province, province) || other.province == province)&&(identical(other.district, district) || other.district == district)&&(identical(other.undecidedName, undecidedName) || other.undecidedName == undecidedName)&&(identical(other.undecidedRegion, undecidedRegion) || other.undecidedRegion == undecidedRegion)&&const DeepCollectionEquality().equals(other.environment, _environment)&&(identical(other.environmentSkipped, environmentSkipped) || other.environmentSkipped == environmentSkipped)&&const DeepCollectionEquality().equals(other.classTypes, _classTypes)&&const DeepCollectionEquality().equals(other.guidance, _guidance)&&const DeepCollectionEquality().equals(other.priorities, _priorities)&&const DeepCollectionEquality().equals(other.controllers, _controllers)&&(identical(other.floorArea, floorArea) || other.floorArea == floorArea));
}


@override
int get hashCode {
    return Object.hash(runtimeType,purpose,role,centerName,const DeepCollectionEquality().hash(_centerTypes),province,district,undecidedName,undecidedRegion,const DeepCollectionEquality().hash(_environment),environmentSkipped,const DeepCollectionEquality().hash(_classTypes),const DeepCollectionEquality().hash(_guidance),const DeepCollectionEquality().hash(_priorities),const DeepCollectionEquality().hash(_controllers),floorArea);
}

@override
String toString() {
    return 'CenterProfile(purpose: $purpose, role: $role, centerName: $centerName, centerTypes: $centerTypes, province: $province, district: $district, undecidedName: $undecidedName, undecidedRegion: $undecidedRegion, environment: $environment, environmentSkipped: $environmentSkipped, classTypes: $classTypes, guidance: $guidance, priorities: $priorities, controllers: $controllers, floorArea: $floorArea)';
}


}

/// @nodoc
abstract mixin class _$CenterProfileCopyWith<$Res> implements $CenterProfileCopyWith<$Res> {
  factory _$CenterProfileCopyWith(_CenterProfile value, $Res Function(_CenterProfile) _then) = __$CenterProfileCopyWithImpl;
@override @useResult
$Res call({
 String? purpose, String? role, String centerName, List<String> centerTypes, String province, String district, bool undecidedName, bool undecidedRegion, Map<String, String> environment, bool environmentSkipped, List<String> classTypes, List<String> guidance, List<String> priorities, List<String> controllers, String floorArea
});




}
/// @nodoc
class __$CenterProfileCopyWithImpl<$Res>
    implements _$CenterProfileCopyWith<$Res> {
  __$CenterProfileCopyWithImpl(this._self, this._then);

  final _CenterProfile _self;
  final $Res Function(_CenterProfile) _then;

/// Create a copy of CenterProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? purpose = freezed,Object? role = freezed,Object? centerName = null,Object? centerTypes = null,Object? province = null,Object? district = null,Object? undecidedName = null,Object? undecidedRegion = null,Object? environment = null,Object? environmentSkipped = null,Object? classTypes = null,Object? guidance = null,Object? priorities = null,Object? controllers = null,Object? floorArea = null,}) {
  return _then(_CenterProfile(
purpose: freezed == purpose ? _self.purpose : purpose // ignore: cast_nullable_to_non_nullable
as String?,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,centerName: null == centerName ? _self.centerName : centerName // ignore: cast_nullable_to_non_nullable
as String,centerTypes: null == centerTypes ? _self._centerTypes : centerTypes // ignore: cast_nullable_to_non_nullable
as List<String>,province: null == province ? _self.province : province // ignore: cast_nullable_to_non_nullable
as String,district: null == district ? _self.district : district // ignore: cast_nullable_to_non_nullable
as String,undecidedName: null == undecidedName ? _self.undecidedName : undecidedName // ignore: cast_nullable_to_non_nullable
as bool,undecidedRegion: null == undecidedRegion ? _self.undecidedRegion : undecidedRegion // ignore: cast_nullable_to_non_nullable
as bool,environment: null == environment ? _self._environment : environment // ignore: cast_nullable_to_non_nullable
as Map<String, String>,environmentSkipped: null == environmentSkipped ? _self.environmentSkipped : environmentSkipped // ignore: cast_nullable_to_non_nullable
as bool,classTypes: null == classTypes ? _self._classTypes : classTypes // ignore: cast_nullable_to_non_nullable
as List<String>,guidance: null == guidance ? _self._guidance : guidance // ignore: cast_nullable_to_non_nullable
as List<String>,priorities: null == priorities ? _self._priorities : priorities // ignore: cast_nullable_to_non_nullable
as List<String>,controllers: null == controllers ? _self._controllers : controllers // ignore: cast_nullable_to_non_nullable
as List<String>,floorArea: null == floorArea ? _self.floorArea : floorArea // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$CenterOnboarding {

 bool get phoneRequired; String get storeId; CenterProfile get profile; int get step; int get revision; bool get completed; bool get deferred; String get status; bool get hasAccess; bool get trialEligible; int get trialStartedAtMs; int get trialEndsAtMs; int get serverNowMs; int get suggestedTrialEndsAtMs;
/// Create a copy of CenterOnboarding
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CenterOnboardingCopyWith<CenterOnboarding> get copyWith => _$CenterOnboardingCopyWithImpl<CenterOnboarding>(this as CenterOnboarding, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CenterOnboarding;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CenterOnboarding&&(identical(other.phoneRequired, _this.phoneRequired) || other.phoneRequired == _this.phoneRequired)&&(identical(other.storeId, _this.storeId) || other.storeId == _this.storeId)&&(identical(other.profile, _this.profile) || other.profile == _this.profile)&&(identical(other.step, _this.step) || other.step == _this.step)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&(identical(other.completed, _this.completed) || other.completed == _this.completed)&&(identical(other.deferred, _this.deferred) || other.deferred == _this.deferred)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.hasAccess, _this.hasAccess) || other.hasAccess == _this.hasAccess)&&(identical(other.trialEligible, _this.trialEligible) || other.trialEligible == _this.trialEligible)&&(identical(other.trialStartedAtMs, _this.trialStartedAtMs) || other.trialStartedAtMs == _this.trialStartedAtMs)&&(identical(other.trialEndsAtMs, _this.trialEndsAtMs) || other.trialEndsAtMs == _this.trialEndsAtMs)&&(identical(other.serverNowMs, _this.serverNowMs) || other.serverNowMs == _this.serverNowMs)&&(identical(other.suggestedTrialEndsAtMs, _this.suggestedTrialEndsAtMs) || other.suggestedTrialEndsAtMs == _this.suggestedTrialEndsAtMs));
}


@override
int get hashCode {
  final _this = this as CenterOnboarding;
  return Object.hash(runtimeType,_this.phoneRequired,_this.storeId,_this.profile,_this.step,_this.revision,_this.completed,_this.deferred,_this.status,_this.hasAccess,_this.trialEligible,_this.trialStartedAtMs,_this.trialEndsAtMs,_this.serverNowMs,_this.suggestedTrialEndsAtMs);
}

@override
String toString() {
  final _this = this as CenterOnboarding;
  return 'CenterOnboarding(phoneRequired: ${_this.phoneRequired}, storeId: ${_this.storeId}, profile: ${_this.profile}, step: ${_this.step}, revision: ${_this.revision}, completed: ${_this.completed}, deferred: ${_this.deferred}, status: ${_this.status}, hasAccess: ${_this.hasAccess}, trialEligible: ${_this.trialEligible}, trialStartedAtMs: ${_this.trialStartedAtMs}, trialEndsAtMs: ${_this.trialEndsAtMs}, serverNowMs: ${_this.serverNowMs}, suggestedTrialEndsAtMs: ${_this.suggestedTrialEndsAtMs})';
}


}

/// @nodoc
abstract mixin class $CenterOnboardingCopyWith<$Res>  {
  factory $CenterOnboardingCopyWith(CenterOnboarding value, $Res Function(CenterOnboarding) _then) = _$CenterOnboardingCopyWithImpl;
@useResult
$Res call({
 bool phoneRequired, String storeId, CenterProfile profile, int step, int revision, bool completed, bool deferred, String status, bool hasAccess, bool trialEligible, int trialStartedAtMs, int trialEndsAtMs, int serverNowMs, int suggestedTrialEndsAtMs
});


$CenterProfileCopyWith<$Res> get profile;

}
/// @nodoc
class _$CenterOnboardingCopyWithImpl<$Res>
    implements $CenterOnboardingCopyWith<$Res> {
  _$CenterOnboardingCopyWithImpl(this._self, this._then);

  final CenterOnboarding _self;
  final $Res Function(CenterOnboarding) _then;

/// Create a copy of CenterOnboarding
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? phoneRequired = null,Object? storeId = null,Object? profile = null,Object? step = null,Object? revision = null,Object? completed = null,Object? deferred = null,Object? status = null,Object? hasAccess = null,Object? trialEligible = null,Object? trialStartedAtMs = null,Object? trialEndsAtMs = null,Object? serverNowMs = null,Object? suggestedTrialEndsAtMs = null,}) {
  return _then(CenterOnboarding(
phoneRequired: null == phoneRequired ? _self.phoneRequired : phoneRequired // ignore: cast_nullable_to_non_nullable
as bool,storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,profile: null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as CenterProfile,step: null == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as int,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,deferred: null == deferred ? _self.deferred : deferred // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,hasAccess: null == hasAccess ? _self.hasAccess : hasAccess // ignore: cast_nullable_to_non_nullable
as bool,trialEligible: null == trialEligible ? _self.trialEligible : trialEligible // ignore: cast_nullable_to_non_nullable
as bool,trialStartedAtMs: null == trialStartedAtMs ? _self.trialStartedAtMs : trialStartedAtMs // ignore: cast_nullable_to_non_nullable
as int,trialEndsAtMs: null == trialEndsAtMs ? _self.trialEndsAtMs : trialEndsAtMs // ignore: cast_nullable_to_non_nullable
as int,serverNowMs: null == serverNowMs ? _self.serverNowMs : serverNowMs // ignore: cast_nullable_to_non_nullable
as int,suggestedTrialEndsAtMs: null == suggestedTrialEndsAtMs ? _self.suggestedTrialEndsAtMs : suggestedTrialEndsAtMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of CenterOnboarding
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CenterProfileCopyWith<$Res> get profile {
  
  return $CenterProfileCopyWith<$Res>(_self.profile, (value) {
    return _then(_self.copyWith(profile: value));
  });
}
}


/// Adds pattern-matching-related methods to [CenterOnboarding].
extension CenterOnboardingPatterns on CenterOnboarding {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CenterOnboarding value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CenterOnboarding() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CenterOnboarding value)  $default,){
final _that = this;
switch (_that) {
case _CenterOnboarding():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CenterOnboarding value)?  $default,){
final _that = this;
switch (_that) {
case _CenterOnboarding() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool phoneRequired,  String storeId,  CenterProfile profile,  int step,  int revision,  bool completed,  bool deferred,  String status,  bool hasAccess,  bool trialEligible,  int trialStartedAtMs,  int trialEndsAtMs,  int serverNowMs,  int suggestedTrialEndsAtMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CenterOnboarding() when $default != null:
return $default(_that.phoneRequired,_that.storeId,_that.profile,_that.step,_that.revision,_that.completed,_that.deferred,_that.status,_that.hasAccess,_that.trialEligible,_that.trialStartedAtMs,_that.trialEndsAtMs,_that.serverNowMs,_that.suggestedTrialEndsAtMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool phoneRequired,  String storeId,  CenterProfile profile,  int step,  int revision,  bool completed,  bool deferred,  String status,  bool hasAccess,  bool trialEligible,  int trialStartedAtMs,  int trialEndsAtMs,  int serverNowMs,  int suggestedTrialEndsAtMs)  $default,) {final _that = this;
switch (_that) {
case _CenterOnboarding():
return $default(_that.phoneRequired,_that.storeId,_that.profile,_that.step,_that.revision,_that.completed,_that.deferred,_that.status,_that.hasAccess,_that.trialEligible,_that.trialStartedAtMs,_that.trialEndsAtMs,_that.serverNowMs,_that.suggestedTrialEndsAtMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool phoneRequired,  String storeId,  CenterProfile profile,  int step,  int revision,  bool completed,  bool deferred,  String status,  bool hasAccess,  bool trialEligible,  int trialStartedAtMs,  int trialEndsAtMs,  int serverNowMs,  int suggestedTrialEndsAtMs)?  $default,) {final _that = this;
switch (_that) {
case _CenterOnboarding() when $default != null:
return $default(_that.phoneRequired,_that.storeId,_that.profile,_that.step,_that.revision,_that.completed,_that.deferred,_that.status,_that.hasAccess,_that.trialEligible,_that.trialStartedAtMs,_that.trialEndsAtMs,_that.serverNowMs,_that.suggestedTrialEndsAtMs);case _:
  return null;

}
}

}

/// @nodoc


class _CenterOnboarding implements CenterOnboarding {
  const _CenterOnboarding({this.phoneRequired = true, this.storeId = '', this.profile = const CenterProfile(), this.step = 0, this.revision = 0, this.completed = false, this.deferred = false, this.status = 'pending_connection', this.hasAccess = false, this.trialEligible = true, this.trialStartedAtMs = 0, this.trialEndsAtMs = 0, this.serverNowMs = 0, this.suggestedTrialEndsAtMs = 0});
  

@override@JsonKey() final  bool phoneRequired;
@override@JsonKey() final  String storeId;
@override@JsonKey() final  CenterProfile profile;
@override@JsonKey() final  int step;
@override@JsonKey() final  int revision;
@override@JsonKey() final  bool completed;
@override@JsonKey() final  bool deferred;
@override@JsonKey() final  String status;
@override@JsonKey() final  bool hasAccess;
@override@JsonKey() final  bool trialEligible;
@override@JsonKey() final  int trialStartedAtMs;
@override@JsonKey() final  int trialEndsAtMs;
@override@JsonKey() final  int serverNowMs;
@override@JsonKey() final  int suggestedTrialEndsAtMs;

/// Create a copy of CenterOnboarding
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CenterOnboardingCopyWith<_CenterOnboarding> get copyWith => __$CenterOnboardingCopyWithImpl<_CenterOnboarding>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CenterOnboarding&&(identical(other.phoneRequired, phoneRequired) || other.phoneRequired == phoneRequired)&&(identical(other.storeId, storeId) || other.storeId == storeId)&&(identical(other.profile, profile) || other.profile == profile)&&(identical(other.step, step) || other.step == step)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.deferred, deferred) || other.deferred == deferred)&&(identical(other.status, status) || other.status == status)&&(identical(other.hasAccess, hasAccess) || other.hasAccess == hasAccess)&&(identical(other.trialEligible, trialEligible) || other.trialEligible == trialEligible)&&(identical(other.trialStartedAtMs, trialStartedAtMs) || other.trialStartedAtMs == trialStartedAtMs)&&(identical(other.trialEndsAtMs, trialEndsAtMs) || other.trialEndsAtMs == trialEndsAtMs)&&(identical(other.serverNowMs, serverNowMs) || other.serverNowMs == serverNowMs)&&(identical(other.suggestedTrialEndsAtMs, suggestedTrialEndsAtMs) || other.suggestedTrialEndsAtMs == suggestedTrialEndsAtMs));
}


@override
int get hashCode {
    return Object.hash(runtimeType,phoneRequired,storeId,profile,step,revision,completed,deferred,status,hasAccess,trialEligible,trialStartedAtMs,trialEndsAtMs,serverNowMs,suggestedTrialEndsAtMs);
}

@override
String toString() {
    return 'CenterOnboarding(phoneRequired: $phoneRequired, storeId: $storeId, profile: $profile, step: $step, revision: $revision, completed: $completed, deferred: $deferred, status: $status, hasAccess: $hasAccess, trialEligible: $trialEligible, trialStartedAtMs: $trialStartedAtMs, trialEndsAtMs: $trialEndsAtMs, serverNowMs: $serverNowMs, suggestedTrialEndsAtMs: $suggestedTrialEndsAtMs)';
}


}

/// @nodoc
abstract mixin class _$CenterOnboardingCopyWith<$Res> implements $CenterOnboardingCopyWith<$Res> {
  factory _$CenterOnboardingCopyWith(_CenterOnboarding value, $Res Function(_CenterOnboarding) _then) = __$CenterOnboardingCopyWithImpl;
@override @useResult
$Res call({
 bool phoneRequired, String storeId, CenterProfile profile, int step, int revision, bool completed, bool deferred, String status, bool hasAccess, bool trialEligible, int trialStartedAtMs, int trialEndsAtMs, int serverNowMs, int suggestedTrialEndsAtMs
});


@override $CenterProfileCopyWith<$Res> get profile;

}
/// @nodoc
class __$CenterOnboardingCopyWithImpl<$Res>
    implements _$CenterOnboardingCopyWith<$Res> {
  __$CenterOnboardingCopyWithImpl(this._self, this._then);

  final _CenterOnboarding _self;
  final $Res Function(_CenterOnboarding) _then;

/// Create a copy of CenterOnboarding
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? phoneRequired = null,Object? storeId = null,Object? profile = null,Object? step = null,Object? revision = null,Object? completed = null,Object? deferred = null,Object? status = null,Object? hasAccess = null,Object? trialEligible = null,Object? trialStartedAtMs = null,Object? trialEndsAtMs = null,Object? serverNowMs = null,Object? suggestedTrialEndsAtMs = null,}) {
  return _then(_CenterOnboarding(
phoneRequired: null == phoneRequired ? _self.phoneRequired : phoneRequired // ignore: cast_nullable_to_non_nullable
as bool,storeId: null == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String,profile: null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as CenterProfile,step: null == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as int,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,deferred: null == deferred ? _self.deferred : deferred // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,hasAccess: null == hasAccess ? _self.hasAccess : hasAccess // ignore: cast_nullable_to_non_nullable
as bool,trialEligible: null == trialEligible ? _self.trialEligible : trialEligible // ignore: cast_nullable_to_non_nullable
as bool,trialStartedAtMs: null == trialStartedAtMs ? _self.trialStartedAtMs : trialStartedAtMs // ignore: cast_nullable_to_non_nullable
as int,trialEndsAtMs: null == trialEndsAtMs ? _self.trialEndsAtMs : trialEndsAtMs // ignore: cast_nullable_to_non_nullable
as int,serverNowMs: null == serverNowMs ? _self.serverNowMs : serverNowMs // ignore: cast_nullable_to_non_nullable
as int,suggestedTrialEndsAtMs: null == suggestedTrialEndsAtMs ? _self.suggestedTrialEndsAtMs : suggestedTrialEndsAtMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of CenterOnboarding
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CenterProfileCopyWith<$Res> get profile {
  
  return $CenterProfileCopyWith<$Res>(_self.profile, (value) {
    return _then(_self.copyWith(profile: value));
  });
}
}

// dart format on
