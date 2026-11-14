import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/app_error_toast.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/home_shadcn.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/preparation_shadcn.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('missing root host fails visibly instead of losing an error', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('내용'))),
    );
    expect(
      () => AppErrorToast.show(tester.element(find.text('내용')), '실패'),
      throwsFlutterError,
    );
  });

  testWidgets(
    'bursts are bounded, duplicate notices keep lifetime, old close cannot dismiss new',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => AppErrorToastHost(child: child!),
          home: const Scaffold(body: Text('내용')),
        ),
      );
      final context = tester.element(find.text('내용'));
      final oldClose = AppErrorToast.show(context, '첫 오류');
      await tester.pumpAndSettle();
      final firstSonner = tester.state(find.byType(ShadSonner));
      AppErrorToast.show(context, '첫 오류');
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ShadSonner)), same(firstSonner));
      for (var i = 0; i < 20; i++) {
        AppErrorToast.show(context, '오류 $i');
      }
      await tester.pumpAndSettle();
      oldClose();
      expect(find.text('오류 19'), findsOneWidget);
      expect(find.byType(ShadToast), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.byType(ShadToast), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final preparation in [false, true]) {
    testWidgets(
      '${preparation ? 'preparation' : 'home'} local overlay and dialog use accessible root toast',
      (tester) async {
        final semantics = tester.ensureSemantics();

        var routeBuilds = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: XonTheme.light,
            builder: (_, child) => AppErrorToastHost(child: child!),
            home: Builder(
              builder: (context) {
                routeBuilds++;
                final content = Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('작업 확인'),
                          actions: [
                            TextButton(
                              onPressed: () => AppErrorToast.show(
                                dialogContext,
                                '연결을 확인한 뒤 다시 시도해 주세요.',
                              ),
                              child: const Text('실패 표시'),
                            ),
                          ],
                        ),
                      ),
                      child: const Text('대화상자'),
                    ),
                  ),
                );
                return preparation
                    ? PreparationShadcnScope(child: content)
                    : HomeShadcnScope(child: content);
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final before = routeBuilds;
        await tester.tap(find.text('대화상자'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('실패 표시'));
        await tester.pumpAndSettle();
        // Local ShadAppBuilder also mounts Sonner, but only root owns a toast.
        expect(find.byType(ShadToast), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.bySemanticsLabel(RegExp('오류.*')), findsWidgets);
        expect(
          find.byKey(const ValueKey('error-toast-close')).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('error-toast-close')));
        await tester.pumpAndSettle();
        expect(find.byType(ShadToast), findsNothing);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(routeBuilds, before);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
