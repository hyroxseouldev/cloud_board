import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/feature/operations/data/models/store_operations_models.dart';
import 'package:cloud_board/src/app/feature/operations/data/models/audience_branding_model.dart';

class StoreOperationsLocalDataSource {
  const StoreOperationsLocalDataSource(this._preferences, {this.ownerId});

  final SharedPreferencesAsync _preferences;
  final String? ownerId;
  // A provider refresh may create a new repository while the old subscription
  // is still flushing. Serialize by owner across datasource instances too.
  static final _audienceWrites = <String, Future<void>>{};

  String _brandKey(bool effective) =>
      'operations.${effective ? 'effectiveBrand' : 'brandConfig'}.v2.${ownerId ?? 'signed-out'}';
  String get _schedulesKey =>
      'operations.schedules.v2.${ownerId ?? 'signed-out'}';
  String get _audienceBrandingKey =>
      'operations.audienceBranding.v1.${ownerId ?? 'signed-out'}';

  Future<AudienceBrandingModel?> loadAudienceBranding() async {
    final owner = ownerId;
    if (owner == null) return null;
    final encoded = await _preferences.getString(_audienceBrandingKey);
    if (encoded == null) return null;
    try {
      final model = AudienceBrandingModel.parse(jsonDecode(encoded), owner);
      if (model != null) return model;
    } catch (_) {
      // Invalid or pre-contract caches cannot become an authoritative policy.
    }
    // Do not delete a malformed value after this asynchronous read: another
    // subscription may already have replaced it with a valid newer policy.
    return null;
  }

  Future<void> saveAudienceBranding(AudienceBrandingModel model) async {
    if (ownerId != null && model.ownerId == ownerId) {
      final key = _audienceBrandingKey;
      final write = (_audienceWrites[key] ?? Future<void>.value())
          .catchError((Object _) {})
          .then((_) async {
            final previous = await loadAudienceBranding();
            if (!model.supersedes(previous)) return;
            await _preferences.setString(key, jsonEncode(model.toJson()));
          });
      _audienceWrites[key] = write;
      try {
        await write;
      } finally {
        if (identical(_audienceWrites[key], write)) _audienceWrites.remove(key);
      }
    }
  }

  Future<BrandTemplateModel?> loadBrandTemplate({
    bool effective = false,
  }) async {
    if (ownerId == null) return null;
    final encoded = await _preferences.getString(_brandKey(effective));
    if (encoded == null) return null;
    try {
      return BrandTemplateModel.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
    } catch (_) {
      await _preferences.remove(_brandKey(effective));
      return null;
    }
  }

  Future<void> saveBrandTemplate(
    BrandTemplateModel model, {
    bool effective = false,
  }) async {
    if (ownerId != null) {
      await _preferences.setString(
        _brandKey(effective),
        jsonEncode(model.toJson()),
      );
    }
  }

  Future<List<WorkoutScheduleModel>> loadSchedules() async {
    if (ownerId == null) return const [];
    final encoded = await _preferences.getString(_schedulesKey);
    if (encoded == null) return const [];
    try {
      final values = jsonDecode(encoded) as List;
      return values
          .map(
            (value) => WorkoutScheduleModel.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList();
    } catch (_) {
      await _preferences.remove(_schedulesKey);
      return const [];
    }
  }

  Future<void> saveSchedules(List<WorkoutScheduleModel> models) =>
      _preferences.setString(
        _schedulesKey,
        jsonEncode(models.map((model) => model.toJson()).toList()),
      );
}
