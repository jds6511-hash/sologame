"""무기 회전 여백·손 접점·대기 복귀를 출력 픽셀에서 검증한다."""
import unittest
from PIL import Image
import gen_sword_sweep as sweep
from lpc_common import palette_violations


class SwordSweepTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bodies = sweep.load_bodies()
        cls.sheets = sweep.build_sheets(cls.bodies)

    def test_return_pose_is_exact_padded_idle_in_every_direction(self):
        with Image.open(sweep.base.OUT_DIR / "player_warrior_v2_idle.png") as idle:
            for sheet in self.sheets.values():
                for row in range(3):
                    for index in (0, 7):
                        frame = sheet.crop((index*64+18, row*64+14, index*64+46, row*64+50))
                        self.assertEqual(frame.tobytes(), idle.crop((0, row*36, 28, row*36+36)).tobytes())

    def test_active_frames_differ_and_blade_is_not_clipped(self):
        for sheet in self.sheets.values():
            self.assertFalse(palette_violations(sheet))
            for row in range(3):
                active = [sheet.crop((i*64, row*64, (i+1)*64, (row+1)*64)) for i in (2, 3, 4)]
                self.assertEqual(len({frame.tobytes() for frame in active}), 3)
                for frame in active:
                    x0, y0, x1, y1 = frame.getbbox()
                    self.assertTrue(0 < x0 < x1 < 64 and 0 < y0 < y1 < 64)

    def test_weapon_grip_is_same_skin_pixel_as_body(self):
        for state, sheet in self.sheets.items():
            for row, direction in enumerate(sweep.DIRECTIONS):
                for index in range(1, 7):
                    order = sweep.BODY_ORDERS[index]
                    if state == "attack2" and direction == "back" and order == 2:
                        order = 1
                    body = self.bodies[(state, direction, order)]
                    x, y = sweep.hand_pixel(body, sweep.HANDS[(state, direction)][order])
                    self.assertEqual(sheet.getpixel((index*64+x+18, row*64+y+14)), body.getpixel((x,y)))


if __name__ == "__main__":
    unittest.main()
