"""Native CPU regression for all stable island idle appearance combinations."""
from pathlib import Path
import sys,tempfile
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT))
from tools.island_avatar.staging import prepare
from tools.hero_2d.run_review import _isolated_environment,ENGINE
from tools.godot_entrypoints import run_validated_godot
def main():
 project=prepare('island-avatar-contracts',['game/tests/test_island_idle_stability.gd'])
 with tempfile.TemporaryDirectory(prefix='snapland-idle-contracts-') as temp:
  env=_isolated_environment(Path(temp),False)
  for args in [['--editor','--import'],['--script','res://game/tests/test_island_idle_stability.gd']]:
   r=run_validated_godot(project,[ENGINE,'--headless','--path',str(project),*args],env=env,timeout=240);log=r.stdout+r.stderr
   if r.returncode or 'ERROR:' in log:raise RuntimeError(log[-3500:])
   print('\n'.join(l for l in log.splitlines() if 'PASS' in l))
if __name__=='__main__':main()
