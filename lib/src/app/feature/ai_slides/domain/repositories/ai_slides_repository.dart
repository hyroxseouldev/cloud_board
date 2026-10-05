import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';

abstract interface class AiSlidesRepository {
  Future<AiSlidesAccess> access();
  Future<AiSlidesResult> generate(String prompt);
}
