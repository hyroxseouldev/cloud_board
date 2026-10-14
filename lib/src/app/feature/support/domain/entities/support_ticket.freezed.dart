// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'support_ticket.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SupportAttachment {

 Uint8List get bytes; String get contentType; String get fileId;
/// Create a copy of SupportAttachment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupportAttachmentCopyWith<SupportAttachment> get copyWith => _$SupportAttachmentCopyWithImpl<SupportAttachment>(this as SupportAttachment, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SupportAttachment;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportAttachment&&const DeepCollectionEquality().equals(other.bytes, _this.bytes)&&(identical(other.contentType, _this.contentType) || other.contentType == _this.contentType)&&(identical(other.fileId, _this.fileId) || other.fileId == _this.fileId));
}


@override
int get hashCode {
  final _this = this as SupportAttachment;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.bytes),_this.contentType,_this.fileId);
}

@override
String toString() {
  final _this = this as SupportAttachment;
  return 'SupportAttachment(bytes: ${_this.bytes}, contentType: ${_this.contentType}, fileId: ${_this.fileId})';
}


}

/// @nodoc
abstract mixin class $SupportAttachmentCopyWith<$Res>  {
  factory $SupportAttachmentCopyWith(SupportAttachment value, $Res Function(SupportAttachment) _then) = _$SupportAttachmentCopyWithImpl;
@useResult
$Res call({
 Uint8List bytes, String contentType, String fileId
});




}
/// @nodoc
class _$SupportAttachmentCopyWithImpl<$Res>
    implements $SupportAttachmentCopyWith<$Res> {
  _$SupportAttachmentCopyWithImpl(this._self, this._then);

  final SupportAttachment _self;
  final $Res Function(SupportAttachment) _then;

/// Create a copy of SupportAttachment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bytes = null,Object? contentType = null,Object? fileId = null,}) {
  return _then(SupportAttachment(
bytes: null == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as Uint8List,contentType: null == contentType ? _self.contentType : contentType // ignore: cast_nullable_to_non_nullable
as String,fileId: null == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SupportAttachment].
extension SupportAttachmentPatterns on SupportAttachment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupportAttachment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupportAttachment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupportAttachment value)  $default,){
final _that = this;
switch (_that) {
case _SupportAttachment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupportAttachment value)?  $default,){
final _that = this;
switch (_that) {
case _SupportAttachment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Uint8List bytes,  String contentType,  String fileId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupportAttachment() when $default != null:
return $default(_that.bytes,_that.contentType,_that.fileId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Uint8List bytes,  String contentType,  String fileId)  $default,) {final _that = this;
switch (_that) {
case _SupportAttachment():
return $default(_that.bytes,_that.contentType,_that.fileId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Uint8List bytes,  String contentType,  String fileId)?  $default,) {final _that = this;
switch (_that) {
case _SupportAttachment() when $default != null:
return $default(_that.bytes,_that.contentType,_that.fileId);case _:
  return null;

}
}

}

/// @nodoc


class _SupportAttachment implements SupportAttachment {
  const _SupportAttachment({required this.bytes, required this.contentType, required this.fileId});
  

@override final  Uint8List bytes;
@override final  String contentType;
@override final  String fileId;

/// Create a copy of SupportAttachment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupportAttachmentCopyWith<_SupportAttachment> get copyWith => __$SupportAttachmentCopyWithImpl<_SupportAttachment>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupportAttachment&&const DeepCollectionEquality().equals(other.bytes, bytes)&&(identical(other.contentType, contentType) || other.contentType == contentType)&&(identical(other.fileId, fileId) || other.fileId == fileId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(bytes),contentType,fileId);
}

@override
String toString() {
    return 'SupportAttachment(bytes: $bytes, contentType: $contentType, fileId: $fileId)';
}


}

/// @nodoc
abstract mixin class _$SupportAttachmentCopyWith<$Res> implements $SupportAttachmentCopyWith<$Res> {
  factory _$SupportAttachmentCopyWith(_SupportAttachment value, $Res Function(_SupportAttachment) _then) = __$SupportAttachmentCopyWithImpl;
@override @useResult
$Res call({
 Uint8List bytes, String contentType, String fileId
});




}
/// @nodoc
class __$SupportAttachmentCopyWithImpl<$Res>
    implements _$SupportAttachmentCopyWith<$Res> {
  __$SupportAttachmentCopyWithImpl(this._self, this._then);

  final _SupportAttachment _self;
  final $Res Function(_SupportAttachment) _then;

/// Create a copy of SupportAttachment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bytes = null,Object? contentType = null,Object? fileId = null,}) {
  return _then(_SupportAttachment(
bytes: null == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as Uint8List,contentType: null == contentType ? _self.contentType : contentType // ignore: cast_nullable_to_non_nullable
as String,fileId: null == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$SupportTicket {

 String get id; String get number; int get receivedAtMs; String get notificationStatus;
/// Create a copy of SupportTicket
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupportTicketCopyWith<SupportTicket> get copyWith => _$SupportTicketCopyWithImpl<SupportTicket>(this as SupportTicket, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SupportTicket;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportTicket&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.receivedAtMs, _this.receivedAtMs) || other.receivedAtMs == _this.receivedAtMs)&&(identical(other.notificationStatus, _this.notificationStatus) || other.notificationStatus == _this.notificationStatus));
}


@override
int get hashCode {
  final _this = this as SupportTicket;
  return Object.hash(runtimeType,_this.id,_this.number,_this.receivedAtMs,_this.notificationStatus);
}

@override
String toString() {
  final _this = this as SupportTicket;
  return 'SupportTicket(id: ${_this.id}, number: ${_this.number}, receivedAtMs: ${_this.receivedAtMs}, notificationStatus: ${_this.notificationStatus})';
}


}

/// @nodoc
abstract mixin class $SupportTicketCopyWith<$Res>  {
  factory $SupportTicketCopyWith(SupportTicket value, $Res Function(SupportTicket) _then) = _$SupportTicketCopyWithImpl;
@useResult
$Res call({
 String id, String number, int receivedAtMs, String notificationStatus
});




}
/// @nodoc
class _$SupportTicketCopyWithImpl<$Res>
    implements $SupportTicketCopyWith<$Res> {
  _$SupportTicketCopyWithImpl(this._self, this._then);

  final SupportTicket _self;
  final $Res Function(SupportTicket) _then;

/// Create a copy of SupportTicket
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? receivedAtMs = null,Object? notificationStatus = null,}) {
  return _then(SupportTicket(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,receivedAtMs: null == receivedAtMs ? _self.receivedAtMs : receivedAtMs // ignore: cast_nullable_to_non_nullable
as int,notificationStatus: null == notificationStatus ? _self.notificationStatus : notificationStatus // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SupportTicket].
extension SupportTicketPatterns on SupportTicket {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupportTicket value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupportTicket() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupportTicket value)  $default,){
final _that = this;
switch (_that) {
case _SupportTicket():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupportTicket value)?  $default,){
final _that = this;
switch (_that) {
case _SupportTicket() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String number,  int receivedAtMs,  String notificationStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupportTicket() when $default != null:
return $default(_that.id,_that.number,_that.receivedAtMs,_that.notificationStatus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String number,  int receivedAtMs,  String notificationStatus)  $default,) {final _that = this;
switch (_that) {
case _SupportTicket():
return $default(_that.id,_that.number,_that.receivedAtMs,_that.notificationStatus);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String number,  int receivedAtMs,  String notificationStatus)?  $default,) {final _that = this;
switch (_that) {
case _SupportTicket() when $default != null:
return $default(_that.id,_that.number,_that.receivedAtMs,_that.notificationStatus);case _:
  return null;

}
}

}

/// @nodoc


class _SupportTicket implements SupportTicket {
  const _SupportTicket({required this.id, required this.number, required this.receivedAtMs, required this.notificationStatus});
  

@override final  String id;
@override final  String number;
@override final  int receivedAtMs;
@override final  String notificationStatus;

/// Create a copy of SupportTicket
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupportTicketCopyWith<_SupportTicket> get copyWith => __$SupportTicketCopyWithImpl<_SupportTicket>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupportTicket&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.receivedAtMs, receivedAtMs) || other.receivedAtMs == receivedAtMs)&&(identical(other.notificationStatus, notificationStatus) || other.notificationStatus == notificationStatus));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,number,receivedAtMs,notificationStatus);
}

@override
String toString() {
    return 'SupportTicket(id: $id, number: $number, receivedAtMs: $receivedAtMs, notificationStatus: $notificationStatus)';
}


}

/// @nodoc
abstract mixin class _$SupportTicketCopyWith<$Res> implements $SupportTicketCopyWith<$Res> {
  factory _$SupportTicketCopyWith(_SupportTicket value, $Res Function(_SupportTicket) _then) = __$SupportTicketCopyWithImpl;
@override @useResult
$Res call({
 String id, String number, int receivedAtMs, String notificationStatus
});




}
/// @nodoc
class __$SupportTicketCopyWithImpl<$Res>
    implements _$SupportTicketCopyWith<$Res> {
  __$SupportTicketCopyWithImpl(this._self, this._then);

  final _SupportTicket _self;
  final $Res Function(_SupportTicket) _then;

/// Create a copy of SupportTicket
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? receivedAtMs = null,Object? notificationStatus = null,}) {
  return _then(_SupportTicket(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,receivedAtMs: null == receivedAtMs ? _self.receivedAtMs : receivedAtMs // ignore: cast_nullable_to_non_nullable
as int,notificationStatus: null == notificationStatus ? _self.notificationStatus : notificationStatus // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$SupportDraft {

 String get requestId; String get message; String get replyEmail; Map<String, Object?> get diagnostics; SupportAttachment? get attachment; SupportTicket? get ticket; bool get submitting; bool get frozen; String? get error;
/// Create a copy of SupportDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupportDraftCopyWith<SupportDraft> get copyWith => _$SupportDraftCopyWithImpl<SupportDraft>(this as SupportDraft, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SupportDraft;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportDraft&&(identical(other.requestId, _this.requestId) || other.requestId == _this.requestId)&&(identical(other.message, _this.message) || other.message == _this.message)&&(identical(other.replyEmail, _this.replyEmail) || other.replyEmail == _this.replyEmail)&&const DeepCollectionEquality().equals(other.diagnostics, _this.diagnostics)&&(identical(other.attachment, _this.attachment) || other.attachment == _this.attachment)&&(identical(other.ticket, _this.ticket) || other.ticket == _this.ticket)&&(identical(other.submitting, _this.submitting) || other.submitting == _this.submitting)&&(identical(other.frozen, _this.frozen) || other.frozen == _this.frozen)&&(identical(other.error, _this.error) || other.error == _this.error));
}


@override
int get hashCode {
  final _this = this as SupportDraft;
  return Object.hash(runtimeType,_this.requestId,_this.message,_this.replyEmail,const DeepCollectionEquality().hash(_this.diagnostics),_this.attachment,_this.ticket,_this.submitting,_this.frozen,_this.error);
}

@override
String toString() {
  final _this = this as SupportDraft;
  return 'SupportDraft(requestId: ${_this.requestId}, message: ${_this.message}, replyEmail: ${_this.replyEmail}, diagnostics: ${_this.diagnostics}, attachment: ${_this.attachment}, ticket: ${_this.ticket}, submitting: ${_this.submitting}, frozen: ${_this.frozen}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $SupportDraftCopyWith<$Res>  {
  factory $SupportDraftCopyWith(SupportDraft value, $Res Function(SupportDraft) _then) = _$SupportDraftCopyWithImpl;
@useResult
$Res call({
 String requestId, String message, String replyEmail, Map<String, Object?> diagnostics, SupportAttachment? attachment, SupportTicket? ticket, bool submitting, bool frozen, String? error
});


$SupportAttachmentCopyWith<$Res>? get attachment;$SupportTicketCopyWith<$Res>? get ticket;

}
/// @nodoc
class _$SupportDraftCopyWithImpl<$Res>
    implements $SupportDraftCopyWith<$Res> {
  _$SupportDraftCopyWithImpl(this._self, this._then);

  final SupportDraft _self;
  final $Res Function(SupportDraft) _then;

/// Create a copy of SupportDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? requestId = null,Object? message = null,Object? replyEmail = null,Object? diagnostics = null,Object? attachment = freezed,Object? ticket = freezed,Object? submitting = null,Object? frozen = null,Object? error = freezed,}) {
  return _then(SupportDraft(
requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,replyEmail: null == replyEmail ? _self.replyEmail : replyEmail // ignore: cast_nullable_to_non_nullable
as String,diagnostics: null == diagnostics ? _self.diagnostics : diagnostics // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,attachment: freezed == attachment ? _self.attachment : attachment // ignore: cast_nullable_to_non_nullable
as SupportAttachment?,ticket: freezed == ticket ? _self.ticket : ticket // ignore: cast_nullable_to_non_nullable
as SupportTicket?,submitting: null == submitting ? _self.submitting : submitting // ignore: cast_nullable_to_non_nullable
as bool,frozen: null == frozen ? _self.frozen : frozen // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of SupportDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupportAttachmentCopyWith<$Res>? get attachment {
    if (_self.attachment == null) {
    return null;
  }

  return $SupportAttachmentCopyWith<$Res>(_self.attachment!, (value) {
    return _then(_self.copyWith(attachment: value));
  });
}/// Create a copy of SupportDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupportTicketCopyWith<$Res>? get ticket {
    if (_self.ticket == null) {
    return null;
  }

  return $SupportTicketCopyWith<$Res>(_self.ticket!, (value) {
    return _then(_self.copyWith(ticket: value));
  });
}
}


/// Adds pattern-matching-related methods to [SupportDraft].
extension SupportDraftPatterns on SupportDraft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SupportDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SupportDraft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SupportDraft value)  $default,){
final _that = this;
switch (_that) {
case _SupportDraft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SupportDraft value)?  $default,){
final _that = this;
switch (_that) {
case _SupportDraft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String requestId,  String message,  String replyEmail,  Map<String, Object?> diagnostics,  SupportAttachment? attachment,  SupportTicket? ticket,  bool submitting,  bool frozen,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SupportDraft() when $default != null:
return $default(_that.requestId,_that.message,_that.replyEmail,_that.diagnostics,_that.attachment,_that.ticket,_that.submitting,_that.frozen,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String requestId,  String message,  String replyEmail,  Map<String, Object?> diagnostics,  SupportAttachment? attachment,  SupportTicket? ticket,  bool submitting,  bool frozen,  String? error)  $default,) {final _that = this;
switch (_that) {
case _SupportDraft():
return $default(_that.requestId,_that.message,_that.replyEmail,_that.diagnostics,_that.attachment,_that.ticket,_that.submitting,_that.frozen,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String requestId,  String message,  String replyEmail,  Map<String, Object?> diagnostics,  SupportAttachment? attachment,  SupportTicket? ticket,  bool submitting,  bool frozen,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _SupportDraft() when $default != null:
return $default(_that.requestId,_that.message,_that.replyEmail,_that.diagnostics,_that.attachment,_that.ticket,_that.submitting,_that.frozen,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _SupportDraft implements SupportDraft {
  const _SupportDraft({required this.requestId, this.message = '', this.replyEmail = '',  Map<String, Object?> diagnostics = const {}, this.attachment, this.ticket, this.submitting = false, this.frozen = false, this.error}): _diagnostics = diagnostics;
  

@override final  String requestId;
@override@JsonKey() final  String message;
@override@JsonKey() final  String replyEmail;
 final  Map<String, Object?> _diagnostics;
@override@JsonKey() Map<String, Object?> get diagnostics {
  if (_diagnostics is EqualUnmodifiableMapView) return _diagnostics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_diagnostics);
}

@override final  SupportAttachment? attachment;
@override final  SupportTicket? ticket;
@override@JsonKey() final  bool submitting;
@override@JsonKey() final  bool frozen;
@override final  String? error;

/// Create a copy of SupportDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SupportDraftCopyWith<_SupportDraft> get copyWith => __$SupportDraftCopyWithImpl<_SupportDraft>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SupportDraft&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.message, message) || other.message == message)&&(identical(other.replyEmail, replyEmail) || other.replyEmail == replyEmail)&&const DeepCollectionEquality().equals(other.diagnostics, _diagnostics)&&(identical(other.attachment, attachment) || other.attachment == attachment)&&(identical(other.ticket, ticket) || other.ticket == ticket)&&(identical(other.submitting, submitting) || other.submitting == submitting)&&(identical(other.frozen, frozen) || other.frozen == frozen)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,requestId,message,replyEmail,const DeepCollectionEquality().hash(_diagnostics),attachment,ticket,submitting,frozen,error);
}

@override
String toString() {
    return 'SupportDraft(requestId: $requestId, message: $message, replyEmail: $replyEmail, diagnostics: $diagnostics, attachment: $attachment, ticket: $ticket, submitting: $submitting, frozen: $frozen, error: $error)';
}


}

/// @nodoc
abstract mixin class _$SupportDraftCopyWith<$Res> implements $SupportDraftCopyWith<$Res> {
  factory _$SupportDraftCopyWith(_SupportDraft value, $Res Function(_SupportDraft) _then) = __$SupportDraftCopyWithImpl;
@override @useResult
$Res call({
 String requestId, String message, String replyEmail, Map<String, Object?> diagnostics, SupportAttachment? attachment, SupportTicket? ticket, bool submitting, bool frozen, String? error
});


@override $SupportAttachmentCopyWith<$Res>? get attachment;@override $SupportTicketCopyWith<$Res>? get ticket;

}
/// @nodoc
class __$SupportDraftCopyWithImpl<$Res>
    implements _$SupportDraftCopyWith<$Res> {
  __$SupportDraftCopyWithImpl(this._self, this._then);

  final _SupportDraft _self;
  final $Res Function(_SupportDraft) _then;

/// Create a copy of SupportDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? requestId = null,Object? message = null,Object? replyEmail = null,Object? diagnostics = null,Object? attachment = freezed,Object? ticket = freezed,Object? submitting = null,Object? frozen = null,Object? error = freezed,}) {
  return _then(_SupportDraft(
requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,replyEmail: null == replyEmail ? _self.replyEmail : replyEmail // ignore: cast_nullable_to_non_nullable
as String,diagnostics: null == diagnostics ? _self._diagnostics : diagnostics // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,attachment: freezed == attachment ? _self.attachment : attachment // ignore: cast_nullable_to_non_nullable
as SupportAttachment?,ticket: freezed == ticket ? _self.ticket : ticket // ignore: cast_nullable_to_non_nullable
as SupportTicket?,submitting: null == submitting ? _self.submitting : submitting // ignore: cast_nullable_to_non_nullable
as bool,frozen: null == frozen ? _self.frozen : frozen // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of SupportDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupportAttachmentCopyWith<$Res>? get attachment {
    if (_self.attachment == null) {
    return null;
  }

  return $SupportAttachmentCopyWith<$Res>(_self.attachment!, (value) {
    return _then(_self.copyWith(attachment: value));
  });
}/// Create a copy of SupportDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SupportTicketCopyWith<$Res>? get ticket {
    if (_self.ticket == null) {
    return null;
  }

  return $SupportTicketCopyWith<$Res>(_self.ticket!, (value) {
    return _then(_self.copyWith(ticket: value));
  });
}
}

// dart format on
