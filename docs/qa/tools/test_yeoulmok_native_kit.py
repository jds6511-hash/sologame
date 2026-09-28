"""실제 배포 후보 PNG/앵커 계약 검사. 저장소 루트와 무관하게 실행한다."""
import json
from pathlib import Path
import sys
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "godot/assets/tools"))
from edg32_palette import ALLOWED_RGB_SET

KIT = ROOT / "docs/art/concepts/yeoulmok/native-kit"


class NativeKitTests(unittest.TestCase):
    def test_palette_alpha_and_grid(self):
        image = Image.open(KIT / "environment.png").convert("RGBA")
        self.assertEqual(image.size, (160, 96))
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
        image = Image.open(KIT / "environment.png").convert("RGBA")
        for asset in list(manifest["buildings"].values()) + list(manifest["props"].values()):
            x, y, w, h = asset["region"]
            self.assertTrue(0 <= x < x + w <= image.width)
            self.assertTrue(0 <= y < y + h <= image.height)
            self.assertIsNotNone(image.crop((x, y, x+w, y+h)).getbbox())


if __name__ == "__main__":
    unittest.main()
