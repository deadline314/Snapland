"""Validate baked standing roots, eyelids, neck compatibility and planted legs."""
from pathlib import Path
from PIL import Image,ImageChops
import json,argparse
VIEWS={'front','front_right','right','back_right','back','back_left','left','front_left'}
def visible(im):
 data=bytearray(im.convert('RGBA').tobytes())
 for i in range(0,len(data),4):
  if data[i+3]<102:data[i:i+3]=b'\0\0\0'
 return bytes(data)
def validate_cycle(images,spec):
 if len(images)!=int(spec['frames']) or len(images) not in (4,8):raise ValueError('Missing idle cels')
 if any(im.size!=(280,360) for im in images):raise ValueError('Wrong idle canvas')
 seam=int(spec['head_neck_seam_y']);boxes=spec['eye_regions'];blink=int(spec['blink_frame'])
 if not 175<=seam<=190:raise ValueError('Head seam out of reviewed range')
 head=images[0].crop((0,0,280,seam));legs=visible(images[0].crop((0,270,280,360)))
 for i,im in enumerate(images):
  current=im.crop((0,0,280,seam));reference=head.copy()
  if i==blink:
   for x,y,w,h in boxes:
    if min(x,y,w,h)<0 or x+w>280 or y+h>seam:raise ValueError('Eye patch outside head')
    current.paste(reference.crop((x,y,x+w,y+h)),(x,y))
  if visible(current)!=visible(reference):raise ValueError('Head or non-blink eyes shifted')
  if visible(im.crop((0,270,280,360)))!=legs:raise ValueError('Planted legs shifted')
  # An incompatible old oversized portrait leaves a broad second chin below
  # the canonical neck. This reviewed source-palette bound catches that failure.
  skin=0
  for y in range(seam,seam+25):
   for x in range(80,220):
    r,g,b,a=im.getpixel((x,y))
    if a>128 and r>150 and .62<g/max(r,1)<.85 and .58<b/max(g,1)<.85:skin+=1
  if skin>120:raise ValueError('Incompatible oversized portrait below neck')
 if boxes and visible(images[blink].crop((0,0,280,seam)))==visible(head):raise ValueError('Blink missing')
 if len({visible(im) for im in images})<2:raise ValueError('Idle frozen')
def validate(root):
 root=Path(root);manifest=json.loads((root/'manifest.json').read_text());sequences=manifest['sequences']
 if set(sequences)!={'hero-idle/'+v for v in VIEWS}:raise ValueError('Eight idle headings required')
 count=0
 for key,spec in sequences.items():
  atlas=Image.open(root/(key.split('/')[1]+'.png')).convert('RGBA')
  if atlas.size!=(280*int(spec['frames']),360):raise ValueError('Atlas size mismatch')
  images=[atlas.crop((280*i,0,280*(i+1),360)) for i in range(int(spec['frames']))];validate_cycle(images,spec);count+=len(images)
 return count
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('root',type=Path);a=p.parse_args();print('PASS',validate(a.root),'fixed-head idle source cels')
