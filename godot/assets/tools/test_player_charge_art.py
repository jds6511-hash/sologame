"""외부 LPC 원본을 가진 작업 환경에서 차지 정면 손 접점과 전체 전사 검증을 확인한다."""
import contextlib
import io
import unittest
from unittest.mock import patch

import gen_player_lpc as generator
from lpc_common import LPC_DIR, head_mask


@unittest.skipUnless((LPC_DIR / "body/bodies/male/backslash.png").exists(), "외부 LPC 원본 필요")
class PlayerChargeArtTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contacts = []
        original = generator.draw_weapon

        def record(job, spec, direction, order, frame):
            selected = spec.state == "charge" and direction == "front"
            if selected:
                hand = generator.hand_xy(direction, *generator.CHARGE_FRONT_POSE[order][-2:])
                contact = frame.getpixel(tuple(round(v) for v in hand))
                head = {point: frame.getpixel(point) for point in head_mask(frame)}
            result = original(job, spec, direction, order, frame)
            if selected:
                preserved = all(frame.getpixel(point) == color for point, color in head.items())
                cls.contacts.append((contact, preserved, result))
            return result

        with patch.object(generator, "draw_weapon", side_effect=record), contextlib.redirect_stdout(io.StringIO()):
            cls.total, cls.issues = generator.build_job("warrior", True, pending={})

    def test_warrior_all_frames_pass_asset_validation(self):
        self.assertEqual(self.total, 90)
        self.assertEqual(self.issues, [])

    def test_both_charge_grips_start_inside_skin_and_preserve_the_head(self):
        self.assertEqual(len(self.contacts), 2)
        skin = {(232, 183, 150), (228, 166, 114), (215, 118, 67), (184, 111, 80)}
        for contact, preserved, result in self.contacts:
            self.assertEqual(contact[3], 255)
            self.assertIn(contact[:3], skin, "손 내부 픽셀이 손잡이 기준점이어야 한다")
            self.assertTrue(preserved, "얼굴/머리 원본 픽셀 보존")
            self.assertTrue(result[0])
            self.assertTrue(result[1])


if __name__ == "__main__":
    unittest.main()
