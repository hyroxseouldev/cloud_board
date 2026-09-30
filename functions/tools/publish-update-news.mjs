import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {initializeApp, applicationDefault} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {validateNews, mergeNewsFeed} from '../../tool/update-news/news.mjs';

export async function publishUpdateNews(db, news) {
  validateNews(news, {withBuilds: true});
  if (!Object.keys(news.builds).length) return 'no-deployed-builds';
  const ref = db.doc('appContent/updateNews');
  return db.runTransaction(async transaction => {
    const before = (await transaction.get(ref)).data();
    const after = mergeNewsFeed(before, news);
    if (JSON.stringify(before) === JSON.stringify(after)) return 'unchanged';
    transaction.set(ref, after);
    return 'updated';
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [file, flag] = process.argv.slice(2);
  if (!file || ![undefined, '--apply'].includes(flag)) throw new Error('Usage: publish-update-news.mjs file.json [--apply]');
  const news = validateNews(JSON.parse(readFileSync(file, 'utf8')), {withBuilds: true});
  if (flag === '--apply') {
    const app = initializeApp({credential: applicationDefault(), projectId: 'cloud-board-stationd'});
    console.log(`Update news: ${await publishUpdateNews(getFirestore(app), news)}`);
  } else {
    console.log(`Validated ${news.id}; platforms: ${Object.keys(news.builds).join(', ') || 'none'}`);
  }
}
