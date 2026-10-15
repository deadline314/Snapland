"""Stage the ART-30 single-hair sample, preserving the accepted ART-29 export."""
from pathlib import Path
import os,sys,shutil,json,subprocess,uuid,argparse
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from tools.hero_2d.run_review import _listed_pack_files,_isolated_environment,ENGINE
from tools.godot_entrypoints import run_validated_godot
PROJECT=ROOT/'build/hero-2d-hair-sample'
REVIEW=ROOT/'.review/hero-2d-hair-20261016'
PACK=ROOT/'assets/characters/hero-2d-v1'
FILES=['game/world/hero_2d_library.gd','game/world/hero_2d_pose.gd','game/world/hero_2d_hair_spring.gd','game/world/hero_2d_hair_rig.gd','game/review/hero_2d_sample.gd','game/review/hero_2d_hair_sample.gd','game/review/hero_2d_hair_sample.tscn','game/tests/native_hero_2d_hair_gpu.gd','game/tests/native_hero_2d_hair_gpu.tscn','game/tests/test_hero_2d_hair_spring.gd','game/tests/test_hero_2d_hair_rig.gd']
def prepare():
    if not PROJECT.resolve().is_relative_to((ROOT/'build').resolve()): raise RuntimeError('staging escaped build')
    missing=[name for name in FILES if not (ROOT/name).is_file()]
    if missing: raise SystemExit('Required hair sample source missing: '+', '.join(missing))
    expected=ROOT.resolve()/'build'/'hero-2d-hair-sample'
    if PROJECT.is_symlink() or PROJECT.resolve()!=expected: raise RuntimeError('staging target differs from owned build directory')
    if PROJECT.exists(): shutil.rmtree(PROJECT)
    PROJECT.mkdir(parents=True,exist_ok=True)
    for name in FILES:
        source=ROOT/name
        target=PROJECT/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    destination=PROJECT/'assets/characters/hero-2d-v1';destination.mkdir(parents=True,exist_ok=True)
    for relative,source in _listed_pack_files(PACK,PACK/'manifest.json'):
        target=destination/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    for name in ['manifest.json','hair-rig-windswept.json']: shutil.copy2(PACK/name,destination/name)
    (PROJECT/'project.godot').write_text('[application]\nconfig/name="Snapland Hero 2D Hair Sample"\nrun/main_scene="res://game/review/hero_2d_hair_sample.tscn"\n\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=800\nwindow/stretch/mode="canvas_items"\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
    return PROJECT

def contracts():
    project=prepare();out=REVIEW/'contracts';out.mkdir(parents=True,exist_ok=True);env=_isolated_environment(out,False)
    r=run_validated_godot(project,[ENGINE,'--headless','--path',str(project),'--editor','--import'],env=env,timeout=90)
    log=r.stdout+'\n'+r.stderr;(out/'import.log').write_text(log,encoding='utf-8')
    if r.returncode or 'ERROR:' in log or 'SCRIPT ERROR' in log: print(log[-5000:]);raise SystemExit(1)
    for name in ['spring','rig']:
        r=run_validated_godot(project,[ENGINE,'--headless','--path',str(project),'--script',f'res://game/tests/test_hero_2d_hair_{name}.gd'],env=env,timeout=90)
        log=r.stdout+'\n'+r.stderr;(out/(name+'.log')).write_text(log,encoding='utf-8');print(name,'exit',r.returncode,log[-2600:])
        if r.returncode or 'SCRIPT ERROR' in log or 'ERROR:' in log: raise SystemExit(1)
def checked(project, command, env, timeout, logfile):
    r=run_validated_godot(project,command,env=env,timeout=timeout)
    log=r.stdout+'\n'+r.stderr;logfile.write_text(log,encoding='utf-8')
    if r.returncode or 'ERROR:' in log or 'SCRIPT ERROR' in log: raise SystemExit(log[-4500:])
    return log

def output(tag):
    out=REVIEW/tag
    if out.exists():
        resolved=out.resolve()
        if not resolved.is_relative_to(REVIEW.resolve()) or resolved==REVIEW.resolve(): raise RuntimeError('archive escaped review')
        history=REVIEW/'history'/(tag+'-'+uuid.uuid4().hex[:10]);history.parent.mkdir(parents=True,exist_ok=True);out.rename(history)
    out.mkdir(parents=True,exist_ok=True)
    return out

def native(tag, quarter=False, probe=False, executable=None, movie=True):
    project=prepare();out=output(tag);env=_isolated_environment(out,quarter)
    if not executable: checked(project,[ENGINE,'--headless','--path',str(project),'--editor','--import'],env,120,out/'import.log')
    command=[str(executable) if executable else ENGINE]
    if not executable: command+=['--path',str(project)]
    command+=['--fixed-fps','30','--resolution','1280x800']
    if movie: command+=['--write-movie',str(out/'movie.png')]
    if probe: command+=['--quit-after','30']
    else: command+=['--','--hair-review']
    log=checked(project,command,env,600 if quarter else 240,out/'run.log')
    if not probe:
        audit=json.loads((out/'audit.json').read_text(encoding='utf-8'))
        if audit.get('result')!='PASS_STATE_CHECKS' or not all(v is True for v in audit.get('checks',{}).values()): raise SystemExit('Native hair checks failed: '+str(out/'audit.json'))
        print(tag, audit['result'],json.dumps(audit['checks']), 'tip max',audit['hair_motion']['tip_max_pixels'])
    if movie:
        ffmpeg=shutil.which('ffmpeg')
        if not ffmpeg: raise SystemExit('ffmpeg required')
        target=out/(tag+'.mp4')
        subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-framerate','30','-i',str(out/'movie%08d.png'),'-an','-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(target)],check=True)
        for p in out.glob('movie[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].png'): p.unlink()
        print('video',target)
    return out

def export(smoke=False):
    project=prepare();out=output('export');env=_isolated_environment(out,False)
    template_root=Path(os.environ.get('APPDATA',str(Path.home()/'AppData/Roaming')))
    templates=template_root/'Godot/export_templates/4.7.2.stable'
    if not (templates/'windows_release_x86_64.exe').is_file(): raise SystemExit('Official Godot 4.7.2 Windows templates required')
    env['APPDATA']=str(template_root)
    release=ROOT/'build/hero-2d-hair-sample-release';release.mkdir(parents=True,exist_ok=True)
    executable=release/'Snapland-Hero-2D-Hair-Sample.exe'
    preset=project/'export_presets.cfg'
    preset.write_text('[preset.0]\nname="Snapland Hero 2D Hair Sample"\nplatform="Windows Desktop"\nrunnable=true\nexport_filter="all_resources"\ninclude_filter="assets/characters/hero-2d-v1/*.json,assets/characters/hero-2d-v1/compiled/*.png"\nexclude_filter="game/tests/*"\nscript_export_mode=2\n\n[preset.0.options]\nbinary_format/embed_pck=true\nbinary_format/architecture="x86_64"\napplication/modify_resources=false\n',encoding='utf-8')
    checked(project,[ENGINE,'--headless','--path',str(project),'--editor','--import'],env,120,out/'import.log')
    checked(project,[ENGINE,'--headless','--path',str(project),'--export-release','Snapland Hero 2D Hair Sample',str(executable)],env,300,out/'export.log')
    if not executable.is_file(): raise SystemExit('Export missing')
    print('export',executable)
    if smoke: native('export-startup',probe=True,executable=executable)
    return executable

def gpu_contracts():
    project=prepare();out=output('gpu-contracts');env=_isolated_environment(out,False)
    checked(project,[ENGINE,'--headless','--path',str(project),'--editor','--import'],env,120,out/'import.log')
    checked(project,[ENGINE,'--path',str(project),'--fixed-fps','30','--scene','res://game/tests/native_hero_2d_hair_gpu.tscn'],env,120,out/'run.log')
    print('GPU captures',out)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    group=parser.add_mutually_exclusive_group()
    for flag in ['contracts','gpu-contracts','normal','quarter','probe','export','export-controls','prepare-only']: group.add_argument('--'+flag,action='store_true')
    parser.add_argument('--smoke-export',action='store_true')
    args=parser.parse_args()
    if args.gpu_contracts: gpu_contracts()
    elif args.normal: native('normal')
    elif args.quarter: native('quarter',True)
    elif args.probe: native('probe',probe=True)
    elif args.export: export(args.smoke_export)
    elif args.export_controls: native('export-controls',executable=ROOT/'build/hero-2d-hair-sample-release/Snapland-Hero-2D-Hair-Sample.exe',movie=False)
    elif args.prepare_only: print(prepare())
    else: contracts()
if __name__=='__main__': main()
