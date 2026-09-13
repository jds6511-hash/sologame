"""외부 LPC 궁수의 후면 활 접점과 머리 보존 회귀 검사."""
import contextlib
import io
import unittest
from unittest.mock import patch

import gen_player_lpc as generator
from lpc_common import LPC_DIR, head_mask


@unittest.skipUnless((LPC_DIR / "body/bodies/male/shoot.png").exists(), "외부 LPC 원본 필요")
class PlayerArcherArtTest(unittest.TestCase):
    def test_rear_shots_keep_grip_on_hand_and_preserve_head(self):
        contacts = []
        original = generator.draw_bow

        def record(frame, hand, *args, **kwargs):
            contact = frame.getpixel(tuple(round(v) for v in hand))
            head = {point: frame.getpixel(point) for point in head_mask(frame)}
            result = original(frame, hand, *args, **kwargs)
            if kwargs.get("lock_grip"):
                contacts.append((contact, all(frame.getpixel(p) == c for p, c in head.items()), result))
            return result

        with patch.object(generator, "draw_bow", side_effect=record), contextlib.redirect_stdout(io.StringIO()):
            total, issues = generator.build_job("archer", True, pending={})
        self.assertEqual(total, 90)
        self.assertEqual(issues, [])
        self.assertEqual(len(contacts), 8)
        skin = {(232, 183, 150), (228, 166, 114), (215, 118, 67), (184, 111, 80)}
        for contact, preserved, clear in contacts:
            self.assertEqual(contact[3], 255)
            self.assertIn(contact[:3], skin)
            self.assertTrue(preserved)
            self.assertTrue(clear)


if __name__ == "__main__":
    unittest.main()
