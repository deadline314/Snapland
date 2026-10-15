"""Offline initial source registration for reviewed original-style 2D art.
Requires Pillow, numpy and opencv-python. It only extracts existing alpha
silhouettes; all resulting geometry is explicit in authoring.json for review.
"""
from __future__ import annotations
import copy, hashlib, json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
PACK=ROOT/'assets/characters/hero-2d-v1'
DIRS=['front','front_right','right','back_right','back','back_left','left','front_left']

def split(name, rows, directions, head_height=None):
    src=PACK/'candidates'/name
    im=Image.open(src).convert('RGBA');pixels=np.array(im)
    _,labels,stats,_=cv2.connectedComponentsWithStats((pixels[:,:,3]>=8).astype(np.uint8),8)
    components=[(i,tuple(map(int,r))) for i,r in enumerate(stats) if i and r[4]>1200]
    if len(components)!=rows*len(directions):
        raise ValueError(f'{name}: expected {rows*len(directions)} whole silhouettes, got {len(components)}')
    components.sort(key=lambda item:item[1][1]);out=[]
    folder=PACK/'registered'/src.stem;folder.mkdir(parents=True,exist_ok=True)
    for row in range(rows):
        line=sorted(components[row*len(directions):(row+1)*len(directions)],key=lambda item:item[1][0]);out.append({})
        for direction,(label,(x,y,w,h,area)) in zip(directions,line):
            xx,yy=max(0,x-2),max(0,y-2);xe,ye=min(im.width,x+w+2),min(im.height,y+h+2)
            cell=pixels[yy:ye,xx:xe].copy();cell[:,:,3]=np.where(labels[yy:ye,xx:xe]==label,cell[:,:,3],0)
            target=folder/f'{row:02d}-{direction}.png';Image.fromarray(cell).save(target)
            record={'source':str(target.relative_to(PACK)).replace('\\','/'),'region':[0,0,xe-xx,ye-yy],
                'original_source':'candidates/'+name,'original_region':[xx,yy,xe-xx,ye-yy],
                'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'alpha_component_area':area}
            if head_height:
                a=cell[:,:,3]>=8;top=y-yy;lo=top+round(head_height*.12);hi=top+round(head_height*.62)
                ys,xs=np.nonzero(a[lo:hi]);cx=(int(xs.min())+int(xs.max()))/2
                feet_y=y+h-yy-1;band=a[max(0,feet_y-7):feet_y+1];ys,xs=np.nonzero(band)
                record.update(head_anchor=[cx,top+head_height/2],feet=[(int(xs.min())+int(xs.max()))/2,feet_y],scale=1.0)
            out[row][direction]=record
    return out

def normalize_rows(rows,baseline=0):
    for d in rows[0]:
        first=rows[baseline][d];height=first['original_region'][3]-4;scale=248/height
        for row in rows:row[d]['scale']=round(scale,6)
    return rows

def foreground(record,direction):
    s=record['scale'];hx=140+(record['head_anchor'][0]-record['feet'][0])*s;hy=346+(record['head_anchor'][1]-record['feet'][1])*s
    if direction=='right':r=[round(hx+22),round(hy+16),51,70]
    elif direction=='left':r=[round(hx-73),round(hy+16),51,70]
    elif direction in ['front','front_left','front_right']:r=[round(hx-49),round(hy+20),98,62]
    else:return []
    return [r]

def main():
    data={'schema_version':1,'note':'Original 2D bitmap sources; explicit per-cel author geometry. Registered components preserve source pixels and remove disconnected neighboring fragments. Human binding QA required.','part_canvas':[256,256],'walk':{},'actions':{},'parts':{'hair':{},'hats':{}}}
    groups=[('front-back',['front','back']),('sides',['left','right']),('front-diagonal',['front_left','front_right']),('back-diagonal',['back_left','back_right'])]
    for suffix,directions in groups:
        base=split(f'bald-walk-{suffix}-v1.png',2,[str(i) for i in range(8)],132)
        coat=split(f'coat-walk-{suffix}-v1.png',2,[str(i) for i in range(8)],132)
        for row,d in enumerate(directions):
            frames=[];scale=248/(base[row]['0']['original_region'][3]-4);coat_scale=248/(coat[row]['0']['original_region'][3]-4)
            for col in range(8):
                original=json.loads((ROOT/'assets/characters/walk-regions.json').read_text())['directions'][d]
                root_x=original['regions'][col][0]+original['anchors'][col]['center_x']
                base[row][str(col)]['feet'][0]=root_x-base[row][str(col)]['original_region'][0]
                coat[row][str(col)]['feet'][0]=root_x-coat[row][str(col)]['original_region'][0]
                r=base[row][str(col)];r['scale']=round(scale,6);variant=coat[row][str(col)];variant['scale']=round(coat_scale,6);r['outfits']={'long_coat':variant};frames.append(r)
            data['walk'][d]=frames
    transitions=normalize_rows(split('transitions-eight-view-v1.png',4,DIRS,100))
    coat_transitions=normalize_rows(split('coat-transitions-eight-view-v1.png',4,DIRS,100))
    photo=normalize_rows(split('photo-eight-view-v1.png',4,DIRS,100))
    coat_photo=normalize_rows(split('coat-photo-eight-view-v1.png',4,DIRS,100))
    for d in DIRS:
        for rows,variants in [(transitions,coat_transitions),(photo,coat_photo)]:
            for i in range(4):rows[i][d]['outfits']={'long_coat':variants[i][d]}
        photos=[]
        for i in [0,1,2,2,2,3,0]:
            r=copy.deepcopy(photo[i][d])
            if i in [1,2]:
                r['foreground_regions']=foreground(r,d);r['outfits']['long_coat']['foreground_regions']=foreground(r['outfits']['long_coat'],d)
            photos.append(r)
        data['actions'][d]={'idle':[transitions[0][d]],'start':[transitions[1][d]],'stop':[transitions[2][d],transitions[0][d]],'turn':[transitions[3][d]],'photo':photos}
    for direction,frames in data['walk'].items():
        neutral=data['actions'][direction]['idle'][0]
        for key in ['tide_jacket','long_coat']:
            idle=neutral if key=='tide_jacket' else neutral['outfits'][key]
            target=140+(idle['head_anchor'][0]-idle['feet'][0])*idle['scale']
            for frame in frames:
                r=frame if key=='tide_jacket' else frame['outfits'][key]
                r['feet'][0]=r['head_anchor'][0]-(target-140)/r['scale']
                r['root_registration_method']='authored torso axis; stable across walk loop, independent of shoe silhouette'
    hair=split('hair-eight-view-v2.png',2,DIRS)
    for row,style in enumerate(['windswept','bob']):
        data['parts']['hair'][style]={}
        for col,d in enumerate(DIRS):
            r=hair[row][d];x,y,_,_=r['original_region'];r.update(anchor=[(col+.5)*2039/8-x,(242 if row==0 else 535.5)-y],scale=.67,offset=[0,-4])


            data['parts']['hair'][style][d]=r
    hatted=split('hatted-hair-eight-view-v1.png',2,DIRS)
    width,height=Image.open(PACK/'candidates/hatted-hair-eight-view-v1.png').size
    for row,style in enumerate(['windswept','bob']):
        for col,d in enumerate(DIRS):
            r=hatted[row][d];x,y,_,_=r['original_region']
            r.update(anchor=[(col+.5)*width/8-x,(242 if row==0 else 535.5)*height/771-y],scale=.67,offset=[0,-4])
            data['parts']['hair'][style][d]['hat_variant']=r
    cap=split('cap-eight-view-v1.png',1,DIRS)[0];data['parts']['hats']['traveller']={}
    for col,d in enumerate(DIRS):
        r=cap[d];x,y,_,_=r['original_region'];r.update(anchor=[(col+.5)*2079/8-x,472-y],scale=.47,offset=[0,0]);data['parts']['hats']['traveller'][d]=r
    data['walk']={d:data['walk'][d] for d in DIRS}
    try:
        from tools.hero_2d.align_body_pivots import align
    except ModuleNotFoundError:
        from align_body_pivots import align
    data=align(data)
    (PACK/'authoring.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Registered original 2D source silhouettes and explicit per-cel geometry; not visual acceptance')
if __name__=='__main__':main()
