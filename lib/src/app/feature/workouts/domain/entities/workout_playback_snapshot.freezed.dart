// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workout_playback_snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WorkoutPlaybackSnapshot {

 WorkoutContent get content; WorkoutPreferences get settings; bool get usesAccountSettings;
/// Create a copy of WorkoutPlaybackSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkoutPlaybackSnapshotCopyWith<WorkoutPlaybackSnapshot> get copyWith => _$WorkoutPlaybackSnapshotCopyWithImpl<WorkoutPlaybackSnapshot>(this as WorkoutPlaybackSnapshot, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WorkoutPlaybackSnapshot;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkoutPlaybackSnapshot&&(identical(other.content, _this.content) || other.content == _this.content)&&(identical(other.settings, _this.settings) || other.settings == _this.settings)&&(identical(other.usesAccountSettings, _this.usesAccountSettings) || other.usesAccountSettings == _this.usesAccountSettings));
}


@override
int get hashCode {
  final _this = this as WorkoutPlaybackSnapshot;
  return Object.hash(runtimeType,_this.content,_this.settings,_this.usesAccountSettings);
}

@override
String toString() {
  final _this = this as WorkoutPlaybackSnapshot;
  return 'WorkoutPlaybackSnapshot(content: ${_this.content}, settings: ${_this.settings}, usesAccountSettings: ${_this.usesAccountSettings})';
}


}

/// @nodoc
abstract mixin class $WorkoutPlaybackSnapshotCopyWith<$Res>  {
  factory $WorkoutPlaybackSnapshotCopyWith(WorkoutPlaybackSnapshot value, $Res Function(WorkoutPlaybackSnapshot) _then) = _$WorkoutPlaybackSnapshotCopyWithImpl;
@useResult
$Res call({
 WorkoutContent content, WorkoutPreferences settings, bool usesAccountSettings
});


$WorkoutContentCopyWith<$Res> get content;$WorkoutPreferencesCopyWith<$Res> get settings;

}
/// @nodoc
class _$WorkoutPlaybackSnapshotCopyWithImpl<$Res>
    implements $WorkoutPlaybackSnapshotCopyWith<$Res> {
  _$WorkoutPlaybackSnapshotCopyWithImpl(this._self, this._then);

  final WorkoutPlaybackSnapshot _self;
  final $Res Function(WorkoutPlaybackSnapshot) _then;

/// Create a copy of WorkoutPlaybackSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? content = null,Object? settings = null,Object? usesAccountSettings = null,}) {
  return _then(WorkoutPlaybackSnapshot(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as WorkoutContent,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as WorkoutPreferences,usesAccountSettings: null == usesAccountSettings ? _self.usesAccountSettings : usesAccountSettings // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of WorkoutPlaybackSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutContentCopyWith<$Res> get content {
  
  return $WorkoutContentCopyWith<$Res>(_self.content, (value) {
    return _then(_self.copyWith(content: value));
  });
}/// Create a copy of WorkoutPlaybackSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutPreferencesCopyWith<$Res> get settings {
  
  return $WorkoutPreferencesCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}


/// Adds pattern-matching-related methods to [WorkoutPlaybackSnapshot].
extension WorkoutPlaybackSnapshotPatterns on WorkoutPlaybackSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkoutPlaybackSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkoutPlaybackSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkoutPlaybackSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _WorkoutPlaybackSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkoutPlaybackSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _WorkoutPlaybackSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WorkoutContent content,  WorkoutPreferences settings,  bool usesAccountSettings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkoutPlaybackSnapshot() when $default != null:
return $default(_that.content,_that.settings,_that.usesAccountSettings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WorkoutContent content,  WorkoutPreferences settings,  bool usesAccountSettings)  $default,) {final _that = this;
switch (_that) {
case _WorkoutPlaybackSnapshot():
return $default(_that.content,_that.settings,_that.usesAccountSettings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WorkoutContent content,  WorkoutPreferences settings,  bool usesAccountSettings)?  $default,) {final _that = this;
switch (_that) {
case _WorkoutPlaybackSnapshot() when $default != null:
return $default(_that.content,_that.settings,_that.usesAccountSettings);case _:
  return null;

}
}

}

/// @nodoc


class _WorkoutPlaybackSnapshot extends WorkoutPlaybackSnapshot {
  const _WorkoutPlaybackSnapshot({required this.content, required this.settings, required this.usesAccountSettings}): super._();
  

@override final  WorkoutContent content;
@override final  WorkoutPreferences settings;
@override final  bool usesAccountSettings;

/// Create a copy of WorkoutPlaybackSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkoutPlaybackSnapshotCopyWith<_WorkoutPlaybackSnapshot> get copyWith => __$WorkoutPlaybackSnapshotCopyWithImpl<_WorkoutPlaybackSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkoutPlaybackSnapshot&&(identical(other.content, content) || other.content == content)&&(identical(other.settings, settings) || other.settings == settings)&&(identical(other.usesAccountSettings, usesAccountSettings) || other.usesAccountSettings == usesAccountSettings));
}


@override
int get hashCode {
    return Object.hash(runtimeType,content,settings,usesAccountSettings);
}

@override
String toString() {
    return 'WorkoutPlaybackSnapshot(content: $content, settings: $settings, usesAccountSettings: $usesAccountSettings)';
}


}

/// @nodoc
abstract mixin class _$WorkoutPlaybackSnapshotCopyWith<$Res> implements $WorkoutPlaybackSnapshotCopyWith<$Res> {
  factory _$WorkoutPlaybackSnapshotCopyWith(_WorkoutPlaybackSnapshot value, $Res Function(_WorkoutPlaybackSnapshot) _then) = __$WorkoutPlaybackSnapshotCopyWithImpl;
@override @useResult
$Res call({
 WorkoutContent content, WorkoutPreferences settings, bool usesAccountSettings
});


@override $WorkoutContentCopyWith<$Res> get content;@override $WorkoutPreferencesCopyWith<$Res> get settings;

}
/// @nodoc
class __$WorkoutPlaybackSnapshotCopyWithImpl<$Res>
    implements _$WorkoutPlaybackSnapshotCopyWith<$Res> {
  __$WorkoutPlaybackSnapshotCopyWithImpl(this._self, this._then);

  final _WorkoutPlaybackSnapshot _self;
  final $Res Function(_WorkoutPlaybackSnapshot) _then;

/// Create a copy of WorkoutPlaybackSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? content = null,Object? settings = null,Object? usesAccountSettings = null,}) {
  return _then(_WorkoutPlaybackSnapshot(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as WorkoutContent,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as WorkoutPreferences,usesAccountSettings: null == usesAccountSettings ? _self.usesAccountSettings : usesAccountSettings // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of WorkoutPlaybackSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutContentCopyWith<$Res> get content {
  
  return $WorkoutContentCopyWith<$Res>(_self.content, (value) {
    return _then(_self.copyWith(content: value));
  });
}/// Create a copy of WorkoutPlaybackSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutPreferencesCopyWith<$Res> get settings {
  
  return $WorkoutPreferencesCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}

// dart format on
