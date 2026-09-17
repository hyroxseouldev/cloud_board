// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'countdown_preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CountdownAppearance _$CountdownAppearanceFromJson(Map<String, dynamic> json) =>
    _CountdownAppearance(
      showReady: json['showReady'] as bool? ?? true,
      showTitle: json['showTitle'] as bool? ?? true,
      numberScale: (json['numberScale'] as num?)?.toDouble() ?? 1.0,
      numberFormat:
          $enumDecodeNullable(
            _$CountdownNumberFormatEnumMap,
            json['numberFormat'],
          ) ??
          CountdownNumberFormat.seconds,
      numberColor: (json['numberColor'] as num?)?.toInt(),
      numberShadow: json['numberShadow'] as bool? ?? false,
      overlayEnabled: json['overlayEnabled'] as bool? ?? true,
      overlayOpacity: (json['overlayOpacity'] as num?)?.toDouble(),
      overlayColor: (json['overlayColor'] as num?)?.toInt(),
    );

Map<String, dynamic> _$CountdownAppearanceToJson(
  _CountdownAppearance instance,
) => <String, dynamic>{
  'showReady': instance.showReady,
  'showTitle': instance.showTitle,
  'numberScale': instance.numberScale,
  'numberFormat': _$CountdownNumberFormatEnumMap[instance.numberFormat]!,
  'numberColor': instance.numberColor,
  'numberShadow': instance.numberShadow,
  'overlayEnabled': instance.overlayEnabled,
  'overlayOpacity': instance.overlayOpacity,
  'overlayColor': instance.overlayColor,
};

const _$CountdownNumberFormatEnumMap = {
  CountdownNumberFormat.seconds: 'seconds',
  CountdownNumberFormat.clock: 'clock',
};

_CountdownPreferences _$CountdownPreferencesFromJson(
  Map<String, dynamic> json,
) => _CountdownPreferences(
  seconds: (json['seconds'] as num?)?.toInt() ?? 3,
  backgroundColor: (json['backgroundColor'] as num?)?.toInt() ?? 0xFF000000,
  imageSource: json['imageSource'] as String? ?? '',
  appearance: json['appearance'] == null
      ? const CountdownAppearance()
      : CountdownAppearance.fromJson(
          json['appearance'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$CountdownPreferencesToJson(
  _CountdownPreferences instance,
) => <String, dynamic>{
  'seconds': instance.seconds,
  'backgroundColor': instance.backgroundColor,
  'imageSource': instance.imageSource,
  'appearance': instance.appearance.toJson(),
};
