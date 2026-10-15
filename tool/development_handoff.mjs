import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';

// This checks that review evidence is supplied, not that the claimed tests passed.
// Reviewers assess the evidence; production validation remains a separate gate.
export function validateHandoff(event) {
  const pr = event.pull_request;
  assert(pr && /^[a-f0-9]{40}$/.test(pr.head?.sha || ''), 'A pull request head is required');
  const body = (pr.body || '').replace(/<!--[\s\S]*?-->/g, '');
  for (const title of ['변경한 동작', '기능 검증', '미확인 사항과 인계']) {
    const section = body.match(new RegExp(`^## ${title}\\s*\\n([\\s\\S]*?)(?=^## |$(?![\\s\\S]))`, 'm'))?.[1];
    assert(section && section.trim().length > 10, `Fill in the PR section: ${title}`);
  }
  const revision = body.match(/검증한 커밋:\s*`?([a-f0-9]{7,40})`?\b/);
  assert(revision && pr.head.sha.startsWith(revision[1]),
    'Record 검증한 커밋: with the tested current PR head; reassess evidence after changes');
  return {sha: pr.head.sha, scope: 'developer-handoff-only'};
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const result = validateHandoff(JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8')));
  console.log(`Developer handoff supplied for ${result.sha}. Actual test evidence requires review.`);
}
