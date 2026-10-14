import 'package:cloud_board/src/app/feature/support/data/datasources/support_data_source.dart';
import 'package:cloud_board/src/app/feature/support/domain/entities/support_ticket.dart';
import 'package:cloud_board/src/app/feature/support/domain/repositories/support_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'support_repository_impl.g.dart';

class SupportRepositoryImpl implements SupportRepository {
  const SupportRepositoryImpl(this.source);
  final SupportDataSource source;

  @override
  Future<SupportTicket> submit(String accountId, SupportDraft draft) async {
    final attachment = draft.attachment;
    final path = attachment == null
        ? null
        : await source.upload(accountId, draft.requestId, attachment);
    final result = await source.submit(accountId, {
      'requestId': draft.requestId,
      'message': draft.message.trim(),
      'replyEmail': draft.replyEmail.trim(),
      'diagnostics': filterSupportDiagnostics(draft.diagnostics),
      'attachments': [
        if (path != null) {'path': path},
      ],
    });
    final id = result['ticketId'];
    final number = result['ticketNumber'];
    final received = result['receivedAtMs'];
    final notification = result['notificationStatus'];
    if (id is! String ||
        id.isEmpty ||
        number is! String ||
        number.isEmpty ||
        received is! num ||
        received <= 0 ||
        !const {'queued', 'sent', 'retrying'}.contains(notification)) {
      throw const FormatException('접수 결과를 확인하지 못했습니다. 같은 내용으로 다시 확인해 주세요.');
    }
    return SupportTicket(
      id: id,
      number: number,
      receivedAtMs: received.toInt(),
      notificationStatus: notification as String,
    );
  }
}

@riverpod
SupportRepository supportRepository(Ref ref) =>
    SupportRepositoryImpl(FirebaseSupportDataSource());
