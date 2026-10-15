"""Offline authored head attachments, separate from fixed body registration.
The runtime reads explicit points only; no template matching or color inference runs in-game.
"""
from pathlib import Path
import json,hashlib,argparse
ROOT=Path(__file__).resolve().parents[2]
PACK=ROOT/'assets/characters/hero-2d-v1'

def apply(data, path=None):
    path=Path(path) if path else PACK/'head-attachments.json'
    markers=json.loads(path.read_text(encoding='utf-8'))
    for direction,frames in data['walk'].items():
        for outfit in ['tide_jacket','long_coat']:
            points=markers['walk'][direction][outfit]
            if len(points)!=len(frames): raise ValueError('Head attachment coverage mismatch: '+direction)
            for frame,point in zip(frames,points):
                record=frame if outfit=='tide_jacket' else frame['outfits'][outfit]
                if record['source_sha256']!=point['original_source_sha256']: raise ValueError('Head calibration source changed: '+direction+'/'+outfit)
                record['head_attachment_offset']=point['offset']
                record['head_attachment_reference']='head-attachments.json; reviewed offline head-feature translation, independent of body root'
    data['head_attachment_source']='head-attachments.json'
    return data

def propose(output):
    # Only an authoring suggestion. The resulting sheet and actual playback require review.
    import cv2,numpy as np
    from PIL import Image
    m=json.loads((PACK/'manifest.json').read_text(encoding='utf-8'))
    authors=json.loads((PACK/'authoring.json').read_text(encoding='utf-8'))
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    result={'schema_version':1,'method':'Offline normalized grayscale head-feature translation within a fixed authored ROI and +/-6px search; explicit points are reviewed before adoption. Runtime does not infer anatomy.','reference_roi':[95,110,91,66],'search_radius':6,'body_registration':'Unchanged body pixels, feet and scale; attachment is independent of the fixed 140,148 author guide.','unchanged_body_sha256':{name:sha(PACK/name) for name in m['files'] if Path(name).name.startswith(('tide-','coat-'))},'walk':{}}
    scores=[]
    for direction in m['directions']:
        result['walk'][direction]={}
        for outfit in ['tide_jacket','long_coat']:
            reference=None;points=[]
            for i,frame in enumerate(m['poses'][direction]['walk']):
                body=frame if outfit=='tide_jacket' else frame['outfits'][outfit]
                x,y,w,h=body['region']
                image=Image.open(PACK/body['source']).crop((x,y,x+w,y+h)).convert('RGBA')
                pixels=np.array(image);gray=cv2.cvtColor(pixels[:,:,:3],cv2.COLOR_RGB2GRAY)
                if reference is None: reference=gray[110:176,95:186].copy()
                score_map=cv2.matchTemplate(gray[104:182,89:192],reference,cv2.TM_CCOEFF_NORMED)
                _,score,_,location=cv2.minMaxLoc(score_map)
                dx,dy=location[0]-6,location[1]-6
                source=authors['walk'][direction][i]
                if outfit!='tide_jacket':source=source['outfits'][outfit]
                guide=body.get('body_guide',[140,148])
                points.append({'offset':[dx,dy],'attachment':[guide[0]+dx,guide[1]+dy],'match_score':round(score,6),'original_source_sha256':source['source_sha256']})
                scores.append(score)
            result['walk'][direction][outfit]=points
    Path(output).parent.mkdir(parents=True,exist_ok=True)
    Path(output).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('128 attachment proposals; lowest head feature correlation',round(min(scores),4))
    if min(scores)<0.85: raise ValueError('Low-confidence head proposal requires manual correction before adoption')
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--propose',type=Path,help='Write a candidate JSON; never overwrites authoring or runtime assets')
    args=parser.parse_args()
    if not args.propose: parser.error('Use --propose <candidate.json> and review the points before applying')
    propose(args.propose)
