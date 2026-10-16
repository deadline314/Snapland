"""Bake fixed-head idle cels from existing authored art; no new character drawing."""
from pathlib import Path
import argparse,json,hashlib,math
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
def build(source,output):
 source=Path(source).resolve();output=Path(output).resolve();output.mkdir(parents=True,exist_ok=True)
 specs=json.loads((source/'sources.json').read_text());result={'schema_version':1,'source_settings_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [source/'sources.json',source/'standing-registration.json']},'sequences':{}}
 for view,spec in specs.items():
  walk=Image.open(source/f'{view}-walk.png').convert('RGBA');w,h=walk.size;seam=int(spec['seam'])
  idle=[Image.open(source/f'{view}-idle-{i}.png').convert('RGBA') for i in range(spec['count'])]
  neutral=Image.open(source/f'{view}-standing.png').convert('RGBA')
  atlas=Image.new('RGBA',(w*len(idle),h));eye_boxes=[]
  blink=4 if len(idle)==8 else 2
  for box in spec['eyes']:
   x,y,bw,bh=box;eye_boxes.append([x-1,y-1,bw+2,bh+2])
  if len(spec['eyes'])!=len(spec['idle_eyes']):raise ValueError('Eye coverage differs: '+view)
  for i,raw in enumerate(idle):
   # A matched-proportion whole standing source avoids joining the old
   # oversized idle portrait to the smaller walking head. A bounded one-pixel
   # chest breath has zero displacement at the neck and planted pelvis.
   canvas=neutral.copy()
   breathe=i in ([2,3] if len(idle)==8 else [1])
   if breathe:
    for y in range(seam,270):
     shift=round(math.sin(math.pi*(y-seam)/(270-seam)))
     canvas.paste(neutral.crop((0,y+shift,w,y+shift+1)),(0,y))
   canvas.paste(walk.crop((0,0,w,seam)),(0,0))
   if i==blink:
    for target,origin in zip(eye_boxes,spec['idle_eyes']):
     x,y,bw,bh=origin;patch=raw.crop((x-2,y-2,x+bw+2,y+bh+2));tx,ty,tw,th=target
     patch=patch.resize((tw,th),Image.Resampling.NEAREST);canvas.paste(patch,(tx,ty))
   atlas.paste(canvas,(i*w,0))
  path=output/f'{view}.png';atlas.save(path)
  durations=[2.1,.25,.2,.08,.12,.08,.25,.4] if len(idle)==8 else [1.9,.3,.12,.5]
  result['sequences']['hero-idle/'+view]={'source':'res://'+path.relative_to(ROOT).as_posix(),'canvas':[w,h],'frames':len(idle),'head_neck_seam_y':seam,'eye_regions':eye_boxes,'blink_frame':blink if eye_boxes else -1,'frame_durations':durations,'body_motion_region':[0,seam,w,270-seam],'source_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [source/f'{view}-standing.png',source/f'{view}-walk.png',*[source/f'{view}-idle-{i}.png' for i in range(len(idle))]]}}
 (output/'manifest.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
 print('Built eight fixed-head idle cycles, five blink views, matched standing proportions, bounded chest breath and planted feet')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('output',type=Path);a=p.parse_args();build(a.source,a.output)
