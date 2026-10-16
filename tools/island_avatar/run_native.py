"""Record the actual island idle/hair integration with isolated saves."""
from pathlib import Path
import argparse,os,sys,json,subprocess,shutil,re
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT))
from tools.godot_entrypoints import run_validated_godot
ENGINE='C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe'
def main():
 p=argparse.ArgumentParser();p.add_argument('--quarter',action='store_true');p.add_argument('--tag',required=True);p.add_argument('--project',type=Path,default=ROOT);a=p.parse_args()
 if not re.fullmatch(r'[a-z][a-z0-9-]{0,79}',a.tag):raise ValueError('Simple review tag required')
 project=a.project.resolve();out=ROOT/'.review/island-idle-hair-20261016'/a.tag
 if not project.is_relative_to(ROOT) or out.is_symlink():raise ValueError('Review project/output escaped workspace')
 if out.exists():raise ValueError('Preserve previous review; choose another tag')
 out.mkdir(parents=True)
 for rel in ['game/tests/native_island_idle_hair.gd','game/tests/native_island_idle_hair.tscn']:
  if project!=ROOT:(project/rel).write_bytes((ROOT/rel).read_bytes())
 env=dict(os.environ,SNAPLAND_SAVE_PATH=str(out/'profile/progress.json'),SNAPLAND_ISLAND_AVATAR_DIR=str(out),SNAPLAND_ISLAND_AVATAR_QUARTER='1' if a.quarter else '0')
 r=run_validated_godot(project,[ENGINE,'--path',str(project),'--rendering-method','forward_plus','--fixed-fps','30','--resolution','1280x720','--log-file',str(out/'engine.log'),'--write-movie',str(out/'movie.png'),'res://game/tests/native_island_idle_hair.tscn'],env=env,timeout=600)
 log=r.stdout+r.stderr;(out/'run.log').write_text(log,encoding='utf-8')
 if r.returncode or 'ERROR:' in log:raise RuntimeError(log[-3500:])
 audit=json.loads((out/'audit.json').read_text());assert audit['result']=='PASS_NATIVE_ISLAND_IDLE' and len(audit['cases'])==8
 subprocess.run([shutil.which('ffmpeg'),'-hide_banner','-loglevel','error','-y','-framerate','30','-i',str(out/'movie%08d.png'),'-an','-c:v','libx264','-crf','24','-pix_fmt','yuv420p','-movflags','+faststart',str(out/'review.mp4')],check=True)
 for f in out.glob('movie????????.png'):f.unlink()
 print(audit['result'],a.tag,'scale',audit['scale'])
if __name__=='__main__':main()
