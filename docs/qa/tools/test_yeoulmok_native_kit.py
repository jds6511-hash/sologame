"""실제 배포 후보 PNG/앵커 계약 검사. 저장소 루트와 무관하게 실행한다."""
import json
from pathlib import Path
import sys
import unittest
import math

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "godot/assets/tools"))
from edg32_palette import ALLOWED_RGB_SET

KIT = ROOT / "docs/art/concepts/yeoulmok/native-kit"


class NativeKitTests(unittest.TestCase):
    def test_palette_alpha_and_grid(self):
        image = Image.open(KIT / "environment.png").convert("RGBA")
        self.assertEqual(image.size, (160, 128))
        for r, g, b, a in image.getdata():
            self.assertIn(a, (0, 255))
            if a:
                self.assertIn((r, g, b), ALLOWED_RGB_SET)

    def test_explicit_anchors_and_original_footprints(self):
        manifest = json.loads((KIT / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(set(manifest["buildings"]), {"House", "Workshop"})
        expected = {"House": [52, 400, 40, 24], "Workshop": [228, 404, 40, 20]}
        for name, asset in manifest["buildings"].items():
            self.assertEqual(asset["threshold"], asset["anchor"])
            self.assertEqual(asset["anchor"][1], asset["wall_bottom"])
            ox, oy = asset["origin"]
            ax, ay = asset["anchor"]
            x, y, w, h = asset["footprint"]
            self.assertEqual([ox - ax + x, oy - ay + y, w, h], expected[name])
        self.assertEqual(len(manifest["props"]), 5)
        self.assertEqual(len(manifest["tiles"]), 10)
        image = Image.open(KIT / "environment.png").convert("RGBA")
        for asset in list(manifest["buildings"].values()) + list(manifest["props"].values()) + list(manifest["tiles"].values()):
            x, y, w, h = asset["region"]
            self.assertTrue(0 <= x < x + w <= image.width)
            self.assertTrue(0 <= y < y + h <= image.height)
            self.assertIsNotNone(image.crop((x, y, x+w, y+h)).getbbox())

    def test_visible_walls_and_door_pixels(self):
        manifest = json.loads((KIT / "manifest.json").read_text(encoding="utf-8"))
        image = Image.open(KIT / "environment.png").convert("RGBA")
        for name, entry in manifest["buildings"].items():
            self.assertNotIn("roof_overhang", entry)
            roof = entry["roof_bounds"]
            wall = entry["visible_wall"]
            self.assertLessEqual(roof[1] + roof[3], wall[1])
            self.assertEqual(wall[1] + wall[3], entry["wall_bottom"])
            offset = entry["region"][0]
            for y in range(wall[1], wall[1]+wall[3]):
                self.assertEqual(image.getpixel((offset+12, y))[3], 255)
                self.assertEqual(image.getpixel((offset+51, y))[3], 255)
            # 문 가운데와 계단의 실제 그림 색을 독립적으로 확인한다.
            self.assertEqual(image.getpixel((offset+32, 52))[:3], (184, 111, 80))
            self.assertEqual(image.getpixel((offset+32, 60))[:3], (139, 155, 180))

    def test_ground_variants_are_opaque_and_low_contrast(self):
        manifest = json.loads((KIT / "manifest.json").read_text(encoding="utf-8"))
        image = Image.open(KIT / "environment.png").convert("RGBA")
        for name in ("grass0", "grass1", "dirt0", "dirt1"):
            x, y, w, h = manifest["tiles"][name]["region"]
            pixels = list(image.crop((x, y, x+w, y+h)).getdata())
            self.assertTrue(all(p[3] == 255 for p in pixels))
            self.assertNotIn((255, 255, 255, 255), pixels)
            if name.startswith("grass"):
                self.assertTrue(set(pixels) <= {(62, 137, 72, 255), (38, 92, 66, 255)})
            luma = [0.299*r + 0.587*g + 0.114*b for r, g, b, _ in pixels]
            mean = sum(luma)/len(luma)
            self.assertLessEqual(math.sqrt(sum((v-mean)**2 for v in luma)/len(luma)), 10)
            self.assertLessEqual(max(abs(v-mean) for v in luma), 40)


if __name__ == "__main__":
    unittest.main()
