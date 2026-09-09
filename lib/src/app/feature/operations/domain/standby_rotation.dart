import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';

int standbyMinutes(BrandTemplate brand, int index) =>
    index < brand.promotionDurationMinutes.length &&
        brand.promotionDurationMinutes[index] > 0
    ? brand.promotionDurationMinutes[index]
    : 1;

/// Absolute-time scheduling keeps displays and reconnects on the same slide.
int? standbyImageIndex(
  BrandTemplate brand,
  DateTime now, {
  Set<int> failed = const {},
}) {
  final indices = List.generate(brand.promotionImageUrls.length, (i) => i)
      .where(
        (i) => !failed.contains(i) && brand.promotionImageUrls[i].isNotEmpty,
      )
      .toList();
  if (indices.isEmpty) return null;
  final total = indices.fold<int>(
    0,
    (sum, i) => sum + standbyMinutes(brand, i) * 60000,
  );
  var position = now.millisecondsSinceEpoch % total;
  for (final i in indices) {
    final duration = standbyMinutes(brand, i) * 60000;
    if (position < duration) return i;
    position -= duration;
  }
  return indices.first;
}
