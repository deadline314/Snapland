import copy,json,unittest
from pathlib import Path
from PIL import Image
from tools.island_avatar.check_idle import validate,validate_cycle
from tools.island_avatar.register_standing import validate_placement,visible_bounds
ROOT=Path(__file__).resolve().parents[1]/'assets/characters/idle-stability-v1'
class IdleAssetTests(unittest.TestCase):
 def setUp(self):
  self.spec=json.loads((ROOT/'manifest.json').read_text())['sequences']['hero-idle/front']
  atlas=Image.open(ROOT/'front.png').convert('RGBA');self.images=[atlas.crop((280*i,0,280*(i+1),360)) for i in range(8)]
 def test_all_eight_sources(self):self.assertEqual(validate(ROOT),36)
 def test_one_pixel_head_change_rejected(self):
  self.images[1].putpixel((140,110),(255,0,255,255))
  with self.assertRaisesRegex(ValueError,'Head'):validate_cycle(self.images,self.spec)
 def test_nonblink_eye_change_rejected(self):
  x,y,w,h=self.spec['eye_regions'][0];self.images[1].putpixel((x+2,y+2),(255,0,255,255))
  with self.assertRaisesRegex(ValueError,'eyes'):validate_cycle(self.images,self.spec)
 def test_missing_blink_rejected(self):
  self.images[self.spec['blink_frame']]=self.images[0].copy()
  with self.assertRaisesRegex(ValueError,'Blink'):validate_cycle(self.images,self.spec)
 def test_one_pixel_leg_shift_rejected(self):
  image=self.images[1];part=image.crop((0,270,280,360));image.paste((0,0,0,0),(0,270,280,360));image.paste(part,(1,270))
  with self.assertRaisesRegex(ValueError,'legs'):validate_cycle(self.images,self.spec)
 def test_old_oversized_chin_rejected(self):
  for im in self.images:im.paste((253,187,123,255),(120,190,160,210))
  with self.assertRaisesRegex(ValueError,'portrait'):validate_cycle(self.images,self.spec)
 def test_semivisible_foot_counts_in_ground(self):
  im=Image.new("RGBA",(10,20));im.putpixel((5,10),(100,80,60,255));im.putpixel((5,18),(100,80,60,110))
  self.assertEqual(visible_bounds(im)[3],19)
  with self.assertRaisesRegex(ValueError,"clipped"):validate_placement(visible_bounds(im),(0,2),(10,20))
 def test_clipped_standing_placement_rejected(self):
  for delta in [(-1,0),(0,-1),(272,0),(0,352)]:
   with self.assertRaisesRegex(ValueError,'clipped'):validate_placement((0,0,10,10),delta)
  self.assertEqual(validate_placement((0,0,10,10),(10,10)),(10,10,20,20))
if __name__=='__main__':unittest.main()
