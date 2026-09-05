enum DeviceMode {
  controller,
  display;

  String get storageValue => name;

  static DeviceMode fromStorage(String? value) => DeviceMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => DeviceMode.controller,
  );
}
