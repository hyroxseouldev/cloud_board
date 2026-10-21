import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_raster_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_raster_page.dart';

import 'support/ai_raster_fakes.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'raster page preserves Korean composing/cursor and never auto-generates at text scale $scale',
      (tester) async {
        final repository = FakeRasterRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aiRasterRepositoryProvider.overrideWithValue(repository),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const AiRasterPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.descendant(
          of: find.byKey(const ValueKey('raster-wod')),
          matching: find.byType(TextField),
        );
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.showKeyboard(field);
        const editing = TextEditingValue(
          text: '스쿼트 10회\n한',
          selection: TextSelection.collapsed(offset: 9),
          composing: TextRange(start: 8, end: 9),
        );
        tester.testTextInput.updateEditingValue(editing);
        await tester.pump();
        final input = tester.widget<TextField>(field).controller!;
        expect(input.value, editing);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '스쿼트 10회\n한국어 5회',
            selection: TextSelection.collapsed(offset: 14),
          ),
        );
        await tester.pumpAndSettle();
        expect(input.selection, const TextSelection.collapsed(offset: 14));
        expect(repository.generations, 0);
        expect(repository.organizations, 0);
        expect(repository.additions, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'unavailable additive server explains fallback without offering automatic requests',
    (tester) async {
      final repository = FakeRasterRepository()
        ..contextFailure = const AiSlidesFailure(
          '새 기능이 아직 연결되지 않았어요.',
          code: 'not-found',
        );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [aiRasterRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: AiRasterPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('기존 템플릿은 계속'), findsOneWidget);
      expect(find.byKey(const ValueKey('raster-generate')), findsNothing);
      expect(repository.generations, 0);
    },
  );
}
