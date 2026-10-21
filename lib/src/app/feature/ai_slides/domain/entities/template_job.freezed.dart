// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'template_job.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TemplateJob {

 String get requestId; String get status; String get title; String get subtitle; String get rawWod; String get designId; String get designName; int get createdAtMs; int get updatedAtMs; String? get sha256; String? get message; bool get retryable;
/// Create a copy of TemplateJob
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TemplateJobCopyWith<TemplateJob> get copyWith => _$TemplateJobCopyWithImpl<TemplateJob>(this as TemplateJob, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as TemplateJob;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TemplateJob&&(identical(other.requestId, _this.requestId) || other.requestId == _this.requestId)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.subtitle, _this.subtitle) || other.subtitle == _this.subtitle)&&(identical(other.rawWod, _this.rawWod) || other.rawWod == _this.rawWod)&&(identical(other.designId, _this.designId) || other.designId == _this.designId)&&(identical(other.designName, _this.designName) || other.designName == _this.designName)&&(identical(other.createdAtMs, _this.createdAtMs) || other.createdAtMs == _this.createdAtMs)&&(identical(other.updatedAtMs, _this.updatedAtMs) || other.updatedAtMs == _this.updatedAtMs)&&(identical(other.sha256, _this.sha256) || other.sha256 == _this.sha256)&&(identical(other.message, _this.message) || other.message == _this.message)&&(identical(other.retryable, _this.retryable) || other.retryable == _this.retryable));
}


@override
int get hashCode {
  final _this = this as TemplateJob;
  return Object.hash(runtimeType,_this.requestId,_this.status,_this.title,_this.subtitle,_this.rawWod,_this.designId,_this.designName,_this.createdAtMs,_this.updatedAtMs,_this.sha256,_this.message,_this.retryable);
}

@override
String toString() {
  final _this = this as TemplateJob;
  return 'TemplateJob(requestId: ${_this.requestId}, status: ${_this.status}, title: ${_this.title}, subtitle: ${_this.subtitle}, rawWod: ${_this.rawWod}, designId: ${_this.designId}, designName: ${_this.designName}, createdAtMs: ${_this.createdAtMs}, updatedAtMs: ${_this.updatedAtMs}, sha256: ${_this.sha256}, message: ${_this.message}, retryable: ${_this.retryable})';
}


}

/// @nodoc
abstract mixin class $TemplateJobCopyWith<$Res>  {
  factory $TemplateJobCopyWith(TemplateJob value, $Res Function(TemplateJob) _then) = _$TemplateJobCopyWithImpl;
@useResult
$Res call({
 String requestId, String status, String title, String subtitle, String rawWod, String designId, String designName, int createdAtMs, int updatedAtMs, String? sha256, String? message, bool retryable
});




}
/// @nodoc
class _$TemplateJobCopyWithImpl<$Res>
    implements $TemplateJobCopyWith<$Res> {
  _$TemplateJobCopyWithImpl(this._self, this._then);

  final TemplateJob _self;
  final $Res Function(TemplateJob) _then;

/// Create a copy of TemplateJob
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? requestId = null,Object? status = null,Object? title = null,Object? subtitle = null,Object? rawWod = null,Object? designId = null,Object? designName = null,Object? createdAtMs = null,Object? updatedAtMs = null,Object? sha256 = freezed,Object? message = freezed,Object? retryable = null,}) {
  return _then(TemplateJob(
requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,subtitle: null == subtitle ? _self.subtitle : subtitle // ignore: cast_nullable_to_non_nullable
as String,rawWod: null == rawWod ? _self.rawWod : rawWod // ignore: cast_nullable_to_non_nullable
as String,designId: null == designId ? _self.designId : designId // ignore: cast_nullable_to_non_nullable
as String,designName: null == designName ? _self.designName : designName // ignore: cast_nullable_to_non_nullable
as String,createdAtMs: null == createdAtMs ? _self.createdAtMs : createdAtMs // ignore: cast_nullable_to_non_nullable
as int,updatedAtMs: null == updatedAtMs ? _self.updatedAtMs : updatedAtMs // ignore: cast_nullable_to_non_nullable
as int,sha256: freezed == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,retryable: null == retryable ? _self.retryable : retryable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TemplateJob].
extension TemplateJobPatterns on TemplateJob {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TemplateJob value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TemplateJob() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TemplateJob value)  $default,){
final _that = this;
switch (_that) {
case _TemplateJob():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TemplateJob value)?  $default,){
final _that = this;
switch (_that) {
case _TemplateJob() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String requestId,  String status,  String title,  String subtitle,  String rawWod,  String designId,  String designName,  int createdAtMs,  int updatedAtMs,  String? sha256,  String? message,  bool retryable)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TemplateJob() when $default != null:
return $default(_that.requestId,_that.status,_that.title,_that.subtitle,_that.rawWod,_that.designId,_that.designName,_that.createdAtMs,_that.updatedAtMs,_that.sha256,_that.message,_that.retryable);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String requestId,  String status,  String title,  String subtitle,  String rawWod,  String designId,  String designName,  int createdAtMs,  int updatedAtMs,  String? sha256,  String? message,  bool retryable)  $default,) {final _that = this;
switch (_that) {
case _TemplateJob():
return $default(_that.requestId,_that.status,_that.title,_that.subtitle,_that.rawWod,_that.designId,_that.designName,_that.createdAtMs,_that.updatedAtMs,_that.sha256,_that.message,_that.retryable);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String requestId,  String status,  String title,  String subtitle,  String rawWod,  String designId,  String designName,  int createdAtMs,  int updatedAtMs,  String? sha256,  String? message,  bool retryable)?  $default,) {final _that = this;
switch (_that) {
case _TemplateJob() when $default != null:
return $default(_that.requestId,_that.status,_that.title,_that.subtitle,_that.rawWod,_that.designId,_that.designName,_that.createdAtMs,_that.updatedAtMs,_that.sha256,_that.message,_that.retryable);case _:
  return null;

}
}

}

/// @nodoc


class _TemplateJob extends TemplateJob {
  const _TemplateJob({required this.requestId, required this.status, required this.title, required this.subtitle, required this.rawWod, required this.designId, required this.designName, required this.createdAtMs, required this.updatedAtMs, this.sha256, this.message, this.retryable = false}): super._();


@override final  String requestId;
@override final  String status;
@override final  String title;
@override final  String subtitle;
@override final  String rawWod;
@override final  String designId;
@override final  String designName;
@override final  int createdAtMs;
@override final  int updatedAtMs;
@override final  String? sha256;
@override final  String? message;
@override@JsonKey() final  bool retryable;

/// Create a copy of TemplateJob
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TemplateJobCopyWith<_TemplateJob> get copyWith => __$TemplateJobCopyWithImpl<_TemplateJob>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TemplateJob&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.status, status) || other.status == status)&&(identical(other.title, title) || other.title == title)&&(identical(other.subtitle, subtitle) || other.subtitle == subtitle)&&(identical(other.rawWod, rawWod) || other.rawWod == rawWod)&&(identical(other.designId, designId) || other.designId == designId)&&(identical(other.designName, designName) || other.designName == designName)&&(identical(other.createdAtMs, createdAtMs) || other.createdAtMs == createdAtMs)&&(identical(other.updatedAtMs, updatedAtMs) || other.updatedAtMs == updatedAtMs)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.message, message) || other.message == message)&&(identical(other.retryable, retryable) || other.retryable == retryable));
}


@override
int get hashCode {
    return Object.hash(runtimeType,requestId,status,title,subtitle,rawWod,designId,designName,createdAtMs,updatedAtMs,sha256,message,retryable);
}

@override
String toString() {
    return 'TemplateJob(requestId: $requestId, status: $status, title: $title, subtitle: $subtitle, rawWod: $rawWod, designId: $designId, designName: $designName, createdAtMs: $createdAtMs, updatedAtMs: $updatedAtMs, sha256: $sha256, message: $message, retryable: $retryable)';
}


}

/// @nodoc
abstract mixin class _$TemplateJobCopyWith<$Res> implements $TemplateJobCopyWith<$Res> {
  factory _$TemplateJobCopyWith(_TemplateJob value, $Res Function(_TemplateJob) _then) = __$TemplateJobCopyWithImpl;
@override @useResult
$Res call({
 String requestId, String status, String title, String subtitle, String rawWod, String designId, String designName, int createdAtMs, int updatedAtMs, String? sha256, String? message, bool retryable
});




}
/// @nodoc
class __$TemplateJobCopyWithImpl<$Res>
    implements _$TemplateJobCopyWith<$Res> {
  __$TemplateJobCopyWithImpl(this._self, this._then);

  final _TemplateJob _self;
  final $Res Function(_TemplateJob) _then;

/// Create a copy of TemplateJob
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? requestId = null,Object? status = null,Object? title = null,Object? subtitle = null,Object? rawWod = null,Object? designId = null,Object? designName = null,Object? createdAtMs = null,Object? updatedAtMs = null,Object? sha256 = freezed,Object? message = freezed,Object? retryable = null,}) {
  return _then(_TemplateJob(
requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,subtitle: null == subtitle ? _self.subtitle : subtitle // ignore: cast_nullable_to_non_nullable
as String,rawWod: null == rawWod ? _self.rawWod : rawWod // ignore: cast_nullable_to_non_nullable
as String,designId: null == designId ? _self.designId : designId // ignore: cast_nullable_to_non_nullable
as String,designName: null == designName ? _self.designName : designName // ignore: cast_nullable_to_non_nullable
as String,createdAtMs: null == createdAtMs ? _self.createdAtMs : createdAtMs // ignore: cast_nullable_to_non_nullable
as int,updatedAtMs: null == updatedAtMs ? _self.updatedAtMs : updatedAtMs // ignore: cast_nullable_to_non_nullable
as int,sha256: freezed == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,retryable: null == retryable ? _self.retryable : retryable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$TemplateJobsState {

 List<TemplateJob> get jobs; bool get loading; bool get submitting; bool get unresolved; bool get opening; bool get authorityDenied; StudioUsage? get usage; String? get nextCursor; bool get loadingMore; StudioInput? get acceptedInput; String? get error; String? get currentRequestId; Uint8List? get currentPng; bool? get currentAssetLoading; String? get currentAssetError; bool? get recoveryChecked;
/// Create a copy of TemplateJobsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TemplateJobsStateCopyWith<TemplateJobsState> get copyWith => _$TemplateJobsStateCopyWithImpl<TemplateJobsState>(this as TemplateJobsState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as TemplateJobsState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TemplateJobsState&&const DeepCollectionEquality().equals(other.jobs, _this.jobs)&&(identical(other.loading, _this.loading) || other.loading == _this.loading)&&(identical(other.submitting, _this.submitting) || other.submitting == _this.submitting)&&(identical(other.unresolved, _this.unresolved) || other.unresolved == _this.unresolved)&&(identical(other.opening, _this.opening) || other.opening == _this.opening)&&(identical(other.authorityDenied, _this.authorityDenied) || other.authorityDenied == _this.authorityDenied)&&(identical(other.usage, _this.usage) || other.usage == _this.usage)&&(identical(other.nextCursor, _this.nextCursor) || other.nextCursor == _this.nextCursor)&&(identical(other.loadingMore, _this.loadingMore) || other.loadingMore == _this.loadingMore)&&(identical(other.acceptedInput, _this.acceptedInput) || other.acceptedInput == _this.acceptedInput)&&(identical(other.error, _this.error) || other.error == _this.error)&&(identical(other.currentRequestId, _this.currentRequestId) || other.currentRequestId == _this.currentRequestId)&&const DeepCollectionEquality().equals(other.currentPng, _this.currentPng)&&(identical(other.currentAssetLoading, _this.currentAssetLoading) || other.currentAssetLoading == _this.currentAssetLoading)&&(identical(other.currentAssetError, _this.currentAssetError) || other.currentAssetError == _this.currentAssetError)&&(identical(other.recoveryChecked, _this.recoveryChecked) || other.recoveryChecked == _this.recoveryChecked));
}


@override
int get hashCode {
  final _this = this as TemplateJobsState;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.jobs),_this.loading,_this.submitting,_this.unresolved,_this.opening,_this.authorityDenied,_this.usage,_this.nextCursor,_this.loadingMore,_this.acceptedInput,_this.error,_this.currentRequestId,const DeepCollectionEquality().hash(_this.currentPng),_this.currentAssetLoading,_this.currentAssetError,_this.recoveryChecked);
}

@override
String toString() {
  final _this = this as TemplateJobsState;
  return 'TemplateJobsState(jobs: ${_this.jobs}, loading: ${_this.loading}, submitting: ${_this.submitting}, unresolved: ${_this.unresolved}, opening: ${_this.opening}, authorityDenied: ${_this.authorityDenied}, usage: ${_this.usage}, nextCursor: ${_this.nextCursor}, loadingMore: ${_this.loadingMore}, acceptedInput: ${_this.acceptedInput}, error: ${_this.error}, currentRequestId: ${_this.currentRequestId}, currentPng: ${_this.currentPng}, currentAssetLoading: ${_this.currentAssetLoading}, currentAssetError: ${_this.currentAssetError}, recoveryChecked: ${_this.recoveryChecked})';
}


}

/// @nodoc
abstract mixin class $TemplateJobsStateCopyWith<$Res>  {
  factory $TemplateJobsStateCopyWith(TemplateJobsState value, $Res Function(TemplateJobsState) _then) = _$TemplateJobsStateCopyWithImpl;
@useResult
$Res call({
 List<TemplateJob> jobs, bool loading, bool submitting, bool unresolved, bool opening, bool authorityDenied, StudioUsage? usage, String? nextCursor, bool loadingMore, StudioInput? acceptedInput, String? error, String? currentRequestId, Uint8List? currentPng, bool? currentAssetLoading, String? currentAssetError, bool? recoveryChecked
});


$StudioUsageCopyWith<$Res>? get usage;$StudioInputCopyWith<$Res>? get acceptedInput;

}
/// @nodoc
class _$TemplateJobsStateCopyWithImpl<$Res>
    implements $TemplateJobsStateCopyWith<$Res> {
  _$TemplateJobsStateCopyWithImpl(this._self, this._then);

  final TemplateJobsState _self;
  final $Res Function(TemplateJobsState) _then;

/// Create a copy of TemplateJobsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? jobs = null,Object? loading = null,Object? submitting = null,Object? unresolved = null,Object? opening = null,Object? authorityDenied = null,Object? usage = freezed,Object? nextCursor = freezed,Object? loadingMore = null,Object? acceptedInput = freezed,Object? error = freezed,Object? currentRequestId = freezed,Object? currentPng = freezed,Object? currentAssetLoading = freezed,Object? currentAssetError = freezed,Object? recoveryChecked = freezed,}) {
  return _then(TemplateJobsState(
jobs: null == jobs ? _self.jobs : jobs // ignore: cast_nullable_to_non_nullable
as List<TemplateJob>,loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,submitting: null == submitting ? _self.submitting : submitting // ignore: cast_nullable_to_non_nullable
as bool,unresolved: null == unresolved ? _self.unresolved : unresolved // ignore: cast_nullable_to_non_nullable
as bool,opening: null == opening ? _self.opening : opening // ignore: cast_nullable_to_non_nullable
as bool,authorityDenied: null == authorityDenied ? _self.authorityDenied : authorityDenied // ignore: cast_nullable_to_non_nullable
as bool,usage: freezed == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as StudioUsage?,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,acceptedInput: freezed == acceptedInput ? _self.acceptedInput : acceptedInput // ignore: cast_nullable_to_non_nullable
as StudioInput?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,currentRequestId: freezed == currentRequestId ? _self.currentRequestId : currentRequestId // ignore: cast_nullable_to_non_nullable
as String?,currentPng: freezed == currentPng ? _self.currentPng : currentPng // ignore: cast_nullable_to_non_nullable
as Uint8List?,currentAssetLoading: freezed == currentAssetLoading ? _self.currentAssetLoading : currentAssetLoading // ignore: cast_nullable_to_non_nullable
as bool?,currentAssetError: freezed == currentAssetError ? _self.currentAssetError : currentAssetError // ignore: cast_nullable_to_non_nullable
as String?,recoveryChecked: freezed == recoveryChecked ? _self.recoveryChecked : recoveryChecked // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}
/// Create a copy of TemplateJobsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioUsageCopyWith<$Res>? get usage {
    if (_self.usage == null) {
    return null;
  }

  return $StudioUsageCopyWith<$Res>(_self.usage!, (value) {
    return _then(_self.copyWith(usage: value));
  });
}/// Create a copy of TemplateJobsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioInputCopyWith<$Res>? get acceptedInput {
    if (_self.acceptedInput == null) {
    return null;
  }

  return $StudioInputCopyWith<$Res>(_self.acceptedInput!, (value) {
    return _then(_self.copyWith(acceptedInput: value));
  });
}
}


/// Adds pattern-matching-related methods to [TemplateJobsState].
extension TemplateJobsStatePatterns on TemplateJobsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TemplateJobsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TemplateJobsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TemplateJobsState value)  $default,){
final _that = this;
switch (_that) {
case _TemplateJobsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TemplateJobsState value)?  $default,){
final _that = this;
switch (_that) {
case _TemplateJobsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<TemplateJob> jobs,  bool loading,  bool submitting,  bool unresolved,  bool opening,  bool authorityDenied,  StudioUsage? usage,  String? nextCursor,  bool loadingMore,  StudioInput? acceptedInput,  String? error,  String? currentRequestId,  Uint8List? currentPng,  bool? currentAssetLoading,  String? currentAssetError,  bool? recoveryChecked)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TemplateJobsState() when $default != null:
return $default(_that.jobs,_that.loading,_that.submitting,_that.unresolved,_that.opening,_that.authorityDenied,_that.usage,_that.nextCursor,_that.loadingMore,_that.acceptedInput,_that.error,_that.currentRequestId,_that.currentPng,_that.currentAssetLoading,_that.currentAssetError,_that.recoveryChecked);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<TemplateJob> jobs,  bool loading,  bool submitting,  bool unresolved,  bool opening,  bool authorityDenied,  StudioUsage? usage,  String? nextCursor,  bool loadingMore,  StudioInput? acceptedInput,  String? error,  String? currentRequestId,  Uint8List? currentPng,  bool? currentAssetLoading,  String? currentAssetError,  bool? recoveryChecked)  $default,) {final _that = this;
switch (_that) {
case _TemplateJobsState():
return $default(_that.jobs,_that.loading,_that.submitting,_that.unresolved,_that.opening,_that.authorityDenied,_that.usage,_that.nextCursor,_that.loadingMore,_that.acceptedInput,_that.error,_that.currentRequestId,_that.currentPng,_that.currentAssetLoading,_that.currentAssetError,_that.recoveryChecked);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<TemplateJob> jobs,  bool loading,  bool submitting,  bool unresolved,  bool opening,  bool authorityDenied,  StudioUsage? usage,  String? nextCursor,  bool loadingMore,  StudioInput? acceptedInput,  String? error,  String? currentRequestId,  Uint8List? currentPng,  bool? currentAssetLoading,  String? currentAssetError,  bool? recoveryChecked)?  $default,) {final _that = this;
switch (_that) {
case _TemplateJobsState() when $default != null:
return $default(_that.jobs,_that.loading,_that.submitting,_that.unresolved,_that.opening,_that.authorityDenied,_that.usage,_that.nextCursor,_that.loadingMore,_that.acceptedInput,_that.error,_that.currentRequestId,_that.currentPng,_that.currentAssetLoading,_that.currentAssetError,_that.recoveryChecked);case _:
  return null;

}
}

}

/// @nodoc


class _TemplateJobsState implements TemplateJobsState {
  const _TemplateJobsState({ List<TemplateJob> jobs = const [], this.loading = true, this.submitting = false, this.unresolved = false, this.opening = false, this.authorityDenied = false, this.usage, this.nextCursor, this.loadingMore = false, this.acceptedInput, this.error, this.currentRequestId, this.currentPng, this.currentAssetLoading, this.currentAssetError, this.recoveryChecked}): _jobs = jobs;


 final  List<TemplateJob> _jobs;
@override@JsonKey() List<TemplateJob> get jobs {
  if (_jobs is EqualUnmodifiableListView) return _jobs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_jobs);
}

@override@JsonKey() final  bool loading;
@override@JsonKey() final  bool submitting;
@override@JsonKey() final  bool unresolved;
@override@JsonKey() final  bool opening;
@override@JsonKey() final  bool authorityDenied;
@override final  StudioUsage? usage;
@override final  String? nextCursor;
@override@JsonKey() final  bool loadingMore;
@override final  StudioInput? acceptedInput;
@override final  String? error;
@override final  String? currentRequestId;
@override final  Uint8List? currentPng;
@override final  bool? currentAssetLoading;
@override final  String? currentAssetError;
@override final  bool? recoveryChecked;

/// Create a copy of TemplateJobsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TemplateJobsStateCopyWith<_TemplateJobsState> get copyWith => __$TemplateJobsStateCopyWithImpl<_TemplateJobsState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TemplateJobsState&&const DeepCollectionEquality().equals(other.jobs, _jobs)&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.submitting, submitting) || other.submitting == submitting)&&(identical(other.unresolved, unresolved) || other.unresolved == unresolved)&&(identical(other.opening, opening) || other.opening == opening)&&(identical(other.authorityDenied, authorityDenied) || other.authorityDenied == authorityDenied)&&(identical(other.usage, usage) || other.usage == usage)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&(identical(other.acceptedInput, acceptedInput) || other.acceptedInput == acceptedInput)&&(identical(other.error, error) || other.error == error)&&(identical(other.currentRequestId, currentRequestId) || other.currentRequestId == currentRequestId)&&const DeepCollectionEquality().equals(other.currentPng, currentPng)&&(identical(other.currentAssetLoading, currentAssetLoading) || other.currentAssetLoading == currentAssetLoading)&&(identical(other.currentAssetError, currentAssetError) || other.currentAssetError == currentAssetError)&&(identical(other.recoveryChecked, recoveryChecked) || other.recoveryChecked == recoveryChecked));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_jobs),loading,submitting,unresolved,opening,authorityDenied,usage,nextCursor,loadingMore,acceptedInput,error,currentRequestId,const DeepCollectionEquality().hash(currentPng),currentAssetLoading,currentAssetError,recoveryChecked);
}

@override
String toString() {
    return 'TemplateJobsState(jobs: $jobs, loading: $loading, submitting: $submitting, unresolved: $unresolved, opening: $opening, authorityDenied: $authorityDenied, usage: $usage, nextCursor: $nextCursor, loadingMore: $loadingMore, acceptedInput: $acceptedInput, error: $error, currentRequestId: $currentRequestId, currentPng: $currentPng, currentAssetLoading: $currentAssetLoading, currentAssetError: $currentAssetError, recoveryChecked: $recoveryChecked)';
}


}

/// @nodoc
abstract mixin class _$TemplateJobsStateCopyWith<$Res> implements $TemplateJobsStateCopyWith<$Res> {
  factory _$TemplateJobsStateCopyWith(_TemplateJobsState value, $Res Function(_TemplateJobsState) _then) = __$TemplateJobsStateCopyWithImpl;
@override @useResult
$Res call({
 List<TemplateJob> jobs, bool loading, bool submitting, bool unresolved, bool opening, bool authorityDenied, StudioUsage? usage, String? nextCursor, bool loadingMore, StudioInput? acceptedInput, String? error, String? currentRequestId, Uint8List? currentPng, bool? currentAssetLoading, String? currentAssetError, bool? recoveryChecked
});


@override $StudioUsageCopyWith<$Res>? get usage;@override $StudioInputCopyWith<$Res>? get acceptedInput;

}
/// @nodoc
class __$TemplateJobsStateCopyWithImpl<$Res>
    implements _$TemplateJobsStateCopyWith<$Res> {
  __$TemplateJobsStateCopyWithImpl(this._self, this._then);

  final _TemplateJobsState _self;
  final $Res Function(_TemplateJobsState) _then;

/// Create a copy of TemplateJobsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? jobs = null,Object? loading = null,Object? submitting = null,Object? unresolved = null,Object? opening = null,Object? authorityDenied = null,Object? usage = freezed,Object? nextCursor = freezed,Object? loadingMore = null,Object? acceptedInput = freezed,Object? error = freezed,Object? currentRequestId = freezed,Object? currentPng = freezed,Object? currentAssetLoading = freezed,Object? currentAssetError = freezed,Object? recoveryChecked = freezed,}) {
  return _then(_TemplateJobsState(
jobs: null == jobs ? _self._jobs : jobs // ignore: cast_nullable_to_non_nullable
as List<TemplateJob>,loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,submitting: null == submitting ? _self.submitting : submitting // ignore: cast_nullable_to_non_nullable
as bool,unresolved: null == unresolved ? _self.unresolved : unresolved // ignore: cast_nullable_to_non_nullable
as bool,opening: null == opening ? _self.opening : opening // ignore: cast_nullable_to_non_nullable
as bool,authorityDenied: null == authorityDenied ? _self.authorityDenied : authorityDenied // ignore: cast_nullable_to_non_nullable
as bool,usage: freezed == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as StudioUsage?,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,acceptedInput: freezed == acceptedInput ? _self.acceptedInput : acceptedInput // ignore: cast_nullable_to_non_nullable
as StudioInput?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,currentRequestId: freezed == currentRequestId ? _self.currentRequestId : currentRequestId // ignore: cast_nullable_to_non_nullable
as String?,currentPng: freezed == currentPng ? _self.currentPng : currentPng // ignore: cast_nullable_to_non_nullable
as Uint8List?,currentAssetLoading: freezed == currentAssetLoading ? _self.currentAssetLoading : currentAssetLoading // ignore: cast_nullable_to_non_nullable
as bool?,currentAssetError: freezed == currentAssetError ? _self.currentAssetError : currentAssetError // ignore: cast_nullable_to_non_nullable
as String?,recoveryChecked: freezed == recoveryChecked ? _self.recoveryChecked : recoveryChecked // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

/// Create a copy of TemplateJobsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioUsageCopyWith<$Res>? get usage {
    if (_self.usage == null) {
    return null;
  }

  return $StudioUsageCopyWith<$Res>(_self.usage!, (value) {
    return _then(_self.copyWith(usage: value));
  });
}/// Create a copy of TemplateJobsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioInputCopyWith<$Res>? get acceptedInput {
    if (_self.acceptedInput == null) {
    return null;
  }

  return $StudioInputCopyWith<$Res>(_self.acceptedInput!, (value) {
    return _then(_self.copyWith(acceptedInput: value));
  });
}
}

// dart format on
