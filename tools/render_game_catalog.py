"""Render design catalogue documentation, without claiming runtime coverage."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
rows = json.loads((ROOT/"design/02-minigames/catalog.json").read_text())["games"]
out=['# 小遊戲設計目錄（128 個候選）','',
     '更新：2026-10-20。以下是**可評估的設計規格**；不是 128 款已實作或好玩的驗收。001–012 有現行單人程式，其他 116 款只在設計。多人、AI 與異空間欄均是目標規格，除非各實作票另有證據。', '',
     '[機器可讀完整規格](catalog.json) · [來源與修訂決策](revision-notes.md) · [六款原型順序](prototype-order.md)', '',
     '每款小惡魔必須延伸該款主要操作。異空間不計基本款數。普通／輔助、AI、P2P 與同機的實作另驗；同機不用私密畫面或強制語音。', '']
zones=json.loads((ROOT/'design/01-park/park.json').read_text())
names={z['id']:z['name'] for z in zones['zones']};names['theatre']='地底惡魔劇場'
for row in rows:
    if (int(row['id'][5:])-1)%12==0 or row['id']=='game-121':
        out += ['## '+names[row['zone']], '']
    out+=['### '+row['id']+' '+row['name'], '',
          '**'+row['core']+'** · '+row['presentation']+' · '+row['revision']+' · '+('首區單人待整票驗收' if row['zone']=='welcome' else '設計候選'),'',
          '| 項目 | 規格 |','|---|---|']
    labels={'action':'操作','goal':'普通目標','choice':'取捨','feedback':'可見回饋','variation':'重玩變化','solo':'單人','multi':'多人','ai':'簡單 AI','demon':'小惡魔','demon_assist_policy':'輔助與惡魔','variant':'異空間','assist':'輔助','test':'原型檢查','revision_reason':'修訂理由'}
    out += [f'| {label} | {row[key]} |' for key,label in labels.items()]
    out += ['']
(ROOT/'design/02-minigames/catalog.md').write_text('\n'.join(out).rstrip()+'\n')
