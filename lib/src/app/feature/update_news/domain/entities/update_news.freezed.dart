// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'update_news.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UpdateNews {

 String get id; String get title; String get summary; String get date; String get version; Map<String, String> get builds; List<UpdateNewsItem> get items;
/// Create a copy of UpdateNews
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateNewsCopyWith<UpdateNews> get copyWith => _$UpdateNewsCopyWithImpl<UpdateNews>(this as UpdateNews, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as UpdateNews;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateNews&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.summary, _this.summary) || other.summary == _this.summary)&&(identical(other.date, _this.date) || other.date == _this.date)&&(identical(other.version, _this.version) || other.version == _this.version)&&const DeepCollectionEquality().equals(other.builds, _this.builds)&&const DeepCollectionEquality().equals(other.items, _this.items));
}


@override
int get hashCode {
  final _this = this as UpdateNews;
  return Object.hash(runtimeType,_this.id,_this.title,_this.summary,_this.date,_this.version,const DeepCollectionEquality().hash(_this.builds),const DeepCollectionEquality().hash(_this.items));
}

@override
String toString() {
  final _this = this as UpdateNews;
  return 'UpdateNews(id: ${_this.id}, title: ${_this.title}, summary: ${_this.summary}, date: ${_this.date}, version: ${_this.version}, builds: ${_this.builds}, items: ${_this.items})';
}


}

/// @nodoc
abstract mixin class $UpdateNewsCopyWith<$Res>  {
  factory $UpdateNewsCopyWith(UpdateNews value, $Res Function(UpdateNews) _then) = _$UpdateNewsCopyWithImpl;
@useResult
$Res call({
 String id, String title, String summary, String date, String version, Map<String, String> builds, List<UpdateNewsItem> items
});




}
/// @nodoc
class _$UpdateNewsCopyWithImpl<$Res>
    implements $UpdateNewsCopyWith<$Res> {
  _$UpdateNewsCopyWithImpl(this._self, this._then);

  final UpdateNews _self;
  final $Res Function(UpdateNews) _then;

/// Create a copy of UpdateNews
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? summary = null,Object? date = null,Object? version = null,Object? builds = null,Object? items = null,}) {
  return _then(UpdateNews(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,builds: null == builds ? _self.builds : builds // ignore: cast_nullable_to_non_nullable
as Map<String, String>,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<UpdateNewsItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [UpdateNews].
extension UpdateNewsPatterns on UpdateNews {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UpdateNews value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UpdateNews() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UpdateNews value)  $default,){
final _that = this;
switch (_that) {
case _UpdateNews():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UpdateNews value)?  $default,){
final _that = this;
switch (_that) {
case _UpdateNews() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String summary,  String date,  String version,  Map<String, String> builds,  List<UpdateNewsItem> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UpdateNews() when $default != null:
return $default(_that.id,_that.title,_that.summary,_that.date,_that.version,_that.builds,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String summary,  String date,  String version,  Map<String, String> builds,  List<UpdateNewsItem> items)  $default,) {final _that = this;
switch (_that) {
case _UpdateNews():
return $default(_that.id,_that.title,_that.summary,_that.date,_that.version,_that.builds,_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String summary,  String date,  String version,  Map<String, String> builds,  List<UpdateNewsItem> items)?  $default,) {final _that = this;
switch (_that) {
case _UpdateNews() when $default != null:
return $default(_that.id,_that.title,_that.summary,_that.date,_that.version,_that.builds,_that.items);case _:
  return null;

}
}

}

/// @nodoc


class _UpdateNews extends UpdateNews {
  const _UpdateNews({required this.id, required this.title, required this.summary, required this.date, required this.version, required  Map<String, String> builds, required  List<UpdateNewsItem> items}): _builds = builds,_items = items,super._();
  

@override final  String id;
@override final  String title;
@override final  String summary;
@override final  String date;
@override final  String version;
 final  Map<String, String> _builds;
@override Map<String, String> get builds {
  if (_builds is EqualUnmodifiableMapView) return _builds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_builds);
}

 final  List<UpdateNewsItem> _items;
@override List<UpdateNewsItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of UpdateNews
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UpdateNewsCopyWith<_UpdateNews> get copyWith => __$UpdateNewsCopyWithImpl<_UpdateNews>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UpdateNews&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.date, date) || other.date == date)&&(identical(other.version, version) || other.version == version)&&const DeepCollectionEquality().equals(other.builds, _builds)&&const DeepCollectionEquality().equals(other.items, _items));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,title,summary,date,version,const DeepCollectionEquality().hash(_builds),const DeepCollectionEquality().hash(_items));
}

@override
String toString() {
    return 'UpdateNews(id: $id, title: $title, summary: $summary, date: $date, version: $version, builds: $builds, items: $items)';
}


}

/// @nodoc
abstract mixin class _$UpdateNewsCopyWith<$Res> implements $UpdateNewsCopyWith<$Res> {
  factory _$UpdateNewsCopyWith(_UpdateNews value, $Res Function(_UpdateNews) _then) = __$UpdateNewsCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String summary, String date, String version, Map<String, String> builds, List<UpdateNewsItem> items
});




}
/// @nodoc
class __$UpdateNewsCopyWithImpl<$Res>
    implements _$UpdateNewsCopyWith<$Res> {
  __$UpdateNewsCopyWithImpl(this._self, this._then);

  final _UpdateNews _self;
  final $Res Function(_UpdateNews) _then;

/// Create a copy of UpdateNews
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? summary = null,Object? date = null,Object? version = null,Object? builds = null,Object? items = null,}) {
  return _then(_UpdateNews(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,builds: null == builds ? _self._builds : builds // ignore: cast_nullable_to_non_nullable
as Map<String, String>,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<UpdateNewsItem>,
  ));
}


}

/// @nodoc
mixin _$UpdateNewsItem {

 String get title; String get body;
/// Create a copy of UpdateNewsItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateNewsItemCopyWith<UpdateNewsItem> get copyWith => _$UpdateNewsItemCopyWithImpl<UpdateNewsItem>(this as UpdateNewsItem, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as UpdateNewsItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateNewsItem&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.body, _this.body) || other.body == _this.body));
}


@override
int get hashCode {
  final _this = this as UpdateNewsItem;
  return Object.hash(runtimeType,_this.title,_this.body);
}

@override
String toString() {
  final _this = this as UpdateNewsItem;
  return 'UpdateNewsItem(title: ${_this.title}, body: ${_this.body})';
}


}

/// @nodoc
abstract mixin class $UpdateNewsItemCopyWith<$Res>  {
  factory $UpdateNewsItemCopyWith(UpdateNewsItem value, $Res Function(UpdateNewsItem) _then) = _$UpdateNewsItemCopyWithImpl;
@useResult
$Res call({
 String title, String body
});




}
/// @nodoc
class _$UpdateNewsItemCopyWithImpl<$Res>
    implements $UpdateNewsItemCopyWith<$Res> {
  _$UpdateNewsItemCopyWithImpl(this._self, this._then);

  final UpdateNewsItem _self;
  final $Res Function(UpdateNewsItem) _then;

/// Create a copy of UpdateNewsItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? body = null,}) {
  return _then(UpdateNewsItem(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [UpdateNewsItem].
extension UpdateNewsItemPatterns on UpdateNewsItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UpdateNewsItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UpdateNewsItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UpdateNewsItem value)  $default,){
final _that = this;
switch (_that) {
case _UpdateNewsItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UpdateNewsItem value)?  $default,){
final _that = this;
switch (_that) {
case _UpdateNewsItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String body)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UpdateNewsItem() when $default != null:
return $default(_that.title,_that.body);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String body)  $default,) {final _that = this;
switch (_that) {
case _UpdateNewsItem():
return $default(_that.title,_that.body);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String body)?  $default,) {final _that = this;
switch (_that) {
case _UpdateNewsItem() when $default != null:
return $default(_that.title,_that.body);case _:
  return null;

}
}

}

/// @nodoc


class _UpdateNewsItem implements UpdateNewsItem {
  const _UpdateNewsItem({required this.title, required this.body});
  

@override final  String title;
@override final  String body;

/// Create a copy of UpdateNewsItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UpdateNewsItemCopyWith<_UpdateNewsItem> get copyWith => __$UpdateNewsItemCopyWithImpl<_UpdateNewsItem>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UpdateNewsItem&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body));
}


@override
int get hashCode {
    return Object.hash(runtimeType,title,body);
}

@override
String toString() {
    return 'UpdateNewsItem(title: $title, body: $body)';
}


}

/// @nodoc
abstract mixin class _$UpdateNewsItemCopyWith<$Res> implements $UpdateNewsItemCopyWith<$Res> {
  factory _$UpdateNewsItemCopyWith(_UpdateNewsItem value, $Res Function(_UpdateNewsItem) _then) = __$UpdateNewsItemCopyWithImpl;
@override @useResult
$Res call({
 String title, String body
});




}
/// @nodoc
class __$UpdateNewsItemCopyWithImpl<$Res>
    implements _$UpdateNewsItemCopyWith<$Res> {
  __$UpdateNewsItemCopyWithImpl(this._self, this._then);

  final _UpdateNewsItem _self;
  final $Res Function(_UpdateNewsItem) _then;

/// Create a copy of UpdateNewsItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? body = null,}) {
  return _then(_UpdateNewsItem(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$UpdateNewsState {

 List<UpdateNews> get notes; Set<String> get readIds;
/// Create a copy of UpdateNewsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateNewsStateCopyWith<UpdateNewsState> get copyWith => _$UpdateNewsStateCopyWithImpl<UpdateNewsState>(this as UpdateNewsState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as UpdateNewsState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateNewsState&&const DeepCollectionEquality().equals(other.notes, _this.notes)&&const DeepCollectionEquality().equals(other.readIds, _this.readIds));
}


@override
int get hashCode {
  final _this = this as UpdateNewsState;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.notes),const DeepCollectionEquality().hash(_this.readIds));
}

@override
String toString() {
  final _this = this as UpdateNewsState;
  return 'UpdateNewsState(notes: ${_this.notes}, readIds: ${_this.readIds})';
}


}

/// @nodoc
abstract mixin class $UpdateNewsStateCopyWith<$Res>  {
  factory $UpdateNewsStateCopyWith(UpdateNewsState value, $Res Function(UpdateNewsState) _then) = _$UpdateNewsStateCopyWithImpl;
@useResult
$Res call({
 List<UpdateNews> notes, Set<String> readIds
});




}
/// @nodoc
class _$UpdateNewsStateCopyWithImpl<$Res>
    implements $UpdateNewsStateCopyWith<$Res> {
  _$UpdateNewsStateCopyWithImpl(this._self, this._then);

  final UpdateNewsState _self;
  final $Res Function(UpdateNewsState) _then;

/// Create a copy of UpdateNewsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? notes = null,Object? readIds = null,}) {
  return _then(UpdateNewsState(
notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as List<UpdateNews>,readIds: null == readIds ? _self.readIds : readIds // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [UpdateNewsState].
extension UpdateNewsStatePatterns on UpdateNewsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UpdateNewsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UpdateNewsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UpdateNewsState value)  $default,){
final _that = this;
switch (_that) {
case _UpdateNewsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UpdateNewsState value)?  $default,){
final _that = this;
switch (_that) {
case _UpdateNewsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<UpdateNews> notes,  Set<String> readIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UpdateNewsState() when $default != null:
return $default(_that.notes,_that.readIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<UpdateNews> notes,  Set<String> readIds)  $default,) {final _that = this;
switch (_that) {
case _UpdateNewsState():
return $default(_that.notes,_that.readIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<UpdateNews> notes,  Set<String> readIds)?  $default,) {final _that = this;
switch (_that) {
case _UpdateNewsState() when $default != null:
return $default(_that.notes,_that.readIds);case _:
  return null;

}
}

}

/// @nodoc


class _UpdateNewsState extends UpdateNewsState {
  const _UpdateNewsState({ List<UpdateNews> notes = const [],  Set<String> readIds = const {}}): _notes = notes,_readIds = readIds,super._();
  

 final  List<UpdateNews> _notes;
@override@JsonKey() List<UpdateNews> get notes {
  if (_notes is EqualUnmodifiableListView) return _notes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_notes);
}

 final  Set<String> _readIds;
@override@JsonKey() Set<String> get readIds {
  if (_readIds is EqualUnmodifiableSetView) return _readIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_readIds);
}


/// Create a copy of UpdateNewsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UpdateNewsStateCopyWith<_UpdateNewsState> get copyWith => __$UpdateNewsStateCopyWithImpl<_UpdateNewsState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UpdateNewsState&&const DeepCollectionEquality().equals(other.notes, _notes)&&const DeepCollectionEquality().equals(other.readIds, _readIds));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_notes),const DeepCollectionEquality().hash(_readIds));
}

@override
String toString() {
    return 'UpdateNewsState(notes: $notes, readIds: $readIds)';
}


}

/// @nodoc
abstract mixin class _$UpdateNewsStateCopyWith<$Res> implements $UpdateNewsStateCopyWith<$Res> {
  factory _$UpdateNewsStateCopyWith(_UpdateNewsState value, $Res Function(_UpdateNewsState) _then) = __$UpdateNewsStateCopyWithImpl;
@override @useResult
$Res call({
 List<UpdateNews> notes, Set<String> readIds
});




}
/// @nodoc
class __$UpdateNewsStateCopyWithImpl<$Res>
    implements _$UpdateNewsStateCopyWith<$Res> {
  __$UpdateNewsStateCopyWithImpl(this._self, this._then);

  final _UpdateNewsState _self;
  final $Res Function(_UpdateNewsState) _then;

/// Create a copy of UpdateNewsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? notes = null,Object? readIds = null,}) {
  return _then(_UpdateNewsState(
notes: null == notes ? _self._notes : notes // ignore: cast_nullable_to_non_nullable
as List<UpdateNews>,readIds: null == readIds ? _self._readIds : readIds // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}


}

// dart format on
