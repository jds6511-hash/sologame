"""AR-2: 뿔토끼(Horned Rabbit) 몬스터 스프라이트 - CC0 계열 소싱 가공 + 합성 보완.

소싱: "Bunny Rabbit LPC style for PixelFarm" by Ablu 외(OpenGameArt, CC-BY 3.0 선택)
  https://opengameart.org/content/bunny-rabbit-lpc-style-for-pixelfarm
  원본 파일 캐시: godot\\assets\\tools\\_raw_src\\bunnysheet5_ablu.png
  원본은 하/상/측 3방향 각각 "정지 포즈 2종 + 홉(이동) 8프레임" 세트를 담고 있어
  idle/walk는 그대로 프레임을 뽑아 쓴다. 원본에 공격/사망 모션이 없어(호핑·풀뜯기뿐),
  근접 스윙(박치기)·사망은 소싱 프레임을 기반으로 Pillow 변형(스케일/회전/페이드)으로
  합성했다 - m2-monster-spec.md 3-1장 "근접 스윙(박치기)" 행동에 대응.

STYLE_GUIDE.md 준수:
- 1-2장(2026-07-27 스톤샤드식 안 1 개정): 경량 체급 캔버스 **16x16 -> 20x20**로 상향(+4/+4),
  실체 약 18x15. 원본 크롭 bbox를 autotrim한 뒤 최대 변 길이가 18px를 넘지 않도록 축소 비율을
  프레임마다 적응적으로 계산해(`TARGET_MAX_DIM`) NEAREST 리사이즈 - 팔레트 재양자화 전에
  수행하므로 안티앨리어싱이 생기지 않는다.
- 2장: EDG32만 사용 (recolor_by_luminance)
- 3-1장: 아웃라인 1px #181425
- 3-2-1장(명암 단수): 최소 프레임(20x20)이라 4단 램프가 뭉개지므로 **3단으로 절제**한다
  (스타일 가이드가 명시 허용한 소형 프레임 예외 — recolor_by_luminance의 shadow/base/highlight
  3단 유지). 나머지 3종(전사·들개·점액)은 4단.
- 3-3장: 잡몹 예산 idle4/walk4/attack5/death4 x 3방향 = 51프레임 (hit은 idle 프레임 재사용,
  별도 에셋 불필요 - STYLE_GUIDE 3-3 예산 공식에도 hit 미포함)
- 6-3장: 종 식별 실루엣 요소 - 정수리에 뿔(각) 추가 ("뿔토끼" 정체성, m2-monster-spec 실루엣 힌트).
  20x20으로 축소되며 뿔 크기도 비례 축소(1~2px).

출력: godot\\assets\\sprites\\monsters\\mob_rabbit_horned_{idle,walk,attack,death}.png
      (20x20 셀) + 각 파일의 4배 확대 프리뷰(_preview_ 접두사)
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
    save_with_preview,
    snap_to_colors,
)

SRC_PATH = RAW_SRC_DIR / "bunnysheet5_ablu.png"
OUT_DIR = ASSETS_DIR / "sprites" / "monsters"

OUTLINE = RGB["darkest"]
SHADOW = RGB["light_blue_gray"]
BASE = RGB["sand_cream"]
HIGHLIGHT = RGB["white"]
HORN = RGB["tan"]
DEATH_SNAP_COLORS = [OUTLINE, SHADOW, BASE, HIGHLIGHT, HORN]

# bbox 자동 검출 결과(alpha 기준, sprite_extract 1회성 분석) - (x0,y0,x1,y1)
DOWN_EXTRA = [(62, 15, 81, 43), (138, 15, 159, 43)]
DOWN_MAIN = [(29, 47, 48, 78), (62, 47, 81, 78), (103, 47, 122, 78), (139, 47, 158, 78),
             (179, 47, 198, 78), (211, 47, 230, 78), (245, 47, 264, 78), (278, 47, 297, 78)]
UP_EXTRA = [(63, 95, 84, 125), (142, 95, 161, 125)]
UP_MAIN = [(31, 135, 50, 170), (64, 135, 83, 170), (104, 135, 123, 170), (143, 135, 162, 170),
           (182, 135, 201, 170), (213, 135, 232, 170), (248, 135, 267, 170), (281, 135, 300, 170)]
SIDE_A_EXTRA = [(59, 179, 85, 207), (135, 179, 164, 207)]
SIDE_A_MAIN = [(28, 216, 53, 245), (59, 216, 85, 245), (91, 216, 124, 245), (134, 216, 163, 245),
               (179, 216, 205, 245), (210, 216, 237, 245), (243, 216, 271, 245), (275, 216, 303, 245)]
SIDE_B_EXTRA = [(59, 255, 85, 284), (137, 255, 166, 284)]
SIDE_B_MAIN = [(27, 288, 52, 316), (61, 288, 87, 316), (96, 288, 129, 316), (138, 288, 167, 316),
               (178, 288, 204, 316), (208, 288, 235, 316), (240, 288, 268, 316), (275, 288, 303, 316)]

CELL = 20  # 경량 체급 신규격(STYLE_GUIDE 1-2, 2026-07-27 스톤샤드식 +4/+4) - 구 16에서 상향
TARGET_MAX_DIM = 18  # 실체 목표 최대 변 길이(가로/세로 중 큰 값) - 20 캔버스에 여백 확보(실체 약 18x15)


def add_horn(frame: Image.Image) -> None:
    """머리 위쪽에 작은 뿔(1~2px)을 그려 '뿔토끼' 실루엣을 만든다 (16x16 축소에 맞춰 비례 축소)."""
    w, h = frame.size
    cx = w // 2
    px = frame.load()
    tip_y = 0
    for y in range(h):
        row_has = any(frame.getpixel((x, y))[3] > 0 for x in range(w))
        if row_has:
            tip_y = y
            break
    for dy in (-1, 0):
        y = tip_y + dy
        if y < 0:
            continue
        half = 0 if dy == -1 else 1
        for dx in range(-half, half + 1):
            x = cx + dx
            if 0 <= x < w and 0 <= y < h:
                px[x, y] = (*HORN, 255)


def get_frame(im: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    cell = im.crop(box)
    cell = autotrim(cell)
    w, h = cell.size
    factor = min(1.0, TARGET_MAX_DIM / max(w, h))
    if factor < 1.0:
        nw, nh = max(1, round(w * factor)), max(1, round(h * factor))
        cell = cell.resize((nw, nh), Image.NEAREST)
    recolored = recolor_by_luminance(cell, OUTLINE, SHADOW, BASE, HIGHLIGHT, t_outline=0.20, t_shadow=0.55, t_highlight=0.85)
    recolored = ensure_outline(recolored, OUTLINE)
    add_horn(recolored)
    return recolored


def lean_forward(frame: Image.Image, amount: int) -> Image.Image:
    """공격 예고/발동용 - 앞으로 기울인 것처럼 상단을 amount px 이동(전단 변형)."""
    w, h = frame.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        shift = int(amount * (1 - y / h))
        row = frame.crop((0, y, w, y + 1))
        out.paste(row, (shift, y), row)
    return out


def scale_frame(frame: Image.Image, factor: float) -> Image.Image:
    w, h = frame.size
    nw, nh = max(1, int(w * factor)), max(1, int(h * factor))
    scaled = frame.resize((nw, nh), Image.NEAREST)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.paste(scaled, ((w - nw) // 2, h - nh), scaled)
    return canvas


def build_idle(im, extra_boxes, main_boxes) -> list[Image.Image]:
    frames = [get_frame(im, b) for b in extra_boxes]
    frames.append(get_frame(im, main_boxes[0]))
    frames.append(get_frame(im, main_boxes[4]))
    return frames


def build_walk(im, main_boxes) -> list[Image.Image]:
    idxs = [0, 2, 4, 6]
    return [get_frame(im, main_boxes[i]) for i in idxs]


def build_attack_down_up(im, main_boxes) -> list[Image.Image]:
    base = get_frame(im, main_boxes[0])
    lunge = get_frame(im, main_boxes[2])
    f1 = base
    f2 = lean_forward(base, 2)
    f3 = scale_frame(lunge, 1.1)
    f4 = scale_frame(lunge, 1.18)
    f5 = base
    return [f1, f2, f3, f4, f5]


def build_attack_side(im, extra_boxes, main_a, main_b) -> list[Image.Image]:
    f1 = get_frame(im, extra_boxes[0])
    f2 = get_frame(im, extra_boxes[1])
    f3 = get_frame(im, main_b[0])
    f4 = get_frame(im, main_b[1])
    f5 = get_frame(im, main_a[0])
    return [f1, f2, f3, f4, f5]


def build_death(im, main_boxes) -> list[Image.Image]:
    base = get_frame(im, main_boxes[0])
    f1 = base
    f2 = snap_to_colors(base.rotate(-35, expand=False, resample=Image.NEAREST), DEATH_SNAP_COLORS)
    f3 = snap_to_colors(base.rotate(-75, expand=False, resample=Image.NEAREST), DEATH_SNAP_COLORS)
    f4 = fade(f3, 0.5)
    return [f1, f2, f3, f4]


def make_sheet(frames_per_direction: list[list[Image.Image]]) -> Image.Image:
    cols = max(len(f) for f in frames_per_direction)
    sheet = new_sheet(cols, 3, CELL)
    for row, frames in enumerate(frames_per_direction):
        for col, frame in enumerate(frames):
            paste_frame(sheet, frame, col, row, CELL)
    return sheet


def main() -> None:
    if not SRC_PATH.exists():
        raise SystemExit(
            f"소싱 원본이 없습니다: {SRC_PATH}\n"
            "https://opengameart.org/content/bunny-rabbit-lpc-style-for-pixelfarm 에서 재다운로드 필요."
        )
    im = Image.open(SRC_PATH).convert("RGBA")
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    idle_down = build_idle(im, DOWN_EXTRA, DOWN_MAIN)
    idle_up = build_idle(im, UP_EXTRA, UP_MAIN)
    idle_side = build_idle(im, SIDE_A_EXTRA, SIDE_A_MAIN)
    save_with_preview(make_sheet([idle_down, idle_side, idle_up]), OUT_DIR / "mob_rabbit_horned_idle.png")

    walk_down = build_walk(im, DOWN_MAIN)
    walk_up = build_walk(im, UP_MAIN)
    walk_side = build_walk(im, SIDE_A_MAIN)
    save_with_preview(make_sheet([walk_down, walk_side, walk_up]), OUT_DIR / "mob_rabbit_horned_walk.png")

    atk_down = build_attack_down_up(im, DOWN_MAIN)
    atk_up = build_attack_down_up(im, UP_MAIN)
    atk_side = build_attack_side(im, SIDE_B_EXTRA, SIDE_A_MAIN, SIDE_B_MAIN)
    save_with_preview(make_sheet([atk_down, atk_side, atk_up]), OUT_DIR / "mob_rabbit_horned_attack.png")

    death_down = build_death(im, DOWN_MAIN)
    death_up = build_death(im, UP_MAIN)
    death_side = build_death(im, SIDE_A_MAIN)
    save_with_preview(make_sheet([death_down, death_side, death_up]), OUT_DIR / "mob_rabbit_horned_death.png")

    print("뿔토끼 스프라이트 생성 완료(20x20 신규격, 3단 절제):", OUT_DIR)


if __name__ == "__main__":
    main()
