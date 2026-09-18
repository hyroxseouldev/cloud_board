// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workout_content.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WorkoutContent {

 String get id; String get ownerId; WorkoutAuthor get author; String get name; String get folder; List<WorkoutModule> get modules; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of WorkoutContent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkoutContentCopyWith<WorkoutContent> get copyWith => _$WorkoutContentCopyWithImpl<WorkoutContent>(this as WorkoutContent, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WorkoutContent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkoutContent&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.ownerId, _this.ownerId) || other.ownerId == _this.ownerId)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.folder, _this.folder) || other.folder == _this.folder)&&const DeepCollectionEquality().equals(other.modules, _this.modules)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}


@override
int get hashCode {
  final _this = this as WorkoutContent;
  return Object.hash(runtimeType,_this.id,_this.ownerId,_this.author,_this.name,_this.folder,const DeepCollectionEquality().hash(_this.modules),_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as WorkoutContent;
  return 'WorkoutContent(id: ${_this.id}, ownerId: ${_this.ownerId}, author: ${_this.author}, name: ${_this.name}, folder: ${_this.folder}, modules: ${_this.modules}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $WorkoutContentCopyWith<$Res>  {
  factory $WorkoutContentCopyWith(WorkoutContent value, $Res Function(WorkoutContent) _then) = _$WorkoutContentCopyWithImpl;
@useResult
$Res call({
 String id, String ownerId, WorkoutAuthor author, String name, String folder, List<WorkoutModule> modules, DateTime createdAt, DateTime updatedAt
});


$WorkoutAuthorCopyWith<$Res> get author;

}
/// @nodoc
class _$WorkoutContentCopyWithImpl<$Res>
    implements $WorkoutContentCopyWith<$Res> {
  _$WorkoutContentCopyWithImpl(this._self, this._then);

  final WorkoutContent _self;
  final $Res Function(WorkoutContent) _then;

/// Create a copy of WorkoutContent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ownerId = null,Object? author = null,Object? name = null,Object? folder = null,Object? modules = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(WorkoutContent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as WorkoutAuthor,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,folder: null == folder ? _self.folder : folder // ignore: cast_nullable_to_non_nullable
as String,modules: null == modules ? _self.modules : modules // ignore: cast_nullable_to_non_nullable
as List<WorkoutModule>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of WorkoutContent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutAuthorCopyWith<$Res> get author {
  
  return $WorkoutAuthorCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}


/// Adds pattern-matching-related methods to [WorkoutContent].
extension WorkoutContentPatterns on WorkoutContent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkoutContent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkoutContent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkoutContent value)  $default,){
final _that = this;
switch (_that) {
case _WorkoutContent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkoutContent value)?  $default,){
final _that = this;
switch (_that) {
case _WorkoutContent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String ownerId,  WorkoutAuthor author,  String name,  String folder,  List<WorkoutModule> modules,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkoutContent() when $default != null:
return $default(_that.id,_that.ownerId,_that.author,_that.name,_that.folder,_that.modules,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String ownerId,  WorkoutAuthor author,  String name,  String folder,  List<WorkoutModule> modules,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _WorkoutContent():
return $default(_that.id,_that.ownerId,_that.author,_that.name,_that.folder,_that.modules,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String ownerId,  WorkoutAuthor author,  String name,  String folder,  List<WorkoutModule> modules,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _WorkoutContent() when $default != null:
return $default(_that.id,_that.ownerId,_that.author,_that.name,_that.folder,_that.modules,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _WorkoutContent extends WorkoutContent {
  const _WorkoutContent({required this.id, required this.ownerId, required this.author, required this.name, required this.folder, required  List<WorkoutModule> modules, required this.createdAt, required this.updatedAt}): _modules = modules,super._();
  

@override final  String id;
@override final  String ownerId;
@override final  WorkoutAuthor author;
@override final  String name;
@override final  String folder;
 final  List<WorkoutModule> _modules;
@override List<WorkoutModule> get modules {
  if (_modules is EqualUnmodifiableListView) return _modules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_modules);
}

@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of WorkoutContent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkoutContentCopyWith<_WorkoutContent> get copyWith => __$WorkoutContentCopyWithImpl<_WorkoutContent>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkoutContent&&(identical(other.id, id) || other.id == id)&&(identical(other.ownerId, ownerId) || other.ownerId == ownerId)&&(identical(other.author, author) || other.author == author)&&(identical(other.name, name) || other.name == name)&&(identical(other.folder, folder) || other.folder == folder)&&const DeepCollectionEquality().equals(other.modules, _modules)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,ownerId,author,name,folder,const DeepCollectionEquality().hash(_modules),createdAt,updatedAt);
}

@override
String toString() {
    return 'WorkoutContent(id: $id, ownerId: $ownerId, author: $author, name: $name, folder: $folder, modules: $modules, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$WorkoutContentCopyWith<$Res> implements $WorkoutContentCopyWith<$Res> {
  factory _$WorkoutContentCopyWith(_WorkoutContent value, $Res Function(_WorkoutContent) _then) = __$WorkoutContentCopyWithImpl;
@override @useResult
$Res call({
 String id, String ownerId, WorkoutAuthor author, String name, String folder, List<WorkoutModule> modules, DateTime createdAt, DateTime updatedAt
});


@override $WorkoutAuthorCopyWith<$Res> get author;

}
/// @nodoc
class __$WorkoutContentCopyWithImpl<$Res>
    implements _$WorkoutContentCopyWith<$Res> {
  __$WorkoutContentCopyWithImpl(this._self, this._then);

  final _WorkoutContent _self;
  final $Res Function(_WorkoutContent) _then;

/// Create a copy of WorkoutContent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ownerId = null,Object? author = null,Object? name = null,Object? folder = null,Object? modules = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_WorkoutContent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ownerId: null == ownerId ? _self.ownerId : ownerId // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as WorkoutAuthor,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,folder: null == folder ? _self.folder : folder // ignore: cast_nullable_to_non_nullable
as String,modules: null == modules ? _self._modules : modules // ignore: cast_nullable_to_non_nullable
as List<WorkoutModule>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of WorkoutContent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkoutAuthorCopyWith<$Res> get author {
  
  return $WorkoutAuthorCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}

// dart format on
