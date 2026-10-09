import 'package:freezed_annotation/freezed_annotation.dart';

part 'slide_design_style.freezed.dart';
part 'slide_design_style.g.dart';

/// Reusable visual decisions. Workout text and timing stay on the slide.
@freezed
abstract class SlideDesignStyle with _$SlideDesignStyle {
  const factory SlideDesignStyle({
    @Default(1) int version,
    @Default('banner') String family,
    @Default('sans') String fontFamily,
    int? titleColor,
    @Default(900) int titleWeight,
    @Default('') String motif,

    /// A customer-provided, fixed original artwork recipe; never AI-generated.
    String? originalTemplate,
  }) = _SlideDesignStyle;

  factory SlideDesignStyle.fromJson(Map<String, dynamic> json) =>
      _$SlideDesignStyleFromJson(json);
}
