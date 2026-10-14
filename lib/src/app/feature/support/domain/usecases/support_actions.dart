import 'package:cloud_board/src/app/feature/support/data/repositories/support_repository_impl.dart';
import 'package:cloud_board/src/app/feature/support/domain/entities/support_ticket.dart';
import 'package:cloud_board/src/app/feature/support/domain/repositories/support_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'support_actions.g.dart';

class SupportActions {
  const SupportActions(this.repository);
  final SupportRepository repository;

  Future<SupportTicket> submit(String accountId, SupportDraft draft) {
    if (draft.message.trim().isEmpty ||
        draft.message.length > supportMessageLimit) {
      throw const FormatException('발생 상황을 1~4000자로 입력해 주세요.');
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
            .hasMatch(draft.replyEmail.trim()) ||
        draft.replyEmail.length > 254) {
      throw const FormatException('답변받을 이메일을 확인해 주세요.');
    }
    final attachment = draft.attachment;
    if (attachment != null &&
        (attachment.bytes.isEmpty ||
            attachment.bytes.length > supportAttachmentLimit ||
            !const {
              'image/png',
              'image/jpeg',
              'image/webp',
            }.contains(attachment.contentType))) {
      throw const FormatException('PNG, JPG, WebP 이미지 1장, 5MB 이하로 첨부해 주세요.');
    }
    return repository.submit(accountId, draft);
  }
}

@riverpod
SupportActions supportActions(Ref ref) =>
    SupportActions(ref.watch(supportRepositoryProvider));
