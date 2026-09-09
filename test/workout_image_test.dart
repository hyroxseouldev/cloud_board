import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';

void main() {
  testWidgets('웹 원격 이미지는 HTML 요소 렌더링을 우선한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 180,
          child: WorkoutImage(
            source: 'https://example.invalid/workout.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );

    if (kIsWeb) {
      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image as NetworkImage;
      expect(provider.webHtmlElementStrategy, WebHtmlElementStrategy.prefer);
    } else {
      expect(find.byType(CachedNetworkImage), findsOneWidget);
    }
  });
}
