// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_timer_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AiTimerAccess {

 bool get premium; bool get enabled; int get remaining; int get limit; DateTime get resetsAt;
/// Create a copy of AiTimerAccess
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiTimerAccessCopyWith<AiTimerAccess> get copyWith => _$AiTimerAccessCopyWithImpl<AiTimerAccess>(this as AiTimerAccess, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AiTimerAccess;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiTimerAccess&&(identical(other.premium, _this.premium) || other.premium == _this.premium)&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.remaining, _this.remaining) || other.remaining == _this.remaining)&&(identical(other.limit, _this.limit) || other.limit == _this.limit)&&(identical(other.resetsAt, _this.resetsAt) || other.resetsAt == _this.resetsAt));
}


@override
int get hashCode {
  final _this = this as AiTimerAccess;
  return Object.hash(runtimeType,_this.premium,_this.enabled,_this.remaining,_this.limit,_this.resetsAt);
}

@override
String toString() {
  final _this = this as AiTimerAccess;
  return 'AiTimerAccess(premium: ${_this.premium}, enabled: ${_this.enabled}, remaining: ${_this.remaining}, limit: ${_this.limit}, resetsAt: ${_this.resetsAt})';
}


}

/// @nodoc
abstract mixin class $AiTimerAccessCopyWith<$Res>  {
  factory $AiTimerAccessCopyWith(AiTimerAccess value, $Res Function(AiTimerAccess) _then) = _$AiTimerAccessCopyWithImpl;
@useResult
$Res call({
 bool premium, bool enabled, int remaining, int limit, DateTime resetsAt
});




}
/// @nodoc
class _$AiTimerAccessCopyWithImpl<$Res>
    implements $AiTimerAccessCopyWith<$Res> {
  _$AiTimerAccessCopyWithImpl(this._self, this._then);

  final AiTimerAccess _self;
  final $Res Function(AiTimerAccess) _then;

/// Create a copy of AiTimerAccess
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? premium = null,Object? enabled = null,Object? remaining = null,Object? limit = null,Object? resetsAt = null,}) {
  return _then(AiTimerAccess(
premium: null == premium ? _self.premium : premium // ignore: cast_nullable_to_non_nullable
as bool,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,resetsAt: null == resetsAt ? _self.resetsAt : resetsAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [AiTimerAccess].
extension AiTimerAccessPatterns on AiTimerAccess {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiTimerAccess value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiTimerAccess() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiTimerAccess value)  $default,){
final _that = this;
switch (_that) {
case _AiTimerAccess():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiTimerAccess value)?  $default,){
final _that = this;
switch (_that) {
case _AiTimerAccess() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool premium,  bool enabled,  int remaining,  int limit,  DateTime resetsAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiTimerAccess() when $default != null:
return $default(_that.premium,_that.enabled,_that.remaining,_that.limit,_that.resetsAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool premium,  bool enabled,  int remaining,  int limit,  DateTime resetsAt)  $default,) {final _that = this;
switch (_that) {
case _AiTimerAccess():
return $default(_that.premium,_that.enabled,_that.remaining,_that.limit,_that.resetsAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool premium,  bool enabled,  int remaining,  int limit,  DateTime resetsAt)?  $default,) {final _that = this;
switch (_that) {
case _AiTimerAccess() when $default != null:
return $default(_that.premium,_that.enabled,_that.remaining,_that.limit,_that.resetsAt);case _:
  return null;

}
}

}

/// @nodoc


class _AiTimerAccess implements AiTimerAccess {
  const _AiTimerAccess({required this.premium, required this.enabled, required this.remaining, required this.limit, required this.resetsAt});


@override final  bool premium;
@override final  bool enabled;
@override final  int remaining;
@override final  int limit;
@override final  DateTime resetsAt;

/// Create a copy of AiTimerAccess
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiTimerAccessCopyWith<_AiTimerAccess> get copyWith => __$AiTimerAccessCopyWithImpl<_AiTimerAccess>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiTimerAccess&&(identical(other.premium, premium) || other.premium == premium)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.resetsAt, resetsAt) || other.resetsAt == resetsAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,premium,enabled,remaining,limit,resetsAt);
}

@override
String toString() {
    return 'AiTimerAccess(premium: $premium, enabled: $enabled, remaining: $remaining, limit: $limit, resetsAt: $resetsAt)';
}


}

/// @nodoc
abstract mixin class _$AiTimerAccessCopyWith<$Res> implements $AiTimerAccessCopyWith<$Res> {
  factory _$AiTimerAccessCopyWith(_AiTimerAccess value, $Res Function(_AiTimerAccess) _then) = __$AiTimerAccessCopyWithImpl;
@override @useResult
$Res call({
 bool premium, bool enabled, int remaining, int limit, DateTime resetsAt
});




}
/// @nodoc
class __$AiTimerAccessCopyWithImpl<$Res>
    implements _$AiTimerAccessCopyWith<$Res> {
  __$AiTimerAccessCopyWithImpl(this._self, this._then);

  final _AiTimerAccess _self;
  final $Res Function(_AiTimerAccess) _then;

/// Create a copy of AiTimerAccess
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? premium = null,Object? enabled = null,Object? remaining = null,Object? limit = null,Object? resetsAt = null,}) {
  return _then(_AiTimerAccess(
premium: null == premium ? _self.premium : premium // ignore: cast_nullable_to_non_nullable
as bool,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,resetsAt: null == resetsAt ? _self.resetsAt : resetsAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
mixin _$AiTimerSuggestion {

 String? get name; int? get workSeconds; int? get restSeconds; int? get sets; List<String> get warnings; bool get cached; int get remaining;
/// Create a copy of AiTimerSuggestion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiTimerSuggestionCopyWith<AiTimerSuggestion> get copyWith => _$AiTimerSuggestionCopyWithImpl<AiTimerSuggestion>(this as AiTimerSuggestion, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AiTimerSuggestion;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiTimerSuggestion&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.workSeconds, _this.workSeconds) || other.workSeconds == _this.workSeconds)&&(identical(other.restSeconds, _this.restSeconds) || other.restSeconds == _this.restSeconds)&&(identical(other.sets, _this.sets) || other.sets == _this.sets)&&const DeepCollectionEquality().equals(other.warnings, _this.warnings)&&(identical(other.cached, _this.cached) || other.cached == _this.cached)&&(identical(other.remaining, _this.remaining) || other.remaining == _this.remaining));
}


@override
int get hashCode {
  final _this = this as AiTimerSuggestion;
  return Object.hash(runtimeType,_this.name,_this.workSeconds,_this.restSeconds,_this.sets,const DeepCollectionEquality().hash(_this.warnings),_this.cached,_this.remaining);
}

@override
String toString() {
  final _this = this as AiTimerSuggestion;
  return 'AiTimerSuggestion(name: ${_this.name}, workSeconds: ${_this.workSeconds}, restSeconds: ${_this.restSeconds}, sets: ${_this.sets}, warnings: ${_this.warnings}, cached: ${_this.cached}, remaining: ${_this.remaining})';
}


}

/// @nodoc
abstract mixin class $AiTimerSuggestionCopyWith<$Res>  {
  factory $AiTimerSuggestionCopyWith(AiTimerSuggestion value, $Res Function(AiTimerSuggestion) _then) = _$AiTimerSuggestionCopyWithImpl;
@useResult
$Res call({
 String? name, int? workSeconds, int? restSeconds, int? sets, List<String> warnings, bool cached, int remaining
});




}
/// @nodoc
class _$AiTimerSuggestionCopyWithImpl<$Res>
    implements $AiTimerSuggestionCopyWith<$Res> {
  _$AiTimerSuggestionCopyWithImpl(this._self, this._then);

  final AiTimerSuggestion _self;
  final $Res Function(AiTimerSuggestion) _then;

/// Create a copy of AiTimerSuggestion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = freezed,Object? workSeconds = freezed,Object? restSeconds = freezed,Object? sets = freezed,Object? warnings = null,Object? cached = null,Object? remaining = null,}) {
  return _then(AiTimerSuggestion(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,workSeconds: freezed == workSeconds ? _self.workSeconds : workSeconds // ignore: cast_nullable_to_non_nullable
as int?,restSeconds: freezed == restSeconds ? _self.restSeconds : restSeconds // ignore: cast_nullable_to_non_nullable
as int?,sets: freezed == sets ? _self.sets : sets // ignore: cast_nullable_to_non_nullable
as int?,warnings: null == warnings ? _self.warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,cached: null == cached ? _self.cached : cached // ignore: cast_nullable_to_non_nullable
as bool,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AiTimerSuggestion].
extension AiTimerSuggestionPatterns on AiTimerSuggestion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiTimerSuggestion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiTimerSuggestion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiTimerSuggestion value)  $default,){
final _that = this;
switch (_that) {
case _AiTimerSuggestion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiTimerSuggestion value)?  $default,){
final _that = this;
switch (_that) {
case _AiTimerSuggestion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? name,  int? workSeconds,  int? restSeconds,  int? sets,  List<String> warnings,  bool cached,  int remaining)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiTimerSuggestion() when $default != null:
return $default(_that.name,_that.workSeconds,_that.restSeconds,_that.sets,_that.warnings,_that.cached,_that.remaining);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? name,  int? workSeconds,  int? restSeconds,  int? sets,  List<String> warnings,  bool cached,  int remaining)  $default,) {final _that = this;
switch (_that) {
case _AiTimerSuggestion():
return $default(_that.name,_that.workSeconds,_that.restSeconds,_that.sets,_that.warnings,_that.cached,_that.remaining);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? name,  int? workSeconds,  int? restSeconds,  int? sets,  List<String> warnings,  bool cached,  int remaining)?  $default,) {final _that = this;
switch (_that) {
case _AiTimerSuggestion() when $default != null:
return $default(_that.name,_that.workSeconds,_that.restSeconds,_that.sets,_that.warnings,_that.cached,_that.remaining);case _:
  return null;

}
}

}

/// @nodoc


class _AiTimerSuggestion implements AiTimerSuggestion {
  const _AiTimerSuggestion({this.name, this.workSeconds, this.restSeconds, this.sets,  List<String> warnings = const [], this.cached = false, required this.remaining}): _warnings = warnings;


@override final  String? name;
@override final  int? workSeconds;
@override final  int? restSeconds;
@override final  int? sets;
 final  List<String> _warnings;
@override@JsonKey() List<String> get warnings {
  if (_warnings is EqualUnmodifiableListView) return _warnings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_warnings);
}

@override@JsonKey() final  bool cached;
@override final  int remaining;

/// Create a copy of AiTimerSuggestion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiTimerSuggestionCopyWith<_AiTimerSuggestion> get copyWith => __$AiTimerSuggestionCopyWithImpl<_AiTimerSuggestion>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiTimerSuggestion&&(identical(other.name, name) || other.name == name)&&(identical(other.workSeconds, workSeconds) || other.workSeconds == workSeconds)&&(identical(other.restSeconds, restSeconds) || other.restSeconds == restSeconds)&&(identical(other.sets, sets) || other.sets == sets)&&const DeepCollectionEquality().equals(other.warnings, _warnings)&&(identical(other.cached, cached) || other.cached == cached)&&(identical(other.remaining, remaining) || other.remaining == remaining));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,workSeconds,restSeconds,sets,const DeepCollectionEquality().hash(_warnings),cached,remaining);
}

@override
String toString() {
    return 'AiTimerSuggestion(name: $name, workSeconds: $workSeconds, restSeconds: $restSeconds, sets: $sets, warnings: $warnings, cached: $cached, remaining: $remaining)';
}


}

/// @nodoc
abstract mixin class _$AiTimerSuggestionCopyWith<$Res> implements $AiTimerSuggestionCopyWith<$Res> {
  factory _$AiTimerSuggestionCopyWith(_AiTimerSuggestion value, $Res Function(_AiTimerSuggestion) _then) = __$AiTimerSuggestionCopyWithImpl;
@override @useResult
$Res call({
 String? name, int? workSeconds, int? restSeconds, int? sets, List<String> warnings, bool cached, int remaining
});




}
/// @nodoc
class __$AiTimerSuggestionCopyWithImpl<$Res>
    implements _$AiTimerSuggestionCopyWith<$Res> {
  __$AiTimerSuggestionCopyWithImpl(this._self, this._then);

  final _AiTimerSuggestion _self;
  final $Res Function(_AiTimerSuggestion) _then;

/// Create a copy of AiTimerSuggestion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = freezed,Object? workSeconds = freezed,Object? restSeconds = freezed,Object? sets = freezed,Object? warnings = null,Object? cached = null,Object? remaining = null,}) {
  return _then(_AiTimerSuggestion(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,workSeconds: freezed == workSeconds ? _self.workSeconds : workSeconds // ignore: cast_nullable_to_non_nullable
as int?,restSeconds: freezed == restSeconds ? _self.restSeconds : restSeconds // ignore: cast_nullable_to_non_nullable
as int?,sets: freezed == sets ? _self.sets : sets // ignore: cast_nullable_to_non_nullable
as int?,warnings: null == warnings ? _self._warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,cached: null == cached ? _self.cached : cached // ignore: cast_nullable_to_non_nullable
as bool,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
