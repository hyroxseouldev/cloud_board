// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workout_preferences.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WorkoutPreferences {

 String get brandL; String get brandR; WorkoutSoundTheme get soundTheme; WorkoutSound get countdownSound; WorkoutSound get workStartSound; WorkoutSound get restStartSound; WorkoutSound get workoutEndSound; double get soundVolume; CountdownPreferences get countdown;
/// Create a copy of WorkoutPreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkoutPreferencesCopyWith<WorkoutPreferences> get copyWith => _$WorkoutPreferencesCopyWithImpl<WorkoutPreferences>(this as WorkoutPreferences, _$identity);

  /// Serializes this WorkoutPreferences to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WorkoutPreferences;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkoutPreferences&&(identical(other.brandL, _this.brandL) || other.brandL == _this.brandL)&&(identical(other.brandR, _this.brandR) || other.brandR == _this.brandR)&&(identical(other.soundTheme, _this.soundTheme) || other.soundTheme == _this.soundTheme)&&(identical(other.countdownSound, _this.countdownSound) || other.countdownSound == _this.countdownSound)&&(identical(other.workStartSound, _this.workStartSound) || other.workStartSound == _this.workStartSound)&&(identical(other.restStartSound, _this.restStartSound) || other.restStartSound == _this.restStartSound)&&(identical(other.workoutEndSound, _this.workoutEndSound) || other.workoutEndSound == _this.workoutEndSound)&&(identical(other.soundVolume, _this.soundVolume) || other.soundVolume == _this.soundVolume)&&(identical(other.countdown, _this.countdown) || other.countdown == _this.countdown));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WorkoutPreferences;
  return Object.hash(runtimeType,_this.brandL,_this.brandR,_this.soundTheme,_this.countdownSound,_this.workStartSound,_this.restStartSound,_this.workoutEndSound,_this.soundVolume,_this.countdown);
}

@override
String toString() {
  final _this = this as WorkoutPreferences;
  return 'WorkoutPreferences(brandL: ${_this.brandL}, brandR: ${_this.brandR}, soundTheme: ${_this.soundTheme}, countdownSound: ${_this.countdownSound}, workStartSound: ${_this.workStartSound}, restStartSound: ${_this.restStartSound}, workoutEndSound: ${_this.workoutEndSound}, soundVolume: ${_this.soundVolume}, countdown: ${_this.countdown})';
}


}

/// @nodoc
abstract mixin class $WorkoutPreferencesCopyWith<$Res>  {
  factory $WorkoutPreferencesCopyWith(WorkoutPreferences value, $Res Function(WorkoutPreferences) _then) = _$WorkoutPreferencesCopyWithImpl;
@useResult
$Res call({
 String brandL, String brandR, WorkoutSoundTheme soundTheme, WorkoutSound countdownSound, WorkoutSound workStartSound, WorkoutSound restStartSound, WorkoutSound workoutEndSound, double soundVolume, CountdownPreferences countdown
});


$CountdownPreferencesCopyWith<$Res> get countdown;

}
/// @nodoc
class _$WorkoutPreferencesCopyWithImpl<$Res>
    implements $WorkoutPreferencesCopyWith<$Res> {
  _$WorkoutPreferencesCopyWithImpl(this._self, this._then);

  final WorkoutPreferences _self;
  final $Res Function(WorkoutPreferences) _then;

/// Create a copy of WorkoutPreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? brandL = null,Object? brandR = null,Object? soundTheme = null,Object? countdownSound = null,Object? workStartSound = null,Object? restStartSound = null,Object? workoutEndSound = null,Object? soundVolume = null,Object? countdown = null,}) {
  return _then(WorkoutPreferences(
brandL: null == brandL ? _self.brandL : brandL // ignore: cast_nullable_to_non_nullable
as String,brandR: null == brandR ? _self.brandR : brandR // ignore: cast_nullable_to_non_nullable
as String,soundTheme: null == soundTheme ? _self.soundTheme : soundTheme // ignore: cast_nullable_to_non_nullable
as WorkoutSoundTheme,countdownSound: null == countdownSound ? _self.countdownSound : countdownSound // ignore: cast_nullable_to_non_nullable
as WorkoutSound,workStartSound: null == workStartSound ? _self.workStartSound : workStartSound // ignore: cast_nullable_to_non_nullable
as WorkoutSound,restStartSound: null == restStartSound ? _self.restStartSound : restStartSound // ignore: cast_nullable_to_non_nullable
as WorkoutSound,workoutEndSound: null == workoutEndSound ? _self.workoutEndSound : workoutEndSound // ignore: cast_nullable_to_non_nullable
as WorkoutSound,soundVolume: null == soundVolume ? _self.soundVolume : soundVolume // ignore: cast_nullable_to_non_nullable
as double,countdown: null == countdown ? _self.countdown : countdown // ignore: cast_nullable_to_non_nullable
as CountdownPreferences,
  ));
}
/// Create a copy of WorkoutPreferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CountdownPreferencesCopyWith<$Res> get countdown {
  
  return $CountdownPreferencesCopyWith<$Res>(_self.countdown, (value) {
    return _then(_self.copyWith(countdown: value));
  });
}
}


/// Adds pattern-matching-related methods to [WorkoutPreferences].
extension WorkoutPreferencesPatterns on WorkoutPreferences {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkoutPreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkoutPreferences() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkoutPreferences value)  $default,){
final _that = this;
switch (_that) {
case _WorkoutPreferences():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkoutPreferences value)?  $default,){
final _that = this;
switch (_that) {
case _WorkoutPreferences() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String brandL,  String brandR,  WorkoutSoundTheme soundTheme,  WorkoutSound countdownSound,  WorkoutSound workStartSound,  WorkoutSound restStartSound,  WorkoutSound workoutEndSound,  double soundVolume,  CountdownPreferences countdown)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkoutPreferences() when $default != null:
return $default(_that.brandL,_that.brandR,_that.soundTheme,_that.countdownSound,_that.workStartSound,_that.restStartSound,_that.workoutEndSound,_that.soundVolume,_that.countdown);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String brandL,  String brandR,  WorkoutSoundTheme soundTheme,  WorkoutSound countdownSound,  WorkoutSound workStartSound,  WorkoutSound restStartSound,  WorkoutSound workoutEndSound,  double soundVolume,  CountdownPreferences countdown)  $default,) {final _that = this;
switch (_that) {
case _WorkoutPreferences():
return $default(_that.brandL,_that.brandR,_that.soundTheme,_that.countdownSound,_that.workStartSound,_that.restStartSound,_that.workoutEndSound,_that.soundVolume,_that.countdown);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String brandL,  String brandR,  WorkoutSoundTheme soundTheme,  WorkoutSound countdownSound,  WorkoutSound workStartSound,  WorkoutSound restStartSound,  WorkoutSound workoutEndSound,  double soundVolume,  CountdownPreferences countdown)?  $default,) {final _that = this;
switch (_that) {
case _WorkoutPreferences() when $default != null:
return $default(_that.brandL,_that.brandR,_that.soundTheme,_that.countdownSound,_that.workStartSound,_that.restStartSound,_that.workoutEndSound,_that.soundVolume,_that.countdown);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _WorkoutPreferences extends WorkoutPreferences {
  const _WorkoutPreferences({this.brandL = 'CloudBoard', this.brandR = '', this.soundTheme = WorkoutSoundTheme.videoBeep, this.countdownSound = WorkoutSound.videoBeep, this.workStartSound = WorkoutSound.videoBeep, this.restStartSound = WorkoutSound.videoBeep, this.workoutEndSound = WorkoutSound.videoBeep, this.soundVolume = 1.0, this.countdown = const CountdownPreferences()}): super._();
  factory _WorkoutPreferences.fromJson(Map<String, dynamic> json) => _$WorkoutPreferencesFromJson(json);

@override@JsonKey() final  String brandL;
@override@JsonKey() final  String brandR;
@override@JsonKey() final  WorkoutSoundTheme soundTheme;
@override@JsonKey() final  WorkoutSound countdownSound;
@override@JsonKey() final  WorkoutSound workStartSound;
@override@JsonKey() final  WorkoutSound restStartSound;
@override@JsonKey() final  WorkoutSound workoutEndSound;
@override@JsonKey() final  double soundVolume;
@override@JsonKey() final  CountdownPreferences countdown;

/// Create a copy of WorkoutPreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkoutPreferencesCopyWith<_WorkoutPreferences> get copyWith => __$WorkoutPreferencesCopyWithImpl<_WorkoutPreferences>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkoutPreferencesToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkoutPreferences&&(identical(other.brandL, brandL) || other.brandL == brandL)&&(identical(other.brandR, brandR) || other.brandR == brandR)&&(identical(other.soundTheme, soundTheme) || other.soundTheme == soundTheme)&&(identical(other.countdownSound, countdownSound) || other.countdownSound == countdownSound)&&(identical(other.workStartSound, workStartSound) || other.workStartSound == workStartSound)&&(identical(other.restStartSound, restStartSound) || other.restStartSound == restStartSound)&&(identical(other.workoutEndSound, workoutEndSound) || other.workoutEndSound == workoutEndSound)&&(identical(other.soundVolume, soundVolume) || other.soundVolume == soundVolume)&&(identical(other.countdown, countdown) || other.countdown == countdown));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,brandL,brandR,soundTheme,countdownSound,workStartSound,restStartSound,workoutEndSound,soundVolume,countdown);
}

@override
String toString() {
    return 'WorkoutPreferences(brandL: $brandL, brandR: $brandR, soundTheme: $soundTheme, countdownSound: $countdownSound, workStartSound: $workStartSound, restStartSound: $restStartSound, workoutEndSound: $workoutEndSound, soundVolume: $soundVolume, countdown: $countdown)';
}


}

/// @nodoc
abstract mixin class _$WorkoutPreferencesCopyWith<$Res> implements $WorkoutPreferencesCopyWith<$Res> {
  factory _$WorkoutPreferencesCopyWith(_WorkoutPreferences value, $Res Function(_WorkoutPreferences) _then) = __$WorkoutPreferencesCopyWithImpl;
@override @useResult
$Res call({
 String brandL, String brandR, WorkoutSoundTheme soundTheme, WorkoutSound countdownSound, WorkoutSound workStartSound, WorkoutSound restStartSound, WorkoutSound workoutEndSound, double soundVolume, CountdownPreferences countdown
});


@override $CountdownPreferencesCopyWith<$Res> get countdown;

}
/// @nodoc
class __$WorkoutPreferencesCopyWithImpl<$Res>
    implements _$WorkoutPreferencesCopyWith<$Res> {
  __$WorkoutPreferencesCopyWithImpl(this._self, this._then);

  final _WorkoutPreferences _self;
  final $Res Function(_WorkoutPreferences) _then;

/// Create a copy of WorkoutPreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? brandL = null,Object? brandR = null,Object? soundTheme = null,Object? countdownSound = null,Object? workStartSound = null,Object? restStartSound = null,Object? workoutEndSound = null,Object? soundVolume = null,Object? countdown = null,}) {
  return _then(_WorkoutPreferences(
brandL: null == brandL ? _self.brandL : brandL // ignore: cast_nullable_to_non_nullable
as String,brandR: null == brandR ? _self.brandR : brandR // ignore: cast_nullable_to_non_nullable
as String,soundTheme: null == soundTheme ? _self.soundTheme : soundTheme // ignore: cast_nullable_to_non_nullable
as WorkoutSoundTheme,countdownSound: null == countdownSound ? _self.countdownSound : countdownSound // ignore: cast_nullable_to_non_nullable
as WorkoutSound,workStartSound: null == workStartSound ? _self.workStartSound : workStartSound // ignore: cast_nullable_to_non_nullable
as WorkoutSound,restStartSound: null == restStartSound ? _self.restStartSound : restStartSound // ignore: cast_nullable_to_non_nullable
as WorkoutSound,workoutEndSound: null == workoutEndSound ? _self.workoutEndSound : workoutEndSound // ignore: cast_nullable_to_non_nullable
as WorkoutSound,soundVolume: null == soundVolume ? _self.soundVolume : soundVolume // ignore: cast_nullable_to_non_nullable
as double,countdown: null == countdown ? _self.countdown : countdown // ignore: cast_nullable_to_non_nullable
as CountdownPreferences,
  ));
}

/// Create a copy of WorkoutPreferences
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CountdownPreferencesCopyWith<$Res> get countdown {
  
  return $CountdownPreferencesCopyWith<$Res>(_self.countdown, (value) {
    return _then(_self.copyWith(countdown: value));
  });
}
}

// dart format on
