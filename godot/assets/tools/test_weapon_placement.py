"""무기 배치 좌표 회귀 검사. PNG 입출력 없이 도형·배치 결과만 검사한다."""

import unittest
from unittest.mock import patch

from PIL import Image

import lpc_common as lpc


class WeaponPlacementTest(unittest.TestCase):
    def test_grip_projection_matches_pillow_rotation_of_a_single_pixel(self):
        marker = Image.new("RGBA", (128, 128))
        marker.putpixel((74, 81), (255, 255, 255, 255))
        rotated, _ = lpc.rotate_pair(marker, Image.new("L", marker.size), 90)
        actual_x, actual_y, _, _ = rotated.getbbox()
        expected = lpc.project_grip((actual_x, actual_y))
        projected = lpc.project_grip((74, 81), tilt_deg=90)
        self.assertAlmostEqual(projected[0], expected[0])
        self.assertAlmostEqual(projected[1], expected[1])

    def test_grip_follows_rotation_before_horizontal_compression(self):
        # 경계 좌표 회전 중심(64,81)의 오른쪽 10px → 90도 회전하면 위로 10px.
        # 이후 가로 1/2 압축은 중심축 위의 점을 움직이지 않아야 한다.
        rotated = lpc.project_grip((73.5, 80.5), tilt_deg=90, narrow=0.5)
        expected = lpc.project_grip((63.5, 70.5))
        self.assertAlmostEqual(rotated[0], expected[0])
        self.assertAlmostEqual(rotated[1], expected[1])

    def test_grip_compression_preserves_body_center_and_vertical_position(self):
        center = lpc.project_grip((63.5, 81))
        normal = lpc.project_grip((74, 81))
        narrowed = lpc.project_grip((74, 81), narrow=0.5)
        self.assertAlmostEqual(narrowed[0] - center[0], (normal[0] - center[0]) * 0.5)
        self.assertEqual(narrowed[1], normal[1])

    def test_grip_rejects_invalid_compression(self):
        with self.assertRaises(ValueError):
            lpc.project_grip((64, 81), narrow=0)

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
