/** Keep the active snapshot and a seven-day reconnect window; bound each pass. */
export async function prunePlaybackSnapshots(base, cutoff) {
  const stale = await base.child('playbackSnapshots').orderByChild('_storedAtMs')
    .endAt(cutoff).limitToFirst(100).get();
  if (!stale.exists()) return 0;
  const activeId = (await base.child('activeSession/id').get()).val();
  const updates = {};
  for (const id of Object.keys(stale.val())) {
    if (id !== activeId) updates[`playbackSnapshots/${id}`] = null;
  }
  if (Object.keys(updates).length) await base.update(updates);
  return Object.keys(updates).length;
}
