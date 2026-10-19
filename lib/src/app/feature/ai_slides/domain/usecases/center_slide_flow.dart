/// A single block remains together when the creation renderer chooses columns.
class CenterSlideSection {
  CenterSlideSection({required this.heading, required List<String> lines})
    : lines = List.unmodifiable(lines);

  final String heading;
  final List<String> lines;

  String get text =>
      heading.isEmpty ? lines.join('\n') : [heading, ...lines].join('\n');
}

const centerSlideFlowMaximumLines = 60;
const centerSlideFlowMaximumLineCharacters = 240;
const centerSlideFlowMaximumCharacters = 6000;
final _flowControlCharacters = RegExp(r'[\x00-\x1F\x7F-\x9F]');
final _sectionHeading = RegExp(r'^\s*(?:[A-Z][.)]\s+|##\s+)');
final _markdownHeading = RegExp(r'^\s*##\s+');

String? centerSlideFlowContentError(List<String> lines) {
  if (lines.isEmpty || lines.every((line) => line.trim().isEmpty)) {
    return '와드 내용을 입력해 주세요.';
  }
  if (lines.length > centerSlideFlowMaximumLines) {
    return '와드 내용은 60줄까지 입력할 수 있어요. 여러 슬라이드로 나눠 주세요.';
  }
  if (lines.any((line) => _flowControlCharacters.hasMatch(line))) {
    return '와드 내용의 줄바꿈이나 특수 문자를 확인해 주세요.';
  }
  if (lines.any(
    (line) => line.runes.length > centerSlideFlowMaximumLineCharacters,
  )) {
    return '한 줄은 240자까지 입력할 수 있어요. 긴 문장을 여러 줄로 나눠 주세요.';
  }
  if (lines.join('\n').runes.length > centerSlideFlowMaximumCharacters) {
    return '와드 내용은 6,000자까지 입력할 수 있어요. 여러 슬라이드로 나눠 주세요.';
  }
  return null;
}

/// Only A. / A) and ## headings start sections. Numbered exercise lines and
/// whitespace-only lines are preserved, including leading/trailing blank lines.
List<CenterSlideSection> parseCenterSlideSections(List<String> lines) {
  final error = centerSlideFlowContentError(lines);
  if (error != null) throw FormatException(error);
  final sections = <CenterSlideSection>[];
  var heading = '';
  var content = <String>[];
  void flush() {
    if (heading.isNotEmpty || content.isNotEmpty) {
      sections.add(CenterSlideSection(heading: heading, lines: content));
    }
  }

  for (final line in lines) {
    if (_sectionHeading.hasMatch(line)) {
      flush();
      heading = line.replaceFirst(_markdownHeading, '');
      content = heading.isEmpty ? [''] : [];
    } else {
      content.add(line);
    }
  }
  flush();
  return List.unmodifiable(sections);
}
