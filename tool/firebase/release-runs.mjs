// Both automatic promotions and explicitly scoped manual repairs can change
// live rules. A later failed/partial attempt must never be hidden by an older
// green run, including when an older workflow ID is re-run.
export function productionRuns(runs, repository, sha) {
  const time = run => Date.parse(run.run_started_at || run.created_at || '') || 0;
  return runs.filter(run => run.head_branch === 'main' && ['push', 'workflow_dispatch'].includes(run.event)
    && run.head_repository?.full_name === repository && (!sha || run.head_sha === sha))
    .sort((a, b) => time(b) - time(a) || b.id - a.id);
}
