import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';

part 'workout_model.g.dart';

@JsonSerializable(explicitToJson: true)
class WorkoutModel {
  const WorkoutModel({
    required this.id,
    required this.ownerId,
    required this.author,
    required this.name,
    required this.folder,
    required this.brandL,
    required this.brandR,
    required this.soundTheme,
    required this.countdownSound,
    required this.workStartSound,
    required this.restStartSound,
    required this.workoutEndSound,
    required this.soundVolume,
    required this.modules,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id, ownerId, name, folder, brandL, brandR;
  @JsonKey(defaultValue: 'classic')
  final String soundTheme;
  @JsonKey(defaultValue: 'classicBeep')
  final String countdownSound;
  @JsonKey(defaultValue: 'sharpBeep')
  final String workStartSound;
  @JsonKey(defaultValue: 'lowPulse')
  final String restStartSound;
  @JsonKey(defaultValue: 'longFinish')
  final String workoutEndSound;
  @JsonKey(defaultValue: 1.0)
  final double soundVolume;
  final WorkoutAuthorModel author;
  final List<WorkoutModuleModel> modules;
  @FirestoreTimestampConverter()
  final DateTime createdAt;
  @FirestoreTimestampConverter()
  final DateTime updatedAt;
  factory WorkoutModel.fromJson(Map<String, dynamic> json) =>
      _$WorkoutModelFromJson(json);
  Map<String, dynamic> toJson() => _$WorkoutModelToJson(this);
  Workout toEntity() => Workout(
    id: id,
    ownerId: ownerId,
    author: author.toEntity(),
    name: name,
    folder: folder,
    brandL: brandL,
    brandR: brandR,
    soundTheme: WorkoutSoundTheme.fromName(soundTheme),
    countdownSound: WorkoutSound.fromName(countdownSound),
    workStartSound: WorkoutSound.fromName(
      workStartSound,
      fallback: WorkoutSound.sharpBeep,
    ),
    restStartSound: WorkoutSound.fromName(
      restStartSound,
      fallback: WorkoutSound.lowPulse,
    ),
    workoutEndSound: WorkoutSound.fromName(
      workoutEndSound,
      fallback: WorkoutSound.longFinish,
    ),
    soundVolume: soundVolume.clamp(0, 1),
    modules: modules.map((item) => item.toEntity()).toList(),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
  factory WorkoutModel.fromEntity(Workout value) => WorkoutModel(
    id: value.id,
    ownerId: value.ownerId,
    author: WorkoutAuthorModel.fromEntity(value.author),
    name: value.name,
    folder: value.folder,
    brandL: value.brandL,
    brandR: value.brandR,
    soundTheme: value.soundTheme.name,
    countdownSound: value.countdownSound.name,
    workStartSound: value.workStartSound.name,
    restStartSound: value.restStartSound.name,
    workoutEndSound: value.workoutEndSound.name,
    soundVolume: value.soundVolume,
    modules: value.modules.map(WorkoutModuleModel.fromEntity).toList(),
    createdAt: value.createdAt,
    updatedAt: value.updatedAt,
  );
}

@JsonSerializable()
class WorkoutAuthorModel {
  const WorkoutAuthorModel({
    required this.id,
    required this.displayName,
    required this.photoUrl,
  });

  final String id;
  final String displayName;
  final String? photoUrl;

  factory WorkoutAuthorModel.fromJson(Map<String, dynamic> json) =>
      _$WorkoutAuthorModelFromJson(json);
  Map<String, dynamic> toJson() => _$WorkoutAuthorModelToJson(this);

  WorkoutAuthor toEntity() =>
      WorkoutAuthor(id: id, displayName: displayName, photoUrl: photoUrl);

  factory WorkoutAuthorModel.fromEntity(WorkoutAuthor value) =>
      WorkoutAuthorModel(
        id: value.id,
        displayName: value.displayName,
        photoUrl: value.photoUrl,
      );
}

@JsonSerializable(explicitToJson: true)
class WorkoutModuleModel {
  const WorkoutModuleModel({
    required this.id,
    required this.name,
    required this.workSeconds,
    required this.sets,
    required this.restSeconds,
    required this.text,
    required this.imageUrl,
    required this.showTimer,
    this.appearance = const SlideAppearanceModel(),
    this.showTimerGauge = true,
    this.showSets,
    required this.beep,
    required this.coverImage,
    required this.timerColorValue,
    this.workGaugeColor,
    this.restGaugeColor,
    this.workTextColor,
    this.restTextColor,
    this.intervalBlocks = const [],
  });
  final String id, name, text, imageUrl;
  final int workSeconds, sets, restSeconds;
  @JsonKey(defaultValue: true)
  final bool showTimer;
  final SlideAppearanceModel appearance;
  final bool showTimerGauge;
  // Missing on legacy slides: preserve their previous visibility.
  final bool? showSets;
  final bool beep, coverImage;
  final int? timerColorValue;
  final String? workGaugeColor, restGaugeColor, workTextColor, restTextColor;
  @JsonKey(defaultValue: <WorkoutIntervalBlockModel>[])
  final List<WorkoutIntervalBlockModel> intervalBlocks;
  factory WorkoutModuleModel.fromJson(Map<String, dynamic> json) =>
      _$WorkoutModuleModelFromJson(json);
  Map<String, dynamic> toJson() => _$WorkoutModuleModelToJson(this);
  WorkoutModule toEntity() => WorkoutModule(
    id: id,
    name: name,
    workSeconds: workSeconds,
    sets: sets,
    restSeconds: restSeconds,
    text: text,
    imageSource: imageUrl,
    showTimer: showTimer,
    appearance: appearance.toEntity(),
    showTimerGauge: showTimerGauge,
    showSets: showSets ?? showTimer,
    beep: beep,
    coverImage: coverImage,
    timerColorValue: timerColorValue,
    workGaugeColor: workGaugeColor,
    restGaugeColor: restGaugeColor,
    workTextColor: workTextColor,
    restTextColor: restTextColor,
    intervalBlocks: intervalBlocks.map((value) => value.toEntity()).toList(),
  );
  factory WorkoutModuleModel.fromEntity(WorkoutModule value) =>
      WorkoutModuleModel(
        id: value.id,
        name: value.name,
        workSeconds: value.workSeconds,
        sets: value.sets,
        restSeconds: value.restSeconds,
        text: value.text,
        imageUrl: value.imageSource,
        showTimer: value.showTimer,
        appearance: SlideAppearanceModel.fromEntity(value.appearance),
        showTimerGauge: value.showTimerGauge,
        showSets: value.showSets,
        beep: value.beep,
        coverImage: value.coverImage,
        timerColorValue: value.timerColorValue,
        workGaugeColor: value.workGaugeColor,
        restGaugeColor: value.restGaugeColor,
        workTextColor: value.workTextColor,
        restTextColor: value.restTextColor,
        intervalBlocks: value.intervalBlocks
            .map(WorkoutIntervalBlockModel.fromEntity)
            .toList(),
      );
}

@JsonSerializable()
class WorkoutIntervalBlockModel {
  const WorkoutIntervalBlockModel({
    required this.id,
    required this.workSeconds,
    required this.restSeconds,
    required this.sets,
  });

  final String id;
  final int workSeconds;
  final int restSeconds;
  final int sets;

  factory WorkoutIntervalBlockModel.fromJson(Map<String, dynamic> json) =>
      _$WorkoutIntervalBlockModelFromJson(json);
  Map<String, dynamic> toJson() => _$WorkoutIntervalBlockModelToJson(this);

  factory WorkoutIntervalBlockModel.fromEntity(WorkoutIntervalBlock value) =>
      WorkoutIntervalBlockModel(
        id: value.id,
        workSeconds: value.workSeconds,
        restSeconds: value.restSeconds,
        sets: value.sets,
      );

  WorkoutIntervalBlock toEntity() => WorkoutIntervalBlock(
    id: id,
    workSeconds: workSeconds,
    restSeconds: restSeconds,
    sets: sets,
  );
}

class FirestoreTimestampConverter implements JsonConverter<DateTime, Object?> {
  const FirestoreTimestampConverter();

  @override
  DateTime fromJson(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    int milliseconds => DateTime.fromMillisecondsSinceEpoch(milliseconds),
    String isoDate => DateTime.parse(isoDate),
    _ => DateTime.fromMillisecondsSinceEpoch(0),
  };

  @override
  Object toJson(DateTime value) => Timestamp.fromDate(value);
}

@JsonSerializable()
class SlideAppearanceModel {
  const SlideAppearanceModel({
    this.timerX = 0.84,
    this.timerY = 0.5,
    this.timerSize = 1,
    this.ringWidth = 30,
    this.showTitle = true,
    this.showBody = true,
    this.showBrand = true,
    this.titleColor = 0xFFFFFFFF,
    this.bodyColor = 0xFFFFFFFF,
    this.setsColor = 0xB3FFFFFF,
    this.brandColor = 0xFFFFFFFF,
  });
  final double timerX;
  final double timerY;
  final double timerSize;
  final double ringWidth;
  final bool showTitle;
  final bool showBody;
  final bool showBrand;
  final int titleColor;
  final int bodyColor;
  final int setsColor;
  final int brandColor;
  factory SlideAppearanceModel.fromJson(Map<String, dynamic> json) =>
      _$SlideAppearanceModelFromJson(json);
  Map<String, dynamic> toJson() => _$SlideAppearanceModelToJson(this);
  SlideAppearance toEntity() => SlideAppearance(
    timerX: timerX.isFinite ? timerX.clamp(0, 1) : .84,
    timerY: timerY.isFinite ? timerY.clamp(0, 1) : .5,
    timerSize: timerSize.isFinite ? timerSize.clamp(.6, 1.6) : 1,
    ringWidth: ringWidth.isFinite ? ringWidth.clamp(12, 40) : 30,
    showTitle: showTitle,
    showBody: showBody,
    showBrand: showBrand,
    titleColor: titleColor,
    bodyColor: bodyColor,
    setsColor: setsColor,
    brandColor: brandColor,
  );
  factory SlideAppearanceModel.fromEntity(SlideAppearance value) =>
      SlideAppearanceModel(
        timerX: value.timerX,
        timerY: value.timerY,
        timerSize: value.timerSize,
        ringWidth: value.ringWidth,
        showTitle: value.showTitle,
        showBody: value.showBody,
        showBrand: value.showBrand,
        titleColor: value.titleColor,
        bodyColor: value.bodyColor,
        setsColor: value.setsColor,
        brandColor: value.brandColor,
      );
}
