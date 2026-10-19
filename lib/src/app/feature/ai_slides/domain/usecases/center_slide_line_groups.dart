import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';

/// Left-aligned text slots in the same visual column form one input area.
List<List<int>> centerSlideLineGroups(CenterSlideRecipe recipe) {
  final fields =
      recipe.fields.where((field) => field.binding == 'line').toList()
        ..sort((a, b) => a.x.compareTo(b.x));
  final groups = <(double, List<int>)>[];
  for (final field in fields) {
    if (groups.isEmpty || (field.x - groups.last.$1).abs() > .02) {
      groups.add((field.x, [field.lineIndex!]));
    } else {
      groups.last.$2.add(field.lineIndex!);
    }
  }
  return [for (final group in groups) group.$2..sort()];
}

List<String> centerSlideGroupValues(List<String> lines, List<int> indexes) => [
  for (final index in indexes) index < lines.length ? lines[index] : '',
];

/// Extra pasted rows remain in the final slot until corrected. They contain a
/// newline, so creation validation rejects them without shifting another column.
List<String> replaceCenterSlideGroup(
  List<String> current,
  List<int> indexes,
  String input,
) {
  if (indexes.isEmpty) return [...current];
  final values = input
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final result = [...current];
  final last = indexes.reduce((a, b) => a > b ? a : b);
  while (result.length <= last) {
    result.add('');
  }
  for (var position = 0; position < indexes.length; position++) {
    result[indexes[position]] = position == indexes.length - 1
        ? values.skip(position).join('\n')
        : position < values.length
        ? values[position]
        : '';
  }
  return result;
}
