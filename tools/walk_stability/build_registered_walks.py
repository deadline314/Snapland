"""Compile stable 2D walk canvases from an explicitly captured runtime baseline.

No runtime image inference: root corrections and rigid head/neck reference parts
are baked into atlases. Source frames and their provenance remain available.
"""
from pathlib import Path
import argparse,hashlib,json,math
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
def rounded(x):return math.floor(x+.5) if x>=0 else math.ceil(x-.5)
def compile_frames(baseline,output):
    import cv2,numpy as np
    baseline=Path(baseline);output=Path(output);output.mkdir(parents=True,exist_ok=True)
    index=json.loads((baseline/"frames.json").read_text(encoding="utf-8"))["frames"]
    groups={}
    for item in index:
        if item["family"] not in ["island-raw","announcer-walk","announcer-walk_candidate","ticket-walk_candidate"]:continue
        groups.setdefault((item["family"],item["view"]),[]).append(item)
    if len(groups)!=12:raise ValueError("Expected eight hero and four NPC walk sequences")
    old=json.loads((ROOT/"assets/characters/walk-regions.json").read_text(encoding="utf-8"))
    manifest={"schema_version":1,"method":"Fixed root registration followed by a rigid per-heading head/neck reference part. No runtime anatomy inference.","sequences":{}}
    review=[]
    for (family,view),items in sorted(groups.items()):
        items.sort(key=lambda v:v["frame"])
        images=[Image.open(baseline/r["file"]).convert("RGBA") for r in items];w,h=images[0].size
        if family=="island-raw":
            data=old["directions"][view];scale=360/444
            # Fixed ground plane for the whole sequence, not the bottom of each moving shoe.
            fixed_y=rounded(346-max(float(a["feet_y"]) for a in data["anchors"])*scale)
            fixed_x=rounded(140-float(data["anchors"][0]["center_x"])*scale)
            offsets=[[fixed_x-rounded(140-float(a["center_x"])*scale),fixed_y-rounded(346-float(a["feet_y"])*scale)] for a in data["anchors"]]
            scores=[1.0]*len(images);seam={"front":185,"front_right":185,"right":180,"back_right":178,"back":178,"back_left":178,"left":180,"front_left":185}[view]
        else:
            bbox=images[0].getchannel("A").point(lambda a:255 if a>=128 else 0).getbbox()
            l,t,r,b=bbox;seam=rounded(t+(b-t)*.54)
            x=max(10,l-4);y=max(10,t+4);tw=min(w-2*x,r-l+8);th=max(35,seam-y-12)
            def gray(im):
                bg=Image.new("RGBA",im.size,(215,215,215,255));bg.alpha_composite(im);return cv2.cvtColor(np.array(bg.convert("RGB")),cv2.COLOR_RGB2GRAY)
            reference=gray(images[0])[y:y+th,x:x+tw]
            offsets=[];scores=[]
            for im in images:
                full=gray(im);sx=max(0,x-65);sy=max(0,y-65);ex=min(w,x+tw+65);ey=min(h,y+th+65)
                match=cv2.matchTemplate(full[sy:ey,sx:ex],reference,cv2.TM_CCOEFF_NORMED);_,score,_,loc=cv2.minMaxLoc(match)
                if score<.80:raise ValueError(f"Low-confidence head placement requires review: {family}/{view}/{score}")
                # The original NPC y registration already shares a 448px ground plane.
                # Only undo the swinging-shoe x centroid; freezing the head handles head bob.
                offsets.append([x-(sx+loc[0]),0]);scores.append(float(score))
        placed=[]
        for im,delta in zip(images,offsets):
            canvas=Image.new("RGBA",im.size);canvas.paste(im,tuple(delta));placed.append(canvas)
        reference=placed[0].crop((0,0,w,seam));atlas=Image.new("RGBA",(w*len(items),h))
        for i,canvas in enumerate(placed):
            canvas.paste(reference,(0,0));atlas.paste(canvas,(w*i,0))
        assert all(len(delta)==2 for delta in offsets)
        name=f"{family}-{view}.png";atlas.save(output/name)
        key=("hero" if family=="island-raw" else family)+"/"+view
        spec={"source":"res://"+str((output/name).resolve().relative_to(ROOT.resolve())).replace("\\","/"),"canvas":[w,h],"frames":len(items),"head_neck_seam_y":seam,"registration_offsets":offsets,"placement_scores":scores,"source_frame_sha256":[hashlib.sha256((baseline/r["file"]).read_bytes()).hexdigest() for r in items]}
        if family!="island-raw":
            actor,action=family.split("-",1)
            full=json.loads((ROOT/"assets/characters/complete-animation-regions.json").read_text(encoding="utf-8"))["actors"][actor]
            frame0=full[action][view]["frames"][0]
            scale=min(w/full["reference_size"][0],h/full["reference_size"][1])*float(frame0.get("source_scale",1))
            feet=frame0["anchors"]["feet"];head=frame0["anchors"]["head"]
            destination=[rounded(w/2-feet[0]*scale),int(full["feet_baseline"])-rounded(feet[1]*scale)]
            spec["head_anchor"]=[destination[i]+rounded(head[i]*scale)+offsets[0][i] for i in range(2)]
        manifest["sequences"][key]=spec
        review.append({"sequence":key,"offsets":offsets,"min_score":min(scores),"seam":seam})
    (output/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(review,indent=1))
    return manifest
if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("baseline",type=Path);p.add_argument("output",type=Path);a=p.parse_args();compile_frames(a.baseline,a.output)
