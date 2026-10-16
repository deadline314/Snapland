"""Register a generated standing sheet to approved walking heads and ground."""
from pathlib import Path
from PIL import Image
import json,argparse,hashlib
VIEWS=['front','front_right','right','back_right','back','back_left','left','front_left']
def gray(im):
 import cv2,numpy as np
 bg=Image.new('RGBA',im.size,(215,215,215,255));bg.alpha_composite(im);return cv2.cvtColor(np.array(bg.convert('RGB')),cv2.COLOR_RGB2GRAY)
def validate_placement(bounds,delta,canvas=(280,360)):
 if bounds is None:raise ValueError('Standing source has no visible pixels')
 l,t,r,b=bounds;dx,dy=delta
 if min(l+dx,t+dy)<0 or r+dx>canvas[0] or b+dy>canvas[1]:raise ValueError('Standing source would be clipped by canvas')
 return (l+dx,t+dy,r+dx,b+dy)
def visible_bounds(image):
 return image.getchannel("A").point(lambda a:255 if a>=102 else 0).getbbox()

def register(sheet,folder):
 import cv2,numpy as np
 sheet=Path(sheet);folder=Path(folder);atlas=Image.open(sheet).convert('RGBA');specs=json.loads((folder/'sources.json').read_text());rows={}
 if atlas.width%4 or atlas.height%2:raise ValueError('Sheet must contain eight exact cells')
 cw,ch=atlas.width//4,atlas.height//2
 for i,view in enumerate(VIEWS):
  ref=Image.open(folder/f'{view}-walk.png').convert('RGBA');seam=int(specs[view]['seam']);template=gray(ref)[65:seam,65:225];cell=atlas.crop((i%4*cw,i//4*ch,(i%4+1)*cw,(i//4+1)*ch));best=None
  for multiplier in np.arange(.94,1.10,.0025):
   scale=280/cw*multiplier;scaled=cell.resize((round(cell.width*scale),round(cell.height*scale)),Image.Resampling.NEAREST)
   res=cv2.matchTemplate(gray(scaled)[:230,:],template,cv2.TM_CCOEFF_NORMED);_,score,_,loc=cv2.minMaxLoc(res);delta=(65-loc[0],65-loc[1]);bounds=visible_bounds(scaled);bottom=bounds[3]+delta[1]
   if bottom!=346:continue
   if best is None or score>best[0]:best=(score,scaled,scale,delta,bottom)
  if best is None or best[0]<.70:raise ValueError('Standing head/ground registration needs manual review: '+view)
  score,scaled,scale,delta,bottom=best;bounds=visible_bounds(scaled);expected_bounds=validate_placement(bounds,delta);canvas=Image.new('RGBA',(280,360));canvas.paste(scaled,delta)
  if canvas.getchannel('A').point(lambda a:255 if a>=102 else 0).getbbox()!=expected_bounds:raise ValueError('Standing alpha bounds changed during placement')
  canvas.save(folder/f'{view}-standing.png');rows[view]={'scale':scale,'offset':delta,'head_score':score,'bottom':bottom}
 (folder/'standing-registration.json').write_text(json.dumps({'sheet_sha256':hashlib.sha256(sheet.read_bytes()).hexdigest(),'directions':rows},indent=2)+'\n')
 print('Registered eight standing sources on fixed 346px ground; head seam requires visual review')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('sheet',type=Path);p.add_argument('folder',type=Path);a=p.parse_args();register(a.sheet,a.folder)
