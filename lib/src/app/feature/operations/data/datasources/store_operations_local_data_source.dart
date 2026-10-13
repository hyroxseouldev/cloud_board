import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/feature/operations/data/models/store_operations_models.dart';

class StoreOperationsLocalDataSource {
  const StoreOperationsLocalDataSource(this._preferences, {this.ownerId});

  final SharedPreferencesAsync _preferences;
  final String? ownerId;

  String _brandKey(bool effective) =>
      'operations.${effective ? 'effectiveBrand' : 'brandConfig'}.v2.${ownerId ?? 'signed-out'}';
  String get _schedulesKey =>
      'operations.schedules.v2.${ownerId ?? 'signed-out'}';

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
