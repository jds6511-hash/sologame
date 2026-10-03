"""전사·궁수 정식 스프라이트의 SpriteFrames 리소스(.tres) 생성 (M3 3-A).

`gen_player_lpc.py` 및 `gen_sword_sweep.py`가 만든 시트를 아틀라스 리전 규약
(`Rect2(c*W, r*H, W, H)`, 행 0 front / 1 side / 2 back)으로 잘라
**AnimatedSprite2D 에 그대로 물릴 수 있는 SpriteFrames** 를 써낸다.

좌측 전용 원화는 <기존 PNG 이름>_left.png의 한 행 시트로 선택 공급한다.
한 상태라도 있으면 전 상태가 필요하며, 모두 규격 검증한 뒤 리소스를 기록한다.
이 검증은 원화의 해부학적 손 일관성을 대신하지 않는다.

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
from PIL import Image

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


def sheet_spec(prefix: str, state: str):
    cols = STATES[state][0]
    if prefix == "player_warrior_v2":
        if state in ("attack", "attack2"):
            return 8, 64, 64, "_sweep"
        if state == "walk":
            return cols, 64, 64, "_carry"
    return cols, FRAME_W, FRAME_H, ""


def validate_left_sheets(prefix: str, states: list[str], folder: Path) -> bool:
    expected = []
    for state in states:
        cols, width, height, suffix = sheet_spec(prefix, state)
        expected.append((folder / f"{prefix}_{state}{suffix}_left.png", (cols * width, height)))
    if not any(path.exists() for path, _ in expected):
        return False
    for path, size in expected:
        if not path.exists():
            raise ValueError(f"왼쪽 전 상태 필요: {path.name} 누락")
        with Image.open(path) as image:
            if image.size != size:
                raise ValueError(f"왼쪽 시트 규격: {path.name} {image.size} != {size}")
    return True


def build(prefix: str, states: list[str], with_left: bool = False) -> str:
    ext: list[str] = []
    sub: list[str] = []
    anims: list[str] = []

    for si, state in enumerate(states):
        cols, fps, loop = STATES[state]
        cols, width, height, suffix = sheet_spec(prefix, state)
        filename = f"{prefix}_{state}{suffix}"
        ext_id = f"tex_{state}"
        ext.append(
            f'[ext_resource type="Texture2D" '
            f'path="{RES_PREFIX}/{filename}.png" id="{ext_id}"]'
        )
        if with_left:
            ext.append(
                f'[ext_resource type="Texture2D" '
                f'path="{RES_PREFIX}/{filename}_left.png" id="{ext_id}_left"]'
            )
        directions = list(DIRECTIONS) + (["left"] if with_left else [])
        for row, direction in enumerate(directions):
            texture_id = ext_id + "_left" if direction == "left" else ext_id
            source_row = 0 if direction == "left" else row
            frame_ids = []
            for col in range(cols):
                aid = f"Atlas_{state}_{direction}{col}"
                sub.append(
                    f'[sub_resource type="AtlasTexture" id="{aid}"]\n'
                    f'atlas = ExtResource("{texture_id}")\n'
                    f"region = Rect2({col * width}, {source_row * height}, {width}, {height})\n"
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
    pending = []
    for prefix, states in JOBS.items():
        missing = [s for s in states if not (OUT_DIR / (
            f"{prefix}_{s}{sheet_spec(prefix, s)[3]}.png"
        )).exists()]
        if missing:
            print(f"[실패] {prefix}: 시트 없음 {missing} - gen_player_lpc.py와 gen_sword_sweep.py 실행 필요")
            return 1
        path = OUT_DIR / f"{prefix}_frames.tres"
        try:
            with_left = validate_left_sheets(prefix, states, OUT_DIR)
        except ValueError as error:
            print(f"[실패] {error}")
            return 1
        pending.append((path, build(prefix, states, with_left)))
        total = sum(8 if prefix == "player_warrior_v2" and s in ("attack", "attack2")
                    else STATES[s][0] for s in states) * (4 if with_left else 3)
        print(f"  {path.name}  애니메이션 {len(states) * (4 if with_left else 3)}개 / 프레임 {total}개")
    # 어느 직업의 입력이라도 잘못됐으면 다른 직업 리소스도 갱신하지 않는다.
    for path, text in pending:
        path.write_text(text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
