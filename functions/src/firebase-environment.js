// Never infer production from a missing local/CI environment variable.
export function firebaseProject(env = process.env) {
  const project = env.GCLOUD_PROJECT || env.GOOGLE_CLOUD_PROJECT;
  if (!project || (!['cloud-board-stationd', 'cloud-board-development'].includes(project) && !/^demo-[a-z0-9-]+$/.test(project))) {
    throw new Error('An explicit supported Firebase project is required');
  }
  if (env.GCLOUD_PROJECT && env.GOOGLE_CLOUD_PROJECT && env.GCLOUD_PROJECT !== env.GOOGLE_CLOUD_PROJECT) {
    throw new Error('Firebase project environment variables disagree');
  }
  return project;
}
