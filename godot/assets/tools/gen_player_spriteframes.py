"""전사·궁수 정식 스프라이트의 SpriteFrames 리소스(.tres) 생성 (M3 3-A).

`gen_player_lpc.py` 가 만든 시트를 `STYLE_GUIDE` 7-1 아틀라스 리전 규약
(`Rect2(c*W, r*H, W, H)`, 행 0 front / 1 side / 2 back)으로 잘라
**AnimatedSprite2D 에 그대로 물릴 수 있는 SpriteFrames** 를 써낸다.

애니메이션 이름은 기존 `player.tscn` 규약을 그대로 계승한다 — `<상태>_<방향>`
(예: `idle_front`, `attack2_side`). 씬 배선은 하지 않는다(pixel-artist 범위 밖):
오케스트레이터가 `Sprite`(AnimatedSprite2D)의 `sprite_frames` 를 여기서 나온
리소스로 교체하면 된다.

사용법:
    python gen_player_spriteframes.py
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from lpc_common import ASSETS_DIR, DIRECTIONS, FRAME_H, FRAME_W  # noqa: E402

OUT_DIR = ASSETS_DIR / "sprites" / "player"
RES_PREFIX = "res://assets/sprites/player"

# 상태 -> (프레임 수, 재생 fps, 루프 여부)
# fps 는 `STYLE_GUIDE` 3-3 애니메이션 프레임 수 기준표를 그대로 따른다.
# hit 은 "0.25초 표시" 규격이라 1프레임 4fps(=0.25초)로 환산한다.
STATES: dict[str, tuple[int, float, bool]] = {
    "idle": (4, 6.0, True),
    "walk": (6, 10.0, True),
    "attack": (4, 12.0, False),
    "attack2": (4, 12.0, False),
    "hit": (1, 4.0, False),
    "death": (4, 8.0, False),
    "dodge": (3, 12.0, False),
    "charge": (2, 8.0, True),
    "cast": (2, 8.0, True),
    "aim": (2, 8.0, True),
    "rollshot": (4, 12.0, False),
}

JOBS = {
    "player_warrior_v2": ["idle", "walk", "attack", "attack2", "hit", "death", "dodge", "charge", "cast"],
    "player_archer": ["idle", "walk", "attack", "aim", "hit", "death", "dodge", "rollshot", "cast"],
}


def build(prefix: str, states: list[str]) -> str:
    ext: list[str] = []
    sub: list[str] = []
    anims: list[str] = []

    for si, state in enumerate(states):
        cols, fps, loop = STATES[state]
        ext_id = f"tex_{state}"
        ext.append(
            f'[ext_resource type="Texture2D" '
            f'path="{RES_PREFIX}/{prefix}_{state}.png" id="{ext_id}"]'
        )
        for row, direction in enumerate(DIRECTIONS):
            frame_ids = []
            for col in range(cols):
                aid = f"Atlas_{state}_{direction}{col}"
                sub.append(
                    f'[sub_resource type="AtlasTexture" id="{aid}"]\n'
                    f'atlas = ExtResource("{ext_id}")\n'
                    f"region = Rect2({col * FRAME_W}, {row * FRAME_H}, {FRAME_W}, {FRAME_H})\n"
                )
                frame_ids.append(f'SubResource("{aid}")')
            anims.append(
                "{\n"
                f'"name": &"{state}_{direction}",\n'
                f'"speed": {fps},\n'
                f'"loop": {str(loop).lower()},\n'
                f'"frames": [{", ".join(frame_ids)}]\n'
                "}"
            )
        del si

    load_steps = len(ext) + len(sub) + 2
    body = [
        f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3]',
        "",
        *ext,
        "",
        *sub,
        "[resource]",
        "animations = [" + ", ".join(anims) + "]",
        "",
    ]
    return "\n".join(body)


def main() -> int:
    for prefix, states in JOBS.items():
        missing = [s for s in states if not (OUT_DIR / f"{prefix}_{s}.png").exists()]
        if missing:
            print(f"[실패] {prefix}: 시트 없음 {missing} — 먼저 gen_player_lpc.py 실행")
            return 1
        path = OUT_DIR / f"{prefix}_frames.tres"
        path.write_text(build(prefix, states), encoding="utf-8")
        total = sum(STATES[s][0] for s in states) * len(DIRECTIONS)
        print(f"  {path.name}  애니메이션 {len(states) * 3}개 / 프레임 {total}개")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
