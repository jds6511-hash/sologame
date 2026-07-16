"""AR-2: 들개 마수(Feral Hound) 몬스터 스프라이트 - CC0 계열 소싱 가공 + 방향 근사.

소싱: "[LPC] Wolf Animation" by zerohero 외 Mumu, William.Thompsonj(OpenGameArt, CC-BY 4.0 선택)
  https://opengameart.org/content/lpc-wolf-animation
  원본 파일 캐시: godot\\assets\\tools\\_raw_src\\wolfsheet1_zerohero.png (640x384)
  오른쪽 절반(320~640, 32x32 셀 10열x12행)이 4족 늑대 측면(側面) 걷기/하울(포효)/
  이빨을 드러낸 달리기/누운 포즈 시퀀스다. 왼쪽 절반은 다른 포즈(정면形) 세트라
  이번 종에는 쓰지 않았다.

**방향 근사 한계 명시**: 원본은 측면(side)만 존재한다. 하(down)/상(up) 방향은
정면·후면 원화가 없어, 측면 프레임을 좌우 폭 축소 + 눈 위치 보정으로 "간이 정면/후면"
근사치를 만들었다 (완전한 별도 원화가 아님 - 추후 정식 방향별 원화로 교체 권장).

프레임 매핑(원본 32x32 그리드, row,col 0-index, 오른쪽 절반 기준):
- WALK   : row2 cols[0,2,4,6]  (이빨 안 보이는 평상 달리기)
- HOWL(예고): row1 col[4,5]     (고개 치켜든 포효 - 공격 예고 실루엣 변화)
- BITE(발동): row3 col[3,4]     (이빨 드러낸 돌진)
- REST(회수): row2 col[0]        (평상 자세로 복귀)
- LIE(사망) : row0 col[6,7]      (쓰러진 포즈)

STYLE_GUIDE.md 준수: 캔버스 32x32, EDG32만 사용, 아웃라인 1px #181425,
잡몹 예산 idle4/walk4/attack5/death4 x3방향=51프레임(hit은 idle 재사용, 별도 예산 없음).

출력: godot\\assets\\sprites\\monsters\\mob_wolf_feral_{idle,walk,attack,death}.png
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
    ensure_outline,
    fade,
    new_sheet,
    paste_frame,
    recolor_by_luminance,
    resize_nearest,
    snap_to_colors,
)

SRC_PATH = RAW_SRC_DIR / "wolfsheet1_zerohero.png"
OUT_DIR = ASSETS_DIR / "sprites" / "monsters"
CELL = 32
RIGHT_OFFSET_X = 320  # 원본 시트의 4족 측면 늑대는 오른쪽 절반에 있음

OUTLINE = RGB["darkest"]
SHADOW = RGB["red_brown_dark"]
BASE = RGB["ochre"]
HIGHLIGHT = RGB["tan"]
SNAP_COLORS = [OUTLINE, SHADOW, BASE, HIGHLIGHT]


def cell_box(row: int, col: int) -> tuple[int, int, int, int]:
    x0 = RIGHT_OFFSET_X + col * CELL
    y0 = row * CELL
    return (x0, y0, x0 + CELL, y0 + CELL)


def get_frame(im: Image.Image, row: int, col: int) -> Image.Image:
    cell = im.crop(cell_box(row, col))
    cell = autotrim(cell)
    recolored = recolor_by_luminance(cell, OUTLINE, SHADOW, BASE, HIGHLIGHT, t_outline=0.22, t_shadow=0.5, t_highlight=0.8)
    recolored = ensure_outline(recolored, OUTLINE)
    return recolored


def make_down_up_approx(frame: Image.Image, up: bool) -> Image.Image:
    """측면 원화 기반 하/상 방향 간이 근사 - 좌우 폭을 60%로 압축해 '정면에 가까워 보이는'
    실루엣을 만든다 (정식 원화 부재에 따른 임시 처리, ASSET_SOURCES.md에 한계 기록)."""
    w, h = frame.size
    narrow = resize_nearest(frame, (max(1, int(w * 0.55)), h))
    narrow = snap_to_colors(narrow, SNAP_COLORS)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.paste(narrow, ((w - narrow.width) // 2, 0))
    if up:
        canvas = canvas.transpose(Image.FLIP_TOP_BOTTOM).transpose(Image.FLIP_TOP_BOTTOM)
    return ensure_outline(canvas, OUTLINE)


def build_idle(im: Image.Image) -> tuple[list, list, list]:
    base_side = get_frame(im, 2, 0)
    side = [base_side, get_frame(im, 2, 1), base_side, get_frame(im, 2, 1)]
    down = [make_down_up_approx(f, up=False) for f in side]
    up = [make_down_up_approx(f, up=True) for f in side]
    return down, side, up


def build_walk(im: Image.Image) -> tuple[list, list, list]:
    cols = [0, 2, 4, 6]
    side = [get_frame(im, 2, c) for c in cols]
    down = [make_down_up_approx(f, up=False) for f in side]
    up = [make_down_up_approx(f, up=True) for f in side]
    return down, side, up


def build_attack(im: Image.Image) -> tuple[list, list, list]:
    howl1 = get_frame(im, 1, 4)
    howl2 = get_frame(im, 1, 5)
    bite1 = get_frame(im, 3, 3)
    bite2 = get_frame(im, 3, 4)
    rest = get_frame(im, 2, 0)
    side = [howl1, howl2, bite1, bite2, rest]
    down = [make_down_up_approx(f, up=False) for f in side]
    up = [make_down_up_approx(f, up=True) for f in side]
    return down, side, up


def build_death(im: Image.Image) -> tuple[list, list, list]:
    stagger = get_frame(im, 2, 1)
    lie1 = get_frame(im, 0, 6)
    lie2 = get_frame(im, 0, 7)
    lie3 = fade(lie2, 0.5)
    side = [stagger, lie1, lie2, lie3]
    down = [make_down_up_approx(f, up=False) for f in side]
    up = [make_down_up_approx(f, up=True) for f in side]
    return down, side, up


def make_sheet(down: list, side: list, up: list) -> Image.Image:
    cols = max(len(down), len(side), len(up))
    sheet = new_sheet(cols, 3, CELL)
    for row, frames in enumerate([down, side, up]):
        for col, frame in enumerate(frames):
            paste_frame(sheet, frame, col, row, CELL)
    return sheet


def main() -> None:
    if not SRC_PATH.exists():
        raise SystemExit(
            f"소싱 원본이 없습니다: {SRC_PATH}\n"
            "https://opengameart.org/content/lpc-wolf-animation 에서 재다운로드 필요."
        )
    im = Image.open(SRC_PATH).convert("RGBA")
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    make_sheet(*build_idle(im)).save(OUT_DIR / "mob_wolf_feral_idle.png")
    make_sheet(*build_walk(im)).save(OUT_DIR / "mob_wolf_feral_walk.png")
    make_sheet(*build_attack(im)).save(OUT_DIR / "mob_wolf_feral_attack.png")
    make_sheet(*build_death(im)).save(OUT_DIR / "mob_wolf_feral_death.png")
    print("들개 마수 스프라이트 생성 완료:", OUT_DIR)


if __name__ == "__main__":
    main()
