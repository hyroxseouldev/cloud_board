// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workout.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Workout {

 String get id; String get ownerId; WorkoutAuthor get author; String get name; String get folder; String get brandL; String get brandR; List<WorkoutModule> get modules; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of Workout
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkoutCopyWith<Workout> get copyWith => _$WorkoutCopyWithImpl<Workout>(this as Workout, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Workout;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Workout&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.ownerId, _this.ownerId) || other.ownerId == _this.ownerId)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.folder, _this.folder) || other.folder == _this.folder)&&(identical(other.brandL, _this.brandL) || other.brandL == _this.brandL)&&(identical(other.brandR, _this.brandR) || other.brandR == _this.brandR)&&const DeepCollectionEquality().equals(other.modules, _this.modules)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}


@override
int get hashCode {
  final _this = this as Workout;
  return Object.hash(runtimeType,_this.id,_this.ownerId,_this.author,_this.name,_this.folder,_this.brandL,_this.brandR,const DeepCollectionEquality().hash(_this.modules),_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as Workout;
  return 'Workout(id: ${_this.id}, ownerId: ${_this.ownerId}, author: ${_this.author}, name: ${_this.name}, folder: ${_this.folder}, brandL: ${_this.brandL}, brandR: ${_this.brandR}, modules: ${_this.modules}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $WorkoutCopyWith<$Res>  {
  factory $WorkoutCopyWith(Workout value, $Res Function(Workout) _then) = _$WorkoutCopyWithImpl;
@useResult
$Res call({
 String id, String ownerId, WorkoutAuthor author, String name, String folder, String brandL, String brandR, List<WorkoutModule> modules, DateTime createdAt, DateTime updatedAt
});


$WorkoutAuthorCopyWith<$Res> get author;

}
/// @nodoc
class _$WorkoutCopyWithImpl<$Res>
    implements $WorkoutCopyWith<$Res> {
  _$WorkoutCopyWithImpl(this._self, this._then);

  final Workout _self;
  final $Res Function(Workout) _then;

/// Create a copy of Workout
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ownerId = null,Object? author = null,Object? name = null,Object? folder = null,Object? brandL = null,Object? brandR = null,Object? modules = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(Workout(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as WorkoutAuthor,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,folder: null == folder ? _self.folder : folder // ignore: cast_nullable_to_non_nullable
as String,brandL: null == brandL ? _self.brandL : brandL // ignore: cast_nullable_to_non_nullable
as String,brandR: null == brandR ? _self.brandR : brandR // ignore: cast_nullable_to_non_nullable
as String,modules: null == modules ? _self.modules : modules // ignore: cast_nullable_to_non_nullable
as List<WorkoutModule>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of Workout
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutAuthorCopyWith<$Res> get author {
  
  return $WorkoutAuthorCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}


/// Adds pattern-matching-related methods to [Workout].
extension WorkoutPatterns on Workout {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Workout value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Workout() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Workout value)  $default,){
final _that = this;
switch (_that) {
case _Workout():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Workout value)?  $default,){
final _that = this;
switch (_that) {
case _Workout() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String ownerId,  WorkoutAuthor author,  String name,  String folder,  String brandL,  String brandR,  List<WorkoutModule> modules,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Workout() when $default != null:
return $default(_that.id,_that.ownerId,_that.author,_that.name,_that.folder,_that.brandL,_that.brandR,_that.modules,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String ownerId,  WorkoutAuthor author,  String name,  String folder,  String brandL,  String brandR,  List<WorkoutModule> modules,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Workout():
return $default(_that.id,_that.ownerId,_that.author,_that.name,_that.folder,_that.brandL,_that.brandR,_that.modules,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String ownerId,  WorkoutAuthor author,  String name,  String folder,  String brandL,  String brandR,  List<WorkoutModule> modules,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Workout() when $default != null:
return $default(_that.id,_that.ownerId,_that.author,_that.name,_that.folder,_that.brandL,_that.brandR,_that.modules,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _Workout implements Workout {
  const _Workout({required this.id, required this.ownerId, required this.author, required this.name, required this.folder, required this.brandL, required this.brandR, required  List<WorkoutModule> modules, required this.createdAt, required this.updatedAt}): _modules = modules;
  

@override final  String id;
@override final  String ownerId;
@override final  WorkoutAuthor author;
@override final  String name;
@override final  String folder;
@override final  String brandL;
@override final  String brandR;
 final  List<WorkoutModule> _modules;
@override List<WorkoutModule> get modules {
  if (_modules is EqualUnmodifiableListView) return _modules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_modules);
}

@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of Workout
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkoutCopyWith<_Workout> get copyWith => __$WorkoutCopyWithImpl<_Workout>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Workout&&(identical(other.id, id) || other.id == id)&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId)&&(identical(other.author, author) || other.author == author)&&(identical(other.name, name) || other.name == name)&&(identical(other.folder, folder) || other.folder == folder)&&(identical(other.brandL, brandL) || other.brandL == brandL)&&(identical(other.brandR, brandR) || other.brandR == brandR)&&const DeepCollectionEquality().equals(other.modules, _modules)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,ownerId,author,name,folder,brandL,brandR,const DeepCollectionEquality().hash(_modules),createdAt,updatedAt);
}

@override
String toString() {
    return 'Workout(id: $id, ownerId: $ownerId, author: $author, name: $name, folder: $folder, brandL: $brandL, brandR: $brandR, modules: $modules, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$WorkoutCopyWith<$Res> implements $WorkoutCopyWith<$Res> {
  factory _$WorkoutCopyWith(_Workout value, $Res Function(_Workout) _then) = __$WorkoutCopyWithImpl;
@override @useResult
$Res call({
 String id, String ownerId, WorkoutAuthor author, String name, String folder, String brandL, String brandR, List<WorkoutModule> modules, DateTime createdAt, DateTime updatedAt
});


@override $WorkoutAuthorCopyWith<$Res> get author;

}
/// @nodoc
class __$WorkoutCopyWithImpl<$Res>
    implements _$WorkoutCopyWith<$Res> {
  __$WorkoutCopyWithImpl(this._self, this._then);

  final _Workout _self;
  final $Res Function(_Workout) _then;

/// Create a copy of Workout
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ownerId = null,Object? author = null,Object? name = null,Object? folder = null,Object? brandL = null,Object? brandR = null,Object? modules = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Workout(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as WorkoutAuthor,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,folder: null == folder ? _self.folder : folder // ignore: cast_nullable_to_non_nullable
as String,brandL: null == brandL ? _self.brandL : brandL // ignore: cast_nullable_to_non_nullable
as String,brandR: null == brandR ? _self.brandR : brandR // ignore: cast_nullable_to_non_nullable
as String,modules: null == modules ? _self._modules : modules // ignore: cast_nullable_to_non_nullable
as List<WorkoutModule>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of Workout
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutAuthorCopyWith<$Res> get author {
  
  return $WorkoutAuthorCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}

/// @nodoc
mixin _$WorkoutAuthor {

 String get id; String get displayName; String? get photoUrl;
/// Create a copy of WorkoutAuthor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkoutAuthorCopyWith<WorkoutAuthor> get copyWith => _$WorkoutAuthorCopyWithImpl<WorkoutAuthor>(this as WorkoutAuthor, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WorkoutAuthor;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkoutAuthor&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.photoUrl, _this.photoUrl) || other.photoUrl == _this.photoUrl));
}


@override
int get hashCode {
  final _this = this as WorkoutAuthor;
  return Object.hash(runtimeType,_this.id,_this.displayName,_this.photoUrl);
}

@override
String toString() {
  final _this = this as WorkoutAuthor;
  return 'WorkoutAuthor(id: ${_this.id}, displayName: ${_this.displayName}, photoUrl: ${_this.photoUrl})';
}


}

/// @nodoc
abstract mixin class $WorkoutAuthorCopyWith<$Res>  {
  factory $WorkoutAuthorCopyWith(WorkoutAuthor value, $Res Function(WorkoutAuthor) _then) = _$WorkoutAuthorCopyWithImpl;
@useResult
$Res call({
 String id, String displayName, String? photoUrl
});




}
/// @nodoc
class _$WorkoutAuthorCopyWithImpl<$Res>
    implements $WorkoutAuthorCopyWith<$Res> {
  _$WorkoutAuthorCopyWithImpl(this._self, this._then);

  final WorkoutAuthor _self;
  final $Res Function(WorkoutAuthor) _then;

/// Create a copy of WorkoutAuthor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? photoUrl = freezed,}) {
  return _then(WorkoutAuthor(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkoutAuthor].
extension WorkoutAuthorPatterns on WorkoutAuthor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkoutAuthor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkoutAuthor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkoutAuthor value)  $default,){
final _that = this;
switch (_that) {
case _WorkoutAuthor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkoutAuthor value)?  $default,){
final _that = this;
switch (_that) {
case _WorkoutAuthor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String displayName,  String? photoUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkoutAuthor() when $default != null:
return $default(_that.id,_that.displayName,_that.photoUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String displayName,  String? photoUrl)  $default,) {final _that = this;
switch (_that) {
case _WorkoutAuthor():
return $default(_that.id,_that.displayName,_that.photoUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String displayName,  String? photoUrl)?  $default,) {final _that = this;
switch (_that) {
case _WorkoutAuthor() when $default != null:
return $default(_that.id,_that.displayName,_that.photoUrl);case _:
  return null;

}
}

}

/// @nodoc


class _WorkoutAuthor implements WorkoutAuthor {
  const _WorkoutAuthor({required this.id, required this.displayName, required this.photoUrl});
  

@override final  String id;
@override final  String displayName;
@override final  String? photoUrl;

/// Create a copy of WorkoutAuthor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkoutAuthorCopyWith<_WorkoutAuthor> get copyWith => __$WorkoutAuthorCopyWithImpl<_WorkoutAuthor>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkoutAuthor&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,displayName,photoUrl);
}

@override
String toString() {
    return 'WorkoutAuthor(id: $id, displayName: $displayName, photoUrl: $photoUrl)';
}


}

/// @nodoc
abstract mixin class _$WorkoutAuthorCopyWith<$Res> implements $WorkoutAuthorCopyWith<$Res> {
  factory _$WorkoutAuthorCopyWith(_WorkoutAuthor value, $Res Function(_WorkoutAuthor) _then) = __$WorkoutAuthorCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName, String? photoUrl
});




}
/// @nodoc
class __$WorkoutAuthorCopyWithImpl<$Res>
    implements _$WorkoutAuthorCopyWith<$Res> {
  __$WorkoutAuthorCopyWithImpl(this._self, this._then);

  final _WorkoutAuthor _self;
  final $Res Function(_WorkoutAuthor) _then;

/// Create a copy of WorkoutAuthor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? photoUrl = freezed,}) {
  return _then(_WorkoutAuthor(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$WorkoutModule {

 String get id; String get name; int get workSeconds; int get sets; int get restSeconds; String get text; String get imageSource; bool get showTimer; bool get beep; bool get coverImage;
/// Create a copy of WorkoutModule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkoutModuleCopyWith<WorkoutModule> get copyWith => _$WorkoutModuleCopyWithImpl<WorkoutModule>(this as WorkoutModule, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WorkoutModule;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkoutModule&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.workSeconds, _this.workSeconds) || other.workSeconds == _this.workSeconds)&&(identical(other.sets, _this.sets) || other.sets == _this.sets)&&(identical(other.restSeconds, _this.restSeconds) || other.restSeconds == _this.restSeconds)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.imageSource, _this.imageSource) || other.imageSource == _this.imageSource)&&(identical(other.showTimer, _this.showTimer) || other.showTimer == _this.showTimer)&&(identical(other.beep, _this.beep) || other.beep == _this.beep)&&(identical(other.coverImage, _this.coverImage) || other.coverImage == _this.coverImage));
}


@override
int get hashCode {
  final _this = this as WorkoutModule;
  return Object.hash(runtimeType,_this.id,_this.name,_this.workSeconds,_this.sets,_this.restSeconds,_this.text,_this.imageSource,_this.showTimer,_this.beep,_this.coverImage);
}

@override
String toString() {
  final _this = this as WorkoutModule;
  return 'WorkoutModule(id: ${_this.id}, name: ${_this.name}, workSeconds: ${_this.workSeconds}, sets: ${_this.sets}, restSeconds: ${_this.restSeconds}, text: ${_this.text}, imageSource: ${_this.imageSource}, showTimer: ${_this.showTimer}, beep: ${_this.beep}, coverImage: ${_this.coverImage})';
}


}

/// @nodoc
abstract mixin class $WorkoutModuleCopyWith<$Res>  {
  factory $WorkoutModuleCopyWith(WorkoutModule value, $Res Function(WorkoutModule) _then) = _$WorkoutModuleCopyWithImpl;
@useResult
$Res call({
 String id, String name, int workSeconds, int sets, int restSeconds, String text, String imageSource, bool showTimer, bool beep, bool coverImage
});




}
/// @nodoc
class _$WorkoutModuleCopyWithImpl<$Res>
    implements $WorkoutModuleCopyWith<$Res> {
  _$WorkoutModuleCopyWithImpl(this._self, this._then);

  final WorkoutModule _self;
  final $Res Function(WorkoutModule) _then;

/// Create a copy of WorkoutModule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? workSeconds = null,Object? sets = null,Object? restSeconds = null,Object? text = null,Object? imageSource = null,Object? showTimer = null,Object? beep = null,Object? coverImage = null,}) {
  return _then(WorkoutModule(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,workSeconds: null == workSeconds ? _self.workSeconds : workSeconds // ignore: cast_nullable_to_non_nullable
as int,sets: null == sets ? _self.sets : sets // ignore: cast_nullable_to_non_nullable
as int,restSeconds: null == restSeconds ? _self.restSeconds : restSeconds // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,imageSource: null == imageSource ? _self.imageSource : imageSource // ignore: cast_nullable_to_non_nullable
as String,showTimer: null == showTimer ? _self.showTimer : showTimer // ignore: cast_nullable_to_non_nullable
as bool,beep: null == beep ? _self.beep : beep // ignore: cast_nullable_to_non_nullable
as bool,coverImage: null == coverImage ? _self.coverImage : coverImage // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkoutModule].
extension WorkoutModulePatterns on WorkoutModule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkoutModule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkoutModule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkoutModule value)  $default,){
final _that = this;
switch (_that) {
case _WorkoutModule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkoutModule value)?  $default,){
final _that = this;
switch (_that) {
case _WorkoutModule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  int workSeconds,  int sets,  int restSeconds,  String text,  String imageSource,  bool showTimer,  bool beep,  bool coverImage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkoutModule() when $default != null:
return $default(_that.id,_that.name,_that.workSeconds,_that.sets,_that.restSeconds,_that.text,_that.imageSource,_that.showTimer,_that.beep,_that.coverImage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  int workSeconds,  int sets,  int restSeconds,  String text,  String imageSource,  bool showTimer,  bool beep,  bool coverImage)  $default,) {final _that = this;
switch (_that) {
case _WorkoutModule():
return $default(_that.id,_that.name,_that.workSeconds,_that.sets,_that.restSeconds,_that.text,_that.imageSource,_that.showTimer,_that.beep,_that.coverImage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  int workSeconds,  int sets,  int restSeconds,  String text,  String imageSource,  bool showTimer,  bool beep,  bool coverImage)?  $default,) {final _that = this;
switch (_that) {
case _WorkoutModule() when $default != null:
return $default(_that.id,_that.name,_that.workSeconds,_that.sets,_that.restSeconds,_that.text,_that.imageSource,_that.showTimer,_that.beep,_that.coverImage);case _:
  return null;

}
}

}

/// @nodoc


class _WorkoutModule implements WorkoutModule {
  const _WorkoutModule({required this.id, required this.name, required this.workSeconds, required this.sets, required this.restSeconds, required this.text, required this.imageSource, required this.showTimer, required this.beep, required this.coverImage});
  

@override final  String id;
@override final  String name;
@override final  int workSeconds;
@override final  int sets;
@override final  int restSeconds;
@override final  String text;
@override final  String imageSource;
@override final  bool showTimer;
@override final  bool beep;
@override final  bool coverImage;

/// Create a copy of WorkoutModule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkoutModuleCopyWith<_WorkoutModule> get copyWith => __$WorkoutModuleCopyWithImpl<_WorkoutModule>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkoutModule&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.workSeconds, workSeconds) || other.workSeconds == workSeconds)&&(identical(other.sets, sets) || other.sets == sets)&&(identical(other.restSeconds, restSeconds) || other.restSeconds == restSeconds)&&(identical(other.text, text) || other.text == text)&&(identical(other.imageSource, imageSource) || other.imageSource == imageSource)&&(identical(other.showTimer, showTimer) || other.showTimer == showTimer)&&(identical(other.beep, beep) || other.beep == beep)&&(identical(other.coverImage, coverImage) || other.coverImage == coverImage));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,workSeconds,sets,restSeconds,text,imageSource,showTimer,beep,coverImage);
}

@override
String toString() {
    return 'WorkoutModule(id: $id, name: $name, workSeconds: $workSeconds, sets: $sets, restSeconds: $restSeconds, text: $text, imageSource: $imageSource, showTimer: $showTimer, beep: $beep, coverImage: $coverImage)';
}


}

/// @nodoc
abstract mixin class _$WorkoutModuleCopyWith<$Res> implements $WorkoutModuleCopyWith<$Res> {
  factory _$WorkoutModuleCopyWith(_WorkoutModule value, $Res Function(_WorkoutModule) _then) = __$WorkoutModuleCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, int workSeconds, int sets, int restSeconds, String text, String imageSource, bool showTimer, bool beep, bool coverImage
});




}
/// @nodoc
class __$WorkoutModuleCopyWithImpl<$Res>
    implements _$WorkoutModuleCopyWith<$Res> {
  __$WorkoutModuleCopyWithImpl(this._self, this._then);

  final _WorkoutModule _self;
  final $Res Function(_WorkoutModule) _then;

/// Create a copy of WorkoutModule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? workSeconds = null,Object? sets = null,Object? restSeconds = null,Object? text = null,Object? imageSource = null,Object? showTimer = null,Object? beep = null,Object? coverImage = null,}) {
  return _then(_WorkoutModule(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,workSeconds: null == workSeconds ? _self.workSeconds : workSeconds // ignore: cast_nullable_to_non_nullable
as int,sets: null == sets ? _self.sets : sets // ignore: cast_nullable_to_non_nullable
as int,restSeconds: null == restSeconds ? _self.restSeconds : restSeconds // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,imageSource: null == imageSource ? _self.imageSource : imageSource // ignore: cast_nullable_to_non_nullable
as String,showTimer: null == showTimer ? _self.showTimer : showTimer // ignore: cast_nullable_to_non_nullable
as bool,beep: null == beep ? _self.beep : beep // ignore: cast_nullable_to_non_nullable
as bool,coverImage: null == coverImage ? _self.coverImage : coverImage // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
