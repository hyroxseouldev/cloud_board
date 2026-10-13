import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/models/ai_slides_model.dart';
import 'package:cloud_board/src/app/feature/ai_timer/data/models/ai_timer_response_model.dart';

void main() {
  final reset = DateTime.utc(2026, 10, 31, 15).millisecondsSinceEpoch;
  Map<String, dynamic> response({bool premium = false}) => {
    'premium': premium,
    'enabled': true,
    'limit': premium ? 30 : 0,
    'remaining': premium ? 30 : 0,
    'resetsAtMs': reset,
  };
  test('new Plus access works without claiming legacy Premium capability', () {
    final plus = AiSlidesModel.fromJson({
      ...response(),
      'allowed': true,
      'plan': 'plus',
      'limit': 10,
      'used': 8,
      'remaining': 2,
    }).toAccess();
    expect(plus.premium, false);
    expect(plus.canRequest, true);
    expect(plus.usedRequests, 8);
    expect(plus.resetsAt, DateTime.utc(2026, 10, 31, 15));
    final downgrade = AiSlidesModel.fromJson({
      ...response(),
      'allowed': true,
      'plan': 'plus',
      'limit': 10,
      'used': 15,
      'remaining': 0,
    }).toAccess();
    expect(
      downgrade.usedRequests,
      15,
      reason: 'usage must not be clamped to the new limit',
    );
    expect(
      downgrade.canRequest,
      true,
      reason: 'server may return a free cached result',
    );
  });
  test(
    'old bool-only responses remain compatible and explicit denial wins',
    () {
      expect(
        AiSlidesModel.fromJson(response(premium: true)).toAccess().canRequest,
        true,
      );
      expect(AiSlidesModel.fromJson(response()).toAccess().canRequest, false);
      expect(
        AiSlidesModel.fromJson({...response(premium: true), 'allowed': false})
            .toAccess()
            .canRequest,
        false,
      );
      final timer = AiTimerResponseModel.fromJson({
        ...response(),
        'plan': 'plus',
        'allowed': false,
      }).toAccess();
      expect(timer.canRequest, false);
      expect(
        AiTimerResponseModel.fromJson(response(premium: true))
            .toAccess()
            .canRequest,
        true,
      );
    },
  );
  test('service stop reason is independent of personal remaining requests', () {
    final access = AiSlidesModel.fromJson({
      ...response(),
      'allowed': true,
      'plan': 'plus',
      'limit': 10,
      'remaining': 8,
      'used': 2,
      'availabilityReason': 'service-limit',
    }).toAccess();
    expect(access.remaining, 8);
    expect(access.availabilityReason, 'service-limit');
    expect(
      access.canRequest,
      true,
      reason: 'a cached result still bypasses global reservation',
    );
  });
}
