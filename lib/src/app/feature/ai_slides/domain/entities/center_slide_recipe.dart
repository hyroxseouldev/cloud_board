import 'package:freezed_annotation/freezed_annotation.dart';

part 'center_slide_recipe.freezed.dart';
part 'center_slide_recipe.g.dart';

/// An immutable recipe used only while creating a center's slide artwork.
/// Finished workouts retain a baked PNG, not this rendering contract.
@freezed
abstract class CenterSlideRecipe with _$CenterSlideRecipe {
  // Freezed forwards this annotation to its generated implementation.
  // ignore: invalid_annotation_target
  @JsonSerializable(explicitToJson: true)
  const factory CenterSlideRecipe({
    @Default(1) int schemaVersion,
    required String templateId,
    required int revision,
    required String centerId,
    required int width,
    required int height,
    required int backgroundColor,
    String? backgroundPath,
    String? backgroundSha256,
    required List<CenterSlideField> fields,
  }) = _CenterSlideRecipe;

  factory CenterSlideRecipe.fromJson(Map<String, dynamic> json) =>
      _recipeFromJson(json);
}

@freezed
abstract class CenterSlideField with _$CenterSlideField {
  const factory CenterSlideField({
    required String binding,
    int? lineIndex,
    required double x,
    required double y,
    required double width,
    required double height,
    required double fontSize,
    required int color,
    required String fontFamily,
    required int fontWeight,
    @Default(false) bool italic,
    @Default('left') String align,
    String? originalText,
    int? clearColor,
  }) = _CenterSlideField;

  factory CenterSlideField.fromJson(Map<String, dynamic> json) =>
      _fieldFromJson(json);
}

CenterSlideRecipe _recipeFromJson(Map<String, dynamic> json) {
  _validateRecipeJson(json);
  final recipe = _$CenterSlideRecipeFromJson(json);
  final error = validateCenterSlideRecipe(recipe);
  if (error != null) throw FormatException(error);
  return recipe;
}

CenterSlideField _fieldFromJson(Map<String, dynamic> json) {
  _validateFieldJson(json);
  final field = _$CenterSlideFieldFromJson(json);
  final error = _validateField(field);
  if (error != null) throw FormatException(error);
  return field;
}

const centerSlideMaximumBackgroundBytes = 10 * 1024 * 1024;
const centerSlideMaximumFields = 32;
const centerSlideMaximumLines = 24;
const centerSlideFontFamilies = {'Pretendard', 'RacingSansOne', 'NotoSerifKR'};
final _identifier = RegExp(r'^[A-Za-z0-9_-]{1,120}$');
final _sha256 = RegExp(r'^[a-f0-9]{64}$');
final _controlCharacters = RegExp(r'[\x00-\x1F\x7F]');

/// Checks programmatically constructed recipes as well as parsed recipes.
String? validateCenterSlideRecipe(CenterSlideRecipe recipe) {
  if (recipe.schemaVersion != 1 ||
      recipe.revision < 1 ||
      !_identifier.hasMatch(recipe.templateId) ||
      !_identifier.hasMatch(recipe.centerId)) {
    return '센터 템플릿의 버전 또는 식별자를 확인해 주세요.';
  }
  if (recipe.width < 1 ||
      recipe.width > 4096 ||
      recipe.height < 1 ||
      recipe.height > 4096 ||
      (recipe.height - recipe.width * 9 / 16).abs() > 1) {
    return '센터 템플릿은 4096픽셀 이내의 16:9 이미지여야 해요.';
  }
  if (!_isArgb(recipe.backgroundColor)) {
    return '센터 템플릿의 배경 색상 정보가 올바르지 않아요.';
  }
  final path = recipe.backgroundPath;
  final digest = recipe.backgroundSha256;
  if ((path == null) != (digest == null) ||
      (digest != null &&
          (!_sha256.hasMatch(digest) ||
              path !=
                  'center-templates/${recipe.centerId}/${recipe.templateId}/$digest.png'))) {
    return '센터 템플릿의 원본 이미지 경로를 확인해 주세요.';
  }
  if (recipe.fields.length > centerSlideMaximumFields) {
    return '센터 템플릿의 편집 영역은 32개 이내로 지정해 주세요.';
  }
  final bindings = <String>{};
  for (final field in recipe.fields) {
    final error = _validateField(field);
    if (error != null) return error;
    final key = '${field.binding}:${field.lineIndex ?? ''}';
    if (!bindings.add(key)) {
      return '센터 템플릿에 같은 내용의 편집 영역이 중복되어 있어요.';
    }
  }
  return null;
}

String? _validateField(CenterSlideField field) {
  if (!const {'title', 'subtitle', 'header', 'line'}.contains(field.binding) ||
      (field.binding == 'line'
          ? field.lineIndex == null ||
                field.lineIndex! < 0 ||
                field.lineIndex! >= centerSlideMaximumLines
          : field.lineIndex != null)) {
    return '센터 템플릿의 편집 항목을 확인해 주세요.';
  }
  if (!_within(field.x, 0, 1) ||
      !_within(field.y, 0, 1) ||
      !_within(field.width, 0, 1) ||
      !_within(field.height, 0, 1) ||
      field.width <= 0 ||
      field.height <= 0 ||
      field.x + field.width > 1 + 1e-9 ||
      field.y + field.height > 1 + 1e-9) {
    return '센터 템플릿의 편집 영역이 이미지 밖으로 벗어났어요.';
  }
  if (!_within(field.fontSize, 1, 4096) ||
      !centerSlideFontFamilies.contains(field.fontFamily) ||
      field.fontWeight < 400 ||
      field.fontWeight > 900 ||
      field.fontWeight % 100 != 0 ||
      !const {'left', 'center', 'right'}.contains(field.align) ||
      !_isArgb(field.color) ||
      (field.clearColor != null && !_isArgb(field.clearColor!))) {
    return '센터 템플릿의 글씨 설정을 확인해 주세요.';
  }
  final original = field.originalText;
  if (original != null &&
      (original.runes.length > (field.binding == 'title' ? 60 : 120) ||
          _controlCharacters.hasMatch(original))) {
    return '센터 템플릿의 원본 문구는 길이 제한 안에서 한 줄로 지정해 주세요.';
  }
  return null;
}

bool _within(double value, double min, double max) =>
    value.isFinite && value >= min && value <= max;
bool _isArgb(int value) => value >= 0 && value <= 0xffffffff;

void _validateRecipeJson(Map<String, dynamic> json) {
  for (final key in [
    'schemaVersion',
    'revision',
    'width',
    'height',
    'backgroundColor',
  ]) {
    if (json[key] is! int) _invalidJson(key);
  }
  for (final key in ['templateId', 'centerId']) {
    if (json[key] is! String) _invalidJson(key);
  }
  for (final key in ['backgroundPath', 'backgroundSha256']) {
    if (json[key] != null && json[key] is! String) _invalidJson(key);
  }
  final fields = json['fields'];
  if (fields is! List || fields.length > centerSlideMaximumFields) {
    _invalidJson('fields');
  }
  for (final field in fields) {
    if (field is! Map<String, dynamic>) _invalidJson('fields');
    _validateFieldJson(field);
  }
}

void _validateFieldJson(Map<String, dynamic> json) {
  for (final key in ['binding', 'fontFamily']) {
    if (json[key] is! String) _invalidJson(key);
  }
  for (final key in ['color', 'fontWeight']) {
    if (json[key] is! int) _invalidJson(key);
  }
  for (final key in ['lineIndex', 'clearColor']) {
    if (json[key] != null && json[key] is! int) _invalidJson(key);
  }
  for (final key in ['x', 'y', 'width', 'height', 'fontSize']) {
    final value = json[key];
    if (value is! num || !value.isFinite) _invalidJson(key);
  }
  if (json.containsKey('italic') && json['italic'] is! bool) {
    _invalidJson('italic');
  }
  if (json.containsKey('align') && json['align'] is! String) {
    _invalidJson('align');
  }
  if (json['originalText'] != null && json['originalText'] is! String) {
    _invalidJson('originalText');
  }
}

Never _invalidJson(String key) =>
    throw FormatException('센터 템플릿의 $key 형식이 올바르지 않아요.');
