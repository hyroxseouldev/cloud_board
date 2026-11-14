import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_list_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/home_shadcn.dart';

/// A pushed route owns input/focus; the mounted home retains its own scroll,
/// folder and page. Catalog and thumbnail providers remain account-scoped.
class WorkoutSearchScreen extends HookWidget {
  const WorkoutSearchScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final search = useTextEditingController();
    final focus = useFocusNode();
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) focus.requestFocus();
      });
      return null;
    }, [focus]);
    return HomeShadcnScope(
      child: WorkoutListBody(searchController: search, searchFocus: focus),
    );
  }
}
