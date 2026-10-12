// Reuses the existing Playwright + sharp toolchain; no application dependency.
// node tool/render_release_play_assets.cjs [--native-manifest=relative/path.json]
// Without verified native inputs, outputs stay in review/ with a review label.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {chromium} = require('playwright');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const pack = path.join(root, 'docs/release/1.1.0/google-play');
const storyboard = JSON.parse(fs.readFileSync(path.join(pack, 'storyboard.json')));
const nativeArg = process.argv.find(x => x.startsWith('--native-manifest='));
const manifestFile = nativeArg ? path.resolve(root, nativeArg.split('=').slice(1).join('=')) : path.join(pack, 'source-review/capture-manifest.json');
const inputs = JSON.parse(fs.readFileSync(manifestFile));
const native = Boolean(nativeArg);
const required = [...storyboard.slides.map(s => s.source), 'tv-player.png'];
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const escape = value => String(value).replace(/[&<>"']/g, x => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[x]));
if (native) {
  if (inputs.sourceKind !== 'android-native-release' || inputs.version !== '1.1.0' || inputs.flavor !== 'production' || inputs.firebaseProject !== 'cloud-board-stationd' || inputs.packageName !== 'com.sunmkim.cloudboard' || !Number.isSafeInteger(inputs.build) || inputs.build < 1 || !/^[a-f0-9]{40}$/.test(inputs.sourceSha || '') || !inputs.device || !Number.isFinite(Date.parse(inputs.capturedAt)) || !/^[a-f0-9]{64}$/.test(inputs.artifactSha256 || '') || !inputs.verifiedBy) throw Error('Native candidate metadata is incomplete. See README capture schema.');
  for (const file of required) {
    const capture = inputs.captures.find(c => c.file === file);
    if (!capture || !capture.device || !capture.os || !Number.isFinite(Date.parse(capture.capturedAt)) || !capture.sha256 || capture.candidateBuild !== inputs.build || capture.sourceSha !== inputs.sourceSha) throw Error(`Missing candidate capture evidence: ${file}`);
    if (sha(fs.readFileSync(path.join(path.dirname(manifestFile), file))) !== capture.sha256) throw Error(`Capture hash mismatch: ${file}`);
    if (file === 'tv-player.png' && capture.formFactor !== 'android-tv') throw Error('The TV image requires actual Android TV capture evidence.');
  }
}
const output = path.join(pack, native ? 'ready' : 'review');
for (const directory of ['phone', 'tv', 'branding']) fs.mkdirSync(path.join(output, directory), {recursive: true});
const data = (file, mime='image/png') => `data:${mime};base64,${fs.readFileSync(file).toString('base64')}`;
const source = name => data(path.join(path.dirname(manifestFile), name));
const font = data(path.join(root, 'assets/fonts/pretendard/Pretendard-Bold.otf'), 'font/otf');
const regular = data(path.join(root, 'assets/fonts/pretendard/Pretendard-Regular.otf'), 'font/otf');
const assets = [];
const frame = (file, x, y, width, height, tv=false) => `<div class="frame ${tv ? 'tv' : ''}" style="left:${x}px;top:${y}px;width:${width}px;height:${height}px"><img src="${source(file)}" style="width:100%;height:100%;object-fit:contain" /></div>`;
const css = `@font-face{font-family:P;src:url('${font}');font-weight:700}@font-face{font-family:P;src:url('${regular}');font-weight:400}*{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;overflow:hidden}body{font-family:P,sans-serif;color:#302637}main{position:relative;width:100%;height:100%;overflow:hidden;background:radial-gradient(ellipse at 85% 52%,#DFD3EB,transparent 56%),linear-gradient(145deg,#FAF7F1,#EEE7F1)}h1,p{margin:0}h1{font-size:78px;line-height:1.08;letter-spacing:-3px;font-weight:700}p{font-size:30px;line-height:1.35}.copy{position:absolute;top:56px;left:66px;right:52px;z-index:2}.brand{font-size:25px;letter-spacing:.3px;color:#806891;margin-bottom:17px}.subtitle{margin-top:20px;color:#756A7D}.frame{position:absolute;background:white;border:9px solid #302A35;border-radius:32px;overflow:hidden;box-shadow:0 25px 70px #472B5426;z-index:1}.frame.tv{border-width:10px;border-radius:20px}.board{position:absolute;width:680px;height:960px;left:-285px;top:550px;background:#CDBBE444;border:2px solid #E0D0EF;border-radius:90px;transform:rotate(-13deg)}.board.second{left:830px;top:770px;background:#E7D6CB77;border-color:#EBDCCC;transform:rotate(14deg)}.dark{background:radial-gradient(ellipse at 50% 80%,#796187,transparent 70%),#472B54;color:#FFF8F4}.dark .brand,.dark .subtitle{color:#DECEE8}.dark .board{background:#A988C633;border-color:#A988C633}.dark .frame{box-shadow:0 35px 80px #170C1D55}.review{font:700 18px P;position:absolute;bottom:8px;left:0;right:0;text-align:center;color:#8E8195;z-index:5}`;
async function render(page, html, width, height, file) {
  await page.setViewportSize({width, height});
  await page.setContent(`<!doctype html><html lang="ko"><meta charset="utf-8"><style>${css}</style>${html}</html>`);
  await page.evaluate(async () => {await document.fonts.ready; await Promise.all([...document.images].map(image => image.decode()));});
  const png = await page.screenshot({type:'png'});
  const destination = path.join(output, file);
  await sharp(png).flatten({background:'#F6F2EC'}).removeAlpha().png().toFile(destination);
  const meta = await sharp(destination).metadata();
  if (meta.width !== width || meta.height !== height || meta.hasAlpha) throw Error(`Invalid exported dimensions or transparency: ${file}`);
  assets.push({file, width, height, bytes:fs.statSync(destination).size, sha256:sha(fs.readFileSync(destination))});
}
(async () => {
  // Keep input image aspect ratios; never stretch a phone capture to a TV.
  for (const file of required) {
    const meta = await sharp(path.join(path.dirname(manifestFile), file)).metadata();
    if (file === 'tv-player.png' ? meta.width / meta.height < 1.5 : meta.height / meta.width < 1.6) throw Error(`Unexpected source orientation: ${file}`);
  }
  for (const [file, maximum] of [['title.txt',30],['short-description.txt',80],['full-description.txt',4000],['release-notes.txt',500]]) {
    const text = fs.readFileSync(path.join(pack,'ko-KR',file),'utf8').trim();
    if ([...text].length > maximum) throw Error(`${file} exceeds ${maximum} characters`);
  }
  const browser = await chromium.launch({channel:'chrome',headless:true});
  const page = await browser.newPage({deviceScaleFactor:1});
  try {
    for (const slide of storyboard.slides) {
      const dark = slide.layout === 'dark';
      let images;
      if (slide.layout === 'phone-tv') {
        images = frame(slide.source,275,805,530,1060) + frame(slide.secondary,165,368,750,422,true);
      } else {
        images = frame(slide.source,slide.layout === 'offset' ? 218 : 175,396,730,1460);
      }
      await render(page,`<main class="${dark?'dark':''}"><div class="board"></div><div class="board second"></div><div class="copy"><p class="brand">CloudBoard · 클라우드보드</p><h1>${slide.title.map(escape).join('<br>')}</h1><p class="subtitle">${escape(slide.subtitle)}</p></div>${images}${native?'':'<div class="review">검토용 · 출시 후보의 실제 Android 캡처로 교체 예정</div>'}</main>`,1080,1920,`phone/${slide.id}.png`);
    }
    const tv = path.join(output,'tv/01-player.png');
    await sharp(path.join(path.dirname(manifestFile),'tv-player.png')).resize(1920,1080,{fit:'contain',background:'#F6F2EC'}).flatten({background:'#F6F2EC'}).removeAlpha().png().toFile(tv);
    assets.push({file:'tv/01-player.png',width:1920,height:1080,bytes:fs.statSync(tv).size,sha256:sha(fs.readFileSync(tv))});
    await render(page,`<main><div class="board" style="top:40px;left:750px;height:450px;width:340px"></div><div class="board second" style="top:300px;left:650px"></div><div style="position:absolute;left:108px;top:126px"><p style="font-size:24px;color:#806891;margin-bottom:18px">클라우드보드</p><h1 style="font-size:65px">준비한 수업,<br>흐름 있게.</h1></div></main>`,1024,500,'branding/feature-graphic-1024x500.png');
    await render(page,`<main class="dark"><div class="board" style="top:70px;left:840px;width:430px;height:580px"></div><div class="board second" style="top:280px;left:1050px"></div><div style="position:absolute;left:118px;top:223px"><p style="font-size:29px;color:#DECEE8;margin-bottom:24px">CloudBoard</p><h1 style="font-size:94px">클라우드보드</h1><p style="font-size:34px;margin-top:30px;color:#DECEE8">그룹 수업의 화면과 타이머</p></div></main>`,1280,720,'tv/banner-1280x720.png');
    const result = {schemaVersion:1,status:native?'native-captures-verified-awaiting-visual-review':'review-only-do-not-upload',sourceManifest:path.relative(root,manifestFile),sourceSha:inputs.sourceSha,version:'1.1.0',candidateBuild:inputs.build,generatedAt:new Date().toISOString(),assets};
    fs.writeFileSync(path.join(output,'asset-manifest.json'),JSON.stringify(result,null,2)+'\n');
    const cards=storyboard.slides.map(slide=>`<article><img src="phone/${slide.id}.png"><p>${escape(slide.alt)}</p></article>`).join('');
    fs.writeFileSync(path.join(output,'index.html'),`<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>CloudBoard 1.1.0 · Google Play</title><style>body{margin:40px;background:#F6F2EC;font-family:sans-serif;color:#302637}h1{font-size:30px}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:22px}img{display:block;width:100%;border-radius:12px}p{line-height:1.5;font-size:14px}@media(max-width:900px){.grid{grid-template-columns:repeat(2,1fr)}}</style><h1>Google Play · 1.1.0 · 한국어</h1><p>${native?'실제 Android 후보 캡처 적용 · 최종 시각 검수와 게시 대기':'검토용 이미지 · 실제 Android 후보 캡처 교체 전에는 업로드하지 않음'}</p><div class="grid">${cards}</div></html>`);
    await page.setViewportSize({width:1600,height:1680});
    await page.goto(`file://${path.join(output,'index.html')}`);
    await page.evaluate(async()=>Promise.all([...document.images].map(image=>image.decode())));
    await page.screenshot({path:path.join(output,'contact-sheet.png'),fullPage:true});
    console.log(`Validated ${assets.length} PNG files. Status: ${result.status}`);
  } finally {await browser.close();}
})().catch(error=>{console.error(error.message);process.exitCode=1;});
