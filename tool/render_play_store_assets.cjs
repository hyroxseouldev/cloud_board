// npm packages required: playwright, sharp. See docs/play-store/README.md.
const fs = require('node:fs');
const path = require('node:path');
const {chromium} = require('playwright');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const pack = path.join(root, 'docs/play-store');
const assets = path.join(pack, 'ko-KR/assets');
const data = (file, mime) => `data:${mime};base64,${fs.readFileSync(file).toString('base64')}`;
const font = data(path.join(root,'assets/fonts/pretendard/Pretendard-Bold.otf'),'font/otf');
const regular = data(path.join(root,'assets/fonts/pretendard/Pretendard-Regular.otf'),'font/otf');
const source = name => data(path.join(pack,`source/${name}.png`),'image/png');
const logo = `<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><rect width="512" height="512" fill="#77729D"/><rect x="106" y="123" width="300" height="214" rx="30" fill="none" stroke="#fff" stroke-width="22"/><path d="M130 236H193L220 189L259 276L293 224H382M256 341V383M208 385H304" fill="none" stroke="#fff" stroke-width="20" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
const slides = [
 ['01-workouts','수업 준비를 한곳에서','폴더로 정리하고, 빠르게 찾으세요.'],
 ['02-editor','우리 수업에 맞게 편집','운동 순서부터 시간과 휴식까지.'],
 ['03-briefing','시작 전에 함께 확인','브리핑으로 수업의 흐름을 살펴보세요.'],
 ['04-sounds','전환 순간을 소리로','카운트다운부터 수업 종료까지.'],
];
const specs = [];
const capture = async (page, html, w, h, filename, alpha=false) => {
 await page.setViewportSize({width:w,height:h});
 await page.setContent(`<html lang="ko"><meta charset="utf-8"><style>@font-face{font-family:P;src:url('${font}');font-weight:700}@font-face{font-family:P;src:url('${regular}');font-weight:400}*{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;overflow:hidden}body{font-family:P,sans-serif;color:#202028}img{display:block}h1,p{margin:0}.screen{border:1px solid #E6E3EF;border-radius:24px;overflow:hidden;background:white;box-shadow:0 20px 50px #39334718}</style>${html}</html>`);
 await page.evaluate(async()=>{await document.fonts.ready;await Promise.all([...document.images].map(i=>i.decode()));});
 const png = await page.screenshot({type:'png'});
 let img=sharp(png);
 img=alpha?img.ensureAlpha():img.flatten({background:'#fff'}).removeAlpha();
 await img.png().toFile(path.join(assets,filename));
 specs.push({file:filename,width:w,height:h,alpha});
};
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true});
 const page=await browser.newPage({deviceScaleFactor:1});
 try {
 for(let i=0;i<slides.length;i++) {
   const [slug,title,sub]=slides[i];
   const dark=i===2;
   await capture(page,`<main style="width:1080px;height:1920px;padding:62px 64px;background:${dark?'#77729D':'linear-gradient(145deg,#F5F4F8,#E4E1EE)'};color:${dark?'white':'#202028'}"><p style="font-size:28px;letter-spacing:2px;opacity:.75;margin-bottom:22px">클라우드보드 <span style="float:right">0${i+1}</span></p><h1 style="font-size:66px;font-weight:700;letter-spacing:-3px;line-height:1.1">${title}</h1><p style="font-size:31px;font-weight:400;opacity:.75;margin-top:20px">${sub}</p><div class="screen" style="position:absolute;left:94.5px;top:300px;width:891px;height:1584px"><img src="${source(`phone-${slug}`)}" width="891" height="1584"></div></main>`,1080,1920,`phone/${slug}.png`);
   await sharp(path.join(pack,`source/tablet-${slug}.png`)).flatten({background:'#fff'}).removeAlpha().png().toFile(path.join(assets,`tablet/${slug}.png`));
   specs.push({file:`tablet/${slug}.png`,width:1080,height:1920,alpha:false});
 }
 await sharp(path.join(pack,'source/tv-01-player.png')).flatten({background:'#fff'}).removeAlpha().png().toFile(path.join(assets,'tv/01-player.png'));
 specs.push({file:'tv/01-player.png',width:1920,height:1080,alpha:false});
 await capture(page,logo,512,512,'branding/app-icon-draft-512.png',true);
 fs.writeFileSync(path.join(assets,'branding/app-icon-draft.svg'),logo);
 await capture(page,`<main style="width:1024px;height:500px;background:linear-gradient(130deg,#E4E1EE,#F5F4F8);padding:68px 60px;position:relative"><p style="font-size:24px;color:#77729D;letter-spacing:1px">클라우드보드</p><h1 style="font-size:57px;letter-spacing:-2.8px;line-height:1.13;margin-top:30px">수업의 흐름을<br>한 화면으로.</h1><p style="font-size:23px;color:#777683;margin-top:28px">워크아웃부터 디스플레이까지</p><div class="screen" style="position:absolute;right:48px;top:107px;width:448px;height:252px"><img src="${source('tv-01-player')}" width="448" height="252"></div></main>`,1024,500,'branding/feature-graphic-1024x500.png');
 await capture(page,`<main style="width:1280px;height:720px;background:linear-gradient(125deg,#77729D,#625E86);color:white;display:flex;align-items:center;justify-content:center;gap:54px"><div style="width:196px;height:196px">${logo}</div><div><h1 style="font-size:84px;letter-spacing:-4px">클라우드보드</h1><p style="font-size:31px;font-weight:400;opacity:.8;margin-top:22px">수업을 연결하는 디스플레이</p></div></main>`,1280,720,'tv/banner-1280x720.png');
 for(const item of specs) {
   const meta=await sharp(path.join(assets,item.file)).metadata();
   if(meta.width!==item.width||meta.height!==item.height||meta.hasAlpha!==item.alpha) throw Error(`Invalid output: ${item.file} ${JSON.stringify(meta)}`);
   item.bytes=fs.statSync(path.join(assets,item.file)).size;
   if(item.file.includes('app-icon')&&item.bytes>1024*1024)throw Error('Icon too large');
 }
 fs.writeFileSync(path.join(pack,'asset-manifest.json'),JSON.stringify({appName:'클라우드보드',locale:'ko-KR',generatedAt:new Date().toISOString(),assets:specs},null,2));
 const thumbs=specs.filter(s=>s.file.startsWith('phone/')).map(s=>`<div><img src="ko-KR/assets/${s.file}" style="width:100%;border-radius:16px"/><p>${s.file}</p></div>`).join('');
 fs.writeFileSync(path.join(pack,'index.html'),`<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>클라우드보드 · Google Play 에셋</title><style>@font-face{font-family:P;src:url('../../assets/fonts/pretendard/Pretendard-Regular.otf')}body{font-family:P,sans-serif;background:#F5F4F8;color:#202028;max-width:1400px;margin:48px auto;padding:0 24px}h1{font-size:42px}p{color:#777683}a{color:#625E86}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:24px}.brand{display:flex;align-items:center;gap:32px;margin:40px 0}.brand img{object-fit:contain;max-width:75%}@media(max-width:800px){.grid{grid-template-columns:repeat(2,1fr)}}</style><h1>클라우드보드</h1><p>Google Play · 한국어 스토어 에셋 시안</p><a href="README.md">업로드 안내</a> · <a href="ko-KR/full-description.txt">앱 소개 문구</a><div class="brand"><img src="ko-KR/assets/branding/app-icon-draft-512.png" width="180"/><img src="ko-KR/assets/branding/feature-graphic-1024x500.png" width="820"/></div><h2>휴대폰 · 1080 × 1920</h2><div class="grid">${thumbs}</div><h2>태블릿 · 1080 × 1920</h2><div class="grid">${slides.map(([s])=>`<img src="ko-KR/assets/tablet/${s}.png" style="width:100%"/>`).join('')}</div><h2>Android TV</h2><div class="brand"><img src="ko-KR/assets/tv/01-player.png" width="700"/><img src="ko-KR/assets/tv/banner-1280x720.png" width="450"/></div></html>`);
 // A single contact sheet for quick review and sharing.
 await page.setViewportSize({width:1400,height:1150});
 await page.setContent(`<body style="margin:0;padding:42px;background:#F5F4F8;font-family:sans-serif"><div style="display:flex;gap:24px;align-items:center"><img src="${data(path.join(assets,'branding/app-icon-draft-512.png'),'image/png')}" width="180"><img src="${data(path.join(assets,'branding/feature-graphic-1024x500.png'),'image/png')}" width="700"><img src="${data(path.join(assets,'tv/banner-1280x720.png'),'image/png')}" width="360"></div><div style="display:flex;gap:24px;margin-top:40px">${slides.map(([s])=>`<img src="${data(path.join(assets,`phone/${s}.png`),'image/png')}" width="311">`).join('')}</div></body>`);
 await page.evaluate(async()=>Promise.all([...document.images].map(i=>i.decode())));
 await page.screenshot({path:path.join(pack,'preview.png'),fullPage:true});
 console.log(`Exported and validated ${specs.length} PNGs.`);
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
