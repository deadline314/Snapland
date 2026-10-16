"""Recreate normalized source art for the fixed-head idle compiler."""
from pathlib import Path
import argparse,os,sys
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT))
from tools.island_avatar.staging import prepare
from tools.hero_2d.run_review import _isolated_environment,ENGINE
from tools.godot_entrypoints import run_validated_godot
def main():
 p=argparse.ArgumentParser();p.add_argument('output',type=Path);a=p.parse_args();out=a.output.resolve()
 if not out.is_relative_to(ROOT/'.review') or out.exists():raise ValueError('Use a new owned .review source folder')
 out.mkdir(parents=True);project=prepare('island-avatar-source',['game/tests/export_island_idle.gd'])
 env=_isolated_environment(out,False);env['SNAPLAND_IDLE_OUTPUT']=str(out)
 for label,args in [('import',['--editor','--import']),('export',['--script','res://game/tests/export_island_idle.gd'])]:
  r=run_validated_godot(project,[ENGINE,'--headless','--path',str(project),*args],env=env,timeout=120);log=r.stdout+r.stderr;(out/(label+'.log')).write_text(log,encoding='utf-8')
  if r.returncode or 'ERROR:' in log:raise RuntimeError(log[-3000:])
 print('Exported reviewed raw sources to',out)
if __name__=='__main__':main()
