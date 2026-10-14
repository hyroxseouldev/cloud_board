import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_board/src/app/core/diagnostics/error_details.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/support/data/datasources/support_data_source.dart';
import 'package:cloud_board/src/app/feature/support/data/datasources/support_screenshot_picker.dart';
import 'package:cloud_board/src/app/feature/support/data/repositories/support_repository_impl.dart';
import 'package:cloud_board/src/app/feature/support/domain/entities/support_ticket.dart';
import 'package:cloud_board/src/app/feature/support/domain/usecases/support_actions.dart';
import 'package:cloud_board/src/app/feature/support/presentation/controllers/support_controller.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/support_ticket_fixture.dart';

class _Source implements SupportDataSource {
  final inputs = <Map<String, Object?>>[];
  int uploads = 0;
  Object? uploadError;
  Map<String, dynamic> result = {
    'ticketId': 'id',
    'ticketNumber': 'CB-1',
    'receivedAtMs': 1234,
    'notificationStatus': 'queued',
  };
  @override
  Future<String> upload(
    String accountId,
    String requestId,
    SupportAttachment attachment,
  ) async {
    uploads++;
    if (uploadError != null) throw uploadError!;
    return 'users/$accountId/support/$requestId/${attachment.fileId}';
  }

  @override
  Future<Map<String, dynamic>> submit(
    String accountId,
    Map<String, Object?> input,
  ) async {
    inputs.add(input);
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('repository uploads optional image before ticket, sends path only, and requires server receipt', () async {
    final source = _Source();
    final repository = SupportRepositoryImpl(source);
    final draft = SupportDraft(
      requestId: 'request-1',
      message: '수업 시작 실패',
      replyEmail: 'coach@example.com',
      diagnostics: {
        'errorId': 'actual-error',
        'password': 'secret',
        'stack': 'raw',
        'version': 'unknown',
      },
      attachment: SupportAttachment(
        bytes: supportPng,
        contentType: 'image/png',
        fileId: 'image-1',
      ),
    );
    final result = await repository.submit('owner-a', draft);
    expect(result.number, 'CB-1');
    expect(result.notificationStatus, 'queued');
    expect(source.inputs.single['attachments'], [
      {'path': 'users/owner-a/support/request-1/image-1'},
    ]);
    expect(source.inputs.single['diagnostics'], {'errorId': 'actual-error'});
    source.result = {'notificationStatus': 'sent'};
    await expectLater(
      repository.submit('owner-a', draft),
      throwsFormatException,
    );
    source.uploadError = StateError('upload failed');
    await expectLater(repository.submit('owner-a', draft), throwsStateError);
    expect(source.inputs.length, 2);
  });

  test('general inquiry accepts absent diagnostics and attachment without fake values', () async {
    final source = _Source();
    await SupportRepositoryImpl(source).submit(
      'owner-a',
      const SupportDraft(
        requestId: 'request-general',
        message: '사용 방법 문의',
        replyEmail: 'coach@example.com',
      ),
    );
    expect(source.uploads, 0);
    expect(source.inputs.single['diagnostics'], isEmpty);
    expect(source.inputs.single['attachments'], isEmpty);
  });

  test('message/email/attachment limits reject before network, image type is from content', () async {
    final repository = SupportFakeRepository();
    final actions = SupportActions(repository);
    const draft = SupportDraft(
      requestId: 'request',
      message: '문의',
      replyEmail: 'coach@example.com',
    );
    await expectLater(
      Future.sync(() => actions.submit('owner', draft.copyWith(message: ''))),
      throwsFormatException,
    );
    await expectLater(
      Future.sync(
        () => actions.submit('owner', draft.copyWith(message: 'a' * 4001)),
      ),
      throwsFormatException,
    );
    await expectLater(
      Future.sync(
        () => actions.submit('owner', draft.copyWith(replyEmail: 'invalid')),
      ),
      throwsFormatException,
    );
    await expectLater(
      Future.sync(
        () => actions.submit(
          'owner',
          draft.copyWith(
            attachment: SupportAttachment(
              bytes: Uint8List(supportAttachmentLimit + 1),
              contentType: 'image/png',
              fileId: 'x',
            ),
          ),
        ),
      ),
      throwsFormatException,
    );
    expect(repository.drafts, isEmpty);
    expect(supportImageContentType(supportPng), 'image/png');
    expect(
      supportImageContentType(Uint8List.fromList('not an image'.codeUnits)),
      isNull,
    );
    await actions.submit('owner', draft);
    expect(repository.drafts.length, 1);
  });

  test('technical diagnostics whitelist preserves real event reference and omits secrets/content', () {
    final event = DiagnosticEvent(
      id: 'actual-id',
      occurredAt: DateTime.utc(2026, 10, 14),
      error: StateError('secret raw'),
      stack: StackTrace.current,
      context: {
        'action': 'playback.start',
        'sessionId': 'session-1',
        'version': 'unknown',
        'authorization': 'Bearer secret',
      },
      breadcrumbs: [],
    );
    final data = supportDiagnosticsForEvent(event);
    expect(data['errorId'], 'actual-id');
    expect(data['occurredAtMs'], event.occurredAt.millisecondsSinceEpoch);
    expect(data['sessionId'], 'session-1');
    expect(data.containsKey('version'), false);
    expect(data.keys, isNot(contains('authorization')));
    expect(data.toString(), isNot(contains('secret raw')));
    final filtered = filterSupportDiagnostics({
      'tvs': List.generate(
        12,
        (_) => {
          'deviceId': 'tv',
          'appVersion': '',
          'preparationStatus': 'failed',
          'imageUrl': 'secret',
        },
      ),
    });
    final tvs = filtered['tvs'] as List;
    expect(tvs.length, 10);
    expect(tvs.first, {'deviceId': 'tv', 'preparationStatus': 'failed'});
  });

  test('retry freezes diagnostics and request identity, double tap submits once, editing gets new identity', () async {
    final fixture = SupportFixture();
    addTearDown(fixture.dispose);
    final auth = fixture.container.listen(authStateProvider, (_, _) {});
    addTearDown(auth.close);
    fixture.users.add(supportUser);
    await fixture.container.read(authStateProvider.future);
    final controller = fixture.container.read(
      supportControllerProvider.notifier,
    );
    controller.message('문제가 발생했어요');
    controller.attachment(fixture.picker.value);
    final gate = Completer<SupportTicket>();
    fixture.repository.handler = (_) => gate.future;
    final pending = controller.submit({'version': '1.0', 'tvs': []});
    expect(await controller.submit({'version': '2.0'}), false);
    expect(fixture.repository.drafts.length, 1);
    gate.completeError(
      FirebaseFunctionsException(
        code: 'unavailable',
        message: 'Fixture unavailable',
      ),
    );
    expect(await pending, false);
    final failed = fixture.container.read(supportControllerProvider);
    expect(failed.message, '문제가 발생했어요');
    expect(failed.attachment, fixture.picker.value);
    expect(failed.ticket, isNull);
    fixture.repository.handler = (_) async => supportReceipt;
    expect(await controller.submit({'version': '2.0'}), true);
    expect(
      fixture.repository.drafts[1].requestId,
      fixture.repository.drafts.first.requestId,
    );
    expect(
      fixture.repository.drafts[1].diagnostics,
      fixture.repository.drafts.first.diagnostics,
    );
    expect(
      fixture.container
          .read(supportControllerProvider)
          .ticket
          ?.notificationStatus,
      'queued',
    );
    controller.reset();
    controller.message('새 문의');
    expect(
      fixture.container.read(supportControllerProvider).requestId,
      isNot(failed.requestId),
    );
  });

  test('new account cannot receive previous draft or late receipt, including sign out and same uid return', () async {
    final fixture = SupportFixture();
    addTearDown(fixture.dispose);
    final auth = fixture.container.listen(authStateProvider, (_, _) {});
    addTearDown(auth.close);
    fixture.users.add(supportUser);
    await fixture.container.read(authStateProvider.future);
    final controller = fixture.container.read(
      supportControllerProvider.notifier,
    );
    final keeper = fixture.container.listen(
      supportControllerProvider,
      (_, _) {},
    );
    addTearDown(keeper.close);
    controller.message('old private draft');
    final gate = Completer<SupportTicket>();
    fixture.repository.handler = (_) => gate.future;
    final pending = controller.submit({});
    fixture.users.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(fixture.container.read(supportControllerProvider).message, '');
    fixture.users.add(supportUser);
    await Future<void>.delayed(Duration.zero);
    gate.complete(supportReceipt);
    expect(await pending, false);
    expect(fixture.container.read(supportControllerProvider).ticket, isNull);
    expect(fixture.container.read(supportControllerProvider).message, '');
  });
}
