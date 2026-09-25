from pathlib import Path
import base64, io, json, shutil
from PIL import Image
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from pypdf import PdfReader

root = Path(__file__).resolve().parent
old = root.parent / 'productivity-redesign-2026-09-25'
pages = json.loads((root / 'prompts.json').read_text())
html = (old / 'gallery.html').read_text()
html = html.replace('remaining/', '')
html = html.replace('CloudBoard · 디자인 갤러리', 'CloudBoard · 커서 형 리디자인')
html = html.replace('CLOUDBOARD / DESIGN REVIEW', 'CLOUDBOARD / CURSOR STYLE REVIEW')
html = html.replace('수업 준비는 가볍게.</h1>', '커서 형 리디자인</h1>')
html = html.replace('12개 대표 화면을 한곳에서. 이미지를 누르면 크게 볼 수 있어요.', '따뜻한 크림색과 가는 타이포로 다시 만든 12개 화면. 클릭해 확대하거나 이전 안과 비교해 보세요.')
html = html.replace('STA-36', 'STA-39')
for a,b in {'#f6f6f8':'#f7f7f4','#202027':'#26251e','#fff':'#f7f7f4','#e6e6ed':'#cdcdc9','#7e78a3':'#b9430a','#62626d':'#66665f','#dedee7':'#cdcdc9','#30303c':'#26251e','#272632':'#26251e','#a39bc7':'#b9430a','#e5e5ec':'#cdcdc9','#eeeef2':'#f2f1ed','#e6e4ec':'#e6e5e0','#8a829f':'#7a7974','border-radius:10px':'border-radius:4px','border-radius:14px':'border-radius:4px','font-weight:650':'font-weight:400'}.items():
    html = html.replace(a,b)
html = html.replace('</style>', 'h1,h2{font-weight:400}.version{display:flex;gap:6px;margin-top:18px}.issue{display:inline-block}.viewerbar .compare{white-space:nowrap}</style>')
html = html.replace('<div class="toolbar">', '<div class="version" aria-label="디자인 버전"><button id="newVersion" aria-pressed="true">커서 형</button><button id="oldVersion" aria-pressed="false">이전 안</button></div><div class="toolbar">')
html = html.replace('<button id="zoom"', '<button class="compare" id="compare" aria-pressed="false">이전 안 보기</button><button id="zoom"')
html = html.replace('const source=p=>embedded[p[0]]||p[0];', '''let previous=false;
const oldPaths=''' + json.dumps({p['file']: 'previous/'+p['file'] for p in pages}) + ''';
const source=p=>{const key=previous?oldPaths[p[0]]:p[0];return embedded[key]||key};''')
html = html.replace("+' / 12 · '+p[1]", "+' / 12 · '+p[1]+(previous?' · 이전 안':' · 커서 형')")
html = html.replace("a.download=p[0].split('/').pop()", "a.download=(previous?'previous-':'cursor-')+p[0].split('/').pop()")
html = html.replace('</script>', '''function setVersion(value){
 previous=value;
 document.querySelector('#newVersion').setAttribute('aria-pressed',String(!value));
 document.querySelector('#oldVersion').setAttribute('aria-pressed',String(value));
 document.querySelector('#compare').setAttribute('aria-pressed',String(value));
 document.querySelector('#compare').textContent=value?'커서 형 보기':'이전 안 보기';
 [...gallery.children].forEach((tile,i)=>tile.querySelector('img').src=source(pages[i]));
 if(viewer.open)show(current);
}
document.querySelector('#newVersion').onclick=()=>setVersion(false);
document.querySelector('#oldVersion').onclick=()=>setVersion(true);
document.querySelector('#compare').onclick=()=>setVersion(!previous);
</script>''')
(root/'previous').mkdir(exist_ok=True)
for p in pages:
    shutil.copy2(old/p['source'], root/'previous'/p['file'])
(root/'gallery.html').write_text(html)
embedded = {p.relative_to(root).as_posix(): 'data:image/png;base64,'+base64.b64encode(p.read_bytes()).decode() for p in [*(root.glob('*.png')), *(root/'previous').glob('*.png')]}
(root/'cloudboard-cursor-gallery.html').write_text(html.replace('/*EMBEDDED_IMAGES*/{}','/*EMBEDDED_IMAGES*/'+json.dumps(embedded)))

pdf = root.parents[2]/'output/pdf/cloudboard-cursor-redesign.pdf'
pdf.parent.mkdir(parents=True,exist_ok=True)
c = canvas.Canvas(str(pdf))
c.setTitle('CloudBoard - Cursor Style Redesign - 12 Screens')
c.setAuthor('CloudBoard design review')
english = ['Login','Home','Workout editor','Slide editor','Displays','Profile','Onboarding','Favorites','Operations','Standby settings','Class player','TV display']
for i,p in enumerate(pages):
    im=Image.open(root/p['file']).convert('RGB')
    width=840 if i==11 else 420
    height=width*im.height/im.width
    c.setPageSize((width,height+28))
    c.setFillColorRGB(247/255,247/255,244/255)
    c.rect(0,0,width,height+28,fill=1,stroke=0)
    buf=io.BytesIO();im.save(buf,format='JPEG',quality=94,subsampling=0);buf.seek(0)
    c.drawImage(ImageReader(buf),0,28,width=width,height=height)
    c.setFont('Helvetica',8);c.setFillColorRGB(.3,.3,.27)
    c.drawString(12,10,f'{i+1:02} / 12   {english[i]}  |  CloudBoard - Cursor style')
    c.bookmarkPage(str(i));c.addOutlineEntry(english[i],str(i),0)
    c.showPage()
c.save()
assert len(PdfReader(pdf).pages)==12
print(json.dumps({'pdf':str(pdf),'size':pdf.stat().st_size,'screens':len(pages),'gallery':str(root/'gallery.html')}))
