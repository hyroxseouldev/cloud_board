import assert from 'node:assert/strict';

export function compareBuild(a, b) {
  for (const value of [a, b]) assert(typeof value === 'string' && /^\d+(?:\.\d+){0,3}$/.test(value) && value.length <= 32, 'Invalid release number');
  const left = a.split('.').map(BigInt), right = b.split('.').map(BigInt);
  for (let i = 0; i < Math.max(left.length, right.length); i++) {
    const a = left[i] ?? 0n, b = right[i] ?? 0n;
    if (a !== b) return a < b ? -1 : 1;
  }
  return 0;
}

// Explicit allowlist prevents operational data from entering the public feed.
export function validateNews(value, {withBuilds = false} = {}) {
  assert(value && typeof value === 'object' && !Array.isArray(value), 'Invalid news');
  assert(Object.keys(value).every(key => ['id', 'title', 'summary', 'date', 'version', 'items', ...(withBuilds ? ['builds'] : [])].includes(key)), 'Unknown news field');
  assert(typeof value.id === 'string' && /^[a-z0-9][a-z0-9-]{0,79}$/.test(value.id), 'Invalid news ID');
  for (const [key, limit] of [['title', 100], ['summary', 400]]) {
    assert(typeof value[key] === 'string' && value[key].trim() && value[key].length <= limit, `Invalid ${key}`);
  }
  assert(/^\d{4}-\d{2}-\d{2}$/.test(value.date) && !isNaN(Date.parse(value.date)) && new Date(value.date).toISOString().slice(0, 10) === value.date, 'Invalid date');
  assert(/^\d+\.\d+\.\d+$/.test(value.version), 'Invalid version');
  compareBuild(value.version, value.version);
  assert(Array.isArray(value.items) && value.items.length >= 1 && value.items.length <= 5, 'Use 1–5 news items');
  for (const item of value.items) {
    assert(item && Object.keys(item).every(key => ['title', 'body'].includes(key)), 'Unknown item field');
    for (const [key, limit] of [['title', 100], ['body', 1200]]) {
      assert(typeof item[key] === 'string' && item[key].trim() && item[key].length <= limit, `Invalid item ${key}`);
    }
  }
  if (withBuilds) {
    assert(value.builds && typeof value.builds === 'object' && !Array.isArray(value.builds), 'Missing builds');
    for (const [platform, build] of Object.entries(value.builds)) {
      assert(['web', 'ios', 'android'].includes(platform), 'Unknown platform');
      compareBuild(build, build);
      assert(compareBuild(build, '0') > 0, 'Build must be positive');
    }
  }
  return value;
}

export function newsForDeployment(note, results) {
  validateNews(note);
  const builds = {};
  for (const {pipeline, run, jobs, artifacts} of results) {
    if (!run || !jobs.some(job => job.steps?.some(step =>
      (step.name === pipeline.step || Object.hasOwn(pipeline.previousSteps ?? {}, step.name)) &&
      step.conclusion === 'success'))) continue;
    if (pipeline.key === 'web') {
      builds.web = `${run.run_number}.${run.run_attempt}`;
    } else {
      const matches = [...new Set(artifacts.filter(a => !a.expired)
        .map(a => a.name.match(pipeline.artifact)?.[1]).filter(Boolean))];
      // Ambiguous/missing artifacts must not guess the installed mobile build.
      if (matches.length === 1) builds[pipeline.key] = matches[0];
    }
  }
  return validateNews({...note, builds}, {withBuilds: true});
}

export function mergeNewsFeed(feed, incoming) {
  validateNews(incoming, {withBuilds: true});
  if (!Object.keys(incoming.builds).length) return feed ?? {schemaVersion: 1, entries: []};
  assert(!feed || (feed.schemaVersion === 1 && Array.isArray(feed.entries)), 'Unknown feed schema');
  const entries = (feed?.entries ?? []).map(note => validateNews(note, {withBuilds: true}));
  const previous = entries.find(note => note.id === incoming.id);
  if (previous) {
    for (const key of ['title', 'summary', 'date', 'version', 'items']) {
      assert.deepEqual(previous[key], incoming[key], 'Published news is immutable; use a new ID for new content');
    }
  }
  const builds = {...previous?.builds};
  for (const [platform, build] of Object.entries(incoming.builds)) {
    if (!builds[platform] || compareBuild(build, builds[platform]) < 0) builds[platform] = build;
  }
  const merged = [...entries.filter(note => note.id !== incoming.id), {...incoming, builds}]
    .sort((a, b) => b.date.localeCompare(a.date) || b.id.localeCompare(a.id)).slice(0, 100);
  const result = {schemaVersion: 1, entries: merged};
  assert(Buffer.byteLength(JSON.stringify(result)) < 900_000, 'Feed exceeds document budget');
  return result;
}
