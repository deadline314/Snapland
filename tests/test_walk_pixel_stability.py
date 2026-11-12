"""Use image content, not self-reported pivots, to reject walking head jitter."""
import json
import unittest
import tempfile
from pathlib import Path
from PIL import Image,ImageChops
ROOT=Path(__file__).resolve().parents[1]
PACK=ROOT/"assets/characters/hero-2d-v1"


def region(pack,frame):
    x,y,w,h=frame["region"]
    return Image.open(pack/frame["source"]).convert("RGBA").crop((x,y,x+w,y+h))


class WalkPixelStabilityTest(unittest.TestCase):
    def test_walk_rebuild_rejects_unbound_baseline_before_replacing_pixels(self):
        from tools.walk_stability import build_registered_walks
        views=["front","front_right","right","back_right","back","back_left","left","front_left"]
        groups=[("island-raw",view) for view in views]+[("announcer-walk","left"),("announcer-walk","right"),("announcer-walk_candidate","front"),("ticket-walk_candidate","front")]
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            baseline=root/"baseline"
            baseline.mkdir()
            output=root/"output"
            output.mkdir()
            previous=output/"announcer-walk-left.png"
            previous.write_bytes(b"approved previous atlas")
            for invalid in [None,{}, {"frame":{},"image_sha256":"bad"}, {"frame":{},"image_sha256":"0"*64}]:
                frames=[{"family":family,"view":view,"frame":0,"file":"uncaptured.png","source_binding":invalid} for family,view in groups]
                (baseline/"frames.json").write_text(json.dumps({"frames":frames}),encoding="utf-8")
                with self.assertRaisesRegex(ValueError,"Recapture source-bound native baseline"):
                    build_registered_walks.compile_frames(baseline,output)
                self.assertEqual(b"approved previous atlas",previous.read_bytes())
                self.assertEqual([previous],list(output.iterdir()))

    def test_walk_head_pixels_stay_rigid_while_limbs_animate(self):
        manifest=json.loads((PACK/"manifest.json").read_text(encoding="utf-8"))
        for view in manifest["directions"]:
            for outfit in ["tide_jacket","long_coat"]:
                images=[]
                for frame in manifest["poses"][view]["walk"]:
                    images.append(region(PACK,frame if outfit=="tide_jacket" else frame["outfits"][outfit]))
                reference=images[0].crop((90,100,190,190)).convert("RGB")
                for index,image in enumerate(images[1:],1):
                    diff=ImageChops.difference(reference,image.crop((90,100,190,190)).convert("RGB"))
                    self.assertIsNone(diff.getbbox(),f"{view}/{outfit}/{index}: actual head pixels changed at fixed actor root")
                self.assertGreaterEqual(len({im.crop((0,206,280,360)).tobytes() for im in images}),7,"walking cannot pass by freezing the whole body")

    def test_lower_body_one_pixel_shift_fails_even_with_a_rigid_head(self):
        from tools.walk_stability.check_registration import lower_difference
        source=Image.new("RGBA",(50,80));source.paste((210,120,30,255),(10,40,35,76))
        shifted=Image.new("RGBA",source.size);shifted.paste(source,(1,0))
        self.assertEqual(lower_difference(source,source,30),0)
        self.assertGreater(lower_difference(source,shifted,30),0)

    def test_invisible_rgb_does_not_count_as_visible_jitter(self):
        from tools.walk_stability.check_frames import compare
        a=Image.new("RGBA",(10,10),(255,0,0,0));b=Image.new("RGBA",(10,10),(0,255,0,0))
        self.assertTrue(compare([a,b],(0,0,10,10))["rigid"])

    def test_head_boundary_cannot_hide_the_whole_lower_body(self):
        from tools.walk_stability.check_registration import lower_difference
        a=Image.new("RGBA",(50,80))
        for seam in [0,80,81]:
            with self.assertRaises(ValueError):lower_difference(a,a,seam)
        with self.assertRaises(ValueError):lower_difference(a,Image.new("RGBA",(51,80)),30)

    def test_empty_registration_manifest_cannot_report_pass(self):
        from tools.walk_stability.check_registration import inspect
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp);(folder/"manifest.json").write_text('{"sequences":{}}',encoding="utf-8")
            with self.assertRaises(ValueError):inspect(folder,folder,folder)

    def test_one_pixel_displacement_is_detectable(self):
        source=Image.new("RGB",(32,32),"black")
        for x in range(10,18):
            for y in range(8,22):source.putpixel((x,y),(220,125,80))
        shifted=Image.new("RGB",source.size,"black");shifted.paste(source,(1,0))
        self.assertIsNotNone(ImageChops.difference(source,shifted).getbbox())
