"""Build clearly labeled fixed-root cel comparisons, not gameplay recordings."""
from pathlib import Path
import json,subprocess,shutil
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
REVIEW=ROOT/".review/2d-walk-stability-20261016"
def main():
    out=REVIEW/"comparison";out.mkdir(exist_ok=True)
    rows=json.loads((REVIEW/"before/frames.json").read_text(encoding="utf-8"))["frames"]
    groups={}
    for row in rows:groups.setdefault((row["family"],row["view"]),[]).append(row)
    font=ImageFont.truetype(str(ROOT/"assets/fonts/NotoSansCJKtc-Regular.otf"),24)
    small=ImageFont.truetype(str(ROOT/"assets/fonts/NotoSansCJKtc-Regular.otf"),18)
    names={"island-hero":"原島嶼主角","announcer-walk":"NPC 左右行走","announcer-walk_candidate":"NPC 正面候選（未採用）","ticket-walk_candidate":"售票員候選（未採用）"}
    paths=[]
    for case,items in sorted(groups.items()):
        family,view=case;items.sort(key=lambda r:r["frame"])
        for row in items:
            board=Image.new("RGB",(1280,800),(226,235,227));draw=ImageDraw.Draw(board)
            title=names.get(family,family.replace("sample-","主角樣本 "))+" / "+view+f" / 格 {row['frame']}"
            draw.text((25,15),"固定站位圖格對照 · 鏡頭與人物根點不動",font=font,fill="#20373c")
            draw.text((25,52),title,font=small,fill="#20373c")
            for col,tag in enumerate(["before","after"]):
                im=Image.open(REVIEW/("final-frames" if tag=="after" else tag)/row["file"]).convert("RGBA");x=col*640+(640-im.width)//2;y=730-(346 if im.height==360 else 448)
                draw.text((col*640+25,90),"修正前" if col==0 else "候選修正後",font=font,fill="#20373c")
                board.paste(im,(x,y),im)
                draw.line((col*640+320,280,col*640+320,750),fill="#33949c",width=1)
                draw.line((col*640+90,730,col*640+550,730),fill="#33949c",width=1)
                box=(60,60,225,205) if im.height==360 else (65,130,255,295)
                if family.startswith("sample-"):box=(60,70,225,210)
                if "candidate" in family:
                    bounds=im.getchannel("A").getbbox();box=(max(0,bounds[0]-8),max(0,bounds[1]-8),min(im.width,bounds[2]+8),bounds[1]+170)
                crop=im.crop(box)
                ratio=min(330/crop.width,290/crop.height)
                crop=crop.resize((round(crop.width*ratio),round(crop.height*ratio)),Image.Resampling.NEAREST)
                board.paste(crop,(col*640+270,110),crop)
                draw.rectangle((col*640+270,110,col*640+600,400),outline="#33949c",width=1)
            draw.text((25,765),"原生合成圖格的固定位置播放；實際操作與髮尾動態另有原生錄影。",font=small,fill="#20373c")
            target=out/f"{len(paths):04d}.png";board.save(target);paths.append((target,len(items)))
    ffmpeg=shutil.which("ffmpeg")
    if not ffmpeg:raise RuntimeError("ffmpeg required")
    for tag,scale in [("normal",1),("quarter",4)]:
        lines=[]
        for path,count in paths:
            lines += ["file '"+path.as_posix()+"'",f"duration {scale/count:.9f}"]
        lines.append("file '"+paths[-1][0].as_posix()+"'")
        playlist=out/(tag+".txt");playlist.write_text("\n".join(lines)+"\n",encoding="utf-8")
        subprocess.run([ffmpeg,"-hide_banner","-loglevel","error","-y","-f","concat","-safe","0","-i",str(playlist),"-r","30","-an","-c:v","libx264","-crf","18","-pix_fmt","yuv420p","-movflags","+faststart",str(out/(tag+".mp4"))],check=True)
    print("Fixed-root comparison movies:",out,"sequences",len(groups),"source cels",len(paths))
if __name__=="__main__":main()
