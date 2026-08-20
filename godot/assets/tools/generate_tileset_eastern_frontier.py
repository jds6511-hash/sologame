"""MP-1: 동부 변경 시작 지역 타일셋 절차 생성 (Pillow).

STYLE_GUIDE.md 준수 사항:
- 1장: 타일 크기 16x16px 고정
- 2장: EDG32 32색 팔레트만 사용 (edg32_palette.py 공용 모듈)
- 3-1장: 지형 타일은 아웃라인 없음 - 색 차이만으로 구분
- 3-2장 (2026-08-20 개정): 명암 단계 상한이 대상별로 삼원화됐다.
  · **대면적 지면 10종은 3단 램프 규정 비적용** — 3-2-3절이 대체한다(아래).
  · 프롭·구조물(rubble_stone / stone_wall / wood_fence / flag_banner / rock_small /
    bush_small)은 **3단 램프 고정을 그대로 유지하고 대비를 낮추지 않는다**(3-2-3-6절).
    이 개정의 목적은 대비를 없애는 것이 아니라 지면에서 프롭으로 소유권을 옮기는 것이다.
    flag_banner 는 명시적 예외(포인트색 `#fee761`, 폭 축소 금지).
- 3-2-3장 (대면적 지면 명도 대비 규칙 — 본 스크립트의 핵심 제약):
  · 게이트 지표 = 면적가중 명도 표준편차 **σ_L ≤ 10** (river_water 만 ≤ 12).
    예산식 `Σ p·Δ² ≤ 100` 과 동치이고, 검증은 `validate_ground_contrast.py` 가 한다.
  · 타일당 **총 4색 상한** — 기본색 1(56% 이상) + 등명도 변주 최대 2색(합계 38% 이하)
    + 단계색 1(통상 6~10%). 단일 색 Δ 절대값 **하드 상한 40**, 대면적 지면 `#ffffff` 금지.
  · 질감은 **명암 램프가 아니라 등명도 색상 변주**로 만든다(눈 피로는 명도 대비가
    지배 변수다). 그래서 지면 타일에는 광원 방향 표현이 없다 — 방향성 음영은 프롭이 담당.
  · 등명도 변주는 **불규칙 산발**. 규칙적 2x2 체커 금지(정수 배율 ×4 스크롤에서 패턴
    크롤링이 생긴다) — `texture_field()` 의 부드러운 결정론 노이즈 + 순위 기반 배분으로
    면적을 정확히 맞추면서 덩어리진 불규칙 얼룩을 만든다.
  · **지형 종류 식별은 색이 아니라 단계색의 배치 형태**가 담당한다(3-2-3-4 C 표).
    흙 계열 4종의 색 구성이 같아지는 것은 의도된 결과다 — 구분은 산발/클러스터/
    평행 고랑/분기 균열/직선 이음새 형태로 낸다. 균열을 더 어둡게 만드는 처방은 반려됐다.
- 4장: 동부 변경 서브 팔레트 = 주조색(황토 `#b86f50`, 황갈 `#c28569`, 적갈 어둠 `#733e39`,
  살구 `#e4a672`, 재건의 초록 `#63c74d`) + 포인트색(개척 깃발 노랑 `#fee761`)
  세계관(world-structure.md 1-1장)상 여울목 부락(강가 개척촌)~노베라 들녘(평원)이 무대이므로
  풀밭/흙길/농지/폐허 잔해/개척촌 목조 건물/개울 계열 16종을 구성한다.
  등명도 변주색은 서브팔레트 제약의 예외로 허용된다(명도가 같아 권역 인상을 바꾸지 않는다).

출력:
- godot\\assets\\tiles\\eastern_frontier_tileset.png       (4x4 그리드, 64x64, 원본 1x)
- godot\\assets\\tiles\\eastern_frontier_tileset_4x.png    (검수용 x4 프리뷰, 256x256, Nearest 확대)
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
OCHRE = RGB["ochre"]  # #b86f50 L129.3 동부 대지 기본
TAN = RGB["tan"]  # #c28569 L148.0 흙 등명도 변주 / 목재 결
RED_BROWN_DARK = RGB["red_brown_dark"]  # #733e39 L 77.3 프롭 그림자
BRICK_RED = RGB["brick_red"]  # #be4a2f L105.6 지면 단계색(형태 신호 전담)
FRESH_GREEN = RGB["fresh_green"]  # #63c74d L155.2 재건의 초록(프롭 하이라이트)
GREEN = RGB["green"]  # #3e8948 L107.2 초원 기본
DEEP_GREEN = RGB["deep_green"]  # #265c42 L 72.9 프롭(덤불) 그림자
BRIGHT_YELLOW = RGB["bright_yellow"]  # #fee761 L222.6 개척 깃발 포인트색
PINK = RGB["pink"]  # #f6757a L156.1 들꽃(미세 프롭, 면적 1.5% 캡)
SAND_CREAM = RGB["sand_cream"]  # #ead4aa L213.8 모래 기본
LIGHT_APRICOT = RGB["light_apricot"]  # #e8b796 L193.9 모래·석재 등명도 변주
NAVY = RGB["navy"]  # #124e89 L 66.8 물 기본
NAVY_GRAY = RGB["navy_gray"]  # #3a4466 L 68.9 물 등명도 변주
BLUE_GRAY = RGB["blue_gray"]  # #8b9bb4 L153.1 석재 기본(프롭)
DARK_BLUE_GRAY = RGB["dark_blue_gray"]  # #5a6988 L104.0 초원 변주 / 물 반짝임 / 프롭 그림자
LIGHT_BLUE_GRAY = RGB["light_blue_gray"]  # #c0cbdc L201.6 석재 바닥 기본 / 프롭 하이라이트
ORANGE_BROWN = RGB["orange_brown"]  # #d77643 L141.2 목재 기본 / 흙 등명도 변주


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


# ---------------------------------------------------------------------------
# 대면적 지면 공용 도구 (STYLE_GUIDE 3-2-3)
# ---------------------------------------------------------------------------

Pos = tuple[int, int]


def _smooth_noise(x: int, y: int, seed: int, cell_x: int, cell_y: int) -> float:
    """격자 노이즈를 smoothstep 보간한 값 노이즈. 격자 인덱스를 타일 폭으로 감아
    **타일이 상하좌우로 이어 붙어도 이음매가 보이지 않게** 한다(지면은 수십 타일 연속)."""
    nx = max(1, TILE // cell_x)
    ny = max(1, TILE // cell_y)
    gx, gy = x / cell_x, y / cell_y
    x0, y0 = int(gx), int(gy)
    tx, ty = gx - x0, gy - y0
    sx = tx * tx * (3 - 2 * tx)
    sy = ty * ty * (3 - 2 * ty)
    a = noise(x0 % nx, y0 % ny, seed)
    b = noise((x0 + 1) % nx, y0 % ny, seed)
    c = noise(x0 % nx, (y0 + 1) % ny, seed)
    d = noise((x0 + 1) % nx, (y0 + 1) % ny, seed)
    return (a + (b - a) * sx) * (1 - sy) + (c + (d - c) * sx) * sy


def texture_field(seed: int, cell_x: int = 4, cell_y: int = 4) -> dict[Pos, float]:
    """2옥타브 값 노이즈 스칼라장. 이 장을 순위로 잘라 색을 배분하면
    **면적은 정확하고 배치는 덩어리진 불규칙 얼룩**이 된다 — 3-2-3 의 "등명도 변주는
    불규칙 산발, 규칙적 체커 금지"를 만족시키는 장치다. `cell_x`/`cell_y` 를 다르게
    주면 결(목재 나뭇결·수면 물결)이 한 방향으로 늘어난다."""
    field: dict[Pos, float] = {}
    for y in range(TILE):
        for x in range(TILE):
            coarse = _smooth_noise(x, y, seed, cell_x, cell_y)
            fine = _smooth_noise(x, y, seed + 977, max(1, cell_x // 2), max(1, cell_y // 2))
            field[(x, y)] = 0.62 * coarse + 0.38 * fine
    return field


def scatter_fill(
    img: Image.Image,
    positions: list[Pos],
    field: dict[Pos, float],
    allocation: list[tuple[tuple[int, int, int], int]],
) -> None:
    """`positions` 를 스칼라장 값 오름차순으로 정렬해 `allocation` 순서대로 **정확한
    픽셀 수만큼** 칠한다. 면적 예산식(`Σ p·Δ² ≤ 100`)이 최종 판정이므로 면적은
    비율이 아니라 픽셀 수로 못박는다. 동값은 (y, x) 순으로 깨 재현성을 보장한다."""
    ordered = sorted(positions, key=lambda p: (field[p], p[1], p[0]))
    planned = sum(count for _, count in allocation)
    assert planned == len(ordered), f"배분 합계 {planned} != 대상 픽셀 {len(ordered)}"
    i = 0
    for color, count in allocation:
        for _ in range(count):
            px(img, *ordered[i], color)
            i += 1


def all_positions() -> list[Pos]:
    return [(x, y) for y in range(TILE) for x in range(TILE)]


def pick_by_noise(positions: list[Pos], seed: int, count: int) -> list[Pos]:
    """백색 노이즈 순위로 `count`개를 고른다. 고랑·이음새 같은 **선 위의 파선(dash)**을
    만들 때 쓴다 — 선을 꽉 채우면 단계색 면적이 25%를 넘어 예산을 단독 초과한다."""
    return sorted(sorted(positions, key=lambda p: (noise(p[0], p[1], seed), p[1], p[0]))[:count])


def jittered_points(seed: int, grid_x: int, grid_y: int, count: int) -> list[Pos]:
    """격자 칸마다 지터로 1점씩 뽑아 `count`개 반환 — **방향성 없는 균일 산발**용.
    백색 노이즈로 뽑으면 뭉치는 자리가 생겨 dirt_pebble 의 클러스터 신호와 헷갈린다."""
    cw, ch = TILE / grid_x, TILE / grid_y
    candidates: list[tuple[float, Pos]] = []
    for j in range(grid_y):
        for i in range(grid_x):
            x = min(TILE - 1, int(i * cw + noise(i, j, seed) * cw))
            y = min(TILE - 1, int(j * ch + noise(i, j, seed + 313) * ch))
            candidates.append((noise(i, j, seed + 7), (x, y)))
    candidates.sort(key=lambda c: (c[0], c[1]))
    out: list[Pos] = []
    seen: set[Pos] = set()
    for _, pos in candidates:
        if pos in seen:
            continue
        seen.add(pos)
        out.append(pos)
        if len(out) == count:
            break
    assert len(out) == count, f"균일 산발 점 부족: {len(out)}/{count} (격자를 키울 것)"
    return out


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
    highlight는 위쪽 절반에 더 자주, shadow는 아래쪽 절반에 더 자주 배치.

    **프롭·구조물 전용이다** — 2026-08-20 개정으로 대면적 지면은 램프 규정 비적용이며
    (3-2-3절) 지면에 이 함수를 다시 쓰면 σ_L 게이트를 통과할 수 없다."""
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
# 대면적 지면 10종 (STYLE_GUIDE 3-2-3-5 확정 배합표 — 면적은 256px 기준 픽셀 수)
# ---------------------------------------------------------------------------


def tile_grass_base() -> Image.Image:
    """초원. 초록 계열은 EDG32 내 최소 단차가 34.3이라 램프가 불가능하므로
    **등명도 교차 색조**로 질감을 만든다 — `#5a6988` 회청은 그늘·습기,
    `#be4a2f` 벽돌 적갈은 드러난 흙으로 읽힌다. 구 배합(`#265c42` 25% 그림자 +
    `#63c74d` 10% 하이라이트)은 폐기됐다. 배합: 64% / 26% / 10% -> σ_L 1.4"""
    img = new_tile()
    # 드러난 흙(단계색)은 **덩어리진 얼룩**이어야 흙으로 읽힌다 — 굵은 스칼라장으로 먼저
    # 자리를 잡고, 남은 자리에 고운 스칼라장으로 등명도 변주를 깐다. 두 색을 한 장으로
    # 자르면 흙이 낱픽셀 색종이처럼 흩어지고 변주는 큰 얼룩이 되어 둘 다 어긋난다.
    soil_field = texture_field(seed=101, cell_x=3, cell_y=3)
    soil = sorted(all_positions(), key=lambda p: (-soil_field[p], p[1], p[0]))[:26]
    for x, y in soil:
        px(img, x, y, BRICK_RED)
    free = [p for p in all_positions() if p not in set(soil)]
    scatter_fill(img, free, texture_field(102, 3, 3), [(DARK_BLUE_GRAY, 66), (GREEN, 164)])
    return img


# 들꽃 후보 좌표 — 초록 픽셀인 자리만 3개까지 채택(면적 1.5% 캡 = 3/256 = 1.17%).
# 캡은 Δ49 픽셀의 반짝임을 막는 조건이라 재량 대상이 아니다(3-2-3-5 비고).
_FLOWER_CANDIDATES: list[Pos] = [(4, 3), (11, 6), (6, 12), (13, 10), (2, 8), (9, 14), (14, 2)]
_FLOWER_MAX = 3


def tile_grass_flower() -> Image.Image:
    """초원 + 들꽃. 구 하이라이트 `#fee761`(Δ116)은 1%만으로도 예산을 단독 초과하므로
    2장 지정 용도가 "축제 장식·꽃"인 `#f6757a`(Δ49)로 교체하고 3px 로 제한한다.
    배합: 초록 62.9% / 회청 25.8% / 적갈 10.2% / 꽃 1.17% -> σ_L 5.5"""
    img = tile_grass_base()
    placed = 0
    for x, y in _FLOWER_CANDIDATES:
        if placed >= _FLOWER_MAX:
            break
        if img.getpixel((x, y))[:3] == GREEN:
            px(img, x, y, PINK)
            placed += 1
    return img


def tile_dirt_path() -> Image.Image:
    """흙길. 형태 신호 = **방향성 없는 균일 산발**(3-2-3-4 C).
    배합: 황토 60.2% / 주갈 30.1% / 적갈 9.8% -> σ_L 9.8"""
    img = new_tile()
    step = jittered_points(seed=202, grid_x=6, grid_y=6, count=25)
    for x, y in step:
        px(img, x, y, BRICK_RED)
    free = [p for p in all_positions() if p not in set(step)]
    scatter_fill(img, free, texture_field(203, 3, 3), [(OCHRE, 154), (ORANGE_BROWN, 77)])
    return img


# 형태 신호 = 2~3px 점 클러스터 산발. 좌표를 못박아 클러스터 크기를 보장한다
# (난수 성장은 서로 붙어 큰 얼룩이 되면 dirt_path 와 구분이 안 된다).
_PEBBLE_CLUSTERS: list[Pos] = [
    (2, 4), (3, 4), (2, 5),
    (8, 2), (9, 2), (9, 3),
    (12, 7), (13, 7), (12, 8),
    (5, 11), (6, 11),
    (10, 13), (11, 13),
    (14, 11), (14, 12),
]


def tile_dirt_pebble() -> Image.Image:
    """흙길(자갈). 색 구성은 dirt_path 와 거의 같고 구분은 클러스터 형태가 담당한다.
    배합: 황토 57.0% / 주갈 28.1% / 황갈 9.0% / 적갈 5.9% -> σ_L 9.5"""
    img = new_tile()
    for x, y in _PEBBLE_CLUSTERS:
        px(img, x, y, BRICK_RED)
    free = [p for p in all_positions() if p not in set(_PEBBLE_CLUSTERS)]
    scatter_fill(
        img,
        free,
        texture_field(204, 3, 3),
        [(OCHRE, 146), (ORANGE_BROWN, 72), (TAN, 23)],
    )
    return img


def tile_tilled_soil() -> Image.Image:
    """개척 농지. 형태 신호 = **평행 고랑**(한 방향, 4px 간격).
    고랑 골(단계색)은 파선이고 그 위 이랑 등(등명도 변주 `#d77643`)은 실선이라
    밝은 등 + 어두운 골 짝이 고랑으로 읽힌다 — 골을 실선으로 채우면 단계색이 25%가 되어
    예산을 단독 초과한다. 배합: 황토 60.9% / 주갈 30.1% / 적갈 9.0% -> σ_L 9.5"""
    img = new_tile()
    crest = [(x, y) for y in (1, 5, 9, 13) for x in range(TILE)]
    groove_row = [(x, y) for y in (2, 6, 10, 14) for x in range(TILE)]
    groove = set(pick_by_noise(groove_row, seed=205, count=23))

    for x, y in crest:
        px(img, x, y, ORANGE_BROWN)
    for x, y in groove:
        px(img, x, y, BRICK_RED)
    # 고랑 행의 나머지는 기본색으로 메운다(골의 파선 사이를 잇는 흙).
    for pos in groove_row:
        if pos not in groove:
            px(img, *pos, OCHRE)

    used = set(crest) | set(groove_row)
    free = [p for p in all_positions() if p not in used]
    rest_ochre = 156 - (len(groove_row) - len(groove))
    scatter_fill(
        img, free, texture_field(206, 3, 3), [(OCHRE, rest_ochre), (ORANGE_BROWN, 77 - len(crest))]
    )
    return img


# 형태 신호 = 분기하는 균열선(1px, 불규칙 갈래). 본 줄기 1 + 갈래 2 = 23px.
# 갈래가 타일 가장자리를 관통하지 않게 가운데로 모았다 — 관통하면 타일이 이어질 때
# 같은 대각선이 격자처럼 반복돼 "규칙적 패턴"으로 읽힌다.
# 갈래는 **직교 계단**(한 방향 2px 이상)으로 꺾는다. 1px 순수 대각선은 2x2 창에서
# 대각 동색 + 인접 이색이 되어 체커와 구분되지 않는다(3-2 표 "규칙적 체커 금지" 측정값
# 을 스스로 올린다). 또 갈래를 가운데로 모아 타일 가장자리를 관통시키지 않는다 —
# 관통하면 타일이 이어질 때 같은 선이 격자처럼 반복돼 규칙적 패턴으로 읽힌다.
_CRACK_MAIN: list[Pos] = [
    (6, 12), (6, 11), (6, 10), (6, 9), (7, 9), (8, 9), (8, 8),
    (8, 7), (9, 7), (10, 7), (10, 6), (10, 5), (11, 5), (12, 5),
]
_CRACK_BRANCH_A: list[Pos] = [(5, 10), (4, 10), (4, 11), (4, 12)]
_CRACK_BRANCH_B: list[Pos] = [(12, 4), (13, 4), (13, 3)]
_CRACK_BRANCH_C: list[Pos] = [(6, 13), (5, 13)]


def tile_cracked_ground() -> Image.Image:
    """균열 흉터 대지. 구 배합은 균열을 `#3e2731`(Δ-69)로 그려 예산을 초과했다 —
    **균열을 더 어둡게 만드는 처방은 반려**됐고(3-2-3-4 C) 신호는 분기 형태가 담당한다.
    배합: 황토 60.9% / 주갈 30.1% / 적갈 9.0% -> σ_L 9.5"""
    img = new_tile()
    crack = _CRACK_MAIN + _CRACK_BRANCH_A + _CRACK_BRANCH_B + _CRACK_BRANCH_C
    for x, y in crack:
        px(img, x, y, BRICK_RED)
    free = [p for p in all_positions() if p not in set(crack)]
    scatter_fill(img, free, texture_field(207, 3, 3), [(OCHRE, 156), (ORANGE_BROWN, 77)])
    return img


def tile_riverbank_sand() -> Image.Image:
    """강가 모래톱. 단계색 없이 등명도 3색만으로 성립한다.
    구 `#ffffff` 하이라이트 12%는 전면 폐기(대면적 지면 흰색 금지).
    배합: 모래 62.1% / 회청밝음 25.0% / 살구밝음 12.9% -> σ_L 7.5"""
    img = new_tile()
    scatter_fill(
        img,
        all_positions(),
        texture_field(208, 3, 3),
        [(LIGHT_BLUE_GRAY, 64), (SAND_CREAM, 159), (LIGHT_APRICOT, 33)],
    )
    return img


def tile_stone_floor() -> Image.Image:
    """석재 바닥. 이음새는 등명도 변주 `#e8b796`(Δ-7.5)로 그린다 —
    회청 계열은 기본색 `#c0cbdc` 에서 Δ가 -45 이상이라 하드 상한 40을 넘는다.
    구 `#ffffff` 하이라이트 5%는 폐기. 배합: 58.2% / 27.0% / 14.8% -> σ_L 6.2"""
    img = new_tile()
    seam = [(x, y) for y in (0, 8) for x in range(TILE)]
    seam += [(x, y) for x in (0, 8) for y in range(TILE) if y not in (0, 8)]
    for x, y in seam:
        px(img, x, y, LIGHT_APRICOT)
    free = [p for p in all_positions() if p not in set(seam)]
    scatter_fill(
        img,
        free,
        texture_field(209, 4, 4),
        [(LIGHT_APRICOT, 69 - len(seam)), (LIGHT_BLUE_GRAY, 149), (SAND_CREAM, 38)],
    )
    return img


# 나뭇결 옹이 — 이음새 행을 피해 배치한다.
_PLANK_KNOTS: list[Pos] = [(3, 2), (12, 8), (6, 14), (14, 3), (9, 9)]


def tile_wood_plank() -> Image.Image:
    """목조 바닥. 형태 신호 = **판 경계 직선 이음새**(판 폭 균일).
    이음새는 값싼 등명도 변주 `#b86f50`(Δ-11)이 실선을 잇고 단계색 `#be4a2f`(Δ-35)가
    그 위에 얼룩져 이음새가 끊기지 않는다. 나뭇결은 결 방향으로 늘인 스칼라장으로 만든다.
    배합: 주갈 58.2% / 황갈 27.3% / 황토 9.8% / 적갈 4.7% -> σ_L 9.2"""
    img = new_tile()
    seam = [(x, y) for y in (5, 11) for x in range(TILE)]
    seam_dark = set(pick_by_noise(seam, seed=210, count=12))
    for pos in seam:
        px(img, *pos, BRICK_RED if pos in seam_dark else OCHRE)
    for x, y in _PLANK_KNOTS:
        px(img, x, y, OCHRE)

    used = set(seam) | set(_PLANK_KNOTS)
    free = [p for p in all_positions() if p not in used]
    scatter_fill(
        img, free, texture_field(211, cell_x=8, cell_y=2), [(ORANGE_BROWN, 149), (TAN, 70)]
    )
    return img


# 수면 반짝임 — 짧은 수평 파선(2~3px)이라 물결 방향과 어긋나지 않는다.
_WATER_GLINTS: list[Pos] = [
    (2, 2), (3, 2),
    (9, 4), (10, 4), (11, 4),
    (5, 6), (6, 6),
    (12, 8), (13, 8),
    (3, 10), (4, 10), (5, 10),
    (10, 12), (11, 12),
    (7, 14), (8, 14),
    (14, 6), (1, 13), (8, 1), (13, 15),
]


def tile_river_water() -> Image.Image:
    """여울목 개울물. `#0099db`·`#2ce8f5` 는 6장 색 위계에서 아군·마나 식별색이고
    두 색으로 물을 만들면 σ_L 이 35까지 오르므로 **대면적 사용 금지** — 남색 계열로
    재설계했다. 배합: 남색 62.1% / 남회 30.1% / 회청 7.8% -> σ_L 9.9 (상한 12)"""
    img = new_tile()
    for x, y in _WATER_GLINTS:
        px(img, x, y, DARK_BLUE_GRAY)
    free = [p for p in all_positions() if p not in set(_WATER_GLINTS)]
    scatter_fill(
        img, free, texture_field(212, cell_x=8, cell_y=3), [(NAVY, 159), (NAVY_GRAY, 77)]
    )
    return img


# ---------------------------------------------------------------------------
# 프롭·구조물 6종 (3-2-3-6: 게이트 비적용 — 3단 램프·현행 대비 유지)
# ---------------------------------------------------------------------------


def tile_rubble_stone() -> Image.Image:
    """폐허 잔해(대란의 흉터 모티프) - 회청 석재."""
    img = new_tile()
    ramp_fill(img, seed=6, base=BLUE_GRAY, shadow=DARK_BLUE_GRAY, highlight=LIGHT_BLUE_GRAY)
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
    """개척 깃발 - 동부 변경 포인트색(밝은 노랑) 오브젝트 타일.
    3-2-3-6절 **명시적 예외**: 지면 대비 규칙 비적용이고 명도 폭 축소 금지다."""
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
    print("지면 대비 게이트 확인: python validate_ground_contrast.py")


if __name__ == "__main__":
    main()
