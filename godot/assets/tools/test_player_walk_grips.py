"""전사 걷기 18프레임의 검 손잡이가 실제 피부 손 픽셀에 고정되는지 검사한다."""

import unittest

import gen_player_lpc as generator
from lpc_common import (
    DIRECTIONS,
    FRAME_H,
    FRAME_W,
    compose_frame,
    downscale,
    material_ids,
    narrow_to_frame,
    window_origin,
)


class PlayerWalkGripTest(unittest.TestCase):
    def test_walk_grips_are_exact_skin_pixels_in_all_directions(self):
        spec = next(state for state in generator.WARRIOR_STATES if state.state == "walk")
        weapons = [state.weapon for state in generator.WARRIOR_STATES if state.weapon]
        materials = material_ids(generator.WARRIOR_LAYERS, weapons)
        skin_id = materials["skin"]

        for direction in DIRECTIONS:
            for order in range(len(spec.frames)):
                rgba, ids, _ = compose_frame(
                    generator.WARRIOR_LAYERS,
                    spec,
                    direction,
                    order,
                    materials,
                    weapon_mode="probe",
                )
                rgba, ids, _ = narrow_to_frame(rgba, ids)
                _, small_ids = downscale(rgba, ids, materials)
                x0, y0 = window_origin()
                frame_ids = small_ids.crop((x0, y0, x0 + FRAME_W, y0 + FRAME_H))
                pose = generator.sword_pose_for(spec.state, direction, order)
                hand = tuple(round(value) for value in pose[-2:])
                self.assertEqual(
                    frame_ids.getpixel(hand),
                    skin_id,
                    f"walk/{direction}/{order} 손잡이 {hand}가 실제 손 피부 픽셀이어야 한다",
                )


if __name__ == "__main__":
    unittest.main()
