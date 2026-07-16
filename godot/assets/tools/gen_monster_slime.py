"""AR-2: 균열 점액(Crack Slime) 몬스터 스프라이트 - CC0 계열 소싱 가공.

소싱: "Animated Slime" by Calciumtrice (OpenGameArt, CC-BY 3.0)
  https://opengameart.org/content/animated-slime
  원본 파일 캐시: godot\\assets\\tools\\_raw_src\\slime_calciumtrice.png (32x32, 10열x20행,
  4색 변형 x 5애니메이션(idle/gesture/walk/attack/death) x 10프레임)
  본 스크립트는 blue 색상 행 그룹(5~9행)을 뼈대로 쓰고 EDG32 균열 팔레트로 완전히 재색상화한다.

STYLE_GUIDE.md 준수:
- 1-2장: 소형 몬스터 캔버스 32x32
- 2장: EDG32 32색만 사용 (recolor_by_luminance로 4단 치환)
- 3-1장: 아웃라인 1px #181425
- 3-3장: 잡몹 예산 - idle4/walk4(CC0 소싱 허용치)/attack5(예고2+발동2+회수1)/death4, 3방향
- CB-0 스펙(m2-monster-spec.md 3-3): 솔로 스폰, "핵" 시각 표현 - 몸통 중심에 발광 코어 추가

방향 처리: 슬라임은 원형 대칭 실루엣이라 3방향(하/측/상) 시각 차이가 없음 -> 3행 모두
동일 프레임을 사용한다 (STYLE_GUIDE 3-3의 "3방향 제작" 포맷은 유지하되 내용은 대칭 단순화,
report에 명시).

출력: godot\\assets\\sprites\\monsters\\mob_slime_crack_{idle,walk,attack,death}.png
      (각 3행 x N열, 32x32 셀)
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from edg32_palette import RGB
from sprite_source_common import (
    RAW_SRC_DIR,
    ASSETS_DIR,
    autotrim,
    crop_cell,
    ensure_outline,
    new_sheet,
    paste_frame,
    recolor_by_luminance,
)

CELL = 32
SRC_PATH = RAW_SRC_DIR / "slime_calciumtrice.png"
OUT_DIR = ASSETS_DIR / "sprites" / "monsters"

OUTLINE = RGB["darkest"]
SHADOW = RGB["dark_maroon"]
BASE = RGB["dark_purple"]
HIGHLIGHT = RGB["purple"]
CORE = RGB["cyan"]

# blue 색상 그룹 = 절대 행 5~9 (idle, gesture, walk, attack, death 순)
ROW_IDLE = 5
ROW_WALK = 7
ROW_ATTACK = 8
ROW_DEATH = 9

# 각 애니메이션에서 뽑을 열(0~9, 10프레임 중 샘플링)
IDLE_COLS = [0, 3, 6, 8]
WALK_COLS = [0, 2, 5, 7]
ATTACK_COLS = [0, 2, 4, 6, 9]  # 예고2+발동2+회수1 근사
DEATH_COLS = [0, 3, 6, 9]


def get_frame(im: Image.Image, row: int, col: int) -> Image.Image:
    cell = crop_cell(im, col * CELL, row * CELL, CELL, CELL)
    cell = autotrim(cell)
    recolored = recolor_by_luminance(cell, OUTLINE, SHADOW, BASE, HIGHLIGHT)
    recolored = ensure_outline(recolored, OUTLINE)
    add_core(recolored)
    return recolored


def add_core(frame: Image.Image) -> None:
    """몸통 중심에 2x2 발광 코어(핵)를 찍는다 (CB-0 스펙 '핵' 시각 표현)."""
    w, h = frame.size
    cx, cy = w // 2, h // 2 + 2
    px = frame.load()
    for dx in (-1, 0):
        for dy in (-1, 0):
            x, y = cx + dx, cy + dy
            if 0 <= x < w and 0 <= y < h and px[x, y][3] > 0:
                px[x, y] = (*CORE, 255)


def build_sheet(im: Image.Image, row: int, cols: list[int]) -> Image.Image:
    sheet = new_sheet(len(cols), 3, CELL)
    for direction_row in range(3):  # 하/측/상 동일 프레임 (대칭 단순화)
        for i, c in enumerate(cols):
            frame = get_frame(im, row, c)
            paste_frame(sheet, frame, i, direction_row, CELL)
    return sheet


def main() -> None:
    if not SRC_PATH.exists():
        raise SystemExit(
            f"소싱 원본이 없습니다: {SRC_PATH}\n"
            "https://opengameart.org/content/animated-slime 에서 재다운로드 필요."
        )
    im = Image.open(SRC_PATH).convert("RGBA")
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    build_sheet(im, ROW_IDLE, IDLE_COLS).save(OUT_DIR / "mob_slime_crack_idle.png")
    build_sheet(im, ROW_WALK, WALK_COLS).save(OUT_DIR / "mob_slime_crack_walk.png")
    build_sheet(im, ROW_ATTACK, ATTACK_COLS).save(OUT_DIR / "mob_slime_crack_attack.png")
    build_sheet(im, ROW_DEATH, DEATH_COLS).save(OUT_DIR / "mob_slime_crack_death.png")
    print("균열 점액 스프라이트 생성 완료:", OUT_DIR)


if __name__ == "__main__":
    main()
