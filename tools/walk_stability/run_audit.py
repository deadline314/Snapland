"""Export actual island/sample 2D walk frames into an isolated, camera-free pixel audit."""
from pathlib import Path
import argparse,json,re,shutil,sys,os
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from tools.godot_entrypoints import run_validated_godot
from tools.hero_2d.run_review import _isolated_environment,ENGINE,_listed_pack_files
PROJECT=ROOT/"build/walk-stability-audit"
REVIEW=ROOT/".review/2d-walk-stability-20261016"
SOURCES=["game/world/avatar_renderer.gd","game/world/character_animation_library.gd","game/world/hero_2d_library.gd","game/tests/export_walk_stability.gd","game/tests/test_walk_pixel_stability.gd"]
def prepare():
    expected=ROOT.resolve()/"build/walk-stability-audit"
    if PROJECT.is_symlink() or PROJECT.resolve()!=expected:raise ValueError("Unsafe staging target")
    if PROJECT.exists():shutil.rmtree(PROJECT)
    PROJECT.mkdir(parents=True)
    pending=set(SOURCES);copied=set()
    pack=ROOT/"assets/characters/hero-2d-v1"
    pending.add("assets/characters/hero-2d-v1/manifest.json")
    for relative,source in _listed_pack_files(pack,pack/"manifest.json"):
        pending.add(str(source.relative_to(ROOT)).replace("\\","/"))
    while pending:
        name=pending.pop()
        if name in copied:continue
        source=ROOT/name
        if not source.is_file():raise FileNotFoundError(name)
        target=PROJECT/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target);copied.add(name)
        if source.suffix in [".gd",".json"]:
            content=source.read_text(encoding="utf-8")
            pending.update(re.findall(r'res://([^"\s]+\.(?:gd|json|png))',content))
    (PROJECT/"project.godot").write_text('[application]\nconfig/name="Walk pixel audit"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding="utf-8")
    return copied

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--tag",required=True);parser.add_argument("--test",action="store_true");parser.add_argument("--raw",action="store_true");args=parser.parse_args()
    if not re.fullmatch(r"[a-z0-9-]+",args.tag):raise ValueError("Simple audit tag required")
    out=REVIEW/args.tag
    if out.exists():raise ValueError("Audit output already exists; choose another tag")
    out.mkdir(parents=True);copied=prepare();env=_isolated_environment(out,False);env["SNAPLAND_WALK_AUDIT_DIR"]=str(out.resolve());env["SNAPLAND_WALK_AUDIT_RAW"]="1" if args.raw else "0"
    for label,command in [("import",[ENGINE,"--headless","--path",str(PROJECT),"--editor","--import"]),("parse",[ENGINE,"--headless","--path",str(PROJECT),"--check-only","--script","res://game/tests/test_walk_pixel_stability.gd" if args.test else "res://game/tests/export_walk_stability.gd"]),("export",[ENGINE,"--headless","--path",str(PROJECT),"--script","res://game/tests/test_walk_pixel_stability.gd" if args.test else "res://game/tests/export_walk_stability.gd"])]:
        result=run_validated_godot(PROJECT,command,env=env,timeout=240);log=result.stdout+"\n"+result.stderr;(out/(label+".log")).write_text(log,encoding="utf-8")
        if result.returncode or "ERROR:" in log or "SCRIPT ERROR" in log:raise SystemExit(log[-4500:])
        print(label,log[-700:])
    import hashlib
    hashes={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in sorted(copied)}
    (out/"source-hashes.json").write_text(json.dumps(hashes,indent=2)+"\n",encoding="utf-8")
    print("Runtime frames:",out)
if __name__=="__main__":main()
