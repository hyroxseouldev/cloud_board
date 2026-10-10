import 'package:cloud_board/src/app/core/theme/app_motion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Animates small, confirmed membership changes. Filtering, sorting and bulk
/// pages replace the presentation immediately; data ownership stays upstream.
class AppAnimatedSliverList<T> extends HookWidget {
  const AppAnimatedSliverList({
    super.key,
    required this.items,
    required this.idOf,
    required this.itemBuilder,
    required this.scope,
  });

  final List<T> items;
  final Object Function(T) idOf;
  final Widget Function(BuildContext, T) itemBuilder;
  final Object? scope;

  @override
  Widget build(BuildContext context) {
    final shown = useRef(List<T>.of(items));
    final listKey = useRef(GlobalKey<SliverAnimatedListState>());
    final previousScope = useRef(scope);
    final reduced = AppMotion.reduced(context);
    final previousReduced = useRef(reduced);

    Widget row(T item, Animation<double> animation) => KeyedSubtree(
      key: ValueKey(idOf(item)),
      child: SizeTransition(
        sizeFactor: animation.drive(CurveTween(curve: AppMotion.curve)),
        child: FadeTransition(
          opacity: animation,
          child: itemBuilder(context, item),
        ),
      ),
    );

    useEffect(() {
      final next = {for (final item in items) idOf(item): item};
      final oldIds = shown.value.map(idOf).toList();
      final oldSet = oldIds.toSet();
      final sameOrder = listEquals(
        oldIds.where(next.containsKey).toList(),
        next.keys.where(oldSet.contains).toList(),
      );
      final changed =
          oldIds.where((id) => !next.containsKey(id)).length +
          next.keys.where((id) => !oldSet.contains(id)).length;
      final reset =
          previousScope.value != scope ||
          !sameOrder ||
          previousReduced.value != reduced;
      previousScope.value = scope;
      previousReduced.value = reduced;
      if (reset) {
        shown.value = List<T>.of(items);
        listKey.value = GlobalKey<SliverAnimatedListState>();
      } else {
        // A fetched page should keep existing row elements and scroll geometry.
        // Only small membership changes get a visual transition.
        final duration = changed > 8
            ? Duration.zero
            : AppMotion.duration(context, AppMotion.stateChange);
        for (var i = shown.value.length - 1; i >= 0; i--) {
          if (next.containsKey(idOf(shown.value[i]))) continue;
          final removed = shown.value.removeAt(i);
          listKey.value.currentState?.removeItem(
            i,
            (_, animation) => IgnorePointer(
              child: ExcludeSemantics(child: row(removed, animation)),
            ),
            duration: duration,
          );
        }
        for (var i = 0; i < items.length; i++) {
          if (i < shown.value.length &&
              idOf(shown.value[i]) == idOf(items[i])) {
            shown.value[i] = items[i];
          } else {
            shown.value.insert(i, items[i]);
            listKey.value.currentState?.insertItem(i, duration: duration);
          }
        }
      }
      return null;
    }, [items, scope, reduced]);

    return SliverAnimatedList(
      key: listKey.value,
      initialItemCount: shown.value.length,
      findChildIndexCallback: (key) {
        final index = shown.value.indexWhere(
          (item) => ValueKey(idOf(item)) == key,
        );
        return index < 0 ? null : index;
      },
      itemBuilder: (_, index, animation) => row(shown.value[index], animation),
    );
  }
}
