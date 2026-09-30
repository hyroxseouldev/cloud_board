import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/core/services/installed_app_info.dart';

import 'package:cloud_board/src/app/feature/update_news/domain/entities/update_news.dart';
import 'package:cloud_board/src/app/feature/update_news/domain/repositories/update_news_repository.dart';
import 'package:cloud_board/src/app/feature/update_news/data/datasources/update_news_data_source.dart';
import 'package:cloud_board/src/app/feature/update_news/data/models/update_news_model.dart';
part 'update_news_repository_impl.g.dart';

class FirebaseUpdateNewsRepository implements UpdateNewsRepository {
  FirebaseUpdateNewsRepository(this.source);
  final UpdateNewsDataSource source;

  @override
  Future<List<UpdateNews>> load() async {
    final feed = await source.load();
    if (feed == null) return [];
    if (feed['schemaVersion'] != 1 || feed['entries'] is! List) {
      throw const FormatException('업데이트 소식 형식을 확인할 수 없습니다.');
    }
    final notes = <UpdateNews>[];
    for (final value in (feed['entries'] as List).take(100)) {
      try {
        notes.add(
          UpdateNewsModel.fromJson(Map<String, dynamic>.from(value as Map))
              .toEntity(),
        );
      } catch (_) {
        // A malformed entry must not hide the remaining valid history.
      }
    }
    return notes;
  }

  @override
  Future<InstalledRelease> installed() async {
    final info = await readInstalledAppInfo();
    return (
      platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
      version: info.version,
      build: info.buildNumber,
    );
  }

  @override
  Future<Set<String>> readIds(String uid) => source.readIds(uid);
  @override
  Future<void> saveReadIds(String uid, Set<String> ids) =>
      source.saveReadIds(uid, ids);
}

@riverpod
UpdateNewsRepository updateNewsRepository(Ref ref) =>
    FirebaseUpdateNewsRepository(UpdateNewsDataSource());
