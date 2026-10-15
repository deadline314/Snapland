"""Record real original-island key input at normal or actual quarter simulation speed."""
from pathlib import Path
import argparse,os,sys,json,subprocess,shutil
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT))
from tools.godot_entrypoints import run_validated_godot
from tools.hero_2d.run_review import ENGINE

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--project",type=Path,default=ROOT);p.add_argument("--quarter",action="store_true");args=p.parse_args()
    project=args.project.resolve()
    if not project.is_relative_to(ROOT):raise ValueError("Review project must stay inside the workspace")
    tag="quarter" if args.quarter else "normal";out=ROOT/".review/2d-walk-stability-20261016"/("island-"+tag)
    if out.exists():raise ValueError("Native evidence exists; preserve it and choose a fresh review directory")
    out.mkdir(parents=True);env=os.environ.copy();env["SNAPLAND_SAVE_PATH"]=str(out/"isolated-save.json");env["SNAPLAND_WALK_NATIVE_DIR"]=str(out);env["SNAPLAND_WALK_QUARTER"]="1" if args.quarter else "0"
    command=[ENGINE,"--path",str(project),"--log-file",str(out/"engine.log"),"--rendering-method","forward_plus","--fixed-fps","30","--resolution","1280x720","--write-movie",str(out/"movie.png"),"res://game/tests/native_walk_stability_review.tscn"]
    result=run_validated_godot(project,command,env=env,timeout=600);log=result.stdout+"\n"+result.stderr;(out/"run.log").write_text(log,encoding="utf-8")
    if result.returncode or "ERROR:" in log or "SCRIPT ERROR" in log:raise SystemExit(log[-5000:])
    audit=json.loads((out/"audit.json").read_text(encoding="utf-8"))
    if audit.get("result")!="PASS_NATIVE_ISLAND_INPUT" or len(audit.get("cases",[]))!=13:raise SystemExit("Incomplete actual island input evidence")
    subprocess.run([shutil.which("ffmpeg"),"-hide_banner","-loglevel","error","-y","-framerate","30","-i",str(out/"movie%08d.png"),"-an","-c:v","libx264","-crf","18","-pix_fmt","yuv420p","-movflags","+faststart",str(out/(tag+".mp4"))],check=True)
    for path in out.glob("movie[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].png"):path.unlink()
    print(audit["result"],len(audit["cases"]),"cases",tag,out)
if __name__=="__main__":main()
