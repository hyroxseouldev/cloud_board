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

 String get id; String get ownerId; WorkoutAuthor get author; String get name; String get folder; String get brandL; String get brandR; WorkoutSoundTheme get soundTheme; WorkoutSound get countdownSound; WorkoutSound get workStartSound; WorkoutSound get restStartSound; WorkoutSound get workoutEndSound; double get soundVolume; List<WorkoutModule> get modules; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of Workout
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkoutCopyWith<Workout> get copyWith => _$WorkoutCopyWithImpl<Workout>(this as Workout, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Workout;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Workout&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.ownerId, _this.ownerId) || other.ownerId == _this.ownerId)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.folder, _this.folder) || other.folder == _this.folder)&&(identical(other.brandL, _this.brandL) || other.brandL == _this.brandL)&&(identical(other.brandR, _this.brandR) || other.brandR == _this.brandR)&&(identical(other.soundTheme, _this.soundTheme) || other.soundTheme == _this.soundTheme)&&(identical(other.countdownSound, _this.countdownSound) || other.countdownSound == _this.countdownSound)&&(identical(other.workStartSound, _this.workStartSound) || other.workStartSound == _this.workStartSound)&&(identical(other.restStartSound, _this.restStartSound) || other.restStartSound == _this.restStartSound)&&(identical(other.workoutEndSound, _this.workoutEndSound) || other.workoutEndSound == _this.workoutEndSound)&&(identical(other.soundVolume, _this.soundVolume) || other.soundVolume == _this.soundVolume)&&const DeepCollectionEquality().equals(other.modules, _this.modules)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}


@override
int get hashCode {
  final _this = this as Workout;
  return Object.hash(runtimeType,_this.id,_this.ownerId,_this.author,_this.name,_this.folder,_this.brandL,_this.brandR,_this.soundTheme,_this.countdownSound,_this.workStartSound,_this.restStartSound,_this.workoutEndSound,_this.soundVolume,const DeepCollectionEquality().hash(_this.modules),_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as Workout;
  return 'Workout(id: ${_this.id}, ownerId: ${_this.ownerId}, author: ${_this.author}, name: ${_this.name}, folder: ${_this.folder}, brandL: ${_this.brandL}, brandR: ${_this.brandR}, soundTheme: ${_this.soundTheme}, countdownSound: ${_this.countdownSound}, workStartSound: ${_this.workStartSound}, restStartSound: ${_this.restStartSound}, workoutEndSound: ${_this.workoutEndSound}, soundVolume: ${_this.soundVolume}, modules: ${_this.modules}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $WorkoutCopyWith<$Res>  {
  factory $WorkoutCopyWith(Workout value, $Res Function(Workout) _then) = _$WorkoutCopyWithImpl;
@useResult
$Res call({
 String id, String ownerId, WorkoutAuthor author, String name, String folder, String brandL, String brandR, WorkoutSoundTheme soundTheme, WorkoutSound countdownSound, WorkoutSound workStartSound, WorkoutSound restStartSound, WorkoutSound workoutEndSound, double soundVolume, List<WorkoutModule> modules, DateTime createdAt, DateTime updatedAt
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ownerId = null,Object? author = null,Object? name = null,Object? folder = null,Object? brandL = null,Object? brandR = null,Object? soundTheme = null,Object? countdownSound = null,Object? workStartSound = null,Object? restStartSound = null,Object? workoutEndSound = null,Object? soundVolume = null,Object? modules = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(Workout(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as WorkoutAuthor,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,folder: null == folder ? _self.folder : folder // ignore: cast_nullable_to_non_nullable
as String,brandL: null == brandL ? _self.brandL : brandL // ignore: cast_nullable_to_non_nullable
as String,brandR: null == brandR ? _self.brandR : brandR // ignore: cast_nullable_to_non_nullable
as String,soundTheme: null == soundTheme ? _self.soundTheme : soundTheme // ignore: cast_nullable_to_non_nullable
as WorkoutSoundTheme,countdownSound: null == countdownSound ? _self.countdownSound : countdownSound // ignore: cast_nullable_to_non_nullable
as WorkoutSound,workStartSound: null == workStartSound ? _self.workStartSound : workStartSound // ignore: cast_nullable_to_non_nullable
as WorkoutSound,restStartSound: null == restStartSound ? _self.restStartSound : restStartSound // ignore: cast_nullable_to_non_nullable
as WorkoutSound,workoutEndSound: null == workoutEndSound ? _self.workoutEndSound : workoutEndSound // ignore: cast_nullable_to_non_nullable
as WorkoutSound,soundVolume: null == soundVolume ? _self.soundVolume : soundVolume // ignore: cast_nullable_to_non_nullable
as double,modules: null == modules ? _self.modules : modules // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String ownerId,  WorkoutAuthor author,  String name,  String folder,  String brandL,  String brandR,  WorkoutSoundTheme soundTheme,  WorkoutSound countdownSound,  WorkoutSound workStartSound,  WorkoutSound restStartSound,  WorkoutSound workoutEndSound,  double soundVolume,  List<WorkoutModule> modules,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Workout() when $default != null:
return $default(_that.id,_that.ownerId,_that.author,_that.name,_that.folder,_that.brandL,_that.brandR,_that.soundTheme,_that.countdownSound,_that.workStartSound,_that.restStartSound,_that.workoutEndSound,_that.soundVolume,_that.modules,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String ownerId,  WorkoutAuthor author,  String name,  String folder,  String brandL,  String brandR,  WorkoutSoundTheme soundTheme,  WorkoutSound countdownSound,  WorkoutSound workStartSound,  WorkoutSound restStartSound,  WorkoutSound workoutEndSound,  double soundVolume,  List<WorkoutModule> modules,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Workout():
return $default(_that.id,_that.ownerId,_that.author,_that.name,_that.folder,_that.brandL,_that.brandR,_that.soundTheme,_that.countdownSound,_that.workStartSound,_that.restStartSound,_that.workoutEndSound,_that.soundVolume,_that.modules,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String ownerId,  WorkoutAuthor author,  String name,  String folder,  String brandL,  String brandR,  WorkoutSoundTheme soundTheme,  WorkoutSound countdownSound,  WorkoutSound workStartSound,  WorkoutSound restStartSound,  WorkoutSound workoutEndSound,  double soundVolume,  List<WorkoutModule> modules,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Workout() when $default != null:
return $default(_that.id,_that.ownerId,_that.author,_that.name,_that.folder,_that.brandL,_that.brandR,_that.soundTheme,_that.countdownSound,_that.workStartSound,_that.restStartSound,_that.workoutEndSound,_that.soundVolume,_that.modules,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _Workout implements Workout {
  const _Workout({required this.id, required this.ownerId, required this.author, required this.name, required this.folder, required this.brandL, required this.brandR, required this.soundTheme, required this.countdownSound, required this.workStartSound, required this.restStartSound, required this.workoutEndSound, required this.soundVolume, required  List<WorkoutModule> modules, required this.createdAt, required this.updatedAt}): _modules = modules;
  

@override final  String id;
@override final  String ownerId;
@override final  WorkoutAuthor author;
@override final  String name;
@override final  String folder;
@override final  String brandL;
@override final  String brandR;
@override final  WorkoutSoundTheme soundTheme;
@override final  WorkoutSound countdownSound;
@override final  WorkoutSound workStartSound;
@override final  WorkoutSound restStartSound;
@override final  WorkoutSound workoutEndSound;
@override final  double soundVolume;
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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Workout&&(identical(other.id, id) || other.id == id)&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId)&&(identical(other.author, author) || other.author == author)&&(identical(other.name, name) || other.name == name)&&(identical(other.folder, folder) || other.folder == folder)&&(identical(other.brandL, brandL) || other.brandL == brandL)&&(identical(other.brandR, brandR) || other.brandR == brandR)&&(identical(other.soundTheme, soundTheme) || other.soundTheme == soundTheme)&&(identical(other.countdownSound, countdownSound) || other.countdownSound == countdownSound)&&(identical(other.workStartSound, workStartSound) || other.workStartSound == workStartSound)&&(identical(other.restStartSound, restStartSound) || other.restStartSound == restStartSound)&&(identical(other.workoutEndSound, workoutEndSound) || other.workoutEndSound == workoutEndSound)&&(identical(other.soundVolume, soundVolume) || other.soundVolume == soundVolume)&&const DeepCollectionEquality().equals(other.modules, _modules)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,ownerId,author,name,folder,brandL,brandR,soundTheme,countdownSound,workStartSound,restStartSound,workoutEndSound,soundVolume,const DeepCollectionEquality().hash(_modules),createdAt,updatedAt);
}

@override
String toString() {
    return 'Workout(id: $id, ownerId: $ownerId, author: $author, name: $name, folder: $folder, brandL: $brandL, brandR: $brandR, soundTheme: $soundTheme, countdownSound: $countdownSound, workStartSound: $workStartSound, restStartSound: $restStartSound, workoutEndSound: $workoutEndSound, soundVolume: $soundVolume, modules: $modules, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$WorkoutCopyWith<$Res> implements $WorkoutCopyWith<$Res> {
  factory _$WorkoutCopyWith(_Workout value, $Res Function(_Workout) _then) = __$WorkoutCopyWithImpl;
@override @useResult
$Res call({
 String id, String ownerId, WorkoutAuthor author, String name, String folder, String brandL, String brandR, WorkoutSoundTheme soundTheme, WorkoutSound countdownSound, WorkoutSound workStartSound, WorkoutSound restStartSound, WorkoutSound workoutEndSound, double soundVolume, List<WorkoutModule> modules, DateTime createdAt, DateTime updatedAt
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ownerId = null,Object? author = null,Object? name = null,Object? folder = null,Object? brandL = null,Object? brandR = null,Object? soundTheme = null,Object? countdownSound = null,Object? workStartSound = null,Object? restStartSound = null,Object? workoutEndSound = null,Object? soundVolume = null,Object? modules = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Workout(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as WorkoutAuthor,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,folder: null == folder ? _self.folder : folder // ignore: cast_nullable_to_non_nullable
as String,brandL: null == brandL ? _self.brandL : brandL // ignore: cast_nullable_to_non_nullable
as String,brandR: null == brandR ? _self.brandR : brandR // ignore: cast_nullable_to_non_nullable
as String,soundTheme: null == soundTheme ? _self.soundTheme : soundTheme // ignore: cast_nullable_to_non_nullable
as WorkoutSoundTheme,countdownSound: null == countdownSound ? _self.countdownSound : countdownSound // ignore: cast_nullable_to_non_nullable
as WorkoutSound,workStartSound: null == workStartSound ? _self.workStartSound : workStartSound // ignore: cast_nullable_to_non_nullable
as WorkoutSound,restStartSound: null == restStartSound ? _self.restStartSound : restStartSound // ignore: cast_nullable_to_non_nullable
as WorkoutSound,workoutEndSound: null == workoutEndSound ? _self.workoutEndSound : workoutEndSound // ignore: cast_nullable_to_non_nullable
as WorkoutSound,soundVolume: null == soundVolume ? _self.soundVolume : soundVolume // ignore: cast_nullable_to_non_nullable
as double,modules: null == modules ? _self._modules : modules // ignore: cast_nullable_to_non_nullable
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

 String get id; String get name; int get workSeconds; int get sets; int get restSeconds; String get text; String get imageSource; bool get showTimer; SlideAppearance get appearance; bool get showTimerGauge; bool get showSets; bool get beep; bool get coverImage; int? get timerColorValue; String? get workGaugeColor; String? get restGaugeColor; String? get workTextColor; String? get restTextColor; List<WorkoutIntervalBlock> get intervalBlocks;
/// Create a copy of WorkoutModule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkoutModuleCopyWith<WorkoutModule> get copyWith => _$WorkoutModuleCopyWithImpl<WorkoutModule>(this as WorkoutModule, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WorkoutModule;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkoutModule&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.workSeconds, _this.workSeconds) || other.workSeconds == _this.workSeconds)&&(identical(other.sets, _this.sets) || other.sets == _this.sets)&&(identical(other.restSeconds, _this.restSeconds) || other.restSeconds == _this.restSeconds)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.imageSource, _this.imageSource) || other.imageSource == _this.imageSource)&&(identical(other.showTimer, _this.showTimer) || other.showTimer == _this.showTimer)&&(identical(other.appearance, _this.appearance) || other.appearance == _this.appearance)&&(identical(other.showTimerGauge, _this.showTimerGauge) || other.showTimerGauge == _this.showTimerGauge)&&(identical(other.showSets, _this.showSets) || other.showSets == _this.showSets)&&(identical(other.beep, _this.beep) || other.beep == _this.beep)&&(identical(other.coverImage, _this.coverImage) || other.coverImage == _this.coverImage)&&(identical(other.timerColorValue, _this.timerColorValue) || other.timerColorValue == _this.timerColorValue)&&(identical(other.workGaugeColor, _this.workGaugeColor) || other.workGaugeColor == _this.workGaugeColor)&&(identical(other.restGaugeColor, _this.restGaugeColor) || other.restGaugeColor == _this.restGaugeColor)&&(identical(other.workTextColor, _this.workTextColor) || other.workTextColor == _this.workTextColor)&&(identical(other.restTextColor, _this.restTextColor) || other.restTextColor == _this.restTextColor)&&const DeepCollectionEquality().equals(other.intervalBlocks, _this.intervalBlocks));
}


@override
int get hashCode {
  final _this = this as WorkoutModule;
  return Object.hashAll([runtimeType,_this.id,_this.name,_this.workSeconds,_this.sets,_this.restSeconds,_this.text,_this.imageSource,_this.showTimer,_this.appearance,_this.showTimerGauge,_this.showSets,_this.beep,_this.coverImage,_this.timerColorValue,_this.workGaugeColor,_this.restGaugeColor,_this.workTextColor,_this.restTextColor,const DeepCollectionEquality().hash(_this.intervalBlocks)]);
}

@override
String toString() {
  final _this = this as WorkoutModule;
  return 'WorkoutModule(id: ${_this.id}, name: ${_this.name}, workSeconds: ${_this.workSeconds}, sets: ${_this.sets}, restSeconds: ${_this.restSeconds}, text: ${_this.text}, imageSource: ${_this.imageSource}, showTimer: ${_this.showTimer}, appearance: ${_this.appearance}, showTimerGauge: ${_this.showTimerGauge}, showSets: ${_this.showSets}, beep: ${_this.beep}, coverImage: ${_this.coverImage}, timerColorValue: ${_this.timerColorValue}, workGaugeColor: ${_this.workGaugeColor}, restGaugeColor: ${_this.restGaugeColor}, workTextColor: ${_this.workTextColor}, restTextColor: ${_this.restTextColor}, intervalBlocks: ${_this.intervalBlocks})';
}


}

/// @nodoc
abstract mixin class $WorkoutModuleCopyWith<$Res>  {
  factory $WorkoutModuleCopyWith(WorkoutModule value, $Res Function(WorkoutModule) _then) = _$WorkoutModuleCopyWithImpl;
@useResult
$Res call({
 String id, String name, int workSeconds, int sets, int restSeconds, String text, String imageSource, bool showTimer, SlideAppearance appearance, bool showTimerGauge, bool showSets, bool beep, bool coverImage, int? timerColorValue, String? workGaugeColor, String? restGaugeColor, String? workTextColor, String? restTextColor, List<WorkoutIntervalBlock> intervalBlocks
});


$SlideAppearanceCopyWith<$Res> get appearance;

}
/// @nodoc
class _$WorkoutModuleCopyWithImpl<$Res>
    implements $WorkoutModuleCopyWith<$Res> {
  _$WorkoutModuleCopyWithImpl(this._self, this._then);

  final WorkoutModule _self;
  final $Res Function(WorkoutModule) _then;

/// Create a copy of WorkoutModule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? workSeconds = null,Object? sets = null,Object? restSeconds = null,Object? text = null,Object? imageSource = null,Object? showTimer = null,Object? appearance = null,Object? showTimerGauge = null,Object? showSets = null,Object? beep = null,Object? coverImage = null,Object? timerColorValue = freezed,Object? workGaugeColor = freezed,Object? restGaugeColor = freezed,Object? workTextColor = freezed,Object? restTextColor = freezed,Object? intervalBlocks = null,}) {
  return _then(WorkoutModule(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,workSeconds: null == workSeconds ? _self.workSeconds : workSeconds // ignore: cast_nullable_to_non_nullable
as int,sets: null == sets ? _self.sets : sets // ignore: cast_nullable_to_non_nullable
as int,restSeconds: null == restSeconds ? _self.restSeconds : restSeconds // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,imageSource: null == imageSource ? _self.imageSource : imageSource // ignore: cast_nullable_to_non_nullable
as String,showTimer: null == showTimer ? _self.showTimer : showTimer // ignore: cast_nullable_to_non_nullable
as bool,appearance: null == appearance ? _self.appearance : appearance // ignore: cast_nullable_to_non_nullable
as SlideAppearance,showTimerGauge: null == showTimerGauge ? _self.showTimerGauge : showTimerGauge // ignore: cast_nullable_to_non_nullable
as bool,showSets: null == showSets ? _self.showSets : showSets // ignore: cast_nullable_to_non_nullable
as bool,beep: null == beep ? _self.beep : beep // ignore: cast_nullable_to_non_nullable
as bool,coverImage: null == coverImage ? _self.coverImage : coverImage // ignore: cast_nullable_to_non_nullable
as bool,timerColorValue: freezed == timerColorValue ? _self.timerColorValue : timerColorValue // ignore: cast_nullable_to_non_nullable
as int?,workGaugeColor: freezed == workGaugeColor ? _self.workGaugeColor : workGaugeColor // ignore: cast_nullable_to_non_nullable
as String?,restGaugeColor: freezed == restGaugeColor ? _self.restGaugeColor : restGaugeColor // ignore: cast_nullable_to_non_nullable
as String?,workTextColor: freezed == workTextColor ? _self.workTextColor : workTextColor // ignore: cast_nullable_to_non_nullable
as String?,restTextColor: freezed == restTextColor ? _self.restTextColor : restTextColor // ignore: cast_nullable_to_non_nullable
as String?,intervalBlocks: null == intervalBlocks ? _self.intervalBlocks : intervalBlocks // ignore: cast_nullable_to_non_nullable
as List<WorkoutIntervalBlock>,
  ));
}
/// Create a copy of WorkoutModule
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SlideAppearanceCopyWith<$Res> get appearance {
  
  return $SlideAppearanceCopyWith<$Res>(_self.appearance, (value) {
    return _then(_self.copyWith(appearance: value));
  });
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  int workSeconds,  int sets,  int restSeconds,  String text,  String imageSource,  bool showTimer,  SlideAppearance appearance,  bool showTimerGauge,  bool showSets,  bool beep,  bool coverImage,  int? timerColorValue,  String? workGaugeColor,  String? restGaugeColor,  String? workTextColor,  String? restTextColor,  List<WorkoutIntervalBlock> intervalBlocks)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkoutModule() when $default != null:
return $default(_that.id,_that.name,_that.workSeconds,_that.sets,_that.restSeconds,_that.text,_that.imageSource,_that.showTimer,_that.appearance,_that.showTimerGauge,_that.showSets,_that.beep,_that.coverImage,_that.timerColorValue,_that.workGaugeColor,_that.restGaugeColor,_that.workTextColor,_that.restTextColor,_that.intervalBlocks);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  int workSeconds,  int sets,  int restSeconds,  String text,  String imageSource,  bool showTimer,  SlideAppearance appearance,  bool showTimerGauge,  bool showSets,  bool beep,  bool coverImage,  int? timerColorValue,  String? workGaugeColor,  String? restGaugeColor,  String? workTextColor,  String? restTextColor,  List<WorkoutIntervalBlock> intervalBlocks)  $default,) {final _that = this;
switch (_that) {
case _WorkoutModule():
return $default(_that.id,_that.name,_that.workSeconds,_that.sets,_that.restSeconds,_that.text,_that.imageSource,_that.showTimer,_that.appearance,_that.showTimerGauge,_that.showSets,_that.beep,_that.coverImage,_that.timerColorValue,_that.workGaugeColor,_that.restGaugeColor,_that.workTextColor,_that.restTextColor,_that.intervalBlocks);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  int workSeconds,  int sets,  int restSeconds,  String text,  String imageSource,  bool showTimer,  SlideAppearance appearance,  bool showTimerGauge,  bool showSets,  bool beep,  bool coverImage,  int? timerColorValue,  String? workGaugeColor,  String? restGaugeColor,  String? workTextColor,  String? restTextColor,  List<WorkoutIntervalBlock> intervalBlocks)?  $default,) {final _that = this;
switch (_that) {
case _WorkoutModule() when $default != null:
return $default(_that.id,_that.name,_that.workSeconds,_that.sets,_that.restSeconds,_that.text,_that.imageSource,_that.showTimer,_that.appearance,_that.showTimerGauge,_that.showSets,_that.beep,_that.coverImage,_that.timerColorValue,_that.workGaugeColor,_that.restGaugeColor,_that.workTextColor,_that.restTextColor,_that.intervalBlocks);case _:
  return null;

}
}

}

/// @nodoc


class _WorkoutModule implements WorkoutModule {
  const _WorkoutModule({required this.id, required this.name, required this.workSeconds, required this.sets, required this.restSeconds, required this.text, required this.imageSource, required this.showTimer, this.appearance = const SlideAppearance(), this.showTimerGauge = true, this.showSets = true, required this.beep, required this.coverImage, this.timerColorValue, this.workGaugeColor, this.restGaugeColor, this.workTextColor, this.restTextColor,  List<WorkoutIntervalBlock> intervalBlocks = const <WorkoutIntervalBlock>[]}): _intervalBlocks = intervalBlocks;
  

@override final  String id;
@override final  String name;
@override final  int workSeconds;
@override final  int sets;
@override final  int restSeconds;
@override final  String text;
@override final  String imageSource;
@override final  bool showTimer;
@override@JsonKey() final  SlideAppearance appearance;
@override@JsonKey() final  bool showTimerGauge;
@override@JsonKey() final  bool showSets;
@override final  bool beep;
@override final  bool coverImage;
@override final  int? timerColorValue;
@override final  String? workGaugeColor;
@override final  String? restGaugeColor;
@override final  String? workTextColor;
@override final  String? restTextColor;
 final  List<WorkoutIntervalBlock> _intervalBlocks;
@override@JsonKey() List<WorkoutIntervalBlock> get intervalBlocks {
  if (_intervalBlocks is EqualUnmodifiableListView) return _intervalBlocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_intervalBlocks);
}


/// Create a copy of WorkoutModule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkoutModuleCopyWith<_WorkoutModule> get copyWith => __$WorkoutModuleCopyWithImpl<_WorkoutModule>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkoutModule&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.workSeconds, workSeconds) || other.workSeconds == workSeconds)&&(identical(other.sets, sets) || other.sets == sets)&&(identical(other.restSeconds, restSeconds) || other.restSeconds == restSeconds)&&(identical(other.text, text) || other.text == text)&&(identical(other.imageSource, imageSource) || other.imageSource == imageSource)&&(identical(other.showTimer, showTimer) || other.showTimer == showTimer)&&(identical(other.appearance, appearance) || other.appearance == appearance)&&(identical(other.showTimerGauge, showTimerGauge) || other.showTimerGauge == showTimerGauge)&&(identical(other.showSets, showSets) || other.showSets == showSets)&&(identical(other.beep, beep) || other.beep == beep)&&(identical(other.coverImage, coverImage) || other.coverImage == coverImage)&&(identical(other.timerColorValue, timerColorValue) || other.timerColorValue == timerColorValue)&&(identical(other.workGaugeColor, workGaugeColor) || other.workGaugeColor == workGaugeColor)&&(identical(other.restGaugeColor, restGaugeColor) || other.restGaugeColor == restGaugeColor)&&(identical(other.workTextColor, workTextColor) || other.workTextColor == workTextColor)&&(identical(other.restTextColor, restTextColor) || other.restTextColor == restTextColor)&&const DeepCollectionEquality().equals(other.intervalBlocks, _intervalBlocks));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,id,name,workSeconds,sets,restSeconds,text,imageSource,showTimer,appearance,showTimerGauge,showSets,beep,coverImage,timerColorValue,workGaugeColor,restGaugeColor,workTextColor,restTextColor,const DeepCollectionEquality().hash(_intervalBlocks)]);
}

@override
String toString() {
    return 'WorkoutModule(id: $id, name: $name, workSeconds: $workSeconds, sets: $sets, restSeconds: $restSeconds, text: $text, imageSource: $imageSource, showTimer: $showTimer, appearance: $appearance, showTimerGauge: $showTimerGauge, showSets: $showSets, beep: $beep, coverImage: $coverImage, timerColorValue: $timerColorValue, workGaugeColor: $workGaugeColor, restGaugeColor: $restGaugeColor, workTextColor: $workTextColor, restTextColor: $restTextColor, intervalBlocks: $intervalBlocks)';
}


}

/// @nodoc
abstract mixin class _$WorkoutModuleCopyWith<$Res> implements $WorkoutModuleCopyWith<$Res> {
  factory _$WorkoutModuleCopyWith(_WorkoutModule value, $Res Function(_WorkoutModule) _then) = __$WorkoutModuleCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, int workSeconds, int sets, int restSeconds, String text, String imageSource, bool showTimer, SlideAppearance appearance, bool showTimerGauge, bool showSets, bool beep, bool coverImage, int? timerColorValue, String? workGaugeColor, String? restGaugeColor, String? workTextColor, String? restTextColor, List<WorkoutIntervalBlock> intervalBlocks
});


@override $SlideAppearanceCopyWith<$Res> get appearance;

}
/// @nodoc
class __$WorkoutModuleCopyWithImpl<$Res>
    implements _$WorkoutModuleCopyWith<$Res> {
  __$WorkoutModuleCopyWithImpl(this._self, this._then);

  final _WorkoutModule _self;
  final $Res Function(_WorkoutModule) _then;

/// Create a copy of WorkoutModule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? workSeconds = null,Object? sets = null,Object? restSeconds = null,Object? text = null,Object? imageSource = null,Object? showTimer = null,Object? appearance = null,Object? showTimerGauge = null,Object? showSets = null,Object? beep = null,Object? coverImage = null,Object? timerColorValue = freezed,Object? workGaugeColor = freezed,Object? restGaugeColor = freezed,Object? workTextColor = freezed,Object? restTextColor = freezed,Object? intervalBlocks = null,}) {
  return _then(_WorkoutModule(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,workSeconds: null == workSeconds ? _self.workSeconds : workSeconds // ignore: cast_nullable_to_non_nullable
as int,sets: null == sets ? _self.sets : sets // ignore: cast_nullable_to_non_nullable
as int,restSeconds: null == restSeconds ? _self.restSeconds : restSeconds // ignore: cast_nullable_to_non_nullable
as int,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,imageSource: null == imageSource ? _self.imageSource : imageSource // ignore: cast_nullable_to_non_nullable
as String,showTimer: null == showTimer ? _self.showTimer : showTimer // ignore: cast_nullable_to_non_nullable
as bool,appearance: null == appearance ? _self.appearance : appearance // ignore: cast_nullable_to_non_nullable
as SlideAppearance,showTimerGauge: null == showTimerGauge ? _self.showTimerGauge : showTimerGauge // ignore: cast_nullable_to_non_nullable
as bool,showSets: null == showSets ? _self.showSets : showSets // ignore: cast_nullable_to_non_nullable
as bool,beep: null == beep ? _self.beep : beep // ignore: cast_nullable_to_non_nullable
as bool,coverImage: null == coverImage ? _self.coverImage : coverImage // ignore: cast_nullable_to_non_nullable
as bool,timerColorValue: freezed == timerColorValue ? _self.timerColorValue : timerColorValue // ignore: cast_nullable_to_non_nullable
as int?,workGaugeColor: freezed == workGaugeColor ? _self.workGaugeColor : workGaugeColor // ignore: cast_nullable_to_non_nullable
as String?,restGaugeColor: freezed == restGaugeColor ? _self.restGaugeColor : restGaugeColor // ignore: cast_nullable_to_non_nullable
as String?,workTextColor: freezed == workTextColor ? _self.workTextColor : workTextColor // ignore: cast_nullable_to_non_nullable
as String?,restTextColor: freezed == restTextColor ? _self.restTextColor : restTextColor // ignore: cast_nullable_to_non_nullable
as String?,intervalBlocks: null == intervalBlocks ? _self._intervalBlocks : intervalBlocks // ignore: cast_nullable_to_non_nullable
as List<WorkoutIntervalBlock>,
  ));
}

/// Create a copy of WorkoutModule
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SlideAppearanceCopyWith<$Res> get appearance {
  
  return $SlideAppearanceCopyWith<$Res>(_self.appearance, (value) {
    return _then(_self.copyWith(appearance: value));
  });
}
}

/// @nodoc
mixin _$WorkoutIntervalBlock {

 String get id; int get workSeconds; int get restSeconds; int get sets;
/// Create a copy of WorkoutIntervalBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkoutIntervalBlockCopyWith<WorkoutIntervalBlock> get copyWith => _$WorkoutIntervalBlockCopyWithImpl<WorkoutIntervalBlock>(this as WorkoutIntervalBlock, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WorkoutIntervalBlock;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkoutIntervalBlock&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.workSeconds, _this.workSeconds) || other.workSeconds == _this.workSeconds)&&(identical(other.restSeconds, _this.restSeconds) || other.restSeconds == _this.restSeconds)&&(identical(other.sets, _this.sets) || other.sets == _this.sets));
}


@override
int get hashCode {
  final _this = this as WorkoutIntervalBlock;
  return Object.hash(runtimeType,_this.id,_this.workSeconds,_this.restSeconds,_this.sets);
}

@override
String toString() {
  final _this = this as WorkoutIntervalBlock;
  return 'WorkoutIntervalBlock(id: ${_this.id}, workSeconds: ${_this.workSeconds}, restSeconds: ${_this.restSeconds}, sets: ${_this.sets})';
}


}

/// @nodoc
abstract mixin class $WorkoutIntervalBlockCopyWith<$Res>  {
  factory $WorkoutIntervalBlockCopyWith(WorkoutIntervalBlock value, $Res Function(WorkoutIntervalBlock) _then) = _$WorkoutIntervalBlockCopyWithImpl;
@useResult
$Res call({
 String id, int workSeconds, int restSeconds, int sets
});




}
/// @nodoc
class _$WorkoutIntervalBlockCopyWithImpl<$Res>
    implements $WorkoutIntervalBlockCopyWith<$Res> {
  _$WorkoutIntervalBlockCopyWithImpl(this._self, this._then);

  final WorkoutIntervalBlock _self;
  final $Res Function(WorkoutIntervalBlock) _then;

/// Create a copy of WorkoutIntervalBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workSeconds = null,Object? restSeconds = null,Object? sets = null,}) {
  return _then(WorkoutIntervalBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workSeconds: null == workSeconds ? _self.workSeconds : workSeconds // ignore: cast_nullable_to_non_nullable
as int,restSeconds: null == restSeconds ? _self.restSeconds : restSeconds // ignore: cast_nullable_to_non_nullable
as int,sets: null == sets ? _self.sets : sets // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkoutIntervalBlock].
extension WorkoutIntervalBlockPatterns on WorkoutIntervalBlock {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkoutIntervalBlock value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkoutIntervalBlock() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkoutIntervalBlock value)  $default,){
final _that = this;
switch (_that) {
case _WorkoutIntervalBlock():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkoutIntervalBlock value)?  $default,){
final _that = this;
switch (_that) {
case _WorkoutIntervalBlock() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int workSeconds,  int restSeconds,  int sets)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkoutIntervalBlock() when $default != null:
return $default(_that.id,_that.workSeconds,_that.restSeconds,_that.sets);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int workSeconds,  int restSeconds,  int sets)  $default,) {final _that = this;
switch (_that) {
case _WorkoutIntervalBlock():
return $default(_that.id,_that.workSeconds,_that.restSeconds,_that.sets);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int workSeconds,  int restSeconds,  int sets)?  $default,) {final _that = this;
switch (_that) {
case _WorkoutIntervalBlock() when $default != null:
return $default(_that.id,_that.workSeconds,_that.restSeconds,_that.sets);case _:
  return null;

}
}

}

/// @nodoc


class _WorkoutIntervalBlock implements WorkoutIntervalBlock {
  const _WorkoutIntervalBlock({required this.id, required this.workSeconds, required this.restSeconds, required this.sets});
  

@override final  String id;
@override final  int workSeconds;
@override final  int restSeconds;
@override final  int sets;

/// Create a copy of WorkoutIntervalBlock
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkoutIntervalBlockCopyWith<_WorkoutIntervalBlock> get copyWith => __$WorkoutIntervalBlockCopyWithImpl<_WorkoutIntervalBlock>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkoutIntervalBlock&&(identical(other.id, id) || other.id == id)&&(identical(other.workSeconds, workSeconds) || other.workSeconds == workSeconds)&&(identical(other.restSeconds, restSeconds) || other.restSeconds == restSeconds)&&(identical(other.sets, sets) || other.sets == sets));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,workSeconds,restSeconds,sets);
}

@override
String toString() {
    return 'WorkoutIntervalBlock(id: $id, workSeconds: $workSeconds, restSeconds: $restSeconds, sets: $sets)';
}


}

/// @nodoc
abstract mixin class _$WorkoutIntervalBlockCopyWith<$Res> implements $WorkoutIntervalBlockCopyWith<$Res> {
  factory _$WorkoutIntervalBlockCopyWith(_WorkoutIntervalBlock value, $Res Function(_WorkoutIntervalBlock) _then) = __$WorkoutIntervalBlockCopyWithImpl;
@override @useResult
$Res call({
 String id, int workSeconds, int restSeconds, int sets
});




}
/// @nodoc
class __$WorkoutIntervalBlockCopyWithImpl<$Res>
    implements _$WorkoutIntervalBlockCopyWith<$Res> {
  __$WorkoutIntervalBlockCopyWithImpl(this._self, this._then);

  final _WorkoutIntervalBlock _self;
  final $Res Function(_WorkoutIntervalBlock) _then;

/// Create a copy of WorkoutIntervalBlock
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workSeconds = null,Object? restSeconds = null,Object? sets = null,}) {
  return _then(_WorkoutIntervalBlock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workSeconds: null == workSeconds ? _self.workSeconds : workSeconds // ignore: cast_nullable_to_non_nullable
as int,restSeconds: null == restSeconds ? _self.restSeconds : restSeconds // ignore: cast_nullable_to_non_nullable
as int,sets: null == sets ? _self.sets : sets // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$SlideAppearance {

 double get timerX; double get timerY; double get timerSize; double get ringWidth; bool get showTitle; bool get showBody; bool get showBrand; int get titleColor; int get bodyColor; int get setsColor; int get brandColor;
/// Create a copy of SlideAppearance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SlideAppearanceCopyWith<SlideAppearance> get copyWith => _$SlideAppearanceCopyWithImpl<SlideAppearance>(this as SlideAppearance, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SlideAppearance;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SlideAppearance&&(identical(other.timerX, _this.timerX) || other.timerX == _this.timerX)&&(identical(other.timerY, _this.timerY) || other.timerY == _this.timerY)&&(identical(other.timerSize, _this.timerSize) || other.timerSize == _this.timerSize)&&(identical(other.ringWidth, _this.ringWidth) || other.ringWidth == _this.ringWidth)&&(identical(other.showTitle, _this.showTitle) || other.showTitle == _this.showTitle)&&(identical(other.showBody, _this.showBody) || other.showBody == _this.showBody)&&(identical(other.showBrand, _this.showBrand) || other.showBrand == _this.showBrand)&&(identical(other.titleColor, _this.titleColor) || other.titleColor == _this.titleColor)&&(identical(other.bodyColor, _this.bodyColor) || other.bodyColor == _this.bodyColor)&&(identical(other.setsColor, _this.setsColor) || other.setsColor == _this.setsColor)&&(identical(other.brandColor, _this.brandColor) || other.brandColor == _this.brandColor));
}


@override
int get hashCode {
  final _this = this as SlideAppearance;
  return Object.hash(runtimeType,_this.timerX,_this.timerY,_this.timerSize,_this.ringWidth,_this.showTitle,_this.showBody,_this.showBrand,_this.titleColor,_this.bodyColor,_this.setsColor,_this.brandColor);
}

@override
String toString() {
  final _this = this as SlideAppearance;
  return 'SlideAppearance(timerX: ${_this.timerX}, timerY: ${_this.timerY}, timerSize: ${_this.timerSize}, ringWidth: ${_this.ringWidth}, showTitle: ${_this.showTitle}, showBody: ${_this.showBody}, showBrand: ${_this.showBrand}, titleColor: ${_this.titleColor}, bodyColor: ${_this.bodyColor}, setsColor: ${_this.setsColor}, brandColor: ${_this.brandColor})';
}


}

/// @nodoc
abstract mixin class $SlideAppearanceCopyWith<$Res>  {
  factory $SlideAppearanceCopyWith(SlideAppearance value, $Res Function(SlideAppearance) _then) = _$SlideAppearanceCopyWithImpl;
@useResult
$Res call({
 double timerX, double timerY, double timerSize, double ringWidth, bool showTitle, bool showBody, bool showBrand, int titleColor, int bodyColor, int setsColor, int brandColor
});




}
/// @nodoc
class _$SlideAppearanceCopyWithImpl<$Res>
    implements $SlideAppearanceCopyWith<$Res> {
  _$SlideAppearanceCopyWithImpl(this._self, this._then);

  final SlideAppearance _self;
  final $Res Function(SlideAppearance) _then;

/// Create a copy of SlideAppearance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timerX = null,Object? timerY = null,Object? timerSize = null,Object? ringWidth = null,Object? showTitle = null,Object? showBody = null,Object? showBrand = null,Object? titleColor = null,Object? bodyColor = null,Object? setsColor = null,Object? brandColor = null,}) {
  return _then(SlideAppearance(
timerX: null == timerX ? _self.timerX : timerX // ignore: cast_nullable_to_non_nullable
as double,timerY: null == timerY ? _self.timerY : timerY // ignore: cast_nullable_to_non_nullable
as double,timerSize: null == timerSize ? _self.timerSize : timerSize // ignore: cast_nullable_to_non_nullable
as double,ringWidth: null == ringWidth ? _self.ringWidth : ringWidth // ignore: cast_nullable_to_non_nullable
as double,showTitle: null == showTitle ? _self.showTitle : showTitle // ignore: cast_nullable_to_non_nullable
as bool,showBody: null == showBody ? _self.showBody : showBody // ignore: cast_nullable_to_non_nullable
as bool,showBrand: null == showBrand ? _self.showBrand : showBrand // ignore: cast_nullable_to_non_nullable
as bool,titleColor: null == titleColor ? _self.titleColor : titleColor // ignore: cast_nullable_to_non_nullable
as int,bodyColor: null == bodyColor ? _self.bodyColor : bodyColor // ignore: cast_nullable_to_non_nullable
as int,setsColor: null == setsColor ? _self.setsColor : setsColor // ignore: cast_nullable_to_non_nullable
as int,brandColor: null == brandColor ? _self.brandColor : brandColor // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SlideAppearance].
extension SlideAppearancePatterns on SlideAppearance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SlideAppearance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SlideAppearance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SlideAppearance value)  $default,){
final _that = this;
switch (_that) {
case _SlideAppearance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SlideAppearance value)?  $default,){
final _that = this;
switch (_that) {
case _SlideAppearance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double timerX,  double timerY,  double timerSize,  double ringWidth,  bool showTitle,  bool showBody,  bool showBrand,  int titleColor,  int bodyColor,  int setsColor,  int brandColor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SlideAppearance() when $default != null:
return $default(_that.timerX,_that.timerY,_that.timerSize,_that.ringWidth,_that.showTitle,_that.showBody,_that.showBrand,_that.titleColor,_that.bodyColor,_that.setsColor,_that.brandColor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double timerX,  double timerY,  double timerSize,  double ringWidth,  bool showTitle,  bool showBody,  bool showBrand,  int titleColor,  int bodyColor,  int setsColor,  int brandColor)  $default,) {final _that = this;
switch (_that) {
case _SlideAppearance():
return $default(_that.timerX,_that.timerY,_that.timerSize,_that.ringWidth,_that.showTitle,_that.showBody,_that.showBrand,_that.titleColor,_that.bodyColor,_that.setsColor,_that.brandColor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double timerX,  double timerY,  double timerSize,  double ringWidth,  bool showTitle,  bool showBody,  bool showBrand,  int titleColor,  int bodyColor,  int setsColor,  int brandColor)?  $default,) {final _that = this;
switch (_that) {
case _SlideAppearance() when $default != null:
return $default(_that.timerX,_that.timerY,_that.timerSize,_that.ringWidth,_that.showTitle,_that.showBody,_that.showBrand,_that.titleColor,_that.bodyColor,_that.setsColor,_that.brandColor);case _:
  return null;

}
}

}

/// @nodoc


class _SlideAppearance implements SlideAppearance {
  const _SlideAppearance({this.timerX = 0.84, this.timerY = 0.5, this.timerSize = 1, this.ringWidth = 30, this.showTitle = true, this.showBody = true, this.showBrand = true, this.titleColor = 0xFFFFFFFF, this.bodyColor = 0xFFFFFFFF, this.setsColor = 0xB3FFFFFF, this.brandColor = 0xFFFFFFFF});
  

@override@JsonKey() final  double timerX;
@override@JsonKey() final  double timerY;
@override@JsonKey() final  double timerSize;
@override@JsonKey() final  double ringWidth;
@override@JsonKey() final  bool showTitle;
@override@JsonKey() final  bool showBody;
@override@JsonKey() final  bool showBrand;
@override@JsonKey() final  int titleColor;
@override@JsonKey() final  int bodyColor;
@override@JsonKey() final  int setsColor;
@override@JsonKey() final  int brandColor;

/// Create a copy of SlideAppearance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SlideAppearanceCopyWith<_SlideAppearance> get copyWith => __$SlideAppearanceCopyWithImpl<_SlideAppearance>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SlideAppearance&&(identical(other.timerX, timerX) || other.timerX == timerX)&&(identical(other.timerY, timerY) || other.timerY == timerY)&&(identical(other.timerSize, timerSize) || other.timerSize == timerSize)&&(identical(other.ringWidth, ringWidth) || other.ringWidth == ringWidth)&&(identical(other.showTitle, showTitle) || other.showTitle == showTitle)&&(identical(other.showBody, showBody) || other.showBody == showBody)&&(identical(other.showBrand, showBrand) || other.showBrand == showBrand)&&(identical(other.titleColor, titleColor) || other.titleColor == titleColor)&&(identical(other.bodyColor, bodyColor) || other.bodyColor == bodyColor)&&(identical(other.setsColor, setsColor) || other.setsColor == setsColor)&&(identical(other.brandColor, brandColor) || other.brandColor == brandColor));
}


@override
int get hashCode {
    return Object.hash(runtimeType,timerX,timerY,timerSize,ringWidth,showTitle,showBody,showBrand,titleColor,bodyColor,setsColor,brandColor);
}

@override
String toString() {
    return 'SlideAppearance(timerX: $timerX, timerY: $timerY, timerSize: $timerSize, ringWidth: $ringWidth, showTitle: $showTitle, showBody: $showBody, showBrand: $showBrand, titleColor: $titleColor, bodyColor: $bodyColor, setsColor: $setsColor, brandColor: $brandColor)';
}


}

/// @nodoc
abstract mixin class _$SlideAppearanceCopyWith<$Res> implements $SlideAppearanceCopyWith<$Res> {
  factory _$SlideAppearanceCopyWith(_SlideAppearance value, $Res Function(_SlideAppearance) _then) = __$SlideAppearanceCopyWithImpl;
@override @useResult
$Res call({
 double timerX, double timerY, double timerSize, double ringWidth, bool showTitle, bool showBody, bool showBrand, int titleColor, int bodyColor, int setsColor, int brandColor
});




}
/// @nodoc
class __$SlideAppearanceCopyWithImpl<$Res>
    implements _$SlideAppearanceCopyWith<$Res> {
  __$SlideAppearanceCopyWithImpl(this._self, this._then);

  final _SlideAppearance _self;
  final $Res Function(_SlideAppearance) _then;

/// Create a copy of SlideAppearance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timerX = null,Object? timerY = null,Object? timerSize = null,Object? ringWidth = null,Object? showTitle = null,Object? showBody = null,Object? showBrand = null,Object? titleColor = null,Object? bodyColor = null,Object? setsColor = null,Object? brandColor = null,}) {
  return _then(_SlideAppearance(
timerX: null == timerX ? _self.timerX : timerX // ignore: cast_nullable_to_non_nullable
as double,timerY: null == timerY ? _self.timerY : timerY // ignore: cast_nullable_to_non_nullable
as double,timerSize: null == timerSize ? _self.timerSize : timerSize // ignore: cast_nullable_to_non_nullable
as double,ringWidth: null == ringWidth ? _self.ringWidth : ringWidth // ignore: cast_nullable_to_non_nullable
as double,showTitle: null == showTitle ? _self.showTitle : showTitle // ignore: cast_nullable_to_non_nullable
as bool,showBody: null == showBody ? _self.showBody : showBody // ignore: cast_nullable_to_non_nullable
as bool,showBrand: null == showBrand ? _self.showBrand : showBrand // ignore: cast_nullable_to_non_nullable
as bool,titleColor: null == titleColor ? _self.titleColor : titleColor // ignore: cast_nullable_to_non_nullable
as int,bodyColor: null == bodyColor ? _self.bodyColor : bodyColor // ignore: cast_nullable_to_non_nullable
as int,setsColor: null == setsColor ? _self.setsColor : setsColor // ignore: cast_nullable_to_non_nullable
as int,brandColor: null == brandColor ? _self.brandColor : brandColor // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
