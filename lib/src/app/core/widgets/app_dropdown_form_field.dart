import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/theme/app_style.dart';

/// Styles both the field and the menu route opened by Material dropdowns.
class AppDropdownFormField<T> extends StatelessWidget {
  const AppDropdownFormField({
    super.key,
    this.initialValue,
    required this.items,
    required this.onChanged,
    this.decoration = const InputDecoration(),
    this.isExpanded = true,
  });

  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      focusColor: AppColors.selected,
      hoverColor: AppColors.selected,
      highlightColor: AppColors.selected,
    ),
    child: DropdownButtonFormField<T>(
      initialValue: initialValue,
      items: items,
      onChanged: onChanged,
      decoration: decoration,
      isExpanded: isExpanded,
      dropdownColor: AppColors.dialog,
      borderRadius: BorderRadius.circular(AppStyle.controlRadius),
      elevation: 2,
      focusColor: AppColors.selected,
      iconEnabledColor: AppColors.muted,
      menuMaxHeight: MediaQuery.sizeOf(context).height * .6,
    ),
  );
}
