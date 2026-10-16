"""Build one owned minimal runtime stage, excluding unrelated pending actions."""
from pathlib import Path
import re,shutil,subprocess
ROOT=Path(__file__).resolve().parents[2]
def prepare(name,sources):
 if not re.fullmatch(r'island-avatar-[a-z-]+',name):raise ValueError('Owned stage name required')
 expected=ROOT.resolve()/'build'/name;project=ROOT/'build'/name
 if project.is_symlink() or project.resolve()!=expected:raise ValueError('Stage escaped its named build directory')
 if project.exists():shutil.rmtree(project)
 project.mkdir(parents=True);pending=set(sources);copied=set()
 while pending:
  rel=pending.pop()
  if rel in copied:continue
  file=ROOT/rel
  if not file.is_file():raise FileNotFoundError(rel)
  content=subprocess.check_output(['git','show','HEAD:'+rel],cwd=ROOT) if rel=='assets/characters/complete-animation-regions.json' else file.read_bytes()
  target=project/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(content);copied.add(rel)
  if file.suffix in ['.gd','.json']:pending.update(re.findall(r'res://([^"\s]+\.(?:gd|json|png))',content.decode('utf-8')))
 (project/'project.godot').write_text('[application]\nconfig/name="Island Avatar Contracts"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
 return project
