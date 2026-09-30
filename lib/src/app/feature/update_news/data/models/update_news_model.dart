import 'package:json_annotation/json_annotation.dart';

import 'package:cloud_board/src/app/feature/update_news/domain/entities/update_news.dart';
part 'update_news_model.g.dart';

@JsonSerializable(createToJson: false)
class UpdateNewsModel {
  const UpdateNewsModel({
    required this.id,
    required this.title,
    required this.summary,
    required this.date,
    required this.version,
    required this.builds,
    required this.items,
  });
  final String id, title, summary, date, version;
  final Map<String, String> builds;
  final List<UpdateNewsItemModel> items;
  factory UpdateNewsModel.fromJson(Map<String, dynamic> json) =>
      _$UpdateNewsModelFromJson(json);

  UpdateNews toEntity() {
    if (!RegExp(r'^[a-z0-9][a-z0-9-]{0,79}$').hasMatch(id) ||
        title.trim().isEmpty ||
        title.length > 100 ||
        summary.length > 400 ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        DateTime.tryParse(date) == null ||
        items.isEmpty ||
        items.length > 5 ||
        compareReleaseNumbers(version, version) == null ||
        builds.entries.any(
          (entry) =>
              !['web', 'ios', 'android'].contains(entry.key) ||
              compareReleaseNumbers(entry.value, entry.value) == null,
        ) ||
        items.any(
          (item) =>
              item.title.trim().isEmpty ||
              item.title.length > 100 ||
              item.body.trim().isEmpty ||
              item.body.length > 1200,
        )) {
      throw const FormatException('Invalid update news');
    }
    return UpdateNews(
      id: id,
      title: title,
      summary: summary,
      date: date,
      version: version,
      builds: builds,
      items: items
          .map((item) => UpdateNewsItem(title: item.title, body: item.body))
          .toList(),
    );
  }
}

@JsonSerializable(createToJson: false)
class UpdateNewsItemModel {
  const UpdateNewsItemModel({required this.title, required this.body});
  final String title, body;
  factory UpdateNewsItemModel.fromJson(Map<String, dynamic> json) =>
      _$UpdateNewsItemModelFromJson(json);
}
