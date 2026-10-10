import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/feature/onboarding/domain/entities/exploration_progress.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/repositories/exploration_repository.dart';

part 'exploration_repository_impl.g.dart';

class LocalExplorationRepository implements ExplorationRepository {
  LocalExplorationRepository(this.preferences);
  final SharedPreferencesAsync preferences;

  String _key(String? userId) =>
      'cloudboard.explore.v1.${sha256.convert(utf8.encode(jsonEncode(userId)))}';

  @override
  Future<ExplorationProgress> load(String? userId) async {
    final raw = await preferences.getString(_key(userId));
    if (raw == null) return const ExplorationProgress();
    try {
      return ExplorationProgress.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on FormatException {
      return const ExplorationProgress();
    } on TypeError {
      return const ExplorationProgress();
    }
  }

  @override
  Future<void> save(String? userId, ExplorationProgress value) =>
      preferences.setString(_key(userId), jsonEncode(value.toJson()));
}

@Riverpod(keepAlive: true)
ExplorationRepository explorationRepository(Ref ref) =>
    LocalExplorationRepository(SharedPreferencesAsync());
