import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_slides_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/datasources/ai_slides_data_source.dart';
part 'ai_slides_repository_impl.g.dart';

@riverpod
AiSlidesRepository aiSlidesRepository(Ref ref) =>
    FirebaseAiSlidesRepository(AiSlidesDataSource());

class FirebaseAiSlidesRepository implements AiSlidesRepository {
  const FirebaseAiSlidesRepository(this.source);
  final AiSlidesDataSource source;
  @override
  Future<AiSlidesAccess> access() async =>
      (await source.call({'action': 'status'})).toAccess();
  @override
  Future<AiSlidesResult> generate(String prompt) async =>
      (await source.call({'action': 'generate', 'prompt': prompt})).toResult();
}
