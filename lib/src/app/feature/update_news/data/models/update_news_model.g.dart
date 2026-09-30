// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_news_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateNewsModel _$UpdateNewsModelFromJson(Map<String, dynamic> json) =>
    UpdateNewsModel(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      date: json['date'] as String,
      version: json['version'] as String,
      builds: Map<String, String>.from(json['builds'] as Map),
      items: (json['items'] as List<dynamic>)
          .map((e) => UpdateNewsItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

UpdateNewsItemModel _$UpdateNewsItemModelFromJson(Map<String, dynamic> json) =>
    UpdateNewsItemModel(
      title: json['title'] as String,
      body: json['body'] as String,
    );
