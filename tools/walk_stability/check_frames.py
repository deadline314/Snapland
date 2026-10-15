"""Check actual compositor pixels at a fixed root; no trust in declared anchors."""
from pathlib import Path
import argparse,json
from PIL import Image,ImageChops
VIEWS=["front","front_right","right","back_right","back","back_left","left","front_left"]
def visible(im):
    bg=Image.new("RGBA",im.size,(215,215,215,255));bg.alpha_composite(im.convert("RGBA"))
    return bg.convert("RGB")

def compare(images,box):
    if len(images)<2:raise ValueError("A walk must contain multiple captured cels")
    patches=[visible(im).crop(box) for im in images]
    changes=[]
    for patch in patches:
        diff=ImageChops.difference(patches[0],patch)
        changes.append(sum(any(pixel) for pixel in diff.get_flattened_data()))
    return {"rigid":not any(changes),"changed_pixels_per_frame":changes,"max_changed_pixels":max(changes)}
def inspect(folder):
    folder=Path(folder);rows=json.loads((folder/"frames.json").read_text(encoding="utf-8"))["frames"]
    groups={}
    for row in rows:
        if row["family"] in ["island-raw","island-idle"]:continue
        groups.setdefault((row["family"],row["view"]),[]).append(row)
    expected={("island-hero",v) for v in VIEWS}
    expected|={(f"sample-{outfit}-{hair}-hat{hat}",v) for outfit in ["tide_jacket","long_coat"] for hair in ["windswept","bob"] for hat in [0,1] for v in VIEWS}
    expected|={("announcer-walk",v) for v in ["left","right"]}|{("announcer-walk_candidate","front"),("ticket-walk_candidate","front")}
    if set(groups)!=expected:raise ValueError("Missing, unexpected or duplicated walk sequence coverage")
    cases=[]
    for (family,view),items in sorted(groups.items()):
        items.sort(key=lambda r:r["frame"])
        count=4 if family=="announcer-walk" else 8
        if [r["frame"] for r in items]!=list(range(count)):raise ValueError("Missing/duplicate cels: "+family+"/"+view)
        images=[Image.open(folder/r["file"]).convert("RGBA") for r in items]
        if family.startswith("sample-"):box=(70,75,210,190);seam=206
        elif family=="island-hero":box=(60,65,225,175);seam=206
        elif family=="announcer-walk":box=(65,135,255,290);seam=310
        else:
            bounds=images[0].getchannel("A").getbbox();l,t,r,b=bounds
            seam=round(t+(b-t)*.54);box=(0,0,images[0].width,seam-8)
        result=compare(images,box)
        body_count=len({im.crop((0,seam,im.width,im.height)).tobytes() for im in images})
        result.update(sequence=family+"/"+view,frames=count,head_box=list(box),moving_lower_cels=body_count)
        if body_count<min(4,count):raise ValueError("Whole character frozen instead of fixing registration: "+family+"/"+view)
        cases.append(result)
    result={"scope":"Actual runtime CPU compositor pixels at a fixed actor root. Camera and world movement cannot mask source-cel jitter.","sequences":len(cases),"frames":sum(c["frames"] for c in cases),"unstable_sequences":[c["sequence"] for c in cases if not c["rigid"]],"cases":cases}
    result["result"]="PASS_FIXED_ROOT_PIXELS" if not result["unstable_sequences"] else "FAIL_FIXED_ROOT_PIXELS"
    (folder/"pixel-stability.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    return result
if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("folder",type=Path);p.add_argument("--expect-unstable",action="store_true");a=p.parse_args();r=inspect(a.folder)
    print(r["result"],r["sequences"],"sequences",r["frames"],"actual frames; unstable",len(r["unstable_sequences"]))
    print("Affected families:",sorted({v.rsplit("/",1)[0] for v in r["unstable_sequences"]}))
    if bool(r["unstable_sequences"]) != a.expect_unstable:raise SystemExit(1)
