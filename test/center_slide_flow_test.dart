import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes only explicit headings and preserves numbered workouts', () {
    final sections = parseCenterSlideSections([
      'Warm up',
      '',
      'A. Main',
      '1. Bench Press',
      '- 8 reps',
      '',
      'B) Finisher',
      '10. Burpees',
      '## Cool down',
      'Walk',
      '',
    ]);
    expect(sections.map((section) => section.heading), [
      '',
      'A. Main',
      'B) Finisher',
      'Cool down',
    ]);
    expect(sections[0].lines, ['Warm up', '']);
    expect(sections[1].lines, ['1. Bench Press', '- 8 reps', '']);
    expect(sections[2].lines, ['10. Burpees']);
    expect(sections[3].lines, ['Walk', '']);
    expect(() => sections.add(sections.first), throwsUnsupportedError);
    expect(() => sections.first.lines.add('changed'), throwsUnsupportedError);
  });

  test(
    'retains all blank lines and only removes the markdown heading prefix',
    () {
      final sections = parseCenterSlideSections([
        '',
        '  A. Main',
        '',
        'Ski',
        '',
        '## ',
        'Row',
        '',
      ]);
      expect(
        sections.map((section) => section.text).join('\n'),
        '\n  A. Main\n\nSki\n\n\nRow\n',
      );
    },
  );

  test('bounds multiline input without mutating or truncating its source', () {
    final input = List.filled(61, 'Ski 250m');
    final before = List.of(input);
    expect(centerSlideFlowContentError(input), contains('60줄'));
    expect(input, before);
    expect(centerSlideFlowContentError(List.filled(60, 'x')), isNull);
    expect(centerSlideFlowContentError(['']), isNotNull);
    expect(centerSlideFlowContentError(['  ', '']), isNotNull);
    expect(centerSlideFlowContentError([List.filled(240, '가').join()]), isNull);
    expect(
      centerSlideFlowContentError([List.filled(241, '가').join()]),
      contains('240자'),
    );
    expect(
      centerSlideFlowContentError(List.filled(26, 'x' * 240)),
      contains('6,000자'),
    );
  });

  test('rejects embedded newlines and controls rather than reflowing data', () {
    for (final value in [
      'Ski\nRow',
      'Ski\rRow',
      'Ski\tRow',
      '\x00',
      '\u0085',
    ]) {
      expect(centerSlideFlowContentError([value]), isNotNull);
      expect(() => parseCenterSlideSections([value]), throwsFormatException);
    }
  });
}
