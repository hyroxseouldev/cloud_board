// Run separately per fixture so maxRSS excludes fixture creation and preceding
// decodes. This measures the local native library, not Cloud Functions Linux.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {renderHomeThumbnail,homeImageDimensions} from '../src/home-image-thumbnail.js';
const [path,type,repeats='1']=process.argv.slice(2),bytes=await readFile(path),iterations=Number(repeats);
assert.ok(Number.isInteger(iterations)&&iterations>=1&&iterations<=64);
const rssBefore=process.memoryUsage().rss,start=performance.now();
let result;
for(let i=0;i<iterations;i++){
  result=await renderHomeThumbnail(Buffer.from(bytes),type);
  assert.ok(result&&result.body.length<=65536);
}
console.log(JSON.stringify({path,node:process.version,platform:process.platform,arch:process.arch,inputBytes:bytes.length,
  iterations,
  dimensions:homeImageDimensions(bytes,type),outputBytes:result.body.length,outputWidth:result.width,outputHeight:result.height,
  elapsedMs:Math.round(performance.now()-start),rssBefore,rssAfter:process.memoryUsage().rss,
  processMaxRssBytes:process.resourceUsage().maxRSS*1024,externalServices:false}));
