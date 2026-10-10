// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'exploration_progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ExplorationProgress {

 String get templateKey; String get purpose; bool get pendingImport; List<String> get completedTemplates; List<String> get events;
/// Create a copy of ExplorationProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExplorationProgressCopyWith<ExplorationProgress> get copyWith => _$ExplorationProgressCopyWithImpl<ExplorationProgress>(this as ExplorationProgress, _$identity);

  /// Serializes this ExplorationProgress to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ExplorationProgress;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExplorationProgress&&(identical(other.templateKey, _this.templateKey) || other.templateKey == _this.templateKey)&&(identical(other.purpose, _this.purpose) || other.purpose == _this.purpose)&&(identical(other.pendingImport, _this.pendingImport) || other.pendingImport == _this.pendingImport)&&const DeepCollectionEquality().equals(other.completedTemplates, _this.completedTemplates)&&const DeepCollectionEquality().equals(other.events, _this.events));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ExplorationProgress;
  return Object.hash(runtimeType,_this.templateKey,_this.purpose,_this.pendingImport,const DeepCollectionEquality().hash(_this.completedTemplates),const DeepCollectionEquality().hash(_this.events));
}

@override
String toString() {
  final _this = this as ExplorationProgress;
  return 'ExplorationProgress(templateKey: ${_this.templateKey}, purpose: ${_this.purpose}, pendingImport: ${_this.pendingImport}, completedTemplates: ${_this.completedTemplates}, events: ${_this.events})';
}


}

/// @nodoc
abstract mixin class $ExplorationProgressCopyWith<$Res>  {
  factory $ExplorationProgressCopyWith(ExplorationProgress value, $Res Function(ExplorationProgress) _then) = _$ExplorationProgressCopyWithImpl;
@useResult
$Res call({
 String templateKey, String purpose, bool pendingImport, List<String> completedTemplates, List<String> events
});




}
/// @nodoc
class _$ExplorationProgressCopyWithImpl<$Res>
    implements $ExplorationProgressCopyWith<$Res> {
  _$ExplorationProgressCopyWithImpl(this._self, this._then);

  final ExplorationProgress _self;
  final $Res Function(ExplorationProgress) _then;

/// Create a copy of ExplorationProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? templateKey = null,Object? purpose = null,Object? pendingImport = null,Object? completedTemplates = null,Object? events = null,}) {
  return _then(ExplorationProgress(
templateKey: null == templateKey ? _self.templateKey : templateKey // ignore: cast_nullable_to_non_nullable
as String,purpose: null == purpose ? _self.purpose : purpose // ignore: cast_nullable_to_non_nullable
as String,pendingImport: null == pendingImport ? _self.pendingImport : pendingImport // ignore: cast_nullable_to_non_nullable
as bool,completedTemplates: null == completedTemplates ? _self.completedTemplates : completedTemplates // ignore: cast_nullable_to_non_nullable
as List<String>,events: null == events ? _self.events : events // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [ExplorationProgress].
extension ExplorationProgressPatterns on ExplorationProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExplorationProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExplorationProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExplorationProgress value)  $default,){
final _that = this;
switch (_that) {
case _ExplorationProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExplorationProgress value)?  $default,){
final _that = this;
switch (_that) {
case _ExplorationProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String templateKey,  String purpose,  bool pendingImport,  List<String> completedTemplates,  List<String> events)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExplorationProgress() when $default != null:
return $default(_that.templateKey,_that.purpose,_that.pendingImport,_that.completedTemplates,_that.events);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String templateKey,  String purpose,  bool pendingImport,  List<String> completedTemplates,  List<String> events)  $default,) {final _that = this;
switch (_that) {
case _ExplorationProgress():
return $default(_that.templateKey,_that.purpose,_that.pendingImport,_that.completedTemplates,_that.events);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String templateKey,  String purpose,  bool pendingImport,  List<String> completedTemplates,  List<String> events)?  $default,) {final _that = this;
switch (_that) {
case _ExplorationProgress() when $default != null:
return $default(_that.templateKey,_that.purpose,_that.pendingImport,_that.completedTemplates,_that.events);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExplorationProgress implements ExplorationProgress {
  const _ExplorationProgress({this.templateKey = 'basics', this.purpose = 'exploring', this.pendingImport = false,  List<String> completedTemplates = const <String>[],  List<String> events = const <String>[]}): _completedTemplates = completedTemplates,_events = events;
  factory _ExplorationProgress.fromJson(Map<String, dynamic> json) => _$ExplorationProgressFromJson(json);

@override@JsonKey() final  String templateKey;
@override@JsonKey() final  String purpose;
@override@JsonKey() final  bool pendingImport;
 final  List<String> _completedTemplates;
@override@JsonKey() List<String> get completedTemplates {
  if (_completedTemplates is EqualUnmodifiableListView) return _completedTemplates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_completedTemplates);
}

 final  List<String> _events;
@override@JsonKey() List<String> get events {
  if (_events is EqualUnmodifiableListView) return _events;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_events);
}


/// Create a copy of ExplorationProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExplorationProgressCopyWith<_ExplorationProgress> get copyWith => __$ExplorationProgressCopyWithImpl<_ExplorationProgress>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExplorationProgressToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExplorationProgress&&(identical(other.templateKey, templateKey) || other.templateKey == templateKey)&&(identical(other.purpose, purpose) || other.purpose == purpose)&&(identical(other.pendingImport, pendingImport) || other.pendingImport == pendingImport)&&const DeepCollectionEquality().equals(other.completedTemplates, _completedTemplates)&&const DeepCollectionEquality().equals(other.events, _events));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,templateKey,purpose,pendingImport,const DeepCollectionEquality().hash(_completedTemplates),const DeepCollectionEquality().hash(_events));
}

@override
String toString() {
    return 'ExplorationProgress(templateKey: $templateKey, purpose: $purpose, pendingImport: $pendingImport, completedTemplates: $completedTemplates, events: $events)';
}


}

/// @nodoc
abstract mixin class _$ExplorationProgressCopyWith<$Res> implements $ExplorationProgressCopyWith<$Res> {
  factory _$ExplorationProgressCopyWith(_ExplorationProgress value, $Res Function(_ExplorationProgress) _then) = __$ExplorationProgressCopyWithImpl;
@override @useResult
$Res call({
 String templateKey, String purpose, bool pendingImport, List<String> completedTemplates, List<String> events
});




}
/// @nodoc
class __$ExplorationProgressCopyWithImpl<$Res>
    implements _$ExplorationProgressCopyWith<$Res> {
  __$ExplorationProgressCopyWithImpl(this._self, this._then);

  final _ExplorationProgress _self;
  final $Res Function(_ExplorationProgress) _then;

/// Create a copy of ExplorationProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? templateKey = null,Object? purpose = null,Object? pendingImport = null,Object? completedTemplates = null,Object? events = null,}) {
  return _then(_ExplorationProgress(
templateKey: null == templateKey ? _self.templateKey : templateKey // ignore: cast_nullable_to_non_nullable
as String,purpose: null == purpose ? _self.purpose : purpose // ignore: cast_nullable_to_non_nullable
as String,pendingImport: null == pendingImport ? _self.pendingImport : pendingImport // ignore: cast_nullable_to_non_nullable
as bool,completedTemplates: null == completedTemplates ? _self._completedTemplates : completedTemplates // ignore: cast_nullable_to_non_nullable
as List<String>,events: null == events ? _self._events : events // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
