"""Run the isolated 2D hero pose, compositor and real-pack CPU checks."""
from __future__ import annotations
import os,shutil,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from tools.godot_entrypoints import run_validated_godot
from tools.hero_2d.run_review import prepare_project,_isolated_environment

def main():
    project=prepare_project();output=ROOT/'.review/hero-2d-contract-tests';output.mkdir(parents=True,exist_ok=True)
    engine=os.environ.get('GODOT_BIN',r'C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe')
    env=_isolated_environment(output,False)
    for name in ['pose','library','pack']:
        source=ROOT/f'game/tests/test_hero_2d_{name}.gd';target=project/f'game/tests/{source.name}';shutil.copy2(source,target)
    commands=[('import',[engine,'--headless','--path',str(project),'--editor','--import'])]
    commands += [(name,[engine,'--headless','--path',str(project),'--log-file',str(output/f'{name}-engine.log'),'--script',f'res://game/tests/test_hero_2d_{name}.gd']) for name in ['pose','library','pack']]
    for name,command in commands:
        result=run_validated_godot(project,command,env=env,timeout=120)
        text=result.stdout+'\n'+result.stderr;(output/f'{name}.log').write_text(text,encoding='utf-8')
        if result.returncode or 'SCRIPT ERROR' in text or 'ERROR:' in text:raise SystemExit(f'{name} failed; inspect {output/name}.log\n{text[-1800:]}')
        if name!='import' and 'PASS' not in text:raise SystemExit(f'{name} did not report its assertions')
        print(name+': '+next((line for line in text.splitlines() if line.startswith('PASS')),'imported cleanly'))
if __name__=='__main__':main()
