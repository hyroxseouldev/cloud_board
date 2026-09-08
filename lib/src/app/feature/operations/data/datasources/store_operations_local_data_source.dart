import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/feature/operations/data/models/store_operations_models.dart';

class StoreOperationsLocalDataSource {
  const StoreOperationsLocalDataSource(this._preferences);

  final SharedPreferencesAsync _preferences;

  static const _brandKey = 'operations.brand.v1';
  static const _schedulesKey = 'operations.schedules.v1';

  Future<BrandTemplateModel?> loadBrandTemplate() async {
    final encoded = await _preferences.getString(_brandKey);
    if (encoded == null) return null;
    try {
      return BrandTemplateModel.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
    } catch (_) {
      await _preferences.remove(_brandKey);
      return null;
    }
  }

  Future<void> saveBrandTemplate(BrandTemplateModel model) =>
      _preferences.setString(_brandKey, jsonEncode(model.toJson()));

  Future<List<WorkoutScheduleModel>> loadSchedules() async {
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
