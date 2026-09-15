import 'package:cloud_board/src/app/core/services/device_pairing_diagnostics.dart';

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/device_pairing_error_message.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/controllers/user_profile_controller.dart';
import 'package:cloud_board/src/app/feature/profile/domain/entities/user_profile.dart';

class _PendingProfile extends UserProfileController {
  final pending = Completer<UserProfile>();
  @override
  Future<UserProfile> build() => pending.future;
}

void main() {
  test(
    'diagnostics categorize without exposing code, account, or SDK messages',
    () {
      expect(
        pairingFailureKind(
          FirebaseException(
            plugin: 'database',
            code: 'permission-denied',
            message: 'users/private-uid/pairingCodes/123456',
          ),
        ),
        'permission_denied',
      );
      expect(
        pairingFailureKind(StateError('연결된 매장을 찾을 수 없습니다.')),
        'owner_not_ready',
      );
      expect(pairingFailureKind(StateError('만료된 연결 코드입니다.')), 'expired_code');
      expect(
        pairingFailureKind(StateError('현재 등급에서는 디스플레이를 3대까지 연결할 수 있습니다.')),
        'display_limit',
      );
    },
  );
  test('permission failure is not falsely reported as an expired code', () {
    final message = devicePairingErrorMessage(
      FirebaseException(plugin: 'firebase_database', code: 'permission-denied'),
    );
    expect(message, contains('거부'));
    expect(message, isNot(contains('만료')));
    expect(message, isNot(contains('firebase')));
    expect(
      devicePairingErrorMessage(StateError('현재 등급의 등록 한도입니다.')),
      '현재 등급의 등록 한도입니다.',
    );
    expect(
      devicePairingErrorMessage(TimeoutException('internal details')),
      contains('인터넷 연결'),
    );
  });
  test(
    'repeated submit is ignored while first pairing request is pending',
    () async {
      final profile = _PendingProfile();
      final container = ProviderContainer(
        overrides: [userProfileControllerProvider.overrideWith(() => profile)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        deviceClaimControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final controller = container.read(deviceClaimControllerProvider.notifier);
      final first = controller.claim(
        code: '123456',
        name: 'TV',
        zoneName: 'main',
      );
      expect(container.read(deviceClaimControllerProvider).isLoading, isTrue);
      expect(
        await controller.claim(code: '123456', name: 'TV', zoneName: 'main'),
        isFalse,
      );
      expect(container.read(deviceClaimControllerProvider).isLoading, isTrue);
      profile.pending.completeError(StateError('로그인 정보를 다시 확인해 주세요.'));
      expect(await first, isFalse);
      expect(container.read(deviceClaimControllerProvider).hasError, isTrue);
    },
  );
}
