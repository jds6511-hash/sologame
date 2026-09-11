"""무기 배치 좌표 회귀 검사. PNG 입출력 없이 도형·배치 결과만 검사한다."""

import unittest
from unittest.mock import patch

import lpc_common as lpc


class WeaponPlacementTest(unittest.TestCase):
    def test_bow_limb_passes_through_the_requested_grip(self):
        for bulge in (-1.0, 1.0):
            strokes = lpc._bow_strokes((18.0, 20.0), bulge, 6, 1.0, False)
            self.assertIn((18, 20), strokes[0][0], "활대 손잡이가 실제 손 좌표를 지나야 한다")

    def test_bow_reports_final_hand_after_head_avoidance(self):
        placed = []
        with patch.object(lpc, "_stamp"), patch.object(
            lpc, "_covers", side_effect=[True, False]
        ):
            self.assertTrue(lpc.draw_bow(None, (18.0, 20.0), 1, 4, 0, False, {(0, 0)}, placed))
        self.assertEqual(len(placed), 1)
        self.assertNotEqual(placed[0], (18.0, 20.0), "이동 전 좌표로 연결을 검증하면 안 된다")

    def test_sword_reports_the_grip_that_was_actually_stamped(self):
        placed = []
        with patch.object(lpc, "_stamp") as stamp, patch.object(
            lpc, "_covers", side_effect=[True, False]
        ):
            length, clear = lpc.draw_sword(None, (18.0, 20.0), (0, 1), 10, {(0, 0)}, placed)
        self.assertTrue(clear)
        self.assertGreater(length, 0)
        actual_grip = stamp.call_args.args[1][0][0][0]
        self.assertEqual(actual_grip, tuple(round(v) for v in placed[0]))


if __name__ == "__main__":
    unittest.main()
