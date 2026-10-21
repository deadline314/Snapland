"""Independently check waist placement, ground clearance and authored limbs outside reviewed local art corrections.

Head rigidity alone cannot pass this audit: a one-pixel lower-body translation
fails against the original source cel under its explicit root correction.
"""
from pathlib import Path
import argparse,json,hashlib
from PIL import Image,ImageChops
import sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from tools.walk_stability.check_frames import visible
from tools.walk_stability.source_repairs import apply_repairs

def lower_difference(expected,actual,seam):
    if expected.size!=actual.size or not 0<seam<actual.height:raise ValueError("Lower-body comparison must contain real pixels on equal canvases")
    # Godot's texture importer fills RGB in almost-transparent borders (alpha <128).
    # Alpha/silhouette must match everywhere; opaque colors must match exactly.
    a=expected.crop((0,seam,actual.width,actual.height)).get_flattened_data()
    b=actual.crop((0,seam,actual.width,actual.height)).get_flattened_data()
    return sum(p[3]!=q[3] or (p[3]>=128 and p[:3]!=q[:3]) for p,q in zip(a,b))

def bounds(image):
    return image.getchannel("A").point(lambda a:255 if a>=128 else 0).getbbox()

def waist_deltas(images):
    import cv2,numpy as np
    x,y,w,h=130,320,50,40
    def gray(im):return cv2.cvtColor(np.array(visible(im)),cv2.COLOR_RGB2GRAY)
    template=gray(images[0])[y:y+h,x:x+w];results=[]
    for im in images:
        result=cv2.matchTemplate(gray(im)[y-30:y+h+30,x-55:x+w+55],template,cv2.TM_CCOEFF_NORMED)
        _,score,_,loc=cv2.minMaxLoc(result)
        results.append({"delta":[loc[0]-55,loc[1]-30],"score":round(float(score),6)})
    return results

def inspect(raw,registered,pack):
    raw=Path(raw);registered=Path(registered);pack=Path(pack)
    manifest=json.loads((pack/"manifest.json").read_text(encoding="utf-8"));cases=[];errors=[]
    expected={"hero/"+v for v in ["front","front_right","right","back_right","back","back_left","left","front_left"]}
    expected|={"announcer-walk/left","announcer-walk/right","announcer-walk_candidate/front","ticket-walk_candidate/front"}
    sequences=manifest.get("sequences",{})
    if set(sequences)!=expected:raise ValueError("Root audit requires exactly eight hero and four NPC sequences")
    for key,spec in sequences.items():
        count=4 if key.startswith("announcer-walk/") else 8
        if spec.get("frames")!=count or len(spec.get("registration_offsets",[]))!=count or len(spec.get("source_frame_sha256",[]))!=count:raise ValueError("Root audit frame coverage mismatch: "+key)
        if spec.get("canvas")!=([280,360] if key.startswith("hero/") else [320,460]):raise ValueError("Invalid shared canvas: "+key)
        if any(len(delta)!=2 or any(type(v) is not int for v in delta) for delta in spec["registration_offsets"]):raise ValueError("Root corrections require integer x/y pairs")
        seam=spec.get("head_neck_seam_y")
        low,high=(160,210) if key.startswith("hero/") else (240,330)
        if type(seam) is not int or not low<=seam<=high:raise ValueError("Head boundary could bypass lower-body audit: "+key)
        actor,view=key.split("/");family="island-raw" if actor=="hero" else actor
        old=[];new=[];diffs=[];foot=[]
        for i,delta in enumerate(spec["registration_offsets"]):
            name=f"{family}--{view}--{i:02d}.png"
            source=raw/name
            if hashlib.sha256(source.read_bytes()).hexdigest()!=spec["source_frame_sha256"][i]:raise ValueError("Baseline source provenance mismatch: "+name)
            before=Image.open(source).convert("RGBA");after=Image.open(registered/name).convert("RGBA")
            if list(before.size)!=spec["canvas"] or list(after.size)!=spec["canvas"]:raise ValueError("Native canvas dimensions mismatch: "+name)
            expected=Image.new("RGBA",before.size);expected.paste(before,tuple(delta))
            # No whole-cel clipping at canvas edges under the correction.
            original_count=sum(a>=128 for a in before.getchannel("A").get_flattened_data())
            shifted_count=sum(a>=128 for a in expected.getchannel("A").get_flattened_data())
            if original_count!=shifted_count:errors.append("Root correction clips authored pixels: "+name)
            expected=apply_repairs(expected,key,i,{"schema_version":1,"repairs":manifest.get("source_repairs",[])})
            diff=lower_difference(expected,after,spec["head_neck_seam_y"]);diffs.append(diff)
            if diff:errors.append("Authored lower body changed outside root/approved local correction: "+name)
            box=bounds(after);foot.append(box[3])
            if box[0]<=0 or box[1]<=0 or box[2]>=after.width or box[3]>=after.height:errors.append("Canvas edge clipping: "+name)
            old.append(before);new.append(after)
        case={"sequence":key,"lower_changed_pixels":diffs,"foot_bottom_pixels":foot}
        if actor=="announcer-walk":
            before_waist=waist_deltas(old);after_waist=waist_deltas(new)
            case.update(waist_before=before_waist,waist_after=after_waist)
            if any(v["score"]<.90 or abs(v["delta"][0])>8 or abs(v["delta"][1])>8 for v in after_waist):errors.append("Independent waist reference exceeds authored sway bound: "+key)
            if len(set(foot))!=1 or foot[0]!=448:errors.append("NPC ground plane shifts: "+key)
        cases.append(case)
    result={"result":"PASS_ROOT_AND_AUTHORED_LIMBS" if not errors else "FAIL_ROOT_AND_AUTHORED_LIMBS","scope":"Native fixed-canvas output, lower pixels compared with original source under explicit integer root translation and fingerprint-locked local art corrections; independent waist template and shoe bottom checks for accepted NPC walking. Moving shoe midpoint is never treated as actor root.","cases":cases,"errors":errors}
    (registered/"root-stability.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    return result
if __name__=="__main__":
    import sys
    sys.path.insert(0,str(ROOT))
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("raw",type=Path);parser.add_argument("registered",type=Path);parser.add_argument("pack",type=Path);args=parser.parse_args()
    result=inspect(args.raw,args.registered,args.pack);print(result["result"],len(result["cases"]),"sequences",result["errors"][:5]);raise SystemExit(bool(result["errors"]))
