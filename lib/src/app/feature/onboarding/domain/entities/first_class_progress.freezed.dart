// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'first_class_progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FirstClassProgress {

 String get sessionId; bool get dismissed; bool get centerReady; String? get savedWorkoutId; String? get verifiedDeviceId; String? get playedSessionId; List<String> get events;
/// Create a copy of FirstClassProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FirstClassProgressCopyWith<FirstClassProgress> get copyWith => _$FirstClassProgressCopyWithImpl<FirstClassProgress>(this as FirstClassProgress, _$identity);

  /// Serializes this FirstClassProgress to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FirstClassProgress;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FirstClassProgress&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.dismissed, _this.dismissed) || other.dismissed == _this.dismissed)&&(identical(other.centerReady, _this.centerReady) || other.centerReady == _this.centerReady)&&(identical(other.savedWorkoutId, _this.savedWorkoutId) || other.savedWorkoutId == _this.savedWorkoutId)&&(identical(other.verifiedDeviceId, _this.verifiedDeviceId) || other.verifiedDeviceId == _this.verifiedDeviceId)&&(identical(other.playedSessionId, _this.playedSessionId) || other.playedSessionId == _this.playedSessionId)&&const DeepCollectionEquality().equals(other.events, _this.events));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FirstClassProgress;
  return Object.hash(runtimeType,_this.sessionId,_this.dismissed,_this.centerReady,_this.savedWorkoutId,_this.verifiedDeviceId,_this.playedSessionId,const DeepCollectionEquality().hash(_this.events));
}

@override
String toString() {
  final _this = this as FirstClassProgress;
  return 'FirstClassProgress(sessionId: ${_this.sessionId}, dismissed: ${_this.dismissed}, centerReady: ${_this.centerReady}, savedWorkoutId: ${_this.savedWorkoutId}, verifiedDeviceId: ${_this.verifiedDeviceId}, playedSessionId: ${_this.playedSessionId}, events: ${_this.events})';
}


}

/// @nodoc
abstract mixin class $FirstClassProgressCopyWith<$Res>  {
  factory $FirstClassProgressCopyWith(FirstClassProgress value, $Res Function(FirstClassProgress) _then) = _$FirstClassProgressCopyWithImpl;
@useResult
$Res call({
 String sessionId, bool dismissed, bool centerReady, String? savedWorkoutId, String? verifiedDeviceId, String? playedSessionId, List<String> events
});




}
/// @nodoc
class _$FirstClassProgressCopyWithImpl<$Res>
    implements $FirstClassProgressCopyWith<$Res> {
  _$FirstClassProgressCopyWithImpl(this._self, this._then);

  final FirstClassProgress _self;
  final $Res Function(FirstClassProgress) _then;

/// Create a copy of FirstClassProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? dismissed = null,Object? centerReady = null,Object? savedWorkoutId = freezed,Object? verifiedDeviceId = freezed,Object? playedSessionId = freezed,Object? events = null,}) {
  return _then(FirstClassProgress(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,dismissed: null == dismissed ? _self.dismissed : dismissed // ignore: cast_nullable_to_non_nullable
as bool,centerReady: null == centerReady ? _self.centerReady : centerReady // ignore: cast_nullable_to_non_nullable
as bool,savedWorkoutId: freezed == savedWorkoutId ? _self.savedWorkoutId : savedWorkoutId // ignore: cast_nullable_to_non_nullable
as String?,verifiedDeviceId: freezed == verifiedDeviceId ? _self.verifiedDeviceId : verifiedDeviceId // ignore: cast_nullable_to_non_nullable
as String?,playedSessionId: freezed == playedSessionId ? _self.playedSessionId : playedSessionId // ignore: cast_nullable_to_non_nullable
as String?,events: null == events ? _self.events : events // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [FirstClassProgress].
extension FirstClassProgressPatterns on FirstClassProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FirstClassProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FirstClassProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FirstClassProgress value)  $default,){
final _that = this;
switch (_that) {
case _FirstClassProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FirstClassProgress value)?  $default,){
final _that = this;
switch (_that) {
case _FirstClassProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionId,  bool dismissed,  bool centerReady,  String? savedWorkoutId,  String? verifiedDeviceId,  String? playedSessionId,  List<String> events)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FirstClassProgress() when $default != null:
return $default(_that.sessionId,_that.dismissed,_that.centerReady,_that.savedWorkoutId,_that.verifiedDeviceId,_that.playedSessionId,_that.events);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionId,  bool dismissed,  bool centerReady,  String? savedWorkoutId,  String? verifiedDeviceId,  String? playedSessionId,  List<String> events)  $default,) {final _that = this;
switch (_that) {
case _FirstClassProgress():
return $default(_that.sessionId,_that.dismissed,_that.centerReady,_that.savedWorkoutId,_that.verifiedDeviceId,_that.playedSessionId,_that.events);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionId,  bool dismissed,  bool centerReady,  String? savedWorkoutId,  String? verifiedDeviceId,  String? playedSessionId,  List<String> events)?  $default,) {final _that = this;
switch (_that) {
case _FirstClassProgress() when $default != null:
return $default(_that.sessionId,_that.dismissed,_that.centerReady,_that.savedWorkoutId,_that.verifiedDeviceId,_that.playedSessionId,_that.events);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FirstClassProgress extends FirstClassProgress {
  const _FirstClassProgress({required this.sessionId, this.dismissed = false, this.centerReady = false, this.savedWorkoutId, this.verifiedDeviceId, this.playedSessionId,  List<String> events = const <String>[]}): _events = events,super._();
  factory _FirstClassProgress.fromJson(Map<String, dynamic> json) => _$FirstClassProgressFromJson(json);

@override final  String sessionId;
@override@JsonKey() final  bool dismissed;
@override@JsonKey() final  bool centerReady;
@override final  String? savedWorkoutId;
@override final  String? verifiedDeviceId;
@override final  String? playedSessionId;
 final  List<String> _events;
@override@JsonKey() List<String> get events {
  if (_events is EqualUnmodifiableListView) return _events;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_events);
}


/// Create a copy of FirstClassProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FirstClassProgressCopyWith<_FirstClassProgress> get copyWith => __$FirstClassProgressCopyWithImpl<_FirstClassProgress>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FirstClassProgressToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FirstClassProgress&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.dismissed, dismissed) || other.dismissed == dismissed)&&(identical(other.centerReady, centerReady) || other.centerReady == centerReady)&&(identical(other.savedWorkoutId, savedWorkoutId) || other.savedWorkoutId == savedWorkoutId)&&(identical(other.verifiedDeviceId, verifiedDeviceId) || other.verifiedDeviceId == verifiedDeviceId)&&(identical(other.playedSessionId, playedSessionId) || other.playedSessionId == playedSessionId)&&const DeepCollectionEquality().equals(other.events, _events));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,dismissed,centerReady,savedWorkoutId,verifiedDeviceId,playedSessionId,const DeepCollectionEquality().hash(_events));
}

@override
String toString() {
    return 'FirstClassProgress(sessionId: $sessionId, dismissed: $dismissed, centerReady: $centerReady, savedWorkoutId: $savedWorkoutId, verifiedDeviceId: $verifiedDeviceId, playedSessionId: $playedSessionId, events: $events)';
}


}

/// @nodoc
abstract mixin class _$FirstClassProgressCopyWith<$Res> implements $FirstClassProgressCopyWith<$Res> {
  factory _$FirstClassProgressCopyWith(_FirstClassProgress value, $Res Function(_FirstClassProgress) _then) = __$FirstClassProgressCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, bool dismissed, bool centerReady, String? savedWorkoutId, String? verifiedDeviceId, String? playedSessionId, List<String> events
});




}
/// @nodoc
class __$FirstClassProgressCopyWithImpl<$Res>
    implements _$FirstClassProgressCopyWith<$Res> {
  __$FirstClassProgressCopyWithImpl(this._self, this._then);

  final _FirstClassProgress _self;
  final $Res Function(_FirstClassProgress) _then;

/// Create a copy of FirstClassProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? dismissed = null,Object? centerReady = null,Object? savedWorkoutId = freezed,Object? verifiedDeviceId = freezed,Object? playedSessionId = freezed,Object? events = null,}) {
  return _then(_FirstClassProgress(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,dismissed: null == dismissed ? _self.dismissed : dismissed // ignore: cast_nullable_to_non_nullable
as bool,centerReady: null == centerReady ? _self.centerReady : centerReady // ignore: cast_nullable_to_non_nullable
as bool,savedWorkoutId: freezed == savedWorkoutId ? _self.savedWorkoutId : savedWorkoutId // ignore: cast_nullable_to_non_nullable
as String?,verifiedDeviceId: freezed == verifiedDeviceId ? _self.verifiedDeviceId : verifiedDeviceId // ignore: cast_nullable_to_non_nullable
as String?,playedSessionId: freezed == playedSessionId ? _self.playedSessionId : playedSessionId // ignore: cast_nullable_to_non_nullable
as String?,events: null == events ? _self._events : events // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
