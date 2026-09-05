// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'player_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PlayerStep {

 WorkoutModule get module; int get moduleIndex; int get set; int get totalSets; int get duration; bool get isRest;
/// Create a copy of PlayerStep
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerStepCopyWith<PlayerStep> get copyWith => _$PlayerStepCopyWithImpl<PlayerStep>(this as PlayerStep, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PlayerStep;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerStep&&(identical(other.module, _this.module) || other.module == _this.module)&&(identical(other.moduleIndex, _this.moduleIndex) || other.moduleIndex == _this.moduleIndex)&&(identical(other.set, _this.set) || other.set == _this.set)&&(identical(other.totalSets, _this.totalSets) || other.totalSets == _this.totalSets)&&(identical(other.duration, _this.duration) || other.duration == _this.duration)&&(identical(other.isRest, _this.isRest) || other.isRest == _this.isRest));
}


@override
int get hashCode {
  final _this = this as PlayerStep;
  return Object.hash(runtimeType,_this.module,_this.moduleIndex,_this.set,_this.totalSets,_this.duration,_this.isRest);
}

@override
String toString() {
  final _this = this as PlayerStep;
  return 'PlayerStep(module: ${_this.module}, moduleIndex: ${_this.moduleIndex}, set: ${_this.set}, totalSets: ${_this.totalSets}, duration: ${_this.duration}, isRest: ${_this.isRest})';
}


}

/// @nodoc
abstract mixin class $PlayerStepCopyWith<$Res>  {
  factory $PlayerStepCopyWith(PlayerStep value, $Res Function(PlayerStep) _then) = _$PlayerStepCopyWithImpl;
@useResult
$Res call({
 WorkoutModule module, int moduleIndex, int set, int totalSets, int duration, bool isRest
});


$WorkoutModuleCopyWith<$Res> get module;

}
/// @nodoc
class _$PlayerStepCopyWithImpl<$Res>
    implements $PlayerStepCopyWith<$Res> {
  _$PlayerStepCopyWithImpl(this._self, this._then);

  final PlayerStep _self;
  final $Res Function(PlayerStep) _then;

/// Create a copy of PlayerStep
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? module = null,Object? moduleIndex = null,Object? set = null,Object? totalSets = null,Object? duration = null,Object? isRest = null,}) {
  return _then(PlayerStep(
module: null == module ? _self.module : module // ignore: cast_nullable_to_non_nullable
as WorkoutModule,moduleIndex: null == moduleIndex ? _self.moduleIndex : moduleIndex // ignore: cast_nullable_to_non_nullable
as int,set: null == set ? _self.set : set // ignore: cast_nullable_to_non_nullable
as int,totalSets: null == totalSets ? _self.totalSets : totalSets // ignore: cast_nullable_to_non_nullable
as int,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int,isRest: null == isRest ? _self.isRest : isRest // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of PlayerStep
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutModuleCopyWith<$Res> get module {
  
  return $WorkoutModuleCopyWith<$Res>(_self.module, (value) {
    return _then(_self.copyWith(module: value));
  });
}
}


/// Adds pattern-matching-related methods to [PlayerStep].
extension PlayerStepPatterns on PlayerStep {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlayerStep value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlayerStep() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlayerStep value)  $default,){
final _that = this;
switch (_that) {
case _PlayerStep():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlayerStep value)?  $default,){
final _that = this;
switch (_that) {
case _PlayerStep() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WorkoutModule module,  int moduleIndex,  int set,  int totalSets,  int duration,  bool isRest)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlayerStep() when $default != null:
return $default(_that.module,_that.moduleIndex,_that.set,_that.totalSets,_that.duration,_that.isRest);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WorkoutModule module,  int moduleIndex,  int set,  int totalSets,  int duration,  bool isRest)  $default,) {final _that = this;
switch (_that) {
case _PlayerStep():
return $default(_that.module,_that.moduleIndex,_that.set,_that.totalSets,_that.duration,_that.isRest);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WorkoutModule module,  int moduleIndex,  int set,  int totalSets,  int duration,  bool isRest)?  $default,) {final _that = this;
switch (_that) {
case _PlayerStep() when $default != null:
return $default(_that.module,_that.moduleIndex,_that.set,_that.totalSets,_that.duration,_that.isRest);case _:
  return null;

}
}

}

/// @nodoc


class _PlayerStep implements PlayerStep {
  const _PlayerStep({required this.module, required this.moduleIndex, required this.set, required this.totalSets, required this.duration, required this.isRest});
  

@override final  WorkoutModule module;
@override final  int moduleIndex;
@override final  int set;
@override final  int totalSets;
@override final  int duration;
@override final  bool isRest;

/// Create a copy of PlayerStep
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlayerStepCopyWith<_PlayerStep> get copyWith => __$PlayerStepCopyWithImpl<_PlayerStep>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlayerStep&&(identical(other.module, module) || other.module == module)&&(identical(other.moduleIndex, moduleIndex) || other.moduleIndex == moduleIndex)&&(identical(other.set, set) || other.set == set)&&(identical(other.totalSets, totalSets) || other.totalSets == totalSets)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.isRest, isRest) || other.isRest == isRest));
}


@override
int get hashCode {
    return Object.hash(runtimeType,module,moduleIndex,set,totalSets,duration,isRest);
}

@override
String toString() {
    return 'PlayerStep(module: $module, moduleIndex: $moduleIndex, set: $set, totalSets: $totalSets, duration: $duration, isRest: $isRest)';
}


}

/// @nodoc
abstract mixin class _$PlayerStepCopyWith<$Res> implements $PlayerStepCopyWith<$Res> {
  factory _$PlayerStepCopyWith(_PlayerStep value, $Res Function(_PlayerStep) _then) = __$PlayerStepCopyWithImpl;
@override @useResult
$Res call({
 WorkoutModule module, int moduleIndex, int set, int totalSets, int duration, bool isRest
});


@override $WorkoutModuleCopyWith<$Res> get module;

}
/// @nodoc
class __$PlayerStepCopyWithImpl<$Res>
    implements _$PlayerStepCopyWith<$Res> {
  __$PlayerStepCopyWithImpl(this._self, this._then);

  final _PlayerStep _self;
  final $Res Function(_PlayerStep) _then;

/// Create a copy of PlayerStep
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? module = null,Object? moduleIndex = null,Object? set = null,Object? totalSets = null,Object? duration = null,Object? isRest = null,}) {
  return _then(_PlayerStep(
module: null == module ? _self.module : module // ignore: cast_nullable_to_non_nullable
as WorkoutModule,moduleIndex: null == moduleIndex ? _self.moduleIndex : moduleIndex // ignore: cast_nullable_to_non_nullable
as int,set: null == set ? _self.set : set // ignore: cast_nullable_to_non_nullable
as int,totalSets: null == totalSets ? _self.totalSets : totalSets // ignore: cast_nullable_to_non_nullable
as int,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int,isRest: null == isRest ? _self.isRest : isRest // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of PlayerStep
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutModuleCopyWith<$Res> get module {
  
  return $WorkoutModuleCopyWith<$Res>(_self.module, (value) {
    return _then(_self.copyWith(module: value));
  });
}
}

/// @nodoc
mixin _$PlayerState {

 List<PlayerStep> get steps; int get index; int get remainingMs; bool get isPaused;
/// Create a copy of PlayerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerStateCopyWith<PlayerState> get copyWith => _$PlayerStateCopyWithImpl<PlayerState>(this as PlayerState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PlayerState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerState&&const DeepCollectionEquality().equals(other.steps, _this.steps)&&(identical(other.index, _this.index) || other.index == _this.index)&&(identical(other.remainingMs, _this.remainingMs) || other.remainingMs == _this.remainingMs)&&(identical(other.isPaused, _this.isPaused) || other.isPaused == _this.isPaused));
}


@override
int get hashCode {
  final _this = this as PlayerState;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.steps),_this.index,_this.remainingMs,_this.isPaused);
}

@override
String toString() {
  final _this = this as PlayerState;
  return 'PlayerState(steps: ${_this.steps}, index: ${_this.index}, remainingMs: ${_this.remainingMs}, isPaused: ${_this.isPaused})';
}


}

/// @nodoc
abstract mixin class $PlayerStateCopyWith<$Res>  {
  factory $PlayerStateCopyWith(PlayerState value, $Res Function(PlayerState) _then) = _$PlayerStateCopyWithImpl;
@useResult
$Res call({
 List<PlayerStep> steps, int index, int remainingMs, bool isPaused
});




}
/// @nodoc
class _$PlayerStateCopyWithImpl<$Res>
    implements $PlayerStateCopyWith<$Res> {
  _$PlayerStateCopyWithImpl(this._self, this._then);

  final PlayerState _self;
  final $Res Function(PlayerState) _then;

/// Create a copy of PlayerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? steps = null,Object? index = null,Object? remainingMs = null,Object? isPaused = null,}) {
  return _then(PlayerState(
steps: null == steps ? _self.steps : steps // ignore: cast_nullable_to_non_nullable
as List<PlayerStep>,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,remainingMs: null == remainingMs ? _self.remainingMs : remainingMs // ignore: cast_nullable_to_non_nullable
as int,isPaused: null == isPaused ? _self.isPaused : isPaused // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PlayerState].
extension PlayerStatePatterns on PlayerState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlayerState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlayerState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlayerState value)  $default,){
final _that = this;
switch (_that) {
case _PlayerState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlayerState value)?  $default,){
final _that = this;
switch (_that) {
case _PlayerState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<PlayerStep> steps,  int index,  int remainingMs,  bool isPaused)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlayerState() when $default != null:
return $default(_that.steps,_that.index,_that.remainingMs,_that.isPaused);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<PlayerStep> steps,  int index,  int remainingMs,  bool isPaused)  $default,) {final _that = this;
switch (_that) {
case _PlayerState():
return $default(_that.steps,_that.index,_that.remainingMs,_that.isPaused);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<PlayerStep> steps,  int index,  int remainingMs,  bool isPaused)?  $default,) {final _that = this;
switch (_that) {
case _PlayerState() when $default != null:
return $default(_that.steps,_that.index,_that.remainingMs,_that.isPaused);case _:
  return null;

}
}

}

/// @nodoc


class _PlayerState implements PlayerState {
  const _PlayerState({required  List<PlayerStep> steps, required this.index, required this.remainingMs, required this.isPaused}): _steps = steps;
  

 final  List<PlayerStep> _steps;
@override List<PlayerStep> get steps {
  if (_steps is EqualUnmodifiableListView) return _steps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_steps);
}

@override final  int index;
@override final  int remainingMs;
@override final  bool isPaused;

/// Create a copy of PlayerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlayerStateCopyWith<_PlayerState> get copyWith => __$PlayerStateCopyWithImpl<_PlayerState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlayerState&&const DeepCollectionEquality().equals(other.steps, _steps)&&(identical(other.index, index) || other.index == index)&&(identical(other.remainingMs, remainingMs) || other.remainingMs == remainingMs)&&(identical(other.isPaused, isPaused) || other.isPaused == isPaused));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_steps),index,remainingMs,isPaused);
}

@override
String toString() {
    return 'PlayerState(steps: $steps, index: $index, remainingMs: $remainingMs, isPaused: $isPaused)';
}


}

/// @nodoc
abstract mixin class _$PlayerStateCopyWith<$Res> implements $PlayerStateCopyWith<$Res> {
  factory _$PlayerStateCopyWith(_PlayerState value, $Res Function(_PlayerState) _then) = __$PlayerStateCopyWithImpl;
@override @useResult
$Res call({
 List<PlayerStep> steps, int index, int remainingMs, bool isPaused
});




}
/// @nodoc
class __$PlayerStateCopyWithImpl<$Res>
    implements _$PlayerStateCopyWith<$Res> {
  __$PlayerStateCopyWithImpl(this._self, this._then);

  final _PlayerState _self;
  final $Res Function(_PlayerState) _then;

/// Create a copy of PlayerState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? steps = null,Object? index = null,Object? remainingMs = null,Object? isPaused = null,}) {
  return _then(_PlayerState(
steps: null == steps ? _self._steps : steps // ignore: cast_nullable_to_non_nullable
as List<PlayerStep>,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,remainingMs: null == remainingMs ? _self.remainingMs : remainingMs // ignore: cast_nullable_to_non_nullable
as int,isPaused: null == isPaused ? _self.isPaused : isPaused // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
