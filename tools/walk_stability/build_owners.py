"""Translate existing reviewed head ownership onto the canonical reference head."""
from pathlib import Path
import copy,json,hashlib,argparse
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
def build(raw,registered,output):
    raw=Path(raw);registered=Path(registered);output=Path(output)
    originals=json.loads((ROOT/"assets/characters/avatar-head-material-owners-v1.json").read_text(encoding="utf-8"))["owners"]
    profile=json.loads((output/"manifest.json").read_text(encoding="utf-8"));owners={}
    for key,spec in profile["sequences"].items():
        if not key.startswith("hero/"):continue
        view=key.split("/")[1]
        reference=Image.open(raw/f"island-raw--{view}--00.png").convert("RGBA")
        signature=hashlib.sha256(reference.tobytes()).hexdigest()
        if signature not in originals:raise ValueError("Reference head has no existing reviewed ownership: "+view)
        old=originals[signature];dx,dy=spec["registration_offsets"][0]
        for frame in range(spec["frames"]):
            image=Image.open(registered/f"island-raw--{view}--{frame:02d}.png").convert("RGBA")
            signature=hashlib.sha256(image.tobytes()).hexdigest();entry=copy.deepcopy(old)
            entry["hair_owner_spans"]=[[y+dy,l+dx,r+dx] for y,l,r in old["hair_owner_spans"]]
            entry["body_start_y"]=old["body_start_y"]+dy;entry["poses"]=[f"walk/{view}/{frame}"]
            entry["review"]="Reuses existing reference-cel ownership under the canonical head translation; no new runtime color inference."
            owners[signature]=entry
    if len(owners)!=64:raise ValueError("Expected all 64 immutable runtime source canvases")
    lines=['{', '  "schema_version": 2,', '  "owners": {']
    for i,(key,value) in enumerate(owners.items()):lines.append('    '+json.dumps(key)+': '+json.dumps(value,separators=(',',':'))+(',' if i+1<len(owners) else ''))
    lines+=['  }','}']
    (output/"head-owners.json").write_text('\n'.join(lines)+'\n',encoding="utf-8")
    print("Mapped reviewed ownership onto",len(owners),"actual runtime sources")
if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("raw",type=Path);p.add_argument("registered",type=Path);p.add_argument("output",type=Path);a=p.parse_args();build(a.raw,a.registered,a.output)
