"""Author explicit fixed-canvas body registration; never use shoe extents as roots."""
from __future__ import annotations
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
PACK=ROOT/'assets/characters/hero-2d-v1'
TARGET=(140.,148.)
FEET=(140.,346.)

def head_point(record):
    return tuple(FEET[i]+(record['head_anchor'][i]-record['feet'][i])*record['scale'] for i in range(2))

def place(record,target):
    old=head_point(record);delta=[target[i]-old[i] for i in range(2)]
    record['feet']=[record['head_anchor'][i]-(target[i]-FEET[i])/record['scale'] for i in range(2)]
    if 'foreground_regions' in record:
        record['foreground_regions']=[[round(x+delta[0]),round(y+delta[1]),w,h] for x,y,w,h in record['foreground_regions']]
    record['registration_target']=list(target)
    record['root_registration_method']='explicit shared body guide on fixed 280x360 canvas; independent of trimmed bounds and foot silhouettes'

def align(data):
    for direction,walk in data['walk'].items():
        for r in walk:
            place(r,TARGET);place(r['outfits']['long_coat'],TARGET)
        for action,frames in data['actions'][direction].items():
            if action=='photo':
                reference=head_point(frames[0]);offset=[TARGET[i]-reference[i] for i in range(2)]
                targets=[tuple(head_point(r)[i]+offset[i] for i in range(2)) for r in frames]
            else:targets=[TARGET]*len(frames)
            for r,target in zip(frames,targets):
                place(r,target);place(r['outfits']['long_coat'],target)
    data['body_registration_guide']={'canvas':[280,360],'root':[140,346],'head_reference':[140,148],
        'walk':'Fixed body placement guide only; actual per-cel head attachments are authored separately. No per-cel shoe-bottom recentering or forced static hair root.',
        'photo':'Preserve authored head bow relative to neutral; both outfits use identical per-cel head coordinates.'}
    return data

def main():
    path=PACK/'authoring.json';data=align(json.loads(path.read_text(encoding='utf-8')));path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Applied explicit shared 2D body registration, including every walk cel and both outfits')
if __name__=='__main__':main()
