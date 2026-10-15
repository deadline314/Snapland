import json
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
PACK=ROOT/'assets/characters/hero-2d-v1'
DIRECTIONS={'front','front_right','right','back_right','back','back_left','left','front_left'}
class Hero2DAssetsTest(unittest.TestCase):
    def test_complete_2d_source_and_parts_are_registered(self):
        self.assertTrue((PACK/'manifest.json').is_file(),'The original-style 2D hero source/parts pack has not been authored')
        data=json.loads((PACK/'manifest.json').read_text(encoding='utf-8'))
        self.assertEqual(data['production'],'2d-authored-layers')
        self.assertEqual(set(data['directions']),DIRECTIONS)
        self.assertEqual(set(data['outfits']),{'tide_jacket','long_coat'})
        self.assertEqual(set(data['hair']),{'windswept','bob'})
        for direction in DIRECTIONS:
            for action in ['idle','walk','start','stop','turn','photo']:
                frames=data['poses'].get(direction,{}).get(action,[])
                self.assertTrue(frames,f'Missing 2D pose sequence: {direction}/{action}')
                for frame in frames:
                    self.assertIn('head_anchor',frame)
                    self.assertIn('feet',frame)
                    self.assertIn('source',frame)
            for hair in data['hair']:
                self.assertIn(direction,data['hair'][hair],f'Missing {hair}/{direction}')
        self.assertEqual(data.get('character_model_files',[]),[])
    def test_walk_cycle_root_does_not_snap_horizontally_at_loop(self):
        data=json.loads((PACK/'manifest.json').read_text(encoding='utf-8'))
        for direction in DIRECTIONS:
            frames=data['poses'][direction]['walk']
            for outfit in ['tide_jacket','long_coat']:
                points=[f if outfit=='tide_jacket' else f['outfits'][outfit] for f in frames]
                self.assertLessEqual(abs(points[0]['head_anchor'][0]-points[-1]['head_anchor'][0]),4,f'{direction}/{outfit}: source registration drifts across the loop')
    def test_grounded_actions_keep_registration_across_cels_directions_and_outfits(self):
        data=json.loads((PACK/'manifest.json').read_text(encoding='utf-8'))
        for direction in DIRECTIONS:
            for action in ['walk','idle','start','stop','turn']:
                for frame in data['poses'][direction][action]:
                    for body in [frame,frame['outfits']['long_coat']]:
                        self.assertLessEqual(abs(body.get('body_guide',body['head_anchor'])[0]-140),1,f'{direction}/{action}: horizontal registration drift')
                        self.assertLessEqual(abs(body.get('body_guide',body['head_anchor'])[1]-148),1,f'{direction}/{action}: vertical registration drift')
            for frame in data['poses'][direction]['photo']:
                for axis in [0,1]:
                    self.assertLessEqual(abs(frame['head_anchor'][axis]-frame['outfits']['long_coat']['head_anchor'][axis]),1,f'{direction}/photo: outfit changes head position')
    def test_hair_attachment_follows_actual_walk_head_pixels(self):
        data=json.loads((PACK/'manifest.json').read_text(encoding='utf-8'))
        # Reviewed head feature translations in the unchanged source: +1 x in front cel 1;
        # +2 x/+2 y in left cel 1. A fixed guide [140,148] cannot follow either.
        self.assertEqual(data['poses']['front']['walk'][1]['head_anchor'],[141,148])
        self.assertEqual(data['poses']['left']['walk'][1]['head_anchor'],[142,150])
        markers=json.loads((PACK/'head-attachments.json').read_text(encoding='utf-8'))
        import hashlib
        for name,expected in markers['unchanged_body_sha256'].items():
            self.assertEqual(hashlib.sha256((PACK/name).read_bytes()).hexdigest(),expected,'attachment correction must not move or reshape body pixels')
        for direction in DIRECTIONS:
            for outfit in ['tide_jacket','long_coat']:
                for frame,point in zip(data['poses'][direction]['walk'],markers['walk'][direction][outfit]):
                    entry=frame if outfit=='tide_jacket' else frame['outfits'][outfit]
                    self.assertEqual(entry['head_anchor'],point['attachment'])
                    self.assertEqual(entry['body_guide'],[140,148])

    def test_pack_files_exist_and_stay_2d(self):
        self.assertTrue((PACK/'manifest.json').is_file(),'2D pack missing')
        data=json.loads((PACK/'manifest.json').read_text(encoding='utf-8'))
        for relative in data['files']:
            self.assertNotIn(Path(relative).suffix.lower(),{'.blend','.glb','.gltf','.fbx'})
            self.assertTrue((PACK/relative).is_file(),relative)
if __name__=='__main__':unittest.main()
