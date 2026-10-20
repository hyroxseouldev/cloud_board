// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'saved_slide_order_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SavedSlideOrderState {

 List<String> get ids; bool get ready; bool get saving; String? get error;
/// Create a copy of SavedSlideOrderState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SavedSlideOrderStateCopyWith<SavedSlideOrderState> get copyWith => _$SavedSlideOrderStateCopyWithImpl<SavedSlideOrderState>(this as SavedSlideOrderState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SavedSlideOrderState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SavedSlideOrderState&&const DeepCollectionEquality().equals(other.ids, _this.ids)&&(identical(other.ready, _this.ready) || other.ready == _this.ready)&&(identical(other.saving, _this.saving) || other.saving == _this.saving)&&(identical(other.error, _this.error) || other.error == _this.error));
}


@override
int get hashCode {
  final _this = this as SavedSlideOrderState;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.ids),_this.ready,_this.saving,_this.error);
}

@override
String toString() {
  final _this = this as SavedSlideOrderState;
  return 'SavedSlideOrderState(ids: ${_this.ids}, ready: ${_this.ready}, saving: ${_this.saving}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $SavedSlideOrderStateCopyWith<$Res>  {
  factory $SavedSlideOrderStateCopyWith(SavedSlideOrderState value, $Res Function(SavedSlideOrderState) _then) = _$SavedSlideOrderStateCopyWithImpl;
@useResult
$Res call({
 List<String> ids, bool ready, bool saving, String? error
});




}
/// @nodoc
class _$SavedSlideOrderStateCopyWithImpl<$Res>
    implements $SavedSlideOrderStateCopyWith<$Res> {
  _$SavedSlideOrderStateCopyWithImpl(this._self, this._then);

  final SavedSlideOrderState _self;
  final $Res Function(SavedSlideOrderState) _then;

/// Create a copy of SavedSlideOrderState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ids = null,Object? ready = null,Object? saving = null,Object? error = freezed,}) {
  return _then(SavedSlideOrderState(
ids: null == ids ? _self.ids : ids // ignore: cast_nullable_to_non_nullable
as List<String>,ready: null == ready ? _self.ready : ready // ignore: cast_nullable_to_non_nullable
as bool,saving: null == saving ? _self.saving : saving // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SavedSlideOrderState].
extension SavedSlideOrderStatePatterns on SavedSlideOrderState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SavedSlideOrderState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SavedSlideOrderState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SavedSlideOrderState value)  $default,){
final _that = this;
switch (_that) {
case _SavedSlideOrderState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SavedSlideOrderState value)?  $default,){
final _that = this;
switch (_that) {
case _SavedSlideOrderState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> ids,  bool ready,  bool saving,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SavedSlideOrderState() when $default != null:
return $default(_that.ids,_that.ready,_that.saving,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> ids,  bool ready,  bool saving,  String? error)  $default,) {final _that = this;
switch (_that) {
case _SavedSlideOrderState():
return $default(_that.ids,_that.ready,_that.saving,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> ids,  bool ready,  bool saving,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _SavedSlideOrderState() when $default != null:
return $default(_that.ids,_that.ready,_that.saving,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _SavedSlideOrderState implements SavedSlideOrderState {
  const _SavedSlideOrderState({ List<String> ids = const [], this.ready = false, this.saving = false, this.error}): _ids = ids;


 final  List<String> _ids;
@override@JsonKey() List<String> get ids {
  if (_ids is EqualUnmodifiableListView) return _ids;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ids);
}

@override@JsonKey() final  bool ready;
@override@JsonKey() final  bool saving;
@override final  String? error;

/// Create a copy of SavedSlideOrderState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SavedSlideOrderStateCopyWith<_SavedSlideOrderState> get copyWith => __$SavedSlideOrderStateCopyWithImpl<_SavedSlideOrderState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SavedSlideOrderState&&const DeepCollectionEquality().equals(other.ids, _ids)&&(identical(other.ready, ready) || other.ready == ready)&&(identical(other.saving, saving) || other.saving == saving)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_ids),ready,saving,error);
}

@override
String toString() {
    return 'SavedSlideOrderState(ids: $ids, ready: $ready, saving: $saving, error: $error)';
}


}

/// @nodoc
abstract mixin class _$SavedSlideOrderStateCopyWith<$Res> implements $SavedSlideOrderStateCopyWith<$Res> {
  factory _$SavedSlideOrderStateCopyWith(_SavedSlideOrderState value, $Res Function(_SavedSlideOrderState) _then) = __$SavedSlideOrderStateCopyWithImpl;
@override @useResult
$Res call({
 List<String> ids, bool ready, bool saving, String? error
});




}
/// @nodoc
class __$SavedSlideOrderStateCopyWithImpl<$Res>
    implements _$SavedSlideOrderStateCopyWith<$Res> {
  __$SavedSlideOrderStateCopyWithImpl(this._self, this._then);

  final _SavedSlideOrderState _self;
  final $Res Function(_SavedSlideOrderState) _then;

/// Create a copy of SavedSlideOrderState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ids = null,Object? ready = null,Object? saving = null,Object? error = freezed,}) {
  return _then(_SavedSlideOrderState(
ids: null == ids ? _self._ids : ids // ignore: cast_nullable_to_non_nullable
as List<String>,ready: null == ready ? _self.ready : ready // ignore: cast_nullable_to_non_nullable
as bool,saving: null == saving ? _self.saving : saving // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
