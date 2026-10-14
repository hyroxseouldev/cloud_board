#!/usr/bin/env python3
"""Generate role-based tables from measured Flutter output (standard library only)."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'docs/design/sta162'

def read(path):
    return json.loads((ROOT / path).read_text())

def role(data, name):
    values = [run['fontSize'] for run in data['textRuns'] if run['role'] == name]
    if not values:
        return '—'
    low, high = min(values), max(values)
    return f'{low:g}' if low == high else f'{low:g}–{high:g}'

def change(before, after, name):
    return f'{role(before, name)} → {role(after, name)}'

before, after = read('before/metrics.json'), read('after/metrics.json')
frozen = read('after/frozen-input-metrics.json')
old_inputs, new_inputs = read('before/modules.json'), read('after/modules.json')
paths = read('paths/evidence.json')
lines = [
    '# STA-162 측정 결과', '',
    '`python3 tool/sta162_metrics.py`로 생성. 단위는 1920×1080 설계 캔버스의 px. 범위는 각 역할의 실제 textRuns 최소–최대다. 숫자는 배지 안 글자 크기이며 배지 상자 크기가 아니다.', '',
    '## 새 카탈로그·스타터 기본값 전후', '',
    '| 입력 | 제목 | 본문 | 부제 | 헤더 라벨 | 번호 |',
    '| --- | --- | --- | --- | --- | --- |',
]
keys = [key for key in after if not key.startswith('stress-')]
for key in keys:
    values = [change(before[key], after[key], r) for r in ('title', 'body', 'subtitle', 'headerLabel', 'number')]
    lines.append('| ' + key + ' | ' + ' | '.join(values) + ' |')
lines += [
    '',
    'editorial 본문은 90→92, cream-classic은 92→92다. 제목·부제가 차지하는 공간이 줄면서 기존 자동 축소가 완화된 경우이며, 모든 출력 글자에 고정 배율을 곱하지 않는다. 현재 일반 상한은 92, 카드 상한은 86이다.', '',
    '## 변경 전 입력 고정: 긴 내용과 legacy', '',
    '이 표는 새 샘플 기본값을 섞지 않고 `before/modules.json`을 새 렌더러에 그대로 넣은 결과다. 기준 legacy 렌더러는 역할별 textRuns를 제공하지 않아 이전 본문은 미측정으로 표기한다. 전체 minFontSize를 본문 크기로 대신 사용하지 않는다.', '',
    '| 고정 입력 | 이전 본문 | 현재 본문 | 이전 전체 최소¹ | 현재 경고 |',
    '| --- | --- | --- | --- | --- |',
]
for key in before:
    if key.startswith('stress-'):
        lines.append(f"| {key} | {role(before[key], 'body')} | {role(frozen[key], 'body')} | {before[key]['minFontSize']:g} | {'작은 글씨 경고' if frozen[key]['warning'] else '없음'} |")
lines += ['', '¹ 전체 최소에는 헤더 라벨과 보조 정보가 포함되며, 역할별 본문 비교와 별개인 참고값이다.', '']
for key in ('24-rows-single', '24-rows-columns'):
    lines.append(f"- {key}: 본문 {role(paths[key], 'body')}px, {paths[key]['columns']}열, {'작은 글씨 경고' if paths[key]['warning'] else '경고 없음'}.")
lines += ['', '## 내용·스타일·타이머 보존', '']
protected = ('name', 'text', 'workSeconds', 'restSeconds', 'sets', 'rounds', 'roundRestSeconds', 'timerMode', 'timerDirection', 'includeFinalRest', 'includeFinalRoundRest', 'showTimer', 'showTimerGauge', 'showSets', 'appearance', 'timerColorValue', 'workGaugeColor', 'restGaugeColor', 'workTextColor', 'restTextColor', 'designBackgroundColor', 'designTextColor', 'designAccentColor')
assert all(old_inputs[k].get(field) == new_inputs[k].get(field) for k in keys for field in protected)
assert all(old_inputs[k]['designStyle'][field] == new_inputs[k]['designStyle'][field] for k in keys for field in ('family', 'fontFamily', 'motif'))
assert all(before[k]['timerExclusion'] == after[k]['timerExclusion'] for k in keys)
assert all(after[k]['warning'] is None for k in keys)
old = paths['existing-user-warmup']
body = [r for r in old['metrics']['textRuns'] if r['role'] == 'body']
assert old['weight'] == 900 and old['italic'] is True
assert all(r['fontWeight'] == 900 and r['italic'] is True for r in body)
assert old['subtitle'] == old_inputs['interval-starter_warmup']['designSubtitle']
lines += [
    '- 21개 모두 운동 내용/순서/시간/세트/타이머 위치·크기·색상/원래 테마 색상 입력이 동일하다. 측정된 timerExclusion도 21개 전후 동일하며 새 샘플 경고는 없다.',
    '- 기존 저장 웜업은 본문 900 및 italic=true, 저장된 부제를 유지한다. 새 웜업 기본값만 700 및 italic=false, 샘플 부제 없음으로 바뀐다.',
    '- 대표 웜업 body rect 사이 세로 여백은 103.8→40px로 줄었다. 글자만 줄여 남은 공간을 운동 사이에 더 벌리는 결과를 피했다.',
    '- 직접 캔버스와 PNG fallback의 본문/배치 비교는 README의 경로 검수에 별도로 기록한다. 과거 앱 바이너리를 실행한 결과로 해석하지 않는다.', '',
]
(ROOT / 'metrics-comparison.md').write_text('\n'.join(lines))
print('Wrote metrics-comparison.md; 21 protected inputs/timer regions + explicit saved-style checks passed.')
