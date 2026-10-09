import 'package:json_annotation/json_annotation.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/models/ai_slides_editor_model.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/slide_design_style.dart';

part 'ai_slide_design_model.g.dart';

@JsonSerializable(explicitToJson: true)
class AiSlideDesignModel {
  const AiSlideDesignModel({
    required this.name,
    this.description = '',
    required this.theme,
    this.storeId,
    this.schemaVersion = 1,
  });
  final int schemaVersion;
  final String name, description;
  final String? storeId;
  final AiSlideThemeModel theme;
  factory AiSlideDesignModel.fromJson(Map<String, dynamic> json) =>
      _$AiSlideDesignModelFromJson(json);
  Map<String, dynamic> toJson() => _$AiSlideDesignModelToJson(this);
  factory AiSlideDesignModel.fromEntity(AiSlideDesign design) =>
      AiSlideDesignModel(
        name: design.name,
        description: design.description,
        storeId: design.storeId,
        theme: AiSlideThemeModel.fromEntity(design.theme),
      );
  AiSlideDesign toEntity(String id) {
    if (schemaVersion != 1 ||
        name.trim().isEmpty ||
        name.length > 60 ||
        description.length > 160 ||
        (storeId != null && (storeId!.isEmpty || storeId!.length > 120)) ||
        !RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(id)) {
      throw const FormatException('Unsupported AI slide design');
    }
    return AiSlideDesign(
      id: id,
      name: name,
      description: description,
      storeId: storeId,
      theme: theme.toEntity(),
    );
  }
}

AiSlideDesignResult parseAiSlideDesignResult(
  Map<String, dynamic> data, {
  required bool reference,
}) {
  final result = data['result'];
  final raw = result is Map ? result['designs'] : null;
  if (raw is! List || raw.length != (reference ? 1 : 3)) {
    throw const AiSlidesFailure('디자인 응답을 읽지 못했어요. 다시 시도해 주세요.');
  }
  final designs = <AiSlideDesign>[];
  for (var i = 0; i < raw.length; i++) {
    final item = Map<String, dynamic>.from(raw[i] as Map);
    final family = item['family'];
    final fontFamily = item['fontFamily'];
    int color(String key) {
      final value = item[key];
      if (value is! int || value < 0xff000000 || value > 0xffffffff) {
        throw const AiSlidesFailure('디자인 색상 정보를 읽지 못했어요.');
      }
      return value;
    }

    int weight(String key) {
      final value = item[key];
      if (value is! int || value < 400 || value > 900 || value % 100 != 0) {
        throw const AiSlidesFailure('디자인 글씨 정보를 읽지 못했어요.');
      }
      return value;
    }

    final spacing = item['spacing'];
    final name = item['name'];
    final description = item['description'];
    final motif = item['motif'];
    if (!['banner', 'focus', 'editorial', 'cards'].contains(family) ||
        !['sans', 'serif'].contains(fontFamily) ||
        name is! String ||
        name.trim().isEmpty ||
        name.length > 60 ||
        description is! String ||
        description.length > 160 ||
        motif is! String ||
        motif.runes.length > 12 ||
        spacing is! num ||
        spacing < .8 ||
        spacing > 1.5 ||
        item['italic'] is! bool) {
      throw const AiSlidesFailure('디자인 응답 형식을 확인할 수 없어요. 다시 시도해 주세요.');
    }
    designs.add(
      AiSlideDesign(
        id: 'proposal-$i',
        name: name,
        description: description,
        theme: AiSlideTheme(
          designStyle: SlideDesignStyle(
            family: family as String,
            fontFamily: fontFamily as String,
            titleColor: color('titleColor'),
            titleWeight: weight('titleWeight'),
            motif: motif,
          ),
          designBackgroundColor: color('backgroundColor'),
          designTextColor: color('textColor'),
          designAccentColor: color('accentColor'),
          designFontWeight: weight('bodyWeight'),
          designItalic: item['italic'] as bool,
          designSpacing: spacing.toDouble(),
          showTimer: false,
        ),
      ),
    );
  }
  return AiSlideDesignResult(
    designs: designs,
    warnings: (result as Map)['warnings'] is List
        ? List<String>.from(result['warnings'] as List)
        : const [],
    remaining: (data['remaining'] as num?)?.toInt() ?? 0,
    cached: data['cached'] == true,
  );
}
