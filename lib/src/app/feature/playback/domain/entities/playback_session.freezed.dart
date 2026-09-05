// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'playback_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PlaybackSession {

 String get id; String get ownerId; Workout get workout; PlaybackStatus get status; int get stepIndex; int get remainingMs; int get anchorServerMs; int get revision; String get updatedByDeviceId;
/// Create a copy of PlaybackSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaybackSessionCopyWith<PlaybackSession> get copyWith => _$PlaybackSessionCopyWithImpl<PlaybackSession>(this as PlaybackSession, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PlaybackSession;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaybackSession&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.ownerId, _this.ownerId) || other.ownerId == _this.ownerId)&&(identical(other.workout, _this.workout) || other.workout == _this.workout)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.stepIndex, _this.stepIndex) || other.stepIndex == _this.stepIndex)&&(identical(other.remainingMs, _this.remainingMs) || other.remainingMs == _this.remainingMs)&&(identical(other.anchorServerMs, _this.anchorServerMs) || other.anchorServerMs == _this.anchorServerMs)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&(identical(other.updatedByDeviceId, _this.updatedByDeviceId) || other.updatedByDeviceId == _this.updatedByDeviceId));
}


@override
int get hashCode {
  final _this = this as PlaybackSession;
  return Object.hash(runtimeType,_this.id,_this.ownerId,_this.workout,_this.status,_this.stepIndex,_this.remainingMs,_this.anchorServerMs,_this.revision,_this.updatedByDeviceId);
}

@override
String toString() {
  final _this = this as PlaybackSession;
  return 'PlaybackSession(id: ${_this.id}, ownerId: ${_this.ownerId}, workout: ${_this.workout}, status: ${_this.status}, stepIndex: ${_this.stepIndex}, remainingMs: ${_this.remainingMs}, anchorServerMs: ${_this.anchorServerMs}, revision: ${_this.revision}, updatedByDeviceId: ${_this.updatedByDeviceId})';
}


}

/// @nodoc
abstract mixin class $PlaybackSessionCopyWith<$Res>  {
  factory $PlaybackSessionCopyWith(PlaybackSession value, $Res Function(PlaybackSession) _then) = _$PlaybackSessionCopyWithImpl;
@useResult
$Res call({
 String id, String ownerId, Workout workout, PlaybackStatus status, int stepIndex, int remainingMs, int anchorServerMs, int revision, String updatedByDeviceId
});


$WorkoutCopyWith<$Res> get workout;

}
/// @nodoc
class _$PlaybackSessionCopyWithImpl<$Res>
    implements $PlaybackSessionCopyWith<$Res> {
  _$PlaybackSessionCopyWithImpl(this._self, this._then);

  final PlaybackSession _self;
  final $Res Function(PlaybackSession) _then;

/// Create a copy of PlaybackSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ownerId = null,Object? workout = null,Object? status = null,Object? stepIndex = null,Object? remainingMs = null,Object? anchorServerMs = null,Object? revision = null,Object? updatedByDeviceId = null,}) {
  return _then(PlaybackSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,workout: null == workout ? _self.workout : workout // ignore: cast_nullable_to_non_nullable
as Workout,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PlaybackStatus,stepIndex: null == stepIndex ? _self.stepIndex : stepIndex // ignore: cast_nullable_to_non_nullable
as int,remainingMs: null == remainingMs ? _self.remainingMs : remainingMs // ignore: cast_nullable_to_non_nullable
as int,anchorServerMs: null == anchorServerMs ? _self.anchorServerMs : anchorServerMs // ignore: cast_nullable_to_non_nullable
as int,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,updatedByDeviceId: null == updatedByDeviceId ? _self.updatedByDeviceId : updatedByDeviceId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of PlaybackSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutCopyWith<$Res> get workout {
  
  return $WorkoutCopyWith<$Res>(_self.workout, (value) {
    return _then(_self.copyWith(workout: value));
  });
}
}


/// Adds pattern-matching-related methods to [PlaybackSession].
extension PlaybackSessionPatterns on PlaybackSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlaybackSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlaybackSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlaybackSession value)  $default,){
final _that = this;
switch (_that) {
case _PlaybackSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlaybackSession value)?  $default,){
final _that = this;
switch (_that) {
case _PlaybackSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String ownerId,  Workout workout,  PlaybackStatus status,  int stepIndex,  int remainingMs,  int anchorServerMs,  int revision,  String updatedByDeviceId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlaybackSession() when $default != null:
return $default(_that.id,_that.ownerId,_that.workout,_that.status,_that.stepIndex,_that.remainingMs,_that.anchorServerMs,_that.revision,_that.updatedByDeviceId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String ownerId,  Workout workout,  PlaybackStatus status,  int stepIndex,  int remainingMs,  int anchorServerMs,  int revision,  String updatedByDeviceId)  $default,) {final _that = this;
switch (_that) {
case _PlaybackSession():
return $default(_that.id,_that.ownerId,_that.workout,_that.status,_that.stepIndex,_that.remainingMs,_that.anchorServerMs,_that.revision,_that.updatedByDeviceId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String ownerId,  Workout workout,  PlaybackStatus status,  int stepIndex,  int remainingMs,  int anchorServerMs,  int revision,  String updatedByDeviceId)?  $default,) {final _that = this;
switch (_that) {
case _PlaybackSession() when $default != null:
return $default(_that.id,_that.ownerId,_that.workout,_that.status,_that.stepIndex,_that.remainingMs,_that.anchorServerMs,_that.revision,_that.updatedByDeviceId);case _:
  return null;

}
}

}

/// @nodoc


class _PlaybackSession implements PlaybackSession {
  const _PlaybackSession({required this.id, required this.ownerId, required this.workout, required this.status, required this.stepIndex, required this.remainingMs, required this.anchorServerMs, required this.revision, required this.updatedByDeviceId});
  

@override final  String id;
@override final  String ownerId;
@override final  Workout workout;
@override final  PlaybackStatus status;
@override final  int stepIndex;
@override final  int remainingMs;
@override final  int anchorServerMs;
@override final  int revision;
@override final  String updatedByDeviceId;

/// Create a copy of PlaybackSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlaybackSessionCopyWith<_PlaybackSession> get copyWith => __$PlaybackSessionCopyWithImpl<_PlaybackSession>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlaybackSession&&(identical(other.id, id) || other.id == id)&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId)&&(identical(other.workout, workout) || other.workout == workout)&&(identical(other.status, status) || other.status == status)&&(identical(other.stepIndex, stepIndex) || other.stepIndex == stepIndex)&&(identical(other.remainingMs, remainingMs) || other.remainingMs == remainingMs)&&(identical(other.anchorServerMs, anchorServerMs) || other.anchorServerMs == anchorServerMs)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.updatedByDeviceId, updatedByDeviceId) || other.updatedByDeviceId == updatedByDeviceId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,ownerId,workout,status,stepIndex,remainingMs,anchorServerMs,revision,updatedByDeviceId);
}

@override
String toString() {
    return 'PlaybackSession(id: $id, ownerId: $ownerId, workout: $workout, status: $status, stepIndex: $stepIndex, remainingMs: $remainingMs, anchorServerMs: $anchorServerMs, revision: $revision, updatedByDeviceId: $updatedByDeviceId)';
}


}

/// @nodoc
abstract mixin class _$PlaybackSessionCopyWith<$Res> implements $PlaybackSessionCopyWith<$Res> {
  factory _$PlaybackSessionCopyWith(_PlaybackSession value, $Res Function(_PlaybackSession) _then) = __$PlaybackSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, String ownerId, Workout workout, PlaybackStatus status, int stepIndex, int remainingMs, int anchorServerMs, int revision, String updatedByDeviceId
});


@override $WorkoutCopyWith<$Res> get workout;

}
/// @nodoc
class __$PlaybackSessionCopyWithImpl<$Res>
    implements _$PlaybackSessionCopyWith<$Res> {
  __$PlaybackSessionCopyWithImpl(this._self, this._then);

  final _PlaybackSession _self;
  final $Res Function(_PlaybackSession) _then;

/// Create a copy of PlaybackSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ownerId = null,Object? workout = null,Object? status = null,Object? stepIndex = null,Object? remainingMs = null,Object? anchorServerMs = null,Object? revision = null,Object? updatedByDeviceId = null,}) {
  return _then(_PlaybackSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,workout: null == workout ? _self.workout : workout // ignore: cast_nullable_to_non_nullable
as Workout,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PlaybackStatus,stepIndex: null == stepIndex ? _self.stepIndex : stepIndex // ignore: cast_nullable_to_non_nullable
as int,remainingMs: null == remainingMs ? _self.remainingMs : remainingMs // ignore: cast_nullable_to_non_nullable
as int,anchorServerMs: null == anchorServerMs ? _self.anchorServerMs : anchorServerMs // ignore: cast_nullable_to_non_nullable
as int,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,updatedByDeviceId: null == updatedByDeviceId ? _self.updatedByDeviceId : updatedByDeviceId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of PlaybackSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutCopyWith<$Res> get workout {
  
  return $WorkoutCopyWith<$Res>(_self.workout, (value) {
    return _then(_self.copyWith(workout: value));
  });
}
}

// dart format on
