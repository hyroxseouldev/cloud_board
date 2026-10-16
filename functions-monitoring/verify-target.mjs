if (process.env.GCLOUD_PROJECT !== 'cloud-board-stationd') {
  throw new Error('Class monitoring deploy is production-only: use --project cloud-board-stationd');
}
