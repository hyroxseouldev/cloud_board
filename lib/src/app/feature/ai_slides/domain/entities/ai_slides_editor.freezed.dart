// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_slides_editor.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AiSlideTheme {

 int? get designBackgroundColor; int? get designTextColor; int? get designAccentColor; String get designLayout; int get designFontWeight; bool get designItalic; double get designSpacing; bool get showTimer; double get timerX; double get timerY; double get timerSize;
/// Create a copy of AiSlideTheme
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiSlideThemeCopyWith<AiSlideTheme> get copyWith => _$AiSlideThemeCopyWithImpl<AiSlideTheme>(this as AiSlideTheme, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AiSlideTheme;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiSlideTheme&&(identical(other.designBackgroundColor, _this.designBackgroundColor) || other.designBackgroundColor == _this.designBackgroundColor)&&(identical(other.designTextColor, _this.designTextColor) || other.designTextColor == _this.designTextColor)&&(identical(other.designAccentColor, _this.designAccentColor) || other.designAccentColor == _this.designAccentColor)&&(identical(other.designLayout, _this.designLayout) || other.designLayout == _this.designLayout)&&(identical(other.designFontWeight, _this.designFontWeight) || other.designFontWeight == _this.designFontWeight)&&(identical(other.designItalic, _this.designItalic) || other.designItalic == _this.designItalic)&&(identical(other.designSpacing, _this.designSpacing) || other.designSpacing == _this.designSpacing)&&(identical(other.showTimer, _this.showTimer) || other.showTimer == _this.showTimer)&&(identical(other.timerX, _this.timerX) || other.timerX == _this.timerX)&&(identical(other.timerY, _this.timerY) || other.timerY == _this.timerY)&&(identical(other.timerSize, _this.timerSize) || other.timerSize == _this.timerSize));
}


@override
int get hashCode {
  final _this = this as AiSlideTheme;
  return Object.hash(runtimeType,_this.designBackgroundColor,_this.designTextColor,_this.designAccentColor,_this.designLayout,_this.designFontWeight,_this.designItalic,_this.designSpacing,_this.showTimer,_this.timerX,_this.timerY,_this.timerSize);
}

@override
String toString() {
  final _this = this as AiSlideTheme;
  return 'AiSlideTheme(designBackgroundColor: ${_this.designBackgroundColor}, designTextColor: ${_this.designTextColor}, designAccentColor: ${_this.designAccentColor}, designLayout: ${_this.designLayout}, designFontWeight: ${_this.designFontWeight}, designItalic: ${_this.designItalic}, designSpacing: ${_this.designSpacing}, showTimer: ${_this.showTimer}, timerX: ${_this.timerX}, timerY: ${_this.timerY}, timerSize: ${_this.timerSize})';
}


}

/// @nodoc
abstract mixin class $AiSlideThemeCopyWith<$Res>  {
  factory $AiSlideThemeCopyWith(AiSlideTheme value, $Res Function(AiSlideTheme) _then) = _$AiSlideThemeCopyWithImpl;
@useResult
$Res call({
 int? designBackgroundColor, int? designTextColor, int? designAccentColor, String designLayout, int designFontWeight, bool designItalic, double designSpacing, bool showTimer, double timerX, double timerY, double timerSize
});




}
/// @nodoc
class _$AiSlideThemeCopyWithImpl<$Res>
    implements $AiSlideThemeCopyWith<$Res> {
  _$AiSlideThemeCopyWithImpl(this._self, this._then);

  final AiSlideTheme _self;
  final $Res Function(AiSlideTheme) _then;

/// Create a copy of AiSlideTheme
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? designBackgroundColor = freezed,Object? designTextColor = freezed,Object? designAccentColor = freezed,Object? designLayout = null,Object? designFontWeight = null,Object? designItalic = null,Object? designSpacing = null,Object? showTimer = null,Object? timerX = null,Object? timerY = null,Object? timerSize = null,}) {
  return _then(AiSlideTheme(
designBackgroundColor: freezed == designBackgroundColor ? _self.designBackgroundColor : designBackgroundColor // ignore: cast_nullable_to_non_nullable
as int?,designTextColor: freezed == designTextColor ? _self.designTextColor : designTextColor // ignore: cast_nullable_to_non_nullable
as int?,designAccentColor: freezed == designAccentColor ? _self.designAccentColor : designAccentColor // ignore: cast_nullable_to_non_nullable
as int?,designLayout: null == designLayout ? _self.designLayout : designLayout // ignore: cast_nullable_to_non_nullable
as String,designFontWeight: null == designFontWeight ? _self.designFontWeight : designFontWeight // ignore: cast_nullable_to_non_nullable
as int,designItalic: null == designItalic ? _self.designItalic : designItalic // ignore: cast_nullable_to_non_nullable
as bool,designSpacing: null == designSpacing ? _self.designSpacing : designSpacing // ignore: cast_nullable_to_non_nullable
as double,showTimer: null == showTimer ? _self.showTimer : showTimer // ignore: cast_nullable_to_non_nullable
as bool,timerX: null == timerX ? _self.timerX : timerX // ignore: cast_nullable_to_non_nullable
as double,timerY: null == timerY ? _self.timerY : timerY // ignore: cast_nullable_to_non_nullable
as double,timerSize: null == timerSize ? _self.timerSize : timerSize // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [AiSlideTheme].
extension AiSlideThemePatterns on AiSlideTheme {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiSlideTheme value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiSlideTheme() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiSlideTheme value)  $default,){
final _that = this;
switch (_that) {
case _AiSlideTheme():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiSlideTheme value)?  $default,){
final _that = this;
switch (_that) {
case _AiSlideTheme() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? designBackgroundColor,  int? designTextColor,  int? designAccentColor,  String designLayout,  int designFontWeight,  bool designItalic,  double designSpacing,  bool showTimer,  double timerX,  double timerY,  double timerSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiSlideTheme() when $default != null:
return $default(_that.designBackgroundColor,_that.designTextColor,_that.designAccentColor,_that.designLayout,_that.designFontWeight,_that.designItalic,_that.designSpacing,_that.showTimer,_that.timerX,_that.timerY,_that.timerSize);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? designBackgroundColor,  int? designTextColor,  int? designAccentColor,  String designLayout,  int designFontWeight,  bool designItalic,  double designSpacing,  bool showTimer,  double timerX,  double timerY,  double timerSize)  $default,) {final _that = this;
switch (_that) {
case _AiSlideTheme():
return $default(_that.designBackgroundColor,_that.designTextColor,_that.designAccentColor,_that.designLayout,_that.designFontWeight,_that.designItalic,_that.designSpacing,_that.showTimer,_that.timerX,_that.timerY,_that.timerSize);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? designBackgroundColor,  int? designTextColor,  int? designAccentColor,  String designLayout,  int designFontWeight,  bool designItalic,  double designSpacing,  bool showTimer,  double timerX,  double timerY,  double timerSize)?  $default,) {final _that = this;
switch (_that) {
case _AiSlideTheme() when $default != null:
return $default(_that.designBackgroundColor,_that.designTextColor,_that.designAccentColor,_that.designLayout,_that.designFontWeight,_that.designItalic,_that.designSpacing,_that.showTimer,_that.timerX,_that.timerY,_that.timerSize);case _:
  return null;

}
}

}

/// @nodoc


class _AiSlideTheme implements AiSlideTheme {
  const _AiSlideTheme({this.designBackgroundColor, this.designTextColor, this.designAccentColor, this.designLayout = 'auto', this.designFontWeight = 900, this.designItalic = true, this.designSpacing = 1.0, this.showTimer = true, this.timerX = 0.84, this.timerY = 0.5, this.timerSize = 1.0});
  

@override final  int? designBackgroundColor;
@override final  int? designTextColor;
@override final  int? designAccentColor;
@override@JsonKey() final  String designLayout;
@override@JsonKey() final  int designFontWeight;
@override@JsonKey() final  bool designItalic;
@override@JsonKey() final  double designSpacing;
@override@JsonKey() final  bool showTimer;
@override@JsonKey() final  double timerX;
@override@JsonKey() final  double timerY;
@override@JsonKey() final  double timerSize;

/// Create a copy of AiSlideTheme
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiSlideThemeCopyWith<_AiSlideTheme> get copyWith => __$AiSlideThemeCopyWithImpl<_AiSlideTheme>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiSlideTheme&&(identical(other.designBackgroundColor, designBackgroundColor) || other.designBackgroundColor == designBackgroundColor)&&(identical(other.designTextColor, designTextColor) || other.designTextColor == designTextColor)&&(identical(other.designAccentColor, designAccentColor) || other.designAccentColor == designAccentColor)&&(identical(other.designLayout, designLayout) || other.designLayout == designLayout)&&(identical(other.designFontWeight, designFontWeight) || other.designFontWeight == designFontWeight)&&(identical(other.designItalic, designItalic) || other.designItalic == designItalic)&&(identical(other.designSpacing, designSpacing) || other.designSpacing == designSpacing)&&(identical(other.showTimer, showTimer) || other.showTimer == showTimer)&&(identical(other.timerX, timerX) || other.timerX == timerX)&&(identical(other.timerY, timerY) || other.timerY == timerY)&&(identical(other.timerSize, timerSize) || other.timerSize == timerSize));
}


@override
int get hashCode {
    return Object.hash(runtimeType,designBackgroundColor,designTextColor,designAccentColor,designLayout,designFontWeight,designItalic,designSpacing,showTimer,timerX,timerY,timerSize);
}

@override
String toString() {
    return 'AiSlideTheme(designBackgroundColor: $designBackgroundColor, designTextColor: $designTextColor, designAccentColor: $designAccentColor, designLayout: $designLayout, designFontWeight: $designFontWeight, designItalic: $designItalic, designSpacing: $designSpacing, showTimer: $showTimer, timerX: $timerX, timerY: $timerY, timerSize: $timerSize)';
}


}

/// @nodoc
abstract mixin class _$AiSlideThemeCopyWith<$Res> implements $AiSlideThemeCopyWith<$Res> {
  factory _$AiSlideThemeCopyWith(_AiSlideTheme value, $Res Function(_AiSlideTheme) _then) = __$AiSlideThemeCopyWithImpl;
@override @useResult
$Res call({
 int? designBackgroundColor, int? designTextColor, int? designAccentColor, String designLayout, int designFontWeight, bool designItalic, double designSpacing, bool showTimer, double timerX, double timerY, double timerSize
});




}
/// @nodoc
class __$AiSlideThemeCopyWithImpl<$Res>
    implements _$AiSlideThemeCopyWith<$Res> {
  __$AiSlideThemeCopyWithImpl(this._self, this._then);

  final _AiSlideTheme _self;
  final $Res Function(_AiSlideTheme) _then;

/// Create a copy of AiSlideTheme
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? designBackgroundColor = freezed,Object? designTextColor = freezed,Object? designAccentColor = freezed,Object? designLayout = null,Object? designFontWeight = null,Object? designItalic = null,Object? designSpacing = null,Object? showTimer = null,Object? timerX = null,Object? timerY = null,Object? timerSize = null,}) {
  return _then(_AiSlideTheme(
designBackgroundColor: freezed == designBackgroundColor ? _self.designBackgroundColor : designBackgroundColor // ignore: cast_nullable_to_non_nullable
as int?,designTextColor: freezed == designTextColor ? _self.designTextColor : designTextColor // ignore: cast_nullable_to_non_nullable
as int?,designAccentColor: freezed == designAccentColor ? _self.designAccentColor : designAccentColor // ignore: cast_nullable_to_non_nullable
as int?,designLayout: null == designLayout ? _self.designLayout : designLayout // ignore: cast_nullable_to_non_nullable
as String,designFontWeight: null == designFontWeight ? _self.designFontWeight : designFontWeight // ignore: cast_nullable_to_non_nullable
as int,designItalic: null == designItalic ? _self.designItalic : designItalic // ignore: cast_nullable_to_non_nullable
as bool,designSpacing: null == designSpacing ? _self.designSpacing : designSpacing // ignore: cast_nullable_to_non_nullable
as double,showTimer: null == showTimer ? _self.showTimer : showTimer // ignore: cast_nullable_to_non_nullable
as bool,timerX: null == timerX ? _self.timerX : timerX // ignore: cast_nullable_to_non_nullable
as double,timerY: null == timerY ? _self.timerY : timerY // ignore: cast_nullable_to_non_nullable
as double,timerSize: null == timerSize ? _self.timerSize : timerSize // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$AiSlidesSavedDraft {

 String get prompt; String? get generatedPrompt; AiSlideDraft? get draft; List<String> get warnings;
/// Create a copy of AiSlidesSavedDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiSlidesSavedDraftCopyWith<AiSlidesSavedDraft> get copyWith => _$AiSlidesSavedDraftCopyWithImpl<AiSlidesSavedDraft>(this as AiSlidesSavedDraft, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AiSlidesSavedDraft;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiSlidesSavedDraft&&(identical(other.prompt, _this.prompt) || other.prompt == _this.prompt)&&(identical(other.generatedPrompt, _this.generatedPrompt) || other.generatedPrompt == _this.generatedPrompt)&&(identical(other.draft, _this.draft) || other.draft == _this.draft)&&const DeepCollectionEquality().equals(other.warnings, _this.warnings));
}


@override
int get hashCode {
  final _this = this as AiSlidesSavedDraft;
  return Object.hash(runtimeType,_this.prompt,_this.generatedPrompt,_this.draft,const DeepCollectionEquality().hash(_this.warnings));
}

@override
String toString() {
  final _this = this as AiSlidesSavedDraft;
  return 'AiSlidesSavedDraft(prompt: ${_this.prompt}, generatedPrompt: ${_this.generatedPrompt}, draft: ${_this.draft}, warnings: ${_this.warnings})';
}


}

/// @nodoc
abstract mixin class $AiSlidesSavedDraftCopyWith<$Res>  {
  factory $AiSlidesSavedDraftCopyWith(AiSlidesSavedDraft value, $Res Function(AiSlidesSavedDraft) _then) = _$AiSlidesSavedDraftCopyWithImpl;
@useResult
$Res call({
 String prompt, String? generatedPrompt, AiSlideDraft? draft, List<String> warnings
});


$AiSlideDraftCopyWith<$Res>? get draft;

}
/// @nodoc
class _$AiSlidesSavedDraftCopyWithImpl<$Res>
    implements $AiSlidesSavedDraftCopyWith<$Res> {
  _$AiSlidesSavedDraftCopyWithImpl(this._self, this._then);

  final AiSlidesSavedDraft _self;
  final $Res Function(AiSlidesSavedDraft) _then;

/// Create a copy of AiSlidesSavedDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? prompt = null,Object? generatedPrompt = freezed,Object? draft = freezed,Object? warnings = null,}) {
  return _then(AiSlidesSavedDraft(
prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,generatedPrompt: freezed == generatedPrompt ? _self.generatedPrompt : generatedPrompt // ignore: cast_nullable_to_non_nullable
as String?,draft: freezed == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as AiSlideDraft?,warnings: null == warnings ? _self.warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of AiSlidesSavedDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiSlideDraftCopyWith<$Res>? get draft {
    if (_self.draft == null) {
    return null;
  }

  return $AiSlideDraftCopyWith<$Res>(_self.draft!, (value) {
    return _then(_self.copyWith(draft: value));
  });
}
}


/// Adds pattern-matching-related methods to [AiSlidesSavedDraft].
extension AiSlidesSavedDraftPatterns on AiSlidesSavedDraft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiSlidesSavedDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiSlidesSavedDraft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiSlidesSavedDraft value)  $default,){
final _that = this;
switch (_that) {
case _AiSlidesSavedDraft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiSlidesSavedDraft value)?  $default,){
final _that = this;
switch (_that) {
case _AiSlidesSavedDraft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String prompt,  String? generatedPrompt,  AiSlideDraft? draft,  List<String> warnings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiSlidesSavedDraft() when $default != null:
return $default(_that.prompt,_that.generatedPrompt,_that.draft,_that.warnings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String prompt,  String? generatedPrompt,  AiSlideDraft? draft,  List<String> warnings)  $default,) {final _that = this;
switch (_that) {
case _AiSlidesSavedDraft():
return $default(_that.prompt,_that.generatedPrompt,_that.draft,_that.warnings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String prompt,  String? generatedPrompt,  AiSlideDraft? draft,  List<String> warnings)?  $default,) {final _that = this;
switch (_that) {
case _AiSlidesSavedDraft() when $default != null:
return $default(_that.prompt,_that.generatedPrompt,_that.draft,_that.warnings);case _:
  return null;

}
}

}

/// @nodoc


class _AiSlidesSavedDraft implements AiSlidesSavedDraft {
  const _AiSlidesSavedDraft({this.prompt = '', this.generatedPrompt, this.draft,  List<String> warnings = const []}): _warnings = warnings;
  

@override@JsonKey() final  String prompt;
@override final  String? generatedPrompt;
@override final  AiSlideDraft? draft;
 final  List<String> _warnings;
@override@JsonKey() List<String> get warnings {
  if (_warnings is EqualUnmodifiableListView) return _warnings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_warnings);
}


/// Create a copy of AiSlidesSavedDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiSlidesSavedDraftCopyWith<_AiSlidesSavedDraft> get copyWith => __$AiSlidesSavedDraftCopyWithImpl<_AiSlidesSavedDraft>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiSlidesSavedDraft&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.generatedPrompt, generatedPrompt) || other.generatedPrompt == generatedPrompt)&&(identical(other.draft, draft) || other.draft == draft)&&const DeepCollectionEquality().equals(other.warnings, _warnings));
}


@override
int get hashCode {
    return Object.hash(runtimeType,prompt,generatedPrompt,draft,const DeepCollectionEquality().hash(_warnings));
}

@override
String toString() {
    return 'AiSlidesSavedDraft(prompt: $prompt, generatedPrompt: $generatedPrompt, draft: $draft, warnings: $warnings)';
}


}

/// @nodoc
abstract mixin class _$AiSlidesSavedDraftCopyWith<$Res> implements $AiSlidesSavedDraftCopyWith<$Res> {
  factory _$AiSlidesSavedDraftCopyWith(_AiSlidesSavedDraft value, $Res Function(_AiSlidesSavedDraft) _then) = __$AiSlidesSavedDraftCopyWithImpl;
@override @useResult
$Res call({
 String prompt, String? generatedPrompt, AiSlideDraft? draft, List<String> warnings
});


@override $AiSlideDraftCopyWith<$Res>? get draft;

}
/// @nodoc
class __$AiSlidesSavedDraftCopyWithImpl<$Res>
    implements _$AiSlidesSavedDraftCopyWith<$Res> {
  __$AiSlidesSavedDraftCopyWithImpl(this._self, this._then);

  final _AiSlidesSavedDraft _self;
  final $Res Function(_AiSlidesSavedDraft) _then;

/// Create a copy of AiSlidesSavedDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? prompt = null,Object? generatedPrompt = freezed,Object? draft = freezed,Object? warnings = null,}) {
  return _then(_AiSlidesSavedDraft(
prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,generatedPrompt: freezed == generatedPrompt ? _self.generatedPrompt : generatedPrompt // ignore: cast_nullable_to_non_nullable
as String?,draft: freezed == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as AiSlideDraft?,warnings: null == warnings ? _self._warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of AiSlidesSavedDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiSlideDraftCopyWith<$Res>? get draft {
    if (_self.draft == null) {
    return null;
  }

  return $AiSlideDraftCopyWith<$Res>(_self.draft!, (value) {
    return _then(_self.copyWith(draft: value));
  });
}
}

/// @nodoc
mixin _$AiSlidesEditorState {

 String get prompt; String? get generatedPrompt; AiSlideDraft? get draft; List<String> get warnings; bool get generating; bool get loading; String? get error; String? get storageError; bool get canUndo; AiSlideTheme? get theme; bool get themeSaving; bool get themeSaved; String? get themeError; int? get remaining; bool get cached;
/// Create a copy of AiSlidesEditorState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiSlidesEditorStateCopyWith<AiSlidesEditorState> get copyWith => _$AiSlidesEditorStateCopyWithImpl<AiSlidesEditorState>(this as AiSlidesEditorState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AiSlidesEditorState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiSlidesEditorState&&(identical(other.prompt, _this.prompt) || other.prompt == _this.prompt)&&(identical(other.generatedPrompt, _this.generatedPrompt) || other.generatedPrompt == _this.generatedPrompt)&&(identical(other.draft, _this.draft) || other.draft == _this.draft)&&const DeepCollectionEquality().equals(other.warnings, _this.warnings)&&(identical(other.generating, _this.generating) || other.generating == _this.generating)&&(identical(other.loading, _this.loading) || other.loading == _this.loading)&&(identical(other.error, _this.error) || other.error == _this.error)&&(identical(other.storageError, _this.storageError) || other.storageError == _this.storageError)&&(identical(other.canUndo, _this.canUndo) || other.canUndo == _this.canUndo)&&(identical(other.theme, _this.theme) || other.theme == _this.theme)&&(identical(other.themeSaving, _this.themeSaving) || other.themeSaving == _this.themeSaving)&&(identical(other.themeSaved, _this.themeSaved) || other.themeSaved == _this.themeSaved)&&(identical(other.themeError, _this.themeError) || other.themeError == _this.themeError)&&(identical(other.remaining, _this.remaining) || other.remaining == _this.remaining)&&(identical(other.cached, _this.cached) || other.cached == _this.cached));
}


@override
int get hashCode {
  final _this = this as AiSlidesEditorState;
  return Object.hash(runtimeType,_this.prompt,_this.generatedPrompt,_this.draft,const DeepCollectionEquality().hash(_this.warnings),_this.generating,_this.loading,_this.error,_this.storageError,_this.canUndo,_this.theme,_this.themeSaving,_this.themeSaved,_this.themeError,_this.remaining,_this.cached);
}

@override
String toString() {
  final _this = this as AiSlidesEditorState;
  return 'AiSlidesEditorState(prompt: ${_this.prompt}, generatedPrompt: ${_this.generatedPrompt}, draft: ${_this.draft}, warnings: ${_this.warnings}, generating: ${_this.generating}, loading: ${_this.loading}, error: ${_this.error}, storageError: ${_this.storageError}, canUndo: ${_this.canUndo}, theme: ${_this.theme}, themeSaving: ${_this.themeSaving}, themeSaved: ${_this.themeSaved}, themeError: ${_this.themeError}, remaining: ${_this.remaining}, cached: ${_this.cached})';
}


}

/// @nodoc
abstract mixin class $AiSlidesEditorStateCopyWith<$Res>  {
  factory $AiSlidesEditorStateCopyWith(AiSlidesEditorState value, $Res Function(AiSlidesEditorState) _then) = _$AiSlidesEditorStateCopyWithImpl;
@useResult
$Res call({
 String prompt, String? generatedPrompt, AiSlideDraft? draft, List<String> warnings, bool generating, bool loading, String? error, String? storageError, bool canUndo, AiSlideTheme? theme, bool themeSaving, bool themeSaved, String? themeError, int? remaining, bool cached
});


$AiSlideDraftCopyWith<$Res>? get draft;$AiSlideThemeCopyWith<$Res>? get theme;

}
/// @nodoc
class _$AiSlidesEditorStateCopyWithImpl<$Res>
    implements $AiSlidesEditorStateCopyWith<$Res> {
  _$AiSlidesEditorStateCopyWithImpl(this._self, this._then);

  final AiSlidesEditorState _self;
  final $Res Function(AiSlidesEditorState) _then;

/// Create a copy of AiSlidesEditorState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? prompt = null,Object? generatedPrompt = freezed,Object? draft = freezed,Object? warnings = null,Object? generating = null,Object? loading = null,Object? error = freezed,Object? storageError = freezed,Object? canUndo = null,Object? theme = freezed,Object? themeSaving = null,Object? themeSaved = null,Object? themeError = freezed,Object? remaining = freezed,Object? cached = null,}) {
  return _then(AiSlidesEditorState(
prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,generatedPrompt: freezed == generatedPrompt ? _self.generatedPrompt : generatedPrompt // ignore: cast_nullable_to_non_nullable
as String?,draft: freezed == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as AiSlideDraft?,warnings: null == warnings ? _self.warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,generating: null == generating ? _self.generating : generating // ignore: cast_nullable_to_non_nullable
as bool,loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,storageError: freezed == storageError ? _self.storageError : storageError // ignore: cast_nullable_to_non_nullable
as String?,canUndo: null == canUndo ? _self.canUndo : canUndo // ignore: cast_nullable_to_non_nullable
as bool,theme: freezed == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as AiSlideTheme?,themeSaving: null == themeSaving ? _self.themeSaving : themeSaving // ignore: cast_nullable_to_non_nullable
as bool,themeSaved: null == themeSaved ? _self.themeSaved : themeSaved // ignore: cast_nullable_to_non_nullable
as bool,themeError: freezed == themeError ? _self.themeError : themeError // ignore: cast_nullable_to_non_nullable
as String?,remaining: freezed == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int?,cached: null == cached ? _self.cached : cached // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of AiSlidesEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiSlideDraftCopyWith<$Res>? get draft {
    if (_self.draft == null) {
    return null;
  }

  return $AiSlideDraftCopyWith<$Res>(_self.draft!, (value) {
    return _then(_self.copyWith(draft: value));
  });
}/// Create a copy of AiSlidesEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiSlideThemeCopyWith<$Res>? get theme {
    if (_self.theme == null) {
    return null;
  }

  return $AiSlideThemeCopyWith<$Res>(_self.theme!, (value) {
    return _then(_self.copyWith(theme: value));
  });
}
}


/// Adds pattern-matching-related methods to [AiSlidesEditorState].
extension AiSlidesEditorStatePatterns on AiSlidesEditorState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiSlidesEditorState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiSlidesEditorState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiSlidesEditorState value)  $default,){
final _that = this;
switch (_that) {
case _AiSlidesEditorState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiSlidesEditorState value)?  $default,){
final _that = this;
switch (_that) {
case _AiSlidesEditorState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String prompt,  String? generatedPrompt,  AiSlideDraft? draft,  List<String> warnings,  bool generating,  bool loading,  String? error,  String? storageError,  bool canUndo,  AiSlideTheme? theme,  bool themeSaving,  bool themeSaved,  String? themeError,  int? remaining,  bool cached)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiSlidesEditorState() when $default != null:
return $default(_that.prompt,_that.generatedPrompt,_that.draft,_that.warnings,_that.generating,_that.loading,_that.error,_that.storageError,_that.canUndo,_that.theme,_that.themeSaving,_that.themeSaved,_that.themeError,_that.remaining,_that.cached);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String prompt,  String? generatedPrompt,  AiSlideDraft? draft,  List<String> warnings,  bool generating,  bool loading,  String? error,  String? storageError,  bool canUndo,  AiSlideTheme? theme,  bool themeSaving,  bool themeSaved,  String? themeError,  int? remaining,  bool cached)  $default,) {final _that = this;
switch (_that) {
case _AiSlidesEditorState():
return $default(_that.prompt,_that.generatedPrompt,_that.draft,_that.warnings,_that.generating,_that.loading,_that.error,_that.storageError,_that.canUndo,_that.theme,_that.themeSaving,_that.themeSaved,_that.themeError,_that.remaining,_that.cached);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String prompt,  String? generatedPrompt,  AiSlideDraft? draft,  List<String> warnings,  bool generating,  bool loading,  String? error,  String? storageError,  bool canUndo,  AiSlideTheme? theme,  bool themeSaving,  bool themeSaved,  String? themeError,  int? remaining,  bool cached)?  $default,) {final _that = this;
switch (_that) {
case _AiSlidesEditorState() when $default != null:
return $default(_that.prompt,_that.generatedPrompt,_that.draft,_that.warnings,_that.generating,_that.loading,_that.error,_that.storageError,_that.canUndo,_that.theme,_that.themeSaving,_that.themeSaved,_that.themeError,_that.remaining,_that.cached);case _:
  return null;

}
}

}

/// @nodoc


class _AiSlidesEditorState implements AiSlidesEditorState {
  const _AiSlidesEditorState({this.prompt = '', this.generatedPrompt, this.draft,  List<String> warnings = const [], this.generating = false, this.loading = true, this.error, this.storageError, this.canUndo = false, this.theme, this.themeSaving = false, this.themeSaved = false, this.themeError, this.remaining, this.cached = false}): _warnings = warnings;
  

@override@JsonKey() final  String prompt;
@override final  String? generatedPrompt;
@override final  AiSlideDraft? draft;
 final  List<String> _warnings;
@override@JsonKey() List<String> get warnings {
  if (_warnings is EqualUnmodifiableListView) return _warnings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_warnings);
}

@override@JsonKey() final  bool generating;
@override@JsonKey() final  bool loading;
@override final  String? error;
@override final  String? storageError;
@override@JsonKey() final  bool canUndo;
@override final  AiSlideTheme? theme;
@override@JsonKey() final  bool themeSaving;
@override@JsonKey() final  bool themeSaved;
@override final  String? themeError;
@override final  int? remaining;
@override@JsonKey() final  bool cached;

/// Create a copy of AiSlidesEditorState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiSlidesEditorStateCopyWith<_AiSlidesEditorState> get copyWith => __$AiSlidesEditorStateCopyWithImpl<_AiSlidesEditorState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiSlidesEditorState&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.generatedPrompt, generatedPrompt) || other.generatedPrompt == generatedPrompt)&&(identical(other.draft, draft) || other.draft == draft)&&const DeepCollectionEquality().equals(other.warnings, _warnings)&&(identical(other.generating, generating) || other.generating == generating)&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.error, error) || other.error == error)&&(identical(other.storageError, storageError) || other.storageError == storageError)&&(identical(other.canUndo, canUndo) || other.canUndo == canUndo)&&(identical(other.theme, theme) || other.theme == theme)&&(identical(other.themeSaving, themeSaving) || other.themeSaving == themeSaving)&&(identical(other.themeSaved, themeSaved) || other.themeSaved == themeSaved)&&(identical(other.themeError, themeError) || other.themeError == themeError)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.cached, cached) || other.cached == cached));
}


@override
int get hashCode {
    return Object.hash(runtimeType,prompt,generatedPrompt,draft,const DeepCollectionEquality().hash(_warnings),generating,loading,error,storageError,canUndo,theme,themeSaving,themeSaved,themeError,remaining,cached);
}

@override
String toString() {
    return 'AiSlidesEditorState(prompt: $prompt, generatedPrompt: $generatedPrompt, draft: $draft, warnings: $warnings, generating: $generating, loading: $loading, error: $error, storageError: $storageError, canUndo: $canUndo, theme: $theme, themeSaving: $themeSaving, themeSaved: $themeSaved, themeError: $themeError, remaining: $remaining, cached: $cached)';
}


}

/// @nodoc
abstract mixin class _$AiSlidesEditorStateCopyWith<$Res> implements $AiSlidesEditorStateCopyWith<$Res> {
  factory _$AiSlidesEditorStateCopyWith(_AiSlidesEditorState value, $Res Function(_AiSlidesEditorState) _then) = __$AiSlidesEditorStateCopyWithImpl;
@override @useResult
$Res call({
 String prompt, String? generatedPrompt, AiSlideDraft? draft, List<String> warnings, bool generating, bool loading, String? error, String? storageError, bool canUndo, AiSlideTheme? theme, bool themeSaving, bool themeSaved, String? themeError, int? remaining, bool cached
});


@override $AiSlideDraftCopyWith<$Res>? get draft;@override $AiSlideThemeCopyWith<$Res>? get theme;

}
/// @nodoc
class __$AiSlidesEditorStateCopyWithImpl<$Res>
    implements _$AiSlidesEditorStateCopyWith<$Res> {
  __$AiSlidesEditorStateCopyWithImpl(this._self, this._then);

  final _AiSlidesEditorState _self;
  final $Res Function(_AiSlidesEditorState) _then;

/// Create a copy of AiSlidesEditorState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? prompt = null,Object? generatedPrompt = freezed,Object? draft = freezed,Object? warnings = null,Object? generating = null,Object? loading = null,Object? error = freezed,Object? storageError = freezed,Object? canUndo = null,Object? theme = freezed,Object? themeSaving = null,Object? themeSaved = null,Object? themeError = freezed,Object? remaining = freezed,Object? cached = null,}) {
  return _then(_AiSlidesEditorState(
prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,generatedPrompt: freezed == generatedPrompt ? _self.generatedPrompt : generatedPrompt // ignore: cast_nullable_to_non_nullable
as String?,draft: freezed == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as AiSlideDraft?,warnings: null == warnings ? _self._warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,generating: null == generating ? _self.generating : generating // ignore: cast_nullable_to_non_nullable
as bool,loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,storageError: freezed == storageError ? _self.storageError : storageError // ignore: cast_nullable_to_non_nullable
as String?,canUndo: null == canUndo ? _self.canUndo : canUndo // ignore: cast_nullable_to_non_nullable
as bool,theme: freezed == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as AiSlideTheme?,themeSaving: null == themeSaving ? _self.themeSaving : themeSaving // ignore: cast_nullable_to_non_nullable
as bool,themeSaved: null == themeSaved ? _self.themeSaved : themeSaved // ignore: cast_nullable_to_non_nullable
as bool,themeError: freezed == themeError ? _self.themeError : themeError // ignore: cast_nullable_to_non_nullable
as String?,remaining: freezed == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int?,cached: null == cached ? _self.cached : cached // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of AiSlidesEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiSlideDraftCopyWith<$Res>? get draft {
    if (_self.draft == null) {
    return null;
  }

  return $AiSlideDraftCopyWith<$Res>(_self.draft!, (value) {
    return _then(_self.copyWith(draft: value));
  });
}/// Create a copy of AiSlidesEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiSlideThemeCopyWith<$Res>? get theme {
    if (_self.theme == null) {
    return null;
  }

  return $AiSlideThemeCopyWith<$Res>(_self.theme!, (value) {
    return _then(_self.copyWith(theme: value));
  });
}
}

// dart format on
