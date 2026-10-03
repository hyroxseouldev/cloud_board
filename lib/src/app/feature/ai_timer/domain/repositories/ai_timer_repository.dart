import 'package:cloud_board/src/app/feature/ai_timer/domain/entities/ai_timer_result.dart';

abstract interface class AiTimerRepository {
  Future<AiTimerAccess> access();
  Future<AiTimerSuggestion> recognize(String imageSource);
}
