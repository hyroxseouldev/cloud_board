import 'dart:convert';

import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_flow.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_reference_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_catalog.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';

const centerSlideCatalogMaxBytes = 768 * 1024;
const _maxSafeInteger = 9007199254740991;
final _identifier = RegExp(r'^[A-Za-z0-9_-]{1,120}$');

/// This boundary validates raw JSON before any generated num.toInt conversion.
/// Operators set rejectInvalidItems to prevent publishing a partial catalog.
class CenterSlideCatalogModel {
  const CenterSlideCatalogModel._(
    this.revision,
    this.centerId,
    this.centerName,
    this.entries,
  );
  final int revision;
  final String centerId, centerName;
  final List<CenterSlideCatalogEntryModel> entries;

  factory CenterSlideCatalogModel.fromJson(
    Map<String, dynamic> json, {
    required String centerId,
    bool rejectInvalidItems = false,
  }) {
    if (!_identifier.hasMatch(centerId)) _invalid();
    try {
      if (utf8.encode(jsonEncode(json)).length > centerSlideCatalogMaxBytes) {
        _invalid();
      }
    } catch (_) {
      _invalid();
    }
    _keys(json, const {'schemaVersion', 'revision', 'centerName', 'templates'});
    if (json['schemaVersion'] is! int || json['schemaVersion'] != 1) _invalid();
    final revision = _integer(json['revision'], 1, _maxSafeInteger);
    final centerName = _string(json['centerName'], 120);
    final raw = json['templates'];
    if (raw is! List || raw.length > 100) _invalid();
    final entries = <CenterSlideCatalogEntryModel>[];
    final seen = <String>{};
    for (final value in raw) {
      try {
        final entry = CenterSlideCatalogEntryModel._parse(
          _map(value),
          centerId,
        );
        if (!seen.add(entry.id)) _invalid();
        entries.add(entry);
      } catch (_) {
        if (rejectInvalidItems) _invalid();
      }
    }
    entries.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return CenterSlideCatalogModel._(
      revision,
      centerId,
      centerName,
      List.unmodifiable(entries),
    );
  }

  CenterSlideCatalog toEntity() => CenterSlideCatalog(
    revision: revision,
    centerId: centerId,
    centerName: centerName,
    templates: List.unmodifiable(
      entries
          .where((entry) => entry.published)
          .map((entry) => entry.toEntity(centerId)),
    ),
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'revision': revision,
    'centerName': centerName,
    'templates': entries.map((entry) => entry.toJson()).toList(),
  };
}

class CenterSlideCatalogEntryModel {
  const CenterSlideCatalogEntryModel._({
    required this.id,
    required this.name,
    required this.description,
    required this.sortOrder,
    required this.published,
    this.originalTemplateId,
    this.recipe,
    this.sample,
  });
  final String id, name, description;
  final int sortOrder;
  final bool published;
  final String? originalTemplateId;
  final CenterSlideRecipe? recipe;
  final AiSlideDraft? sample;

  factory CenterSlideCatalogEntryModel._parse(
    Map<String, dynamic> json,
    String centerId,
  ) {
    _keys(json, const {
      'id',
      'name',
      'description',
      'sortOrder',
      'published',
      'originalTemplateId',
      'recipe',
      'sample',
    });
    final id = json['id'];
    if (id is! String || !_identifier.hasMatch(id)) _invalid();
    final name = _string(json['name'], 60, required: true);
    final description = _string(json['description'], 160);
    final order = _integer(
      json['sortOrder'],
      -_maxSafeInteger,
      _maxSafeInteger,
    );
    final published = json['published'];
    if (published is! bool) _invalid();
    final original = json['originalTemplateId'];
    final rawRecipe = json['recipe'];
    if ((original == null) == (rawRecipe == null)) _invalid();
    CenterSlideRecipe? recipe;
    if (original != null) {
      if (original is! String || originalSlideTemplate(original) == null) {
        _invalid();
      }
    } else {
      recipe = CenterSlideRecipe.fromJson(_map(rawRecipe));
      if (validateCenterSlideRecipe(recipe) != null ||
          recipe.centerId != centerId ||
          recipe.templateId != id) {
        _invalid();
      }
    }
    if (recipe?.body != null && json['sample'] == null) _invalid();
    final sample = json['sample'] == null
        ? null
        : _sample(_map(json['sample']), flow: recipe?.body != null);
    if (sample != null && original != null) {
      final originalTemplate = originalSlideTemplate(original as String)!;
      if (sample.lines.length > originalTemplate.maxLines ||
          sample.lines.any(
            (line) => line.trim() == '##' || line.trim().startsWith('## '),
          )) {
        _invalid();
      }
    }
    return CenterSlideCatalogEntryModel._(
      id: id,
      name: name,
      description: description,
      sortOrder: order,
      published: published,
      originalTemplateId: original as String?,
      recipe: recipe,
      sample: sample,
    );
  }

  AiSlideDesign toEntity(String centerId) {
    final original = originalTemplateId;
    final theme = original == null
        ? AiSlideTheme(
            centerRecipe: recipe,
            centerColumns: recipe?.body == null
                ? null
                : recipe!.body!.layout == 'columns'
                ? recipe!.body!.maxColumns
                : recipe!.body!.layout == 'stack'
                ? 1
                : parseCenterSlideSections(sample!.lines).length
                      .clamp(1, recipe!.body!.maxColumns),
            showTimer: false,
          )
        : originalReferenceTheme(original)!;
    final content =
        sample ??
        (original == null
            ? _sampleFromRecipe(recipe!, fallbackTitle: name)
            : initialAiSlideDesignDraft(theme));
    return AiSlideDesign(
      id: id,
      name: name,
      description: description,
      storeId: centerId,
      theme: theme,
      sample: content.copyWith(
        centerRecipe: recipe,
        centerColumns: theme.centerColumns,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'sortOrder': sortOrder,
    'published': published,
    if (originalTemplateId != null) 'originalTemplateId': originalTemplateId,
    if (recipe != null) 'recipe': recipe!.toJson(),
    if (sample != null)
      'sample': {
        'title': sample!.title,
        'subtitle': sample!.designSubtitle,
        'headerLabel': sample!.designHeaderLabel,
        'lines': sample!.lines,
        if (sample!.workSeconds != null) 'workSeconds': sample!.workSeconds,
        if (sample!.restSeconds != null) 'restSeconds': sample!.restSeconds,
        if (sample!.sets != null) 'sets': sample!.sets,
      },
  };
}

/// Preserve the exact source text when an operator omits the optional sample.
/// Sparse line bindings retain their indices; trimming/filtering would shift
/// later lines into a different image region.
AiSlideDraft _sampleFromRecipe(
  CenterSlideRecipe recipe, {
  required String fallbackTitle,
}) {
  var title = fallbackTitle;
  var subtitle = '';
  var header = '';
  final lines = <String>[];
  for (final field in recipe.fields) {
    final text = field.originalText;
    switch (field.binding) {
      case 'title':
        if (text != null) title = text;
        break;
      case 'subtitle':
        if (text != null) subtitle = text;
        break;
      case 'header':
        if (text != null) header = text;
        break;
      case 'line':
        final index = field.lineIndex!;
        while (lines.length <= index) {
          lines.add('');
        }
        lines[index] = text ?? '';
        break;
    }
  }
  return AiSlideDraft(
    title: title,
    layout: 'list',
    lines: lines,
    designSubtitle: subtitle,
    designHeaderLabel: header,
    showTimer: false,
    centerRecipe: recipe,
  );
}

AiSlideDraft _sample(Map<String, dynamic> json, {bool flow = false}) {
  _keys(json, const {
    'title',
    'subtitle',
    'headerLabel',
    'lines',
    'workSeconds',
    'restSeconds',
    'sets',
  });
  final rawLines = json['lines'];
  if (rawLines is! List || rawLines.length > (flow ? 60 : 24)) _invalid();
  final lines = rawLines
      .map((line) => _string(line, flow ? 240 : 120))
      .toList(growable: false);
  if (flow && lines.join('\n').length > 6000) _invalid();
  return AiSlideDraft(
    title: _string(json['title'], 60, required: true),
    layout: 'list',
    lines: lines,
    designSubtitle: _string(json['subtitle'] ?? '', 120),
    designHeaderLabel: _string(json['headerLabel'] ?? '', 120),
    showTimer: false,
    workSeconds: json['workSeconds'] == null
        ? null
        : _integer(json['workSeconds'], 1, 3600),
    restSeconds: json['restSeconds'] == null
        ? null
        : _integer(json['restSeconds'], 0, 3600),
    sets: json['sets'] == null ? null : _integer(json['sets'], 1, 100),
  );
}

Map<String, dynamic> _map(Object? raw) {
  if (raw is! Map || raw.keys.any((key) => key is! String)) _invalid();
  return Map<String, dynamic>.from(raw);
}

void _keys(Map<String, dynamic> json, Set<String> allowed) {
  if (json.keys.any((key) => !allowed.contains(key))) _invalid();
}

int _integer(Object? value, int min, int max) {
  if (value is! int || value < min || value > max) _invalid();
  return value;
}

String _string(Object? value, int max, {bool required = false}) {
  if (value is! String ||
      value.length > max ||
      (required && value.trim().isEmpty) ||
      RegExp(r'[\x00-\x1F\x7F]').hasMatch(value)) {
    _invalid();
  }
  return value;
}

Never _invalid() =>
    throw const FormatException('Unsupported center slide catalog');
