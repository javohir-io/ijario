"""Renders the Ijario app icon (arched doorway mark on the oxblood aurora)."""
import numpy as np, os, json, glob
from PIL import Image, ImageDraw, ImageFilter

OXBLOOD=(0x5E,0x1E,0x2B); DEEP=(0x3B,0x12,0x1B); GLOW=(0x8C,0x34,0x46)
OAK=(0xD2,0xBC,0xA8); PLASTER=(0xDA,0xDC,0xDD); PAPER=(0xF8,0xF7,0xF5)

def radial(size, cx, cy, r, color, alpha):
    y,x=np.mgrid[0:size,0:size].astype(np.float32)
    d=np.sqrt((x-cx*size)**2+(y-cy*size)**2)/(r*size)
    a=np.clip(1-d,0,1)*alpha
    return a[...,None], np.array(color,np.float32)[None,None,:]

def background(size):
    img=np.zeros((size,size,3),np.float32); img[:]=DEEP
    for cx,cy,r,col,al in [(.25,.20,.95,OXBLOOD,1.0),(.88,.40,.62,GLOW,.6),(.55,1.02,.60,OAK,.50),(.95,.02,.38,PLASTER,.16)]:
        a,c=radial(size,cx,cy,r,col,al); img=img*(1-a)+c*a
    return img

def arch_mask(S, w, h, left, top, corner=0.10, scale=1):
    m=Image.new('L',(S,S),0); d=ImageDraw.Draw(m)
    d.pieslice([left,top,left+w,top+w],180,360,fill=255)
    d.rounded_rectangle([left,top+w/2,left+w,top+h],radius=corner*w,corners=(False,False,True,True),fill=255)
    return m

def render(size, mark_height=0.54, with_bg=True):
    S=size*4
    bg=background(S) if with_bg else np.zeros((S,S,3),np.float32)
    # mark geometry (same proportions as IjarioMark in the app)
    h=S*mark_height; w=h*0.62/0.84
    left=(S-w)/2; top=(S-h)/2
    outer=arch_mask(S,w,h,left,top)
    iw=w*0.40; ih=h*0.52
    inner=arch_mask(S,iw,ih,left+(w-iw)/2,top+h-ih-h*0.09,corner=0.06)
    shape=np.array(outer,np.float32)/255-np.array(inner,np.float32)/255
    shape=np.clip(shape,0,1)
    # warm metallic fill: diagonal gradient + light band
    y,x=np.mgrid[0:S,0:S].astype(np.float32)
    t=np.clip(((x-left)+(y-top))/(w+h),0,1)
    stops=[(0,PLASTER),(.38,OAK),(.7,PAPER),(1,OAK)]
    fill=np.zeros((S,S,3),np.float32)
    for (t0,c0),(t1,c1) in zip(stops,stops[1:]):
        k=np.clip((t-t0)/(t1-t0),0,1)[...,None]
        sel=((t>=t0)&(t<=t1))[...,None]
        fill=np.where(sel,np.array(c0,np.float32)*(1-k)+np.array(c1,np.float32)*k,fill)
    band=np.exp(-(((t-0.30)/0.07)**2))[...,None]*0.55
    fill=fill*(1-band)+255*band
    # soft shadow under the mark
    sh=Image.fromarray((shape*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(S*0.012))
    shadow=(np.array(sh,np.float32)/255*0.35)[...,None]
    out=bg*(1-shadow)
    a=shape[...,None]
    out=out*(1-a)+fill*a
    img=Image.fromarray(np.clip(out,0,255).astype(np.uint8)).resize((size,size),Image.LANCZOS)
    return img

if __name__=='__main__':
    import sys
    # usage: python tool/make_icons.py [path-to-app]   (needs: pip install pillow numpy)
    app=os.path.abspath(sys.argv[1] if len(sys.argv)>1 else os.path.join(os.path.dirname(__file__),'..'))
    master=render(1024)
    master.save(os.path.join(os.path.dirname(os.path.abspath(__file__)),'icon-1024.png'))
    def save(img,path,size,rgb=True):
        os.makedirs(os.path.dirname(path),exist_ok=True)
        im=img.resize((size,size),Image.LANCZOS)
        im.convert('RGB').save(path)
    # Android legacy launcher icons
    for d,s in {'mdpi':48,'hdpi':72,'xhdpi':96,'xxhdpi':144,'xxxhdpi':192}.items():
        save(master,f'{app}/android/app/src/main/res/mipmap-{d}/ic_launcher.png',s)
    # iOS
    ios=f'{app}/ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for it in json.load(open(ios+'/Contents.json'))['images']:
        base=float(it['size'].split('x')[0]); sc=int(it['scale'][0])
        save(master,f"{ios}/{it['filename']}",round(base*sc))
    # macOS
    mac=f'{app}/macos/Runner/Assets.xcassets/AppIcon.appiconset'
    for it in json.load(open(mac+'/Contents.json'))['images']:
        base=int(it['size'].split('x')[0]); sc=int(it['scale'][0])
        save(master,f"{mac}/{it['filename']}",base*sc)
    # Web
    save(master,f'{app}/web/icons/Icon-192.png',192); save(master,f'{app}/web/icons/Icon-512.png',512)
    mask=render(1024,mark_height=0.42)   # maskable: mark inside the safe zone
    save(mask,f'{app}/web/icons/Icon-maskable-192.png',192); save(mask,f'{app}/web/icons/Icon-maskable-512.png',512)
    save(master,f'{app}/web/favicon.png',64)
    # Windows .ico
    master.convert('RGB').save(f'{app}/windows/runner/resources/app_icon.ico',sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])
    print('icons written')
