"""외부 원본 손잡이 추정점과 현재 고정 좌표를 비교한다. PNG·원본 파일은 쓰지 않는다.

추정점은 몸-무기 접촉 픽셀의 평균이므로 실제 손 위치 확정값이 아니다.
차이는 재검수 대상을 찾는 진단값이며 자동 불합격/자동 교정 기준으로 쓰지 않는다.
"""

import math

from gen_player_lpc import BOW_POSE, JOBS, SWORD_POSE, hand_xy
from lpc_common import (
    DIRECTIONS, compose_frame, material_ids, narrow_to_frame, project_grip, rotate_pair,
)


def main() -> None:
    for job, (_, layers, _, states) in JOBS.items():
        materials = material_ids(layers, [state.weapon for state in states if state.weapon])
        differences = []
        missing = []
        for state in states:
            if state.state not in ("attack", "attack2", "charge", "rollshot"):
                continue
            for direction in DIRECTIONS:
                for index in range(len(state.frames)):
                    body, ids, metadata = compose_frame(
                        layers, state, direction, index, materials, weapon_mode="probe"
                    )
                    label = f"{state.state}/{direction}/{index}"
                    if metadata["grip"] is None:
                        missing.append(label)
                        continue
                    tilt = state.tilt[index] if state.tilt else 0.0
                    body, ids = rotate_pair(body, ids, tilt)
                    _, _, narrow = narrow_to_frame(body, ids)
                    source = project_grip(metadata["grip"], tilt, narrow)
                    poses = SWORD_POSE if job == "warrior" else BOW_POSE
                    pose = poses[state.state][index]
                    configured = hand_xy(direction, pose[-2], pose[-1])
                    distance = math.dist(source, configured)
                    differences.append((distance, label, source, configured))
        print(f"[{job}] 추정 가능 {len(differences)}, 추정 불가 {len(missing)}")
        for distance, label, source, configured in sorted(differences, reverse=True)[:8]:
            print(f"  {label}: 원본추정=({source[0]:.1f},{source[1]:.1f}) "
                  f"고정좌표={configured} 차이={distance:.1f}px")
        if missing:
            print("  추정 불가: " + ", ".join(missing))


if __name__ == "__main__":
    main()
