import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';

/// Keep a pending deletion visible until its server action succeeds. Stream
/// events may arrive before that action returns; identity is always the device ID.
class AnimatedDisplayList extends HookWidget {
  const AnimatedDisplayList({
    super.key,
    required this.devices,
    required this.pendingRemoval,
    required this.itemBuilder,
  });
  final List<DisplayDevice> devices;
  final String? pendingRemoval;
  final Widget Function(DisplayDevice) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final listKey = useMemoized(() => GlobalKey<AnimatedListState>());
    final shown = useRef([...devices]);
    final revision = useState(0);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 250);
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final desired = [...devices];
        final pending = shown.value
            .where((d) => d.id == pendingRemoval)
            .firstOrNull;
        if (pending != null && !desired.any((d) => d.id == pending.id)) {
          desired.insert(
            shown.value.indexOf(pending).clamp(0, desired.length),
            pending,
          );
        }
        for (var i = shown.value.length - 1; i >= 0; i--) {
          if (desired.any((d) => d.id == shown.value[i].id)) continue;
          final removed = shown.value.removeAt(i);
          listKey.currentState?.removeItem(
            i,
            (context, animation) => IgnorePointer(
              child: ExcludeSemantics(
                child: SizeTransition(
                  sizeFactor: animation,
                  alignment: Alignment.topCenter,
                  child: FadeTransition(
                    opacity: animation,
                    child: itemBuilder(removed),
                  ),
                ),
              ),
            ),
            duration: duration,
          );
        }
        // Preserve the relative order of existing rows even when the server
        // reorders a snapshot, so only the deleted identity animates out.
        for (var i = 0; i < shown.value.length; i++) {
          shown.value[i] = desired.firstWhere((d) => d.id == shown.value[i].id);
        }
        for (final device in desired) {
          if (shown.value.any((d) => d.id == device.id)) continue;
          shown.value.add(device);
          listKey.currentState?.insertItem(
            shown.value.length - 1,
            duration: duration,
          );
        }
        revision.value++;
      });
      return null;
    }, [devices, pendingRemoval, reduceMotion]);
    return Column(
      children: [
        AnimatedList(
          key: listKey,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          initialItemCount: shown.value.length,
          itemBuilder: (context, index, animation) => SizeTransition(
            key: ValueKey(shown.value[index].id),
            sizeFactor: animation,
            child: itemBuilder(shown.value[index]),
          ),
        ),
        if (shown.value.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Text(
              '아직 등록된 디스플레이가 없습니다.\n위의 추가 버튼으로 연결해 주세요.',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
