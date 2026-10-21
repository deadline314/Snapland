"""A reviewed limb correction cannot move the root or alter other body pixels."""
import copy
import unittest
from PIL import Image
from tools.walk_stability.source_repairs import ROOT,load_recipe,apply_repairs

class SourceArtRepairTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe=load_recipe()
        cls.row=cls.recipe['repairs'][0]
        cls.original=Image.open(ROOT/cls.row['reference']).convert('RGBA')

    def test_actual_repair_matches_runtime_atlas_and_preserves_original_parts(self):
        original=self.original.copy();before=original.tobytes()
        fixed=apply_repairs(original,'hero/front_right',3,self.recipe)
        atlas=Image.open(ROOT/'assets/characters/walk-stability-v1/island-raw-front_right.png').convert('RGBA')
        self.assertEqual(fixed.tobytes(),atlas.crop((840,0,1120,360)).tobytes())
        self.assertEqual(original.tobytes(),before,'the immutable original cannot be edited in place')
        self.assertNotEqual(fixed.tobytes(),before)
        x,y,w,h=self.row['region']
        for py in range(360):
            for px in range(280):
                if not (x<=px<x+w and y<=py<y+h):self.assertEqual(fixed.getpixel((px,py)),original.getpixel((px,py)))
        for box in self.row['protected_regions'].values():
            xx,yy,ww,hh=box
            self.assertEqual(fixed.crop((xx,yy,xx+ww,yy+hh)).tobytes(),original.crop((xx,yy,xx+ww,yy+hh)).tobytes())

    def test_changed_opaque_or_even_invisible_alpha_input_needs_new_review(self):
        for point,color in [((110,260),(255,0,255,255)),((0,359),(0,0,0,1))]:
            im=self.original.copy();im.putpixel(point,color)
            with self.assertRaisesRegex(ValueError,'input changed'):apply_repairs(im,'hero/front_right',3,self.recipe)

    def test_changed_patch_or_reference_cannot_reuse_an_approval(self):
        for name in ['patch_png_sha256','reference_png_sha256']:
            r=copy.deepcopy(self.recipe);r['repairs'][0][name]='0'*64
            with self.assertRaisesRegex(ValueError,'source changed'):apply_repairs(self.original,'hero/front_right',3,r)

    def test_patch_cannot_touch_head_feet_or_the_two_correct_camera_hands(self):
        for region in [[68,100,37,47],[68,310,37,47],[120,218,37,47],[-1,218,37,47],[68.5,218,37,47]]:
            r=copy.deepcopy(self.recipe);r['repairs'][0]['region']=region
            with self.assertRaisesRegex(ValueError,'protected|outside|integer'):apply_repairs(self.original,'hero/front_right',3,r)

    def test_duplicate_pose_cannot_silently_overwrite_another_repair(self):
        r=copy.deepcopy(self.recipe);r['repairs'].append(copy.deepcopy(r['repairs'][0]))
        with self.assertRaisesRegex(ValueError,'duplicate'):apply_repairs(self.original,'hero/front_right',3,r)

    def test_other_source_cels_remain_byte_identical(self):
        self.assertEqual(apply_repairs(self.original,'hero/front_right',2,self.recipe).tobytes(),self.original.tobytes())
        self.assertEqual(apply_repairs(self.original,'hero/left',3,self.recipe).tobytes(),self.original.tobytes())

    def test_candidate_or_missing_protection_cannot_be_published(self):
        for key in ['head','feet','camera_hands']:
            r=copy.deepcopy(self.recipe);r['repairs'][0]['protected_regions'].pop(key)
            with self.assertRaisesRegex(ValueError,'must protect'):apply_repairs(self.original,'hero/front_right',3,r)
        r=copy.deepcopy(self.recipe);r['repairs'][0]['review_status']='candidate'
        with self.assertRaisesRegex(ValueError,'needs review'):apply_repairs(self.original,'hero/front_right',3,r)

    def test_changed_output_cannot_be_called_the_reviewed_art(self):
        r=copy.deepcopy(self.recipe);r['repairs'][0]['after_lower_visible_sha256']='0'*64
        with self.assertRaisesRegex(ValueError,'output differs'):apply_repairs(self.original,'hero/front_right',3,r)

if __name__=='__main__':unittest.main()
