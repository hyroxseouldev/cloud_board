// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'slide_editor_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SlideEditorState {

 WorkoutModule get module; WorkoutModule get saved; List<WorkoutModule> get undo; List<WorkoutModule> get redo; List<WorkoutModule> get styles; WorkoutModule? get recovery; bool get localSaved; String? get storageError;
/// Create a copy of SlideEditorState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SlideEditorStateCopyWith<SlideEditorState> get copyWith => _$SlideEditorStateCopyWithImpl<SlideEditorState>(this as SlideEditorState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SlideEditorState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SlideEditorState&&(identical(other.module, _this.module) || other.module == _this.module)&&(identical(other.saved, _this.saved) || other.saved == _this.saved)&&const DeepCollectionEquality().equals(other.undo, _this.undo)&&const DeepCollectionEquality().equals(other.redo, _this.redo)&&const DeepCollectionEquality().equals(other.styles, _this.styles)&&(identical(other.recovery, _this.recovery) || other.recovery == _this.recovery)&&(identical(other.localSaved, _this.localSaved) || other.localSaved == _this.localSaved)&&(identical(other.storageError, _this.storageError) || other.storageError == _this.storageError));
}


@override
int get hashCode {
  final _this = this as SlideEditorState;
  return Object.hash(runtimeType,_this.module,_this.saved,const DeepCollectionEquality().hash(_this.undo),const DeepCollectionEquality().hash(_this.redo),const DeepCollectionEquality().hash(_this.styles),_this.recovery,_this.localSaved,_this.storageError);
}

@override
String toString() {
  final _this = this as SlideEditorState;
  return 'SlideEditorState(module: ${_this.module}, saved: ${_this.saved}, undo: ${_this.undo}, redo: ${_this.redo}, styles: ${_this.styles}, recovery: ${_this.recovery}, localSaved: ${_this.localSaved}, storageError: ${_this.storageError})';
}


}

/// @nodoc
abstract mixin class $SlideEditorStateCopyWith<$Res>  {
  factory $SlideEditorStateCopyWith(SlideEditorState value, $Res Function(SlideEditorState) _then) = _$SlideEditorStateCopyWithImpl;
@useResult
$Res call({
 WorkoutModule module, WorkoutModule saved, List<WorkoutModule> undo, List<WorkoutModule> redo, List<WorkoutModule> styles, WorkoutModule? recovery, bool localSaved, String? storageError
});


$WorkoutModuleCopyWith<$Res> get module;$WorkoutModuleCopyWith<$Res> get saved;$WorkoutModuleCopyWith<$Res>? get recovery;

}
/// @nodoc
class _$SlideEditorStateCopyWithImpl<$Res>
    implements $SlideEditorStateCopyWith<$Res> {
  _$SlideEditorStateCopyWithImpl(this._self, this._then);

  final SlideEditorState _self;
  final $Res Function(SlideEditorState) _then;

/// Create a copy of SlideEditorState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? module = null,Object? saved = null,Object? undo = null,Object? redo = null,Object? styles = null,Object? recovery = freezed,Object? localSaved = null,Object? storageError = freezed,}) {
  return _then(SlideEditorState(
module: null == module ? _self.module : module // ignore: cast_nullable_to_non_nullable
as WorkoutModule,saved: null == saved ? _self.saved : saved // ignore: cast_nullable_to_non_nullable
as WorkoutModule,undo: null == undo ? _self.undo : undo // ignore: cast_nullable_to_non_nullable
as List<WorkoutModule>,redo: null == redo ? _self.redo : redo // ignore: cast_nullable_to_non_nullable
as List<WorkoutModule>,styles: null == styles ? _self.styles : styles // ignore: cast_nullable_to_non_nullable
as List<WorkoutModule>,recovery: freezed == recovery ? _self.recovery : recovery // ignore: cast_nullable_to_non_nullable
as WorkoutModule?,localSaved: null == localSaved ? _self.localSaved : localSaved // ignore: cast_nullable_to_non_nullable
as bool,storageError: freezed == storageError ? _self.storageError : storageError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of SlideEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutModuleCopyWith<$Res> get module {
  
  return $WorkoutModuleCopyWith<$Res>(_self.module, (value) {
    return _then(_self.copyWith(module: value));
  });
}/// Create a copy of SlideEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutModuleCopyWith<$Res> get saved {
  
  return $WorkoutModuleCopyWith<$Res>(_self.saved, (value) {
    return _then(_self.copyWith(saved: value));
  });
}/// Create a copy of SlideEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutModuleCopyWith<$Res>? get recovery {
    if (_self.recovery == null) {
    return null;
  }

  return $WorkoutModuleCopyWith<$Res>(_self.recovery!, (value) {
    return _then(_self.copyWith(recovery: value));
  });
}
}


/// Adds pattern-matching-related methods to [SlideEditorState].
extension SlideEditorStatePatterns on SlideEditorState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SlideEditorState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SlideEditorState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SlideEditorState value)  $default,){
final _that = this;
switch (_that) {
case _SlideEditorState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SlideEditorState value)?  $default,){
final _that = this;
switch (_that) {
case _SlideEditorState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WorkoutModule module,  WorkoutModule saved,  List<WorkoutModule> undo,  List<WorkoutModule> redo,  List<WorkoutModule> styles,  WorkoutModule? recovery,  bool localSaved,  String? storageError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SlideEditorState() when $default != null:
return $default(_that.module,_that.saved,_that.undo,_that.redo,_that.styles,_that.recovery,_that.localSaved,_that.storageError);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WorkoutModule module,  WorkoutModule saved,  List<WorkoutModule> undo,  List<WorkoutModule> redo,  List<WorkoutModule> styles,  WorkoutModule? recovery,  bool localSaved,  String? storageError)  $default,) {final _that = this;
switch (_that) {
case _SlideEditorState():
return $default(_that.module,_that.saved,_that.undo,_that.redo,_that.styles,_that.recovery,_that.localSaved,_that.storageError);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WorkoutModule module,  WorkoutModule saved,  List<WorkoutModule> undo,  List<WorkoutModule> redo,  List<WorkoutModule> styles,  WorkoutModule? recovery,  bool localSaved,  String? storageError)?  $default,) {final _that = this;
switch (_that) {
case _SlideEditorState() when $default != null:
return $default(_that.module,_that.saved,_that.undo,_that.redo,_that.styles,_that.recovery,_that.localSaved,_that.storageError);case _:
  return null;

}
}

}

/// @nodoc


class _SlideEditorState extends SlideEditorState {
  const _SlideEditorState({required this.module, required this.saved,  List<WorkoutModule> undo = const [],  List<WorkoutModule> redo = const [],  List<WorkoutModule> styles = const [], this.recovery, this.localSaved = false, this.storageError}): _undo = undo,_redo = redo,_styles = styles,super._();
  

@override final  WorkoutModule module;
@override final  WorkoutModule saved;
 final  List<WorkoutModule> _undo;
@override@JsonKey() List<WorkoutModule> get undo {
  if (_undo is EqualUnmodifiableListView) return _undo;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_undo);
}

 final  List<WorkoutModule> _redo;
@override@JsonKey() List<WorkoutModule> get redo {
  if (_redo is EqualUnmodifiableListView) return _redo;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_redo);
}

 final  List<WorkoutModule> _styles;
@override@JsonKey() List<WorkoutModule> get styles {
  if (_styles is EqualUnmodifiableListView) return _styles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_styles);
}

@override final  WorkoutModule? recovery;
@override@JsonKey() final  bool localSaved;
@override final  String? storageError;

/// Create a copy of SlideEditorState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SlideEditorStateCopyWith<_SlideEditorState> get copyWith => __$SlideEditorStateCopyWithImpl<_SlideEditorState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SlideEditorState&&(identical(other.module, module) || other.module == module)&&(identical(other.saved, saved) || other.saved == saved)&&const DeepCollectionEquality().equals(other.undo, _undo)&&const DeepCollectionEquality().equals(other.redo, _redo)&&const DeepCollectionEquality().equals(other.styles, _styles)&&(identical(other.recovery, recovery) || other.recovery == recovery)&&(identical(other.localSaved, localSaved) || other.localSaved == localSaved)&&(identical(other.storageError, storageError) || other.storageError == storageError));
}


@override
int get hashCode {
    return Object.hash(runtimeType,module,saved,const DeepCollectionEquality().hash(_undo),const DeepCollectionEquality().hash(_redo),const DeepCollectionEquality().hash(_styles),recovery,localSaved,storageError);
}

@override
String toString() {
    return 'SlideEditorState(module: $module, saved: $saved, undo: $undo, redo: $redo, styles: $styles, recovery: $recovery, localSaved: $localSaved, storageError: $storageError)';
}


}

/// @nodoc
abstract mixin class _$SlideEditorStateCopyWith<$Res> implements $SlideEditorStateCopyWith<$Res> {
  factory _$SlideEditorStateCopyWith(_SlideEditorState value, $Res Function(_SlideEditorState) _then) = __$SlideEditorStateCopyWithImpl;
@override @useResult
$Res call({
 WorkoutModule module, WorkoutModule saved, List<WorkoutModule> undo, List<WorkoutModule> redo, List<WorkoutModule> styles, WorkoutModule? recovery, bool localSaved, String? storageError
});


@override $WorkoutModuleCopyWith<$Res> get module;@override $WorkoutModuleCopyWith<$Res> get saved;@override $WorkoutModuleCopyWith<$Res>? get recovery;

}
/// @nodoc
class __$SlideEditorStateCopyWithImpl<$Res>
    implements _$SlideEditorStateCopyWith<$Res> {
  __$SlideEditorStateCopyWithImpl(this._self, this._then);

  final _SlideEditorState _self;
  final $Res Function(_SlideEditorState) _then;

/// Create a copy of SlideEditorState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? module = null,Object? saved = null,Object? undo = null,Object? redo = null,Object? styles = null,Object? recovery = freezed,Object? localSaved = null,Object? storageError = freezed,}) {
  return _then(_SlideEditorState(
module: null == module ? _self.module : module // ignore: cast_nullable_to_non_nullable
as WorkoutModule,saved: null == saved ? _self.saved : saved // ignore: cast_nullable_to_non_nullable
as WorkoutModule,undo: null == undo ? _self._undo : undo // ignore: cast_nullable_to_non_nullable
as List<WorkoutModule>,redo: null == redo ? _self._redo : redo // ignore: cast_nullable_to_non_nullable
as List<WorkoutModule>,styles: null == styles ? _self._styles : styles // ignore: cast_nullable_to_non_nullable
as List<WorkoutModule>,recovery: freezed == recovery ? _self.recovery : recovery // ignore: cast_nullable_to_non_nullable
as WorkoutModule?,localSaved: null == localSaved ? _self.localSaved : localSaved // ignore: cast_nullable_to_non_nullable
as bool,storageError: freezed == storageError ? _self.storageError : storageError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of SlideEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutModuleCopyWith<$Res> get module {
  
  return $WorkoutModuleCopyWith<$Res>(_self.module, (value) {
    return _then(_self.copyWith(module: value));
  });
}/// Create a copy of SlideEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutModuleCopyWith<$Res> get saved {
  
  return $WorkoutModuleCopyWith<$Res>(_self.saved, (value) {
    return _then(_self.copyWith(saved: value));
  });
}/// Create a copy of SlideEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutModuleCopyWith<$Res>? get recovery {
    if (_self.recovery == null) {
    return null;
  }

  return $WorkoutModuleCopyWith<$Res>(_self.recovery!, (value) {
    return _then(_self.copyWith(recovery: value));
  });
}
}

// dart format on
