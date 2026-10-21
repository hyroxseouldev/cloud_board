import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_templates_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_library_screen.dart';

const imageSource =
    'assets/slide_templates/stationd_unbroken_single_original.png';
final records = [
  WorkoutModule.empty('arbitrary-upload-id')
      .copyWith(name: '저장 이미지', imageSource: imageSource, favorite: false),
  WorkoutModule.empty('studio-text-only')
      .copyWith(name: '텍스트 즐겨찾기', favorite: true),
  WorkoutModule.empty('blank').copyWith(name: '빈 이미지', imageSource: '  '),
];

void main() {
  for (final imagesOnly in [false, true]) {
    testWidgets(
      'library imagesOnly=$imagesOnly preserves source records and allows reuse',
      (tester) async {
        WorkoutModule? selected;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith(
                (_) => Stream.value(
                  const AuthUser(
                    id: 'owner',
                    email: 'local@example.invalid',
                    displayName: 'Local',
                    photoUrl: null,
                  ),
                ),
              ),
              slideTemplatesControllerProvider('owner')
                  .overrideWith(_Images.new),
            ],
            child: MaterialApp(
              home: SlideLibraryScreen(
                imagesOnly: imagesOnly,
                onSelect: (item) => selected = item,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('arbitrary-upload-id')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('studio-text-only')),
          imagesOnly ? findsNothing : findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('blank')),
          imagesOnly ? findsNothing : findsOneWidget,
        );
        if (imagesOnly) {
          expect(find.text('저장된 이미지'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('library-category-tabs')),
            findsNothing,
          );
        }
        await tester.tap(find.text('저장 이미지').last);
        expect(selected, records.first);
        expect(selected!.imageSource, imageSource);
        expect(selected!.favorite, isFalse);
        final c = ProviderScope.containerOf(
          tester.element(find.byType(SlideLibraryScreen)),
        );
        expect(
          c.read(slideTemplatesControllerProvider('owner')).requireValue,
          records,
        );
        await tester.enterText(
          find.widgetWithText(TextField, imagesOnly ? '이미지 검색' : '슬라이드 검색'),
          '없는 결과',
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('검색 조건에 맞는'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Images extends SlideTemplatesController {
  @override
  Stream<List<WorkoutModule>> build(String scope) => Stream.value(records);
}
