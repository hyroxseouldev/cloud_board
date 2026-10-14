import 'package:cloud_board/src/app/feature/support/domain/entities/support_ticket.dart';

abstract interface class SupportRepository {
  Future<SupportTicket> submit(String accountId, SupportDraft draft);
}
