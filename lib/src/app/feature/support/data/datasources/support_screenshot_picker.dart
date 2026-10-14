import 'dart:typed_data';

import 'package:cloud_board/src/app/core/services/event_id.dart';
import 'package:cloud_board/src/app/feature/support/domain/entities/support_ticket.dart';
import 'package:image_picker/image_picker.dart';

abstract interface class SupportScreenshotPicker {
  Future<SupportAttachment?> pick();
}

String? supportImageContentType(Uint8List bytes) {
  bool starts(List<int> header) =>
      bytes.length >= header.length &&
      List.generate(
        header.length,
        (i) => bytes[i] == header[i],
      ).every((v) => v);
  if (starts([137, 80, 78, 71, 13, 10, 26, 10])) return 'image/png';
  if (starts([255, 216, 255])) return 'image/jpeg';
  if (starts([82, 73, 70, 70]) &&
      bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}

class ImagePickerSupportScreenshot implements SupportScreenshotPicker {
  @override
  Future<SupportAttachment?> pick() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    if (await file.length() > supportAttachmentLimit) {
      throw const FormatException('스크린샷은 5MB 이하로 첨부해 주세요.');
    }
    final bytes = await file.readAsBytes();
    final type = supportImageContentType(bytes);
    if (type == null || bytes.length > supportAttachmentLimit) {
      throw const FormatException('PNG, JPG, WebP 이미지 1장, 5MB 이하로 첨부해 주세요.');
    }
    return SupportAttachment(
      bytes: bytes,
      contentType: type,
      fileId: createEventId(),
    );
  }
}
