import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {validateHandoff} from './development_handoff.mjs';

const sha = 'a'.repeat(40);
const body = `## 변경한 동작\n신규 수업 첫 저장의 충돌 조건을 수정했습니다.\n## 기능 검증\n검증한 커밋: ${sha}\n로컬 에뮬레이터에서 실제 요청 저장·재조회 통과. 증거는 첨부 로그.\n## 미확인 사항과 인계\niOS 실기기는 미확인입니다. mock 통과를 실기기 통과로 보고하지 않습니다.`;
const event = value => ({pull_request: {head: {sha}, body: value}});
test('accepts review evidence for current head without claiming runtime success', () => {
  assert.deepEqual(validateHandoff(event(body)), {sha, scope: 'developer-handoff-only'});
  assert.equal(validateHandoff(event(body.replace(sha, `\`${sha.slice(0, 7)}\``))).sha, sha);
});
test('rejects absent PR, missing sections, comments-only evidence and stale revisions', () => {
  assert.throws(() => validateHandoff({}));
  for (const value of ['', `<!-- ${body} -->`, body.replace('## 기능 검증', '## Notes'), body.replace(sha, 'b'.repeat(40))]) {
    assert.throws(() => validateHandoff(event(value)));
  }
  assert.throws(() => validateHandoff(event(readFileSync('.github/pull_request_template.md', 'utf8'))));
});
