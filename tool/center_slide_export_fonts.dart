import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadCenterSlideExportFonts() async {
  final fonts = <String, List<String>>{
    'Pretendard': [
      'assets/fonts/pretendard/Pretendard-Regular.otf',
      'assets/fonts/pretendard/Pretendard-Medium.otf',
      'assets/fonts/pretendard/Pretendard-SemiBold.otf',
      'assets/fonts/pretendard/Pretendard-Bold.otf',
      'assets/fonts/pretendard/Pretendard-ExtraBold.otf',
    ],
    'RacingSansOne': ['assets/fonts/racing_sans_one/RacingSansOne-Regular.ttf'],
    'NotoSerifKR': ['assets/fonts/noto_serif_kr/NotoSerifKR-Variable.ttf'],
  };
  for (final family in fonts.entries) {
    final loader = FontLoader(family.key);
    for (final path in family.value) {
      loader.addFont(File(path).readAsBytes().then(ByteData.sublistView));
    }
    await loader.load();
  }
}
