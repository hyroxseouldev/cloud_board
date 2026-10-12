/// Frozen wire-format fallbacks for records saved before brand configuration.
/// These values are compatibility data, not the current product identity.
/// Never derive them from AppBrand or replace stored user text during a rename.
abstract final class LegacyBrandDefaults {
  static const workoutBrand = 'CloudBoard';
  static const storeName = 'CloudBoard Studio';
}
