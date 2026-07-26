"""AR-2: 들개 마수(Feral Hound) 몬스터 스프라이트 - CC0 계열 소싱 가공 + 방향 근사.

소싱: "[LPC] Wolf Animation" by zerohero 외 Mumu, William.Thompsonj(OpenGameArt, CC-BY 4.0 선택)
  https://opengameart.org/content/lpc-wolf-animation
  원본 파일 캐시: godot\\assets\\tools\\_raw_src\\wolfsheet1_zerohero.png (640x384)
  오른쪽 절반(x 320~640)이 4족 늑대 **측면(側面)** 시퀀스다. 왼쪽 절반은 정면/후면
  세트라 이번 종에는 쓰지 않는다.

**중요(2026-07-26 재생성) - 상반신 누락 버그 수정**:
  원본 측면 늑대 한 마리는 **64px 폭 셀**을 차지한다(머리+앞다리가 앞쪽 32px, 몸통+뒷다리+
  꼬리가 뒤쪽 32px). 이전 버전은 소스 셀 피치를 32px로 잘못 잡아 **한 마리를 반으로 갈라**
  뒷부분(엉덩이·꼬리·뒷다리)만 추출했다 → 게임에서 머리·앞다리가 없는 늑대로 보였다.
  본 버전은 **64px 셀** 단위로 크롭하고, 셀 안에서 가장 큰 연결 성분(largest connected
  component)만 남겨 인접 프레임 잔상을 제거한 뒤 autotrim한다 → 머리부터 꼬리까지 온전한
  늑대 한 마리가 셀 안에 들어간다.

원본 프레임 그리드(오른쪽 절반, x0 = 320 + col*64, col 0~4 / 아래 y밴드는 서브행):
  - TOP (y 1~32)   : 소형 정지/웅크림 포즈 4프레임 (col 0~3). TOP0/1 서 있음, TOP2/3 웅크림
  - A   (y 55~96)  : **하울(고개 치켜듦)** 시퀀스 - 공격 예고 실루엣(A2 고개 반쯤, A3 완전히 치켜듦)
  - B   (y 97~128) : **걷기** 사이클 (B0~B4)
  - C   (y 129~160): 달리기 사이클 (예비, 현재 미사용)
  - D   (y 161~192): **물기(이빨 드러냄)** 시퀀스 - D2 입 벌린 돌진, D3 물기

프레임 매핑(방향은 측면 원화만 존재 → 하/상은 폭 압축 근사, ASSET_SOURCES.md에 한계 기록):
  - IDLE   : side [TOP0, TOP1, TOP0, TOP1]  (차분한 서 있는 호흡)
  - WALK   : side [B0, B1, B2, B3]
  - ATTACK : side [A2, A3(예고: 고개 치켜듦), D2, D3(발동: 물기), B0(회수)]
  - DEATH  : side [A3(피격 젖힘), TOP2(웅크림), TOP3(주저앉음), TOP3 페이드]

STYLE_GUIDE.md 준수(2026-07-27 스톤샤드식 안 1 개정): 출력 캔버스 **32x24 -> 36x28**(가로
2.25타일x세로 1.75타일, 표준 체급, +4/+4), 실체 약 30x19. 원본 64px 셀에서 크롭한 온전한
늑대를 종횡비 유지 NEAREST로 축소(TARGET_W/TARGET_H) 후 EDG32 재양자화 → 안티앨리어싱 없음.
아웃라인 1px #181425. **명암 4단**(STYLE_GUIDE 3-2-1, recolor_ramp4로 야수 가죽 램프
tan→ochre→red_brown_dark→dark_maroon). 잡몹 예산 idle4/walk4/attack5/death4 x3방향=51프레임
(hit은 idle 재사용).

출력: godot\\assets\\sprites\\monsters\\mob_wolf_feral_{idle,walk,attack,death}.png
      (idle/walk/death 144x84, attack 180x84) + 각 파일의 4배 확대 프리뷰(_preview_ 접두사)
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).parent))
from edg32_palette import RGB
from sprite_source_common import (
    RAW_SRC_DIR,
    ASSETS_DIR,
    ensure_outline,
    fade,
    new_sheet,
    paste_frame,
    recolor_ramp4,
    resize_nearest,
    save_with_preview,
    snap_to_colors,
)

SRC_PATH = RAW_SRC_DIR / "wolfsheet1_zerohero.png"
OUT_DIR = ASSETS_DIR / "sprites" / "monsters"

RIGHT_OFFSET_X = 320  # 4족 측면 늑대는 오른쪽 절반
SRC_CELL_W = 64  # 늑대 한 마리는 64px 폭 셀을 차지(머리~꼬리 온전) - 이전 32px 오해가 버그 원인
OUT_CELL = (36, 28)  # 표준 체급 신규격(STYLE_GUIDE 1-2, 2026-07-27 +4/+4) - 구 32x24에서 상향
TARGET_W = 30  # 실체 목표 폭 (실체 약 30x19)
TARGET_H = 19  # 실체 목표 높이

# 오른쪽 절반의 서브행 y밴드(위 그리드 설명 참조). 값은 원본 알파 점유 프로파일의
# 국소 최소점(행 간 골)에서 산출.
BANDS = {
    "TOP": (1, 32),
    "A": (55, 96),
    "B": (97, 128),
    "C": (129, 160),
    "D": (161, 192),
}

# 야수 가죽 4단 램프(STYLE_GUIDE 3-2-1, EDG32 내 인접 명도 - 따뜻한 갈색 → 어두운 적갈)
OUTLINE = RGB["darkest"]
SHADOW2 = RGB["dark_maroon"]  # 최암부(내부 그림자2)
SHADOW = RGB["red_brown_dark"]  # 그림자1
BASE = RGB["ochre"]  # 기본
HIGHLIGHT = RGB["tan"]  # 하이라이트
SNAP_COLORS = [OUTLINE, SHADOW2, SHADOW, BASE, HIGHLIGHT]


def extract_cell(arr: np.ndarray, band: str, col: int) -> Image.Image:
    """오른쪽 절반의 (band, col) 위치에서 64px 셀을 크롭 → 가장 큰 연결 성분만 남겨
    인접 늑대 잔상 제거 → 알파 bbox로 autotrim → 온전한 측면 늑대 한 마리 반환."""
    y0, y1 = BANDS[band]
    x0 = RIGHT_OFFSET_X + col * SRC_CELL_W
    cell = arr[y0:y1, x0 : x0 + SRC_CELL_W].copy()
    mask = cell[:, :, 3] > 32
    labels, n = ndimage.label(mask)
    if n == 0:
        raise ValueError(f"빈 셀: band={band} col={col}")
    sizes = ndimage.sum(np.ones_like(labels), labels, range(1, n + 1))
    keep = int(np.argmax(sizes)) + 1
    keep_mask = labels == keep
    cell[~keep_mask] = (0, 0, 0, 0)
    ys, xs = np.where(keep_mask)
    cell = cell[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    return Image.fromarray(cell, "RGBA")


def get_frame(arr: np.ndarray, band: str, col: int) -> Image.Image:
    """온전한 측면 늑대를 목표 크기로 축소 후 EDG32 재양자화 + 아웃라인."""
    cell = extract_cell(arr, band, col)
    w, h = cell.size
    factor = min(1.0, TARGET_W / w, TARGET_H / h)
    if factor < 1.0:
        nw, nh = max(1, round(w * factor)), max(1, round(h * factor))
        cell = cell.resize((nw, nh), Image.NEAREST)
    recolored = recolor_ramp4(
        cell, OUTLINE, SHADOW2, SHADOW, BASE, HIGHLIGHT,
        t_outline=0.16, t_shadow2=0.34, t_shadow1=0.52, t_highlight=0.80,
    )
    return ensure_outline(recolored, OUTLINE)


def make_down_up_approx(frame: Image.Image, up: bool) -> Image.Image:
    """측면 원화 기반 하/상 방향 간이 근사 - 좌우 폭을 55%로 압축해 '정면에 가까워 보이는'
    실루엣을 만든다 (정식 원화 부재에 따른 임시 처리, ASSET_SOURCES.md에 한계 기록).
    씬(wolf.tscn)은 측면 행만 사용하므로 게임 표시에는 영향 없음."""
    w, h = frame.size
    narrow = resize_nearest(frame, (max(1, int(w * 0.55)), h))
    narrow = snap_to_colors(narrow, SNAP_COLORS)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.paste(narrow, ((w - narrow.width) // 2, 0))
    if up:
        canvas = canvas.transpose(Image.FLIP_TOP_BOTTOM).transpose(Image.FLIP_TOP_BOTTOM)
    return ensure_outline(canvas, OUTLINE)


def _rows_from_side(side: list) -> tuple[list, list, list]:
    down = [make_down_up_approx(f, up=False) for f in side]
    up = [make_down_up_approx(f, up=True) for f in side]
    return down, side, up


def build_idle(arr: np.ndarray) -> tuple[list, list, list]:
    a, b = get_frame(arr, "TOP", 0), get_frame(arr, "TOP", 1)
    return _rows_from_side([a, b, a, b])


def build_walk(arr: np.ndarray) -> tuple[list, list, list]:
    return _rows_from_side([get_frame(arr, "B", c) for c in (0, 1, 2, 3)])


def build_attack(arr: np.ndarray) -> tuple[list, list, list]:
    howl1 = get_frame(arr, "A", 2)  # 예고: 고개 반쯤 치켜듦
    howl2 = get_frame(arr, "A", 3)  # 예고: 고개 완전히 치켜듦(하울)
    bite1 = get_frame(arr, "D", 2)  # 발동: 입 벌린 돌진
    bite2 = get_frame(arr, "D", 3)  # 발동: 물기
    rest = get_frame(arr, "B", 0)  # 회수: 평상 자세
    return _rows_from_side([howl1, howl2, bite1, bite2, rest])


def build_death(arr: np.ndarray) -> tuple[list, list, list]:
    recoil = get_frame(arr, "A", 3)  # 피격에 고개 젖힘
    crouch = get_frame(arr, "TOP", 2)  # 웅크림
    collapse = get_frame(arr, "TOP", 3)  # 주저앉음
    faded = fade(collapse, 0.5)  # 페이드아웃
    return _rows_from_side([recoil, crouch, collapse, faded])


def make_sheet(down: list, side: list, up: list) -> Image.Image:
    cols = max(len(down), len(side), len(up))
    sheet = new_sheet(cols, 3, OUT_CELL)
    for row, frames in enumerate([down, side, up]):
        for col, frame in enumerate(frames):
            paste_frame(sheet, frame, col, row, OUT_CELL)
    return sheet


def main() -> None:
    if not SRC_PATH.exists():
        raise SystemExit(
            f"소싱 원본이 없습니다: {SRC_PATH}\n"
            "https://opengameart.org/content/lpc-wolf-animation 에서 재다운로드 필요."
        )
    arr = np.array(Image.open(SRC_PATH).convert("RGBA"))
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    save_with_preview(make_sheet(*build_idle(arr)), OUT_DIR / "mob_wolf_feral_idle.png")
    save_with_preview(make_sheet(*build_walk(arr)), OUT_DIR / "mob_wolf_feral_walk.png")
    save_with_preview(make_sheet(*build_attack(arr)), OUT_DIR / "mob_wolf_feral_attack.png")
    save_with_preview(make_sheet(*build_death(arr)), OUT_DIR / "mob_wolf_feral_death.png")
    print("들개 마수 스프라이트 생성 완료(36x28 신규격, 4단 명암, 전신 유지):", OUT_DIR)


if __name__ == "__main__":
    main()
