import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/standby_rotation.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';

class StandbySlideshow extends HookWidget {
  const StandbySlideshow({
    super.key,
    required this.brand,
    required this.now,
    required this.fallback,
    this.fit = BoxFit.contain,
  });
  final BrandTemplate brand;
  final DateTime now;
  final Widget fallback;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final failed = useState<Set<int>>({});
    final offsetMs = useState(0);
    useEffect(() {
      failed.value = {};
      offsetMs.value = 0;
      return null;
    }, [brand.promotionImageUrls, brand.promotionDurationMinutes]);
    final index = standbyImageIndex(
      brand,
      now.add(Duration(milliseconds: offsetMs.value)),
      failed: failed.value,
    );
    final child = index == null
        ? KeyedSubtree(key: const ValueKey('fallback'), child: fallback)
        : SizedBox.expand(
            key: ValueKey(index),
            child: WorkoutImage(
              source: brand.promotionImageUrls[index],
              fit: fit,
              onError: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted && !failed.value.contains(index)) {
                    final errors = {...failed.value, index};
                    final count = brand.promotionImageUrls.length;
                    // Start the next valid image for its full configured duration.
                    for (var distance = 1; distance <= count; distance++) {
                      final next = (index + distance) % count;
                      if (errors.contains(next) ||
                          brand.promotionImageUrls[next].isEmpty) {
                        continue;
                      }
                      var prefixMs = 0;
                      for (var i = 0; i < next; i++) {
                        if (!errors.contains(i) &&
                            brand.promotionImageUrls[i].isNotEmpty) {
                          prefixMs += standbyMinutes(brand, i) * 60000;
                        }
                      }
                      offsetMs.value = prefixMs - now.millisecondsSinceEpoch;
                      break;
                    }
                    failed.value = errors;
                  }
                });
                WidgetsBinding.instance.ensureVisualUpdate();
              },
            ),
          );
    if (brand.standbyTransition == StandbyTransition.none) return child;
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        transitionBuilder: (child, animation) =>
            brand.standbyTransition == StandbyTransition.slide
            ? SlideTransition(
                position: Tween(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              )
            : FadeTransition(opacity: animation, child: child),
        child: child,
      ),
    );
  }
}
