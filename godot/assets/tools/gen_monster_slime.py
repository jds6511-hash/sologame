"""AR-2: 균열 점액(Crack Slime) 몬스터 스프라이트 - CC0 계열 소싱 가공.

소싱: "Animated Slime" by Calciumtrice (OpenGameArt, CC-BY 3.0)
  https://opengameart.org/content/animated-slime
  원본 파일 캐시: godot\\assets\\tools\\_raw_src\\slime_calciumtrice.png (32x32, 10열x20행,
  4색 변형 x 5애니메이션(idle/gesture/walk/attack/death) x 10프레임)
  본 스크립트는 blue 색상 행 그룹(5~9행)을 뼈대로 쓰고 EDG32 균열 팔레트로 완전히 재색상화한다.

STYLE_GUIDE.md 준수:
- 1-2장(2026-07-27 스톤샤드식 안 1 개정): 중량 체급 캔버스 **32x32 -> 36x36**(+4/+4). 소싱
  원본 격자는 32x32 그대로 크롭(SRC_CELL)하고, autotrim한 실체를 36 캔버스 하단 중앙에 배치.
- 2장: EDG32 32색만 사용
- 3-1장: 아웃라인 1px #181425
- 3-2-1장: **명암 4단**(recolor_ramp4로 균열 점액 램프 purple→dark_purple→dark_maroon→dark_navy,
  스타일 가이드 3-2-1 예시 그대로) + 발광 코어(cyan)
- 3-3장: 잡몹 예산 - idle4/walk4(CC0 소싱 허용치)/attack5(예고2+발동2+회수1)/death4, 3방향
- CB-0 스펙(m2-monster-spec.md 3-3): 솔로 스폰, "핵" 시각 표현 - 몸통 중심에 발광 코어 추가

방향 처리: 슬라임은 원형 대칭 실루엣이라 3방향(하/측/상) 시각 차이가 없음 -> 3행 모두
동일 프레임을 사용한다 (STYLE_GUIDE 3-3의 "3방향 제작" 포맷은 유지하되 내용은 대칭 단순화,
report에 명시).

출력: godot\\assets\\sprites\\monsters\\mob_slime_crack_{idle,walk,attack,death}.png
      (각 3행 x N열, 36x36 셀) + 각 파일의 4배 확대 프리뷰(_preview_ 접두사)
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
    recolor_ramp4,
    save_with_preview,
)

CELL = 36  # 중량 체급 신규격(STYLE_GUIDE 1-2, 2026-07-27 +4/+4) - 구 32에서 상향(출력 캔버스)
SRC_CELL = 32  # 소싱 원본(slime_calciumtrice.png) 격자 피치 - 원본은 32x32 셀 그대로 유지
TARGET_W = 30  # 실체 목표 폭(STYLE_GUIDE 1-2 중량 실체 약 30x29) - 원본 소형 블롭을 NEAREST 확대
SRC_PATH = RAW_SRC_DIR / "slime_calciumtrice.png"
OUT_DIR = ASSETS_DIR / "sprites" / "monsters"

# 균열 점액 4단 램프(STYLE_GUIDE 3-2-1 예시, EDG32 내 인접 명도)
OUTLINE = RGB["darkest"]
SHADOW2 = RGB["dark_navy"]  # 최암부(그림자2)
SHADOW = RGB["dark_maroon"]  # 그림자1
BASE = RGB["dark_purple"]  # 기본
HIGHLIGHT = RGB["purple"]  # 발광 하이라이트
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
    # 소싱 원본 셀은 32x32이므로 원본 좌표는 32 피치 그대로 크롭한다(신규 캔버스 36과 무관).
    cell = crop_cell(im, col * SRC_CELL, row * SRC_CELL, SRC_CELL, SRC_CELL)
    cell = autotrim(cell)
    # 원본 Calciumtrice 슬라임 실체는 셀 안에서 작게(약 12x10) 그려져 있어, 그대로 쓰면
    # 중량 체급 목표(실체 약 30x29, STYLE_GUIDE 1-2)에 크게 못 미쳐 경량(뿔토끼 18x18)보다도
    # 작아지는 체급 역전이 생긴다. NEAREST로 목표 폭(TARGET_W)까지 확대해 규격을 충족시킨다
    # (재양자화 전 확대라 안티앨리어싱 없음 — 이후 recolor_ramp4가 휘도 4단으로 스냅).
    w, h = cell.size
    factor = TARGET_W / w
    if factor > 1.0:
        cell = cell.resize((round(w * factor), round(h * factor)), Image.NEAREST)
    recolored = recolor_ramp4(cell, OUTLINE, SHADOW2, SHADOW, BASE, HIGHLIGHT)
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

    save_with_preview(build_sheet(im, ROW_IDLE, IDLE_COLS), OUT_DIR / "mob_slime_crack_idle.png")
    save_with_preview(build_sheet(im, ROW_WALK, WALK_COLS), OUT_DIR / "mob_slime_crack_walk.png")
    save_with_preview(build_sheet(im, ROW_ATTACK, ATTACK_COLS), OUT_DIR / "mob_slime_crack_attack.png")
    save_with_preview(build_sheet(im, ROW_DEATH, DEATH_COLS), OUT_DIR / "mob_slime_crack_death.png")
    print("균열 점액 스프라이트 생성 완료(36x36 신규격, 4단 명암):", OUT_DIR)


if __name__ == "__main__":
    main()
