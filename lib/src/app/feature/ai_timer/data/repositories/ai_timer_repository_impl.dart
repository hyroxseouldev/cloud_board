import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/ai_timer/domain/entities/ai_timer_result.dart';
import 'package:cloud_board/src/app/feature/ai_timer/domain/repositories/ai_timer_repository.dart';
import 'package:cloud_board/src/app/feature/ai_timer/data/datasources/ai_timer_data_source.dart';
part 'ai_timer_repository_impl.g.dart';

@riverpod
AiTimerRepository aiTimerRepository(Ref ref) =>
    FirebaseAiTimerRepository(AiTimerDataSource());

class FirebaseAiTimerRepository implements AiTimerRepository {
  const FirebaseAiTimerRepository(this.source);
  final AiTimerDataSource source;
  @override
  Future<AiTimerAccess> access() async =>
      (await source.call({'action': 'status'})).toAccess();
  @override
  Future<AiTimerSuggestion> recognize(String imageSource) async {
    return (await source.call({
      'action': 'analyze',
      'imageBase64': await source.imagePayload(imageSource),
    })).toSuggestion();
  }
}
