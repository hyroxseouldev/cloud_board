import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({super.key, required this.value, required this.data});
  final AsyncValue<T> value;
  final Widget Function(T value) data;

  @override
  Widget build(BuildContext context) => value.when(
    data: data,
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('데이터를 불러오지 못했습니다.\n$error', textAlign: TextAlign.center),
      ),
    ),
  );
}
