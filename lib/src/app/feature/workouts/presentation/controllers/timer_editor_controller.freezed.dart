// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'timer_editor_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TimerEditorState {

 WorkoutModule get module; WorkoutTimerMode get inputMode; bool get detailed; Map<String, String> get errors; int get formRevision; int get lastTimeCap;
/// Create a copy of TimerEditorState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TimerEditorStateCopyWith<TimerEditorState> get copyWith => _$TimerEditorStateCopyWithImpl<TimerEditorState>(this as TimerEditorState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as TimerEditorState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimerEditorState&&(identical(other.module, _this.module) || other.module == _this.module)&&(identical(other.inputMode, _this.inputMode) || other.inputMode == _this.inputMode)&&(identical(other.detailed, _this.detailed) || other.detailed == _this.detailed)&&const DeepCollectionEquality().equals(other.errors, _this.errors)&&(identical(other.formRevision, _this.formRevision) || other.formRevision == _this.formRevision)&&(identical(other.lastTimeCap, _this.lastTimeCap) || other.lastTimeCap == _this.lastTimeCap));
}


@override
int get hashCode {
  final _this = this as TimerEditorState;
  return Object.hash(runtimeType,_this.module,_this.inputMode,_this.detailed,const DeepCollectionEquality().hash(_this.errors),_this.formRevision,_this.lastTimeCap);
}

@override
String toString() {
  final _this = this as TimerEditorState;
  return 'TimerEditorState(module: ${_this.module}, inputMode: ${_this.inputMode}, detailed: ${_this.detailed}, errors: ${_this.errors}, formRevision: ${_this.formRevision}, lastTimeCap: ${_this.lastTimeCap})';
}


}

/// @nodoc
abstract mixin class $TimerEditorStateCopyWith<$Res>  {
  factory $TimerEditorStateCopyWith(TimerEditorState value, $Res Function(TimerEditorState) _then) = _$TimerEditorStateCopyWithImpl;
@useResult
$Res call({
 WorkoutModule module, WorkoutTimerMode inputMode, bool detailed, Map<String, String> errors, int formRevision, int lastTimeCap
});


$WorkoutModuleCopyWith<$Res> get module;

}
/// @nodoc
class _$TimerEditorStateCopyWithImpl<$Res>
    implements $TimerEditorStateCopyWith<$Res> {
  _$TimerEditorStateCopyWithImpl(this._self, this._then);

  final TimerEditorState _self;
  final $Res Function(TimerEditorState) _then;

/// Create a copy of TimerEditorState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? module = null,Object? inputMode = null,Object? detailed = null,Object? errors = null,Object? formRevision = null,Object? lastTimeCap = null,}) {
  return _then(TimerEditorState(
module: null == module ? _self.module : module // ignore: cast_nullable_to_non_nullable
as WorkoutModule,inputMode: null == inputMode ? _self.inputMode : inputMode // ignore: cast_nullable_to_non_nullable
as WorkoutTimerMode,detailed: null == detailed ? _self.detailed : detailed // ignore: cast_nullable_to_non_nullable
as bool,errors: null == errors ? _self.errors : errors // ignore: cast_nullable_to_non_nullable
as Map<String, String>,formRevision: null == formRevision ? _self.formRevision : formRevision // ignore: cast_nullable_to_non_nullable
as int,lastTimeCap: null == lastTimeCap ? _self.lastTimeCap : lastTimeCap // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of TimerEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutModuleCopyWith<$Res> get module {
  
  return $WorkoutModuleCopyWith<$Res>(_self.module, (value) {
    return _then(_self.copyWith(module: value));
  });
}
}


/// Adds pattern-matching-related methods to [TimerEditorState].
extension TimerEditorStatePatterns on TimerEditorState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TimerEditorState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TimerEditorState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TimerEditorState value)  $default,){
final _that = this;
switch (_that) {
case _TimerEditorState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TimerEditorState value)?  $default,){
final _that = this;
switch (_that) {
case _TimerEditorState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WorkoutModule module,  WorkoutTimerMode inputMode,  bool detailed,  Map<String, String> errors,  int formRevision,  int lastTimeCap)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TimerEditorState() when $default != null:
return $default(_that.module,_that.inputMode,_that.detailed,_that.errors,_that.formRevision,_that.lastTimeCap);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WorkoutModule module,  WorkoutTimerMode inputMode,  bool detailed,  Map<String, String> errors,  int formRevision,  int lastTimeCap)  $default,) {final _that = this;
switch (_that) {
case _TimerEditorState():
return $default(_that.module,_that.inputMode,_that.detailed,_that.errors,_that.formRevision,_that.lastTimeCap);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WorkoutModule module,  WorkoutTimerMode inputMode,  bool detailed,  Map<String, String> errors,  int formRevision,  int lastTimeCap)?  $default,) {final _that = this;
switch (_that) {
case _TimerEditorState() when $default != null:
return $default(_that.module,_that.inputMode,_that.detailed,_that.errors,_that.formRevision,_that.lastTimeCap);case _:
  return null;

}
}

}

/// @nodoc


class _TimerEditorState extends TimerEditorState {
  const _TimerEditorState({required this.module, required this.inputMode, this.detailed = false,  Map<String, String> errors = const {}, this.formRevision = 0, this.lastTimeCap = 600}): _errors = errors,super._();
  

@override final  WorkoutModule module;
@override final  WorkoutTimerMode inputMode;
@override@JsonKey() final  bool detailed;
 final  Map<String, String> _errors;
@override@JsonKey() Map<String, String> get errors {
  if (_errors is EqualUnmodifiableMapView) return _errors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_errors);
}

@override@JsonKey() final  int formRevision;
@override@JsonKey() final  int lastTimeCap;

/// Create a copy of TimerEditorState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TimerEditorStateCopyWith<_TimerEditorState> get copyWith => __$TimerEditorStateCopyWithImpl<_TimerEditorState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TimerEditorState&&(identical(other.module, module) || other.module == module)&&(identical(other.inputMode, inputMode) || other.inputMode == inputMode)&&(identical(other.detailed, detailed) || other.detailed == detailed)&&const DeepCollectionEquality().equals(other.errors, _errors)&&(identical(other.formRevision, formRevision) || other.formRevision == formRevision)&&(identical(other.lastTimeCap, lastTimeCap) || other.lastTimeCap == lastTimeCap));
}


@override
int get hashCode {
    return Object.hash(runtimeType,module,inputMode,detailed,const DeepCollectionEquality().hash(_errors),formRevision,lastTimeCap);
}

@override
String toString() {
    return 'TimerEditorState(module: $module, inputMode: $inputMode, detailed: $detailed, errors: $errors, formRevision: $formRevision, lastTimeCap: $lastTimeCap)';
}


}

/// @nodoc
abstract mixin class _$TimerEditorStateCopyWith<$Res> implements $TimerEditorStateCopyWith<$Res> {
  factory _$TimerEditorStateCopyWith(_TimerEditorState value, $Res Function(_TimerEditorState) _then) = __$TimerEditorStateCopyWithImpl;
@override @useResult
$Res call({
 WorkoutModule module, WorkoutTimerMode inputMode, bool detailed, Map<String, String> errors, int formRevision, int lastTimeCap
});


@override $WorkoutModuleCopyWith<$Res> get module;

}
/// @nodoc
class __$TimerEditorStateCopyWithImpl<$Res>
    implements _$TimerEditorStateCopyWith<$Res> {
  __$TimerEditorStateCopyWithImpl(this._self, this._then);

  final _TimerEditorState _self;
  final $Res Function(_TimerEditorState) _then;

/// Create a copy of TimerEditorState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? module = null,Object? inputMode = null,Object? detailed = null,Object? errors = null,Object? formRevision = null,Object? lastTimeCap = null,}) {
  return _then(_TimerEditorState(
module: null == module ? _self.module : module // ignore: cast_nullable_to_non_nullable
as WorkoutModule,inputMode: null == inputMode ? _self.inputMode : inputMode // ignore: cast_nullable_to_non_nullable
as WorkoutTimerMode,detailed: null == detailed ? _self.detailed : detailed // ignore: cast_nullable_to_non_nullable
as bool,errors: null == errors ? _self._errors : errors // ignore: cast_nullable_to_non_nullable
as Map<String, String>,formRevision: null == formRevision ? _self.formRevision : formRevision // ignore: cast_nullable_to_non_nullable
as int,lastTimeCap: null == lastTimeCap ? _self.lastTimeCap : lastTimeCap // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of TimerEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutModuleCopyWith<$Res> get module {
  
  return $WorkoutModuleCopyWith<$Res>(_self.module, (value) {
    return _then(_self.copyWith(module: value));
  });
}
}

// dart format on
