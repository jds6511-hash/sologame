"""MP-1: 동부 변경 시작 지역 타일셋 절차 생성 (Pillow).

STYLE_GUIDE.md 준수 사항:
- 1장: 타일 크기 16x16px 고정
- 2장: EDG32 32색 팔레트만 사용 (edg32_palette.py 공용 모듈)
- 3-1장: 지형 타일은 아웃라인 없음 - 명암(색 값 차이)만으로 구분
- 3-2장: 재질당 3단 램프 고정(기본색+그림자1+하이라이트1), 광원은 위쪽(약간 왼쪽) 고정,
         디더링 원칙 금지(대면적 하늘/물 예외 - 본 타일셋은 낱장 16x16이라 미적용)
- 4장: 동부 변경 서브 팔레트 = 주조색(황토 `#b86f50`, 황갈 `#c28569`, 적갈 어둠 `#733e39`,
       살구 `#e4a672`, 재건의 초록 `#63c74d`) + 포인트색(개척 깃발 노랑 `#fee761`)
  세계관(world-structure.md 1-1장)상 여울목 부락(강가 개척촌)~노베라 들녘(평원)이 무대이므로
  풀밭/흙길/농지/폐허 잔해/개척촌 목조 건물/개울 계열 16종을 구성한다.

출력:
- godot\\assets\\tiles\\eastern_frontier_tileset.png       (4x4 그리드, 64x64, 원본 1x)
- godot\\assets\\tiles\\eastern_frontier_tileset_4x.png    (검수용 x4 프리뷰, 320x320, Nearest 확대)
- godot\\assets\\tiles\\eastern_frontier_tileset.json      (타일 인덱스 매니페스트 - level-designer용)

재실행 시 동일 입력(고정 시드)으로 동일 결과가 나오는 순수 절차 생성 스크립트.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from edg32_palette import RGB

TILE = 16
COLS, ROWS = 4, 4
OUT_DIR = Path(__file__).parent.parent / "tiles"

# 자주 쓰는 색 별칭
OCHRE = RGB["ochre"]  # #b86f50 동부 대지 기본
TAN = RGB["tan"]  # #c28569 동부 대지 밝은 면 / 가죽
RED_BROWN_DARK = RGB["red_brown_dark"]  # #733e39 그림자
APRICOT = RGB["apricot"]  # #e4a672 흙길 밝은 면
FRESH_GREEN = RGB["fresh_green"]  # #63c74d 재건의 초록(신록)
GREEN = RGB["green"]  # #3e8948 초원 기본
DEEP_GREEN = RGB["deep_green"]  # #265c42 초원 그림자
BRIGHT_YELLOW = RGB["bright_yellow"]  # #fee761 개척 깃발 포인트색
SAND_CREAM = RGB["sand_cream"]  # #ead4aa 모래
BLUE = RGB["blue"]  # #0099db 물 기본
CYAN = RGB["cyan"]  # #2ce8f5 물 하이라이트
NAVY = RGB["navy"]  # #124e89 물 그림자(깊은 면)
BLUE_GRAY = RGB["blue_gray"]  # #8b9bb4 석재 기본(폐허)
DARK_BLUE_GRAY = RGB["dark_blue_gray"]  # #5a6988 석재 그림자
LIGHT_BLUE_GRAY = RGB["light_blue_gray"]  # #c0cbdc 석재 하이라이트
DARK_MAROON = RGB["dark_maroon"]  # #3e2731 균열 자국(흉터)
ORANGE_BROWN = RGB["orange_brown"]  # #d77643 목재 밝은 면(신도시 목재)
WHITE = RGB["white"]


def new_tile() -> Image.Image:
    return Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))


def px(img: Image.Image, x: int, y: int, color: tuple[int, int, int]) -> None:
    if 0 <= x < TILE and 0 <= y < TILE:
        img.putpixel((x, y), (*color, 255))


def noise(x: int, y: int, seed: int) -> float:
    """결정론적 의사 난수 (0.0 ~ 1.0). 같은 입력이면 항상 같은 값."""
    n = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    n = n ^ (n >> 16)
    return (n & 0xFFFFFFFF) / 0xFFFFFFFF


def ramp_fill(
    img: Image.Image,
    seed: int,
    base: tuple[int, int, int],
    shadow: tuple[int, int, int],
    highlight: tuple[int, int, int],
    shadow_freq: float = 0.22,
    highlight_freq: float = 0.10,
) -> None:
    """3단 램프로 타일 전체를 채운다. 광원은 위쪽(약간 왼쪽) 고정 규칙 반영:
    highlight는 위쪽 절반에 더 자주, shadow는 아래쪽 절반에 더 자주 배치."""
    for y in range(TILE):
        for x in range(TILE):
            n = noise(x, y, seed)
            upper = y < TILE // 2
            left = x < TILE // 2
            h_bias = highlight_freq * (1.5 if (upper and left) else 1.15 if upper else 0.6)
            s_bias = shadow_freq * (1.5 if not upper else 0.7)
            if n < h_bias:
                px(img, x, y, highlight)
            elif n > 1.0 - s_bias:
                px(img, x, y, shadow)
            else:
                px(img, x, y, base)


# ---------------------------------------------------------------------------
# 개별 타일 생성 함수
# ---------------------------------------------------------------------------


def tile_grass_base() -> Image.Image:
    img = new_tile()
    ramp_fill(img, seed=1, base=GREEN, shadow=DEEP_GREEN, highlight=FRESH_GREEN)
    return img


def tile_grass_flower() -> Image.Image:
    """재건 테마: 초원에 노란 들꽃(개척 깃발 포인트색 재사용) 점점이."""
    img = tile_grass_base()
    for x, y in [(3, 4), (9, 2), (12, 9), (6, 12), (13, 13)]:
        if noise(x, y, 77) < 0.7:
            px(img, x, y, BRIGHT_YELLOW)
    return img


def tile_dirt_path() -> Image.Image:
    img = new_tile()
    ramp_fill(img, seed=2, base=OCHRE, shadow=RED_BROWN_DARK, highlight=APRICOT)
    return img


def tile_dirt_pebble() -> Image.Image:
    img = tile_dirt_path()
    for x, y in [(2, 6), (7, 10), (11, 3), (4, 13), (13, 8)]:
        px(img, x, y, RED_BROWN_DARK)
    return img


def tile_tilled_soil() -> Image.Image:
    """개척촌 농지: 이랑(고랑) 패턴 - 재건의 초록 새싹 점재."""
    img = new_tile()
    for y in range(TILE):
        row_base = RED_BROWN_DARK if y % 4 == 0 else OCHRE
        for x in range(TILE):
            n = noise(x, y, 3)
            if row_base == OCHRE and n < 0.08:
                px(img, x, y, APRICOT)
            else:
                px(img, x, y, row_base)
    # 새싹(재건 초록) 소수 배치
    for x, y in [(3, 2), (8, 6), (12, 10), (5, 14)]:
        px(img, x, y, FRESH_GREEN)
    return img


def tile_river_water() -> Image.Image:
    """여울목(강 여울) 개울물 - 단일 타일이므로 체커 디더 대신 3단 램프 물결 사용."""
    img = new_tile()
    ramp_fill(img, seed=4, base=BLUE, shadow=NAVY, highlight=CYAN, shadow_freq=0.18, highlight_freq=0.14)
    return img


def tile_riverbank_sand() -> Image.Image:
    img = new_tile()
    ramp_fill(img, seed=5, base=SAND_CREAM, shadow=TAN, highlight=WHITE, shadow_freq=0.20, highlight_freq=0.08)
    return img


def tile_rubble_stone() -> Image.Image:
    """폐허 잔해(대란의 흉터 모티프) - 회청 석재."""
    img = new_tile()
    ramp_fill(img, seed=6, base=BLUE_GRAY, shadow=DARK_BLUE_GRAY, highlight=LIGHT_BLUE_GRAY)
    return img


def tile_cracked_ground() -> Image.Image:
    """균열 흉터가 남은 대지 - 황토 바탕에 어두운 균열 선."""
    img = new_tile()
    ramp_fill(img, seed=7, base=OCHRE, shadow=RED_BROWN_DARK, highlight=APRICOT)
    crack = [(2, 1), (3, 3), (4, 5), (5, 7), (6, 8), (7, 10), (8, 12), (9, 14),
             (10, 2), (11, 4), (12, 6)]
    for x, y in crack:
        px(img, x, y, DARK_MAROON)
    return img


def tile_stone_wall() -> Image.Image:
    """개척촌 방벽 - 회청 석재 블록 줄눈."""
    img = new_tile()
    ramp_fill(img, seed=8, base=BLUE_GRAY, shadow=DARK_BLUE_GRAY, highlight=LIGHT_BLUE_GRAY,
              shadow_freq=0.05, highlight_freq=0.05)
    for y in (0, 5, 10, 15):
        for x in range(TILE):
            px(img, x, y, DARK_BLUE_GRAY)
    for row, offset in enumerate((0, 4, 8, 12)):
        y0 = row * 5 + 2
        for x in range(offset % 8, TILE, 8):
            px(img, x, min(y0, TILE - 1), DARK_BLUE_GRAY)
    return img


def tile_stone_floor() -> Image.Image:
    img = new_tile()
    ramp_fill(img, seed=9, base=LIGHT_BLUE_GRAY, shadow=BLUE_GRAY, highlight=WHITE,
              shadow_freq=0.15, highlight_freq=0.06)
    for i in (0, 8):
        for x in range(TILE):
            px(img, x, i, BLUE_GRAY)
        for y in range(TILE):
            px(img, i, y, BLUE_GRAY)
    return img


def tile_wood_plank() -> Image.Image:
    """개척촌(노베라) 목조 바닥 - 신도시 목재색."""
    img = new_tile()
    ramp_fill(img, seed=10, base=ORANGE_BROWN, shadow=RED_BROWN_DARK, highlight=APRICOT,
              shadow_freq=0.08, highlight_freq=0.08)
    for y in (3, 7, 11, 15):
        for x in range(TILE):
            px(img, x, y, RED_BROWN_DARK)
    return img


def tile_wood_fence() -> Image.Image:
    img = new_tile()
    for x in (3, 12):
        for y in range(2, TILE):
            px(img, x, y, RED_BROWN_DARK)
            px(img, x + 1 if x == 3 else x, y, ORANGE_BROWN)
    for y in (5, 10):
        for x in range(2, TILE - 1):
            px(img, x, y, ORANGE_BROWN)
            px(img, x, y + 1, RED_BROWN_DARK)
    return img


def tile_flag_banner() -> Image.Image:
    """개척 깃발 - 동부 변경 포인트색(밝은 노랑) 오브젝트 타일."""
    img = new_tile()
    for y in range(2, TILE):
        px(img, 7, y, RED_BROWN_DARK)
        px(img, 8, y, ORANGE_BROWN)
    # 깃발 천 (삼각 깃발)
    flag_pixels = [
        (9, 2), (10, 2), (11, 2), (12, 2),
        (9, 3), (10, 3), (11, 3),
        (9, 4), (10, 4),
        (9, 5),
    ]
    for x, y in flag_pixels:
        px(img, x, y, BRIGHT_YELLOW)
    for x, y in [(12, 2), (11, 3), (10, 4), (9, 5)]:
        px(img, x, y, OCHRE)
    return img


def tile_rock_small() -> Image.Image:
    img = new_tile()
    rock = [
        (5, 9), (6, 8), (7, 8), (8, 8), (9, 9),
        (5, 10), (6, 10), (7, 10), (8, 10), (9, 10), (10, 10),
        (5, 11), (6, 11), (7, 11), (8, 11), (9, 11), (10, 11),
        (6, 12), (7, 12), (8, 12), (9, 12),
    ]
    for x, y in rock:
        n = noise(x, y, 11)
        color = LIGHT_BLUE_GRAY if (y <= 9 and n < 0.5) else BLUE_GRAY if n < 0.8 else DARK_BLUE_GRAY
        px(img, x, y, color)
    return img


def tile_bush_small() -> Image.Image:
    img = new_tile()
    bush = [
        (6, 9), (7, 8), (8, 8), (9, 9),
        (5, 10), (6, 10), (7, 10), (8, 10), (9, 10), (10, 10),
        (5, 11), (6, 11), (7, 11), (8, 11), (9, 11), (10, 11),
        (6, 12), (7, 12), (8, 12), (9, 12),
    ]
    for x, y in bush:
        n = noise(x, y, 12)
        color = FRESH_GREEN if (y <= 10 and n < 0.45) else GREEN if n < 0.8 else DEEP_GREEN
        px(img, x, y, color)
    return img


TILES: list[tuple[str, str]] = [
    ("grass_base", "풀밭 기본"),
    ("grass_flower", "풀밭(들꽃, 재건 포인트색)"),
    ("dirt_path", "흙길 기본"),
    ("dirt_pebble", "흙길(자갈)"),
    ("tilled_soil", "개척 농지(이랑+새싹)"),
    ("river_water", "여울목 개울물"),
    ("riverbank_sand", "강가 모래톱"),
    ("rubble_stone", "폐허 잔해(석재)"),
    ("cracked_ground", "균열 흉터 대지"),
    ("stone_wall", "개척촌 방벽"),
    ("stone_floor", "석재 바닥"),
    ("wood_plank", "목조 바닥(노베라)"),
    ("wood_fence", "목조 울타리"),
    ("flag_banner", "개척 깃발"),
    ("rock_small", "작은 바위(배경 오브젝트)"),
    ("bush_small", "작은 덤불(배경 오브젝트)"),
]

GENERATORS = {
    "grass_base": tile_grass_base,
    "grass_flower": tile_grass_flower,
    "dirt_path": tile_dirt_path,
    "dirt_pebble": tile_dirt_pebble,
    "tilled_soil": tile_tilled_soil,
    "river_water": tile_river_water,
    "riverbank_sand": tile_riverbank_sand,
    "rubble_stone": tile_rubble_stone,
    "cracked_ground": tile_cracked_ground,
    "stone_wall": tile_stone_wall,
    "stone_floor": tile_stone_floor,
    "wood_plank": tile_wood_plank,
    "wood_fence": tile_wood_fence,
    "flag_banner": tile_flag_banner,
    "rock_small": tile_rock_small,
    "bush_small": tile_bush_small,
}


def build_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (COLS * TILE, ROWS * TILE), (0, 0, 0, 0))
    for i, (key, _label) in enumerate(TILES):
        col, row = i % COLS, i // COLS
        tile_img = GENERATORS[key]()
        sheet.paste(tile_img, (col * TILE, row * TILE), tile_img)
    return sheet


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    sheet = build_sheet()

    out_1x = OUT_DIR / "eastern_frontier_tileset.png"
    sheet.save(out_1x)

    out_4x = OUT_DIR / "eastern_frontier_tileset_4x.png"
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(out_4x)

    manifest = {
        "tile_size": TILE,
        "columns": COLS,
        "rows": ROWS,
        "source": "godot/assets/tools/generate_tileset_eastern_frontier.py",
        "tiles": [
            {"index": i, "col": i % COLS, "row": i // COLS, "key": key, "label": label}
            for i, (key, label) in enumerate(TILES)
        ],
    }
    out_json = OUT_DIR / "eastern_frontier_tileset.json"
    out_json.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"저장 완료: {out_1x}")
    print(f"저장 완료: {out_4x}")
    print(f"저장 완료: {out_json}")


if __name__ == "__main__":
    main()
