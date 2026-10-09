// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_slide_design.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AiSlideDesign {

 String get id; String get name; String get description; AiSlideTheme get theme; String? get storeId;
/// Create a copy of AiSlideDesign
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiSlideDesignCopyWith<AiSlideDesign> get copyWith => _$AiSlideDesignCopyWithImpl<AiSlideDesign>(this as AiSlideDesign, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AiSlideDesign;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiSlideDesign&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.theme, _this.theme) || other.theme == _this.theme)&&(identical(other.storeId, _this.storeId) || other.storeId == _this.storeId));
}


@override
int get hashCode {
  final _this = this as AiSlideDesign;
  return Object.hash(runtimeType,_this.id,_this.name,_this.description,_this.theme,_this.storeId);
}

@override
String toString() {
  final _this = this as AiSlideDesign;
  return 'AiSlideDesign(id: ${_this.id}, name: ${_this.name}, description: ${_this.description}, theme: ${_this.theme}, storeId: ${_this.storeId})';
}


}

/// @nodoc
abstract mixin class $AiSlideDesignCopyWith<$Res>  {
  factory $AiSlideDesignCopyWith(AiSlideDesign value, $Res Function(AiSlideDesign) _then) = _$AiSlideDesignCopyWithImpl;
@useResult
$Res call({
 String id, String name, String description, AiSlideTheme theme, String? storeId
});


$AiSlideThemeCopyWith<$Res> get theme;

}
/// @nodoc
class _$AiSlideDesignCopyWithImpl<$Res>
    implements $AiSlideDesignCopyWith<$Res> {
  _$AiSlideDesignCopyWithImpl(this._self, this._then);

  final AiSlideDesign _self;
  final $Res Function(AiSlideDesign) _then;

/// Create a copy of AiSlideDesign
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = null,Object? theme = null,Object? storeId = freezed,}) {
  return _then(AiSlideDesign(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as AiSlideTheme,storeId: freezed == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of AiSlideDesign
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiSlideThemeCopyWith<$Res> get theme {
  
  return $AiSlideThemeCopyWith<$Res>(_self.theme, (value) {
    return _then(_self.copyWith(theme: value));
  });
}
}


/// Adds pattern-matching-related methods to [AiSlideDesign].
extension AiSlideDesignPatterns on AiSlideDesign {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiSlideDesign value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiSlideDesign() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiSlideDesign value)  $default,){
final _that = this;
switch (_that) {
case _AiSlideDesign():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiSlideDesign value)?  $default,){
final _that = this;
switch (_that) {
case _AiSlideDesign() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String description,  AiSlideTheme theme,  String? storeId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiSlideDesign() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.theme,_that.storeId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String description,  AiSlideTheme theme,  String? storeId)  $default,) {final _that = this;
switch (_that) {
case _AiSlideDesign():
return $default(_that.id,_that.name,_that.description,_that.theme,_that.storeId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String description,  AiSlideTheme theme,  String? storeId)?  $default,) {final _that = this;
switch (_that) {
case _AiSlideDesign() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.theme,_that.storeId);case _:
  return null;

}
}

}

/// @nodoc


class _AiSlideDesign implements AiSlideDesign {
  const _AiSlideDesign({required this.id, required this.name, this.description = '', required this.theme, this.storeId});
  

@override final  String id;
@override final  String name;
@override@JsonKey() final  String description;
@override final  AiSlideTheme theme;
@override final  String? storeId;

/// Create a copy of AiSlideDesign
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiSlideDesignCopyWith<_AiSlideDesign> get copyWith => __$AiSlideDesignCopyWithImpl<_AiSlideDesign>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiSlideDesign&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.theme, theme) || other.theme == theme)&&(identical(other.storeId, storeId) || other.storeId == storeId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,description,theme,storeId);
}

@override
String toString() {
    return 'AiSlideDesign(id: $id, name: $name, description: $description, theme: $theme, storeId: $storeId)';
}


}

/// @nodoc
abstract mixin class _$AiSlideDesignCopyWith<$Res> implements $AiSlideDesignCopyWith<$Res> {
  factory _$AiSlideDesignCopyWith(_AiSlideDesign value, $Res Function(_AiSlideDesign) _then) = __$AiSlideDesignCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String description, AiSlideTheme theme, String? storeId
});


@override $AiSlideThemeCopyWith<$Res> get theme;

}
/// @nodoc
class __$AiSlideDesignCopyWithImpl<$Res>
    implements _$AiSlideDesignCopyWith<$Res> {
  __$AiSlideDesignCopyWithImpl(this._self, this._then);

  final _AiSlideDesign _self;
  final $Res Function(_AiSlideDesign) _then;

/// Create a copy of AiSlideDesign
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = null,Object? theme = null,Object? storeId = freezed,}) {
  return _then(_AiSlideDesign(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as AiSlideTheme,storeId: freezed == storeId ? _self.storeId : storeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of AiSlideDesign
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiSlideThemeCopyWith<$Res> get theme {
  
  return $AiSlideThemeCopyWith<$Res>(_self.theme, (value) {
    return _then(_self.copyWith(theme: value));
  });
}
}

/// @nodoc
mixin _$AiSlideDesignResult {

 List<AiSlideDesign> get designs; List<String> get warnings; int get remaining; bool get cached;
/// Create a copy of AiSlideDesignResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiSlideDesignResultCopyWith<AiSlideDesignResult> get copyWith => _$AiSlideDesignResultCopyWithImpl<AiSlideDesignResult>(this as AiSlideDesignResult, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AiSlideDesignResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiSlideDesignResult&&const DeepCollectionEquality().equals(other.designs, _this.designs)&&const DeepCollectionEquality().equals(other.warnings, _this.warnings)&&(identical(other.remaining, _this.remaining) || other.remaining == _this.remaining)&&(identical(other.cached, _this.cached) || other.cached == _this.cached));
}


@override
int get hashCode {
  final _this = this as AiSlideDesignResult;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.designs),const DeepCollectionEquality().hash(_this.warnings),_this.remaining,_this.cached);
}

@override
String toString() {
  final _this = this as AiSlideDesignResult;
  return 'AiSlideDesignResult(designs: ${_this.designs}, warnings: ${_this.warnings}, remaining: ${_this.remaining}, cached: ${_this.cached})';
}


}

/// @nodoc
abstract mixin class $AiSlideDesignResultCopyWith<$Res>  {
  factory $AiSlideDesignResultCopyWith(AiSlideDesignResult value, $Res Function(AiSlideDesignResult) _then) = _$AiSlideDesignResultCopyWithImpl;
@useResult
$Res call({
 List<AiSlideDesign> designs, List<String> warnings, int remaining, bool cached
});




}
/// @nodoc
class _$AiSlideDesignResultCopyWithImpl<$Res>
    implements $AiSlideDesignResultCopyWith<$Res> {
  _$AiSlideDesignResultCopyWithImpl(this._self, this._then);

  final AiSlideDesignResult _self;
  final $Res Function(AiSlideDesignResult) _then;

/// Create a copy of AiSlideDesignResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? designs = null,Object? warnings = null,Object? remaining = null,Object? cached = null,}) {
  return _then(AiSlideDesignResult(
designs: null == designs ? _self.designs : designs // ignore: cast_nullable_to_non_nullable
as List<AiSlideDesign>,warnings: null == warnings ? _self.warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,cached: null == cached ? _self.cached : cached // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AiSlideDesignResult].
extension AiSlideDesignResultPatterns on AiSlideDesignResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiSlideDesignResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiSlideDesignResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiSlideDesignResult value)  $default,){
final _that = this;
switch (_that) {
case _AiSlideDesignResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiSlideDesignResult value)?  $default,){
final _that = this;
switch (_that) {
case _AiSlideDesignResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AiSlideDesign> designs,  List<String> warnings,  int remaining,  bool cached)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiSlideDesignResult() when $default != null:
return $default(_that.designs,_that.warnings,_that.remaining,_that.cached);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AiSlideDesign> designs,  List<String> warnings,  int remaining,  bool cached)  $default,) {final _that = this;
switch (_that) {
case _AiSlideDesignResult():
return $default(_that.designs,_that.warnings,_that.remaining,_that.cached);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AiSlideDesign> designs,  List<String> warnings,  int remaining,  bool cached)?  $default,) {final _that = this;
switch (_that) {
case _AiSlideDesignResult() when $default != null:
return $default(_that.designs,_that.warnings,_that.remaining,_that.cached);case _:
  return null;

}
}

}

/// @nodoc


class _AiSlideDesignResult implements AiSlideDesignResult {
  const _AiSlideDesignResult({required  List<AiSlideDesign> designs,  List<String> warnings = const [], required this.remaining, this.cached = false}): _designs = designs,_warnings = warnings;
  

 final  List<AiSlideDesign> _designs;
@override List<AiSlideDesign> get designs {
  if (_designs is EqualUnmodifiableListView) return _designs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_designs);
}

 final  List<String> _warnings;
@override@JsonKey() List<String> get warnings {
  if (_warnings is EqualUnmodifiableListView) return _warnings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_warnings);
}

@override final  int remaining;
@override@JsonKey() final  bool cached;

/// Create a copy of AiSlideDesignResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiSlideDesignResultCopyWith<_AiSlideDesignResult> get copyWith => __$AiSlideDesignResultCopyWithImpl<_AiSlideDesignResult>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiSlideDesignResult&&const DeepCollectionEquality().equals(other.designs, _designs)&&const DeepCollectionEquality().equals(other.warnings, _warnings)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.cached, cached) || other.cached == cached));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_designs),const DeepCollectionEquality().hash(_warnings),remaining,cached);
}

@override
String toString() {
    return 'AiSlideDesignResult(designs: $designs, warnings: $warnings, remaining: $remaining, cached: $cached)';
}


}

/// @nodoc
abstract mixin class _$AiSlideDesignResultCopyWith<$Res> implements $AiSlideDesignResultCopyWith<$Res> {
  factory _$AiSlideDesignResultCopyWith(_AiSlideDesignResult value, $Res Function(_AiSlideDesignResult) _then) = __$AiSlideDesignResultCopyWithImpl;
@override @useResult
$Res call({
 List<AiSlideDesign> designs, List<String> warnings, int remaining, bool cached
});




}
/// @nodoc
class __$AiSlideDesignResultCopyWithImpl<$Res>
    implements _$AiSlideDesignResultCopyWith<$Res> {
  __$AiSlideDesignResultCopyWithImpl(this._self, this._then);

  final _AiSlideDesignResult _self;
  final $Res Function(_AiSlideDesignResult) _then;

/// Create a copy of AiSlideDesignResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? designs = null,Object? warnings = null,Object? remaining = null,Object? cached = null,}) {
  return _then(_AiSlideDesignResult(
designs: null == designs ? _self._designs : designs // ignore: cast_nullable_to_non_nullable
as List<AiSlideDesign>,warnings: null == warnings ? _self._warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,cached: null == cached ? _self.cached : cached // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$AiSlideDesignStudioState {

 List<AiSlideDesign> get proposals; List<AiSlideDesign> get templates; AiSlideDesign? get selected; bool get generating; bool get saving; bool get templatesLoading; bool get saved; List<String> get warnings; String? get error; String? get templateError; int? get remaining;
/// Create a copy of AiSlideDesignStudioState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiSlideDesignStudioStateCopyWith<AiSlideDesignStudioState> get copyWith => _$AiSlideDesignStudioStateCopyWithImpl<AiSlideDesignStudioState>(this as AiSlideDesignStudioState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AiSlideDesignStudioState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiSlideDesignStudioState&&const DeepCollectionEquality().equals(other.proposals, _this.proposals)&&const DeepCollectionEquality().equals(other.templates, _this.templates)&&(identical(other.selected, _this.selected) || other.selected == _this.selected)&&(identical(other.generating, _this.generating) || other.generating == _this.generating)&&(identical(other.saving, _this.saving) || other.saving == _this.saving)&&(identical(other.templatesLoading, _this.templatesLoading) || other.templatesLoading == _this.templatesLoading)&&(identical(other.saved, _this.saved) || other.saved == _this.saved)&&const DeepCollectionEquality().equals(other.warnings, _this.warnings)&&(identical(other.error, _this.error) || other.error == _this.error)&&(identical(other.templateError, _this.templateError) || other.templateError == _this.templateError)&&(identical(other.remaining, _this.remaining) || other.remaining == _this.remaining));
}


@override
int get hashCode {
  final _this = this as AiSlideDesignStudioState;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.proposals),const DeepCollectionEquality().hash(_this.templates),_this.selected,_this.generating,_this.saving,_this.templatesLoading,_this.saved,const DeepCollectionEquality().hash(_this.warnings),_this.error,_this.templateError,_this.remaining);
}

@override
String toString() {
  final _this = this as AiSlideDesignStudioState;
  return 'AiSlideDesignStudioState(proposals: ${_this.proposals}, templates: ${_this.templates}, selected: ${_this.selected}, generating: ${_this.generating}, saving: ${_this.saving}, templatesLoading: ${_this.templatesLoading}, saved: ${_this.saved}, warnings: ${_this.warnings}, error: ${_this.error}, templateError: ${_this.templateError}, remaining: ${_this.remaining})';
}


}

/// @nodoc
abstract mixin class $AiSlideDesignStudioStateCopyWith<$Res>  {
  factory $AiSlideDesignStudioStateCopyWith(AiSlideDesignStudioState value, $Res Function(AiSlideDesignStudioState) _then) = _$AiSlideDesignStudioStateCopyWithImpl;
@useResult
$Res call({
 List<AiSlideDesign> proposals, List<AiSlideDesign> templates, AiSlideDesign? selected, bool generating, bool saving, bool templatesLoading, bool saved, List<String> warnings, String? error, String? templateError, int? remaining
});


$AiSlideDesignCopyWith<$Res>? get selected;

}
/// @nodoc
class _$AiSlideDesignStudioStateCopyWithImpl<$Res>
    implements $AiSlideDesignStudioStateCopyWith<$Res> {
  _$AiSlideDesignStudioStateCopyWithImpl(this._self, this._then);

  final AiSlideDesignStudioState _self;
  final $Res Function(AiSlideDesignStudioState) _then;

/// Create a copy of AiSlideDesignStudioState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? proposals = null,Object? templates = null,Object? selected = freezed,Object? generating = null,Object? saving = null,Object? templatesLoading = null,Object? saved = null,Object? warnings = null,Object? error = freezed,Object? templateError = freezed,Object? remaining = freezed,}) {
  return _then(AiSlideDesignStudioState(
proposals: null == proposals ? _self.proposals : proposals // ignore: cast_nullable_to_non_nullable
as List<AiSlideDesign>,templates: null == templates ? _self.templates : templates // ignore: cast_nullable_to_non_nullable
as List<AiSlideDesign>,selected: freezed == selected ? _self.selected : selected // ignore: cast_nullable_to_non_nullable
as AiSlideDesign?,generating: null == generating ? _self.generating : generating // ignore: cast_nullable_to_non_nullable
as bool,saving: null == saving ? _self.saving : saving // ignore: cast_nullable_to_non_nullable
as bool,templatesLoading: null == templatesLoading ? _self.templatesLoading : templatesLoading // ignore: cast_nullable_to_non_nullable
as bool,saved: null == saved ? _self.saved : saved // ignore: cast_nullable_to_non_nullable
as bool,warnings: null == warnings ? _self.warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,templateError: freezed == templateError ? _self.templateError : templateError // ignore: cast_nullable_to_non_nullable
as String?,remaining: freezed == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of AiSlideDesignStudioState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiSlideDesignCopyWith<$Res>? get selected {
    if (_self.selected == null) {
    return null;
  }

  return $AiSlideDesignCopyWith<$Res>(_self.selected!, (value) {
    return _then(_self.copyWith(selected: value));
  });
}
}


/// Adds pattern-matching-related methods to [AiSlideDesignStudioState].
extension AiSlideDesignStudioStatePatterns on AiSlideDesignStudioState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiSlideDesignStudioState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiSlideDesignStudioState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiSlideDesignStudioState value)  $default,){
final _that = this;
switch (_that) {
case _AiSlideDesignStudioState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiSlideDesignStudioState value)?  $default,){
final _that = this;
switch (_that) {
case _AiSlideDesignStudioState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AiSlideDesign> proposals,  List<AiSlideDesign> templates,  AiSlideDesign? selected,  bool generating,  bool saving,  bool templatesLoading,  bool saved,  List<String> warnings,  String? error,  String? templateError,  int? remaining)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiSlideDesignStudioState() when $default != null:
return $default(_that.proposals,_that.templates,_that.selected,_that.generating,_that.saving,_that.templatesLoading,_that.saved,_that.warnings,_that.error,_that.templateError,_that.remaining);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AiSlideDesign> proposals,  List<AiSlideDesign> templates,  AiSlideDesign? selected,  bool generating,  bool saving,  bool templatesLoading,  bool saved,  List<String> warnings,  String? error,  String? templateError,  int? remaining)  $default,) {final _that = this;
switch (_that) {
case _AiSlideDesignStudioState():
return $default(_that.proposals,_that.templates,_that.selected,_that.generating,_that.saving,_that.templatesLoading,_that.saved,_that.warnings,_that.error,_that.templateError,_that.remaining);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AiSlideDesign> proposals,  List<AiSlideDesign> templates,  AiSlideDesign? selected,  bool generating,  bool saving,  bool templatesLoading,  bool saved,  List<String> warnings,  String? error,  String? templateError,  int? remaining)?  $default,) {final _that = this;
switch (_that) {
case _AiSlideDesignStudioState() when $default != null:
return $default(_that.proposals,_that.templates,_that.selected,_that.generating,_that.saving,_that.templatesLoading,_that.saved,_that.warnings,_that.error,_that.templateError,_that.remaining);case _:
  return null;

}
}

}

/// @nodoc


class _AiSlideDesignStudioState implements AiSlideDesignStudioState {
  const _AiSlideDesignStudioState({ List<AiSlideDesign> proposals = const [],  List<AiSlideDesign> templates = const [], this.selected, this.generating = false, this.saving = false, this.templatesLoading = false, this.saved = false,  List<String> warnings = const [], this.error, this.templateError, this.remaining}): _proposals = proposals,_templates = templates,_warnings = warnings;
  

 final  List<AiSlideDesign> _proposals;
@override@JsonKey() List<AiSlideDesign> get proposals {
  if (_proposals is EqualUnmodifiableListView) return _proposals;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_proposals);
}

 final  List<AiSlideDesign> _templates;
@override@JsonKey() List<AiSlideDesign> get templates {
  if (_templates is EqualUnmodifiableListView) return _templates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_templates);
}

@override final  AiSlideDesign? selected;
@override@JsonKey() final  bool generating;
@override@JsonKey() final  bool saving;
@override@JsonKey() final  bool templatesLoading;
@override@JsonKey() final  bool saved;
 final  List<String> _warnings;
@override@JsonKey() List<String> get warnings {
  if (_warnings is EqualUnmodifiableListView) return _warnings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_warnings);
}

@override final  String? error;
@override final  String? templateError;
@override final  int? remaining;

/// Create a copy of AiSlideDesignStudioState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiSlideDesignStudioStateCopyWith<_AiSlideDesignStudioState> get copyWith => __$AiSlideDesignStudioStateCopyWithImpl<_AiSlideDesignStudioState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiSlideDesignStudioState&&const DeepCollectionEquality().equals(other.proposals, _proposals)&&const DeepCollectionEquality().equals(other.templates, _templates)&&(identical(other.selected, selected) || other.selected == selected)&&(identical(other.generating, generating) || other.generating == generating)&&(identical(other.saving, saving) || other.saving == saving)&&(identical(other.templatesLoading, templatesLoading) || other.templatesLoading == templatesLoading)&&(identical(other.saved, saved) || other.saved == saved)&&const DeepCollectionEquality().equals(other.warnings, _warnings)&&(identical(other.error, error) || other.error == error)&&(identical(other.templateError, templateError) || other.templateError == templateError)&&(identical(other.remaining, remaining) || other.remaining == remaining));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_proposals),const DeepCollectionEquality().hash(_templates),selected,generating,saving,templatesLoading,saved,const DeepCollectionEquality().hash(_warnings),error,templateError,remaining);
}

@override
String toString() {
    return 'AiSlideDesignStudioState(proposals: $proposals, templates: $templates, selected: $selected, generating: $generating, saving: $saving, templatesLoading: $templatesLoading, saved: $saved, warnings: $warnings, error: $error, templateError: $templateError, remaining: $remaining)';
}


}

/// @nodoc
abstract mixin class _$AiSlideDesignStudioStateCopyWith<$Res> implements $AiSlideDesignStudioStateCopyWith<$Res> {
  factory _$AiSlideDesignStudioStateCopyWith(_AiSlideDesignStudioState value, $Res Function(_AiSlideDesignStudioState) _then) = __$AiSlideDesignStudioStateCopyWithImpl;
@override @useResult
$Res call({
 List<AiSlideDesign> proposals, List<AiSlideDesign> templates, AiSlideDesign? selected, bool generating, bool saving, bool templatesLoading, bool saved, List<String> warnings, String? error, String? templateError, int? remaining
});


@override $AiSlideDesignCopyWith<$Res>? get selected;

}
/// @nodoc
class __$AiSlideDesignStudioStateCopyWithImpl<$Res>
    implements _$AiSlideDesignStudioStateCopyWith<$Res> {
  __$AiSlideDesignStudioStateCopyWithImpl(this._self, this._then);

  final _AiSlideDesignStudioState _self;
  final $Res Function(_AiSlideDesignStudioState) _then;

/// Create a copy of AiSlideDesignStudioState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? proposals = null,Object? templates = null,Object? selected = freezed,Object? generating = null,Object? saving = null,Object? templatesLoading = null,Object? saved = null,Object? warnings = null,Object? error = freezed,Object? templateError = freezed,Object? remaining = freezed,}) {
  return _then(_AiSlideDesignStudioState(
proposals: null == proposals ? _self._proposals : proposals // ignore: cast_nullable_to_non_nullable
as List<AiSlideDesign>,templates: null == templates ? _self._templates : templates // ignore: cast_nullable_to_non_nullable
as List<AiSlideDesign>,selected: freezed == selected ? _self.selected : selected // ignore: cast_nullable_to_non_nullable
as AiSlideDesign?,generating: null == generating ? _self.generating : generating // ignore: cast_nullable_to_non_nullable
as bool,saving: null == saving ? _self.saving : saving // ignore: cast_nullable_to_non_nullable
as bool,templatesLoading: null == templatesLoading ? _self.templatesLoading : templatesLoading // ignore: cast_nullable_to_non_nullable
as bool,saved: null == saved ? _self.saved : saved // ignore: cast_nullable_to_non_nullable
as bool,warnings: null == warnings ? _self._warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,templateError: freezed == templateError ? _self.templateError : templateError // ignore: cast_nullable_to_non_nullable
as String?,remaining: freezed == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of AiSlideDesignStudioState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiSlideDesignCopyWith<$Res>? get selected {
    if (_self.selected == null) {
    return null;
  }

  return $AiSlideDesignCopyWith<$Res>(_self.selected!, (value) {
    return _then(_self.copyWith(selected: value));
  });
}
}

// dart format on
