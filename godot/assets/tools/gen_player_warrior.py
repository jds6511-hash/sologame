"""AR-1: 전사 플레이어 스프라이트 - Pillow 절차 생성 **플레이스홀더**.

**플레이스홀더 — 추후 교체 필요**
CC0/무료 라이선스 소싱을 우선 시도했으나(OpenGameArt 검색: LPC 계열 전사 원화는 대부분
"Universal LPC Spritesheet Character Generator"라는 웹 생성기로만 완성된 조합을 뽑을 수 있어
(정적 다운로드로는 body/armor/weapon 레이어가 분리돼 있어 조합 합성이 필요), 32x32 캔버스에
칼을 든 판타지 전사 외형 + idle/walk/attack/hit/death 5종 애니메이션을 모두 갖춘 CC0 정적
스프라이트시트는 찾지 못함 - 대체로 발견된 CC0 캐릭터(RPGSoldier32x32 등)는 SF 우주복 스타일로
장르가 맞지 않고 attack/hit/death 프레임도 없었다), 이번 M2에서는 Pillow 절차 생성으로
**실루엣·크기 규격·팔레트만 맞춘 단순 블록형 플레이스홀더**를 제작한다
(디렉터 지시: "M2는 손맛 검증이 목적 - 플레이스홀더로도 게이트 통과 가능").
추후 CC0 원화를 확보하면 이 스크립트의 출력을 교체할 것 (godot\\assets\\CREDITS.md에도
플레이스홀더임을 기록).

**2026-07-18 개정 (G2-2, 스타듀밸리 비율 정합)**:
STYLE_GUIDE.md 1-2장 개정으로 캔버스가 **32x32 -> 16x32(가로 1타일 x 세로 2타일)** 로
슬림화됐다. 세로(32px)는 구 규격과 동일해 기존 Y좌표 레이아웃(머리/몸통/다리 배치)을
그대로 유지하고, 가로(32->16)만 절반으로 좁혀 각 부위 X좌표를 재설계했다
(실체 목표 약 12x28 - 팔 끝까지 폭 12px, 머리 폭 8px, 몸통 폭 8px). 파일명·행 구성(3방향:
하/측/상)·프레임 수·애니메이션 순서는 변경 없음.

STYLE_GUIDE.md 준수:
- 1-2장: 캔버스 16x32(1타일x2타일), 실체 약 12x28, 발밑 기준점(하단 중앙)
- 2장: EDG32 32색만 사용 (직접 RGB 튜플만 그려 안티앨리어싱 원천 차단)
- 3-1장: 1px 아웃라인 #181425
- 3-2장: 재질당 3단 램프(기본+그림자+하이라이트), 광원 위쪽·약간 왼쪽
- 3-3장: 플레이어 프레임 예산 - idle4/walk6/attack4/hit1/death4 x3방향 = 57프레임 (90 이내)

출력: godot\\assets\\sprites\\player\\player_warrior_{idle,walk,attack,hit,death}.png
      (각 3행[하/측/상] x N열, 16x32 셀) + 각 파일의 4배 확대 프리뷰(_preview_ 접두사)
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from edg32_palette import RGB
from sprite_source_common import ASSETS_DIR, ensure_outline, fade, new_sheet, save_with_preview

CELL_W = 16
CELL_H = 32
OUT_DIR = ASSETS_DIR / "sprites" / "player"

OUTLINE = RGB["darkest"]
SKIN_BASE = RGB["apricot"]
SKIN_SHADOW = RGB["ochre"]
SKIN_HI = RGB["light_apricot"]
HAIR = RGB["red_brown_dark"]
ARMOR_BASE = RGB["blue_gray"]
ARMOR_SHADOW = RGB["dark_blue_gray"]
ARMOR_HI = RGB["light_blue_gray"]
PANTS_BASE = RGB["navy_gray"]
PANTS_SHADOW = RGB["dark_navy"]
SCARF = RGB["blue"]  # 아군 식별 포인트 (STYLE_GUIDE 6-1)
BLADE = RGB["light_blue_gray"]
BLADE_HI = RGB["white"]
HILT = RGB["tan"]


def blank() -> Image.Image:
    return Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))


def rect(im: Image.Image, x0: int, y0: int, x1: int, y1: int, color: tuple[int, int, int]) -> None:
    px = im.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            if 0 <= x < CELL_W and 0 <= y < CELL_H:
                px[x, y] = (*color, 255)


def draw_body(im: Image.Image, direction: str, leg_dy: tuple[int, int], arm_dx: int, bob: int) -> None:
    """direction: 'down'(정면) / 'side'(측면, 우측 기준) / 'up'(후면). leg_dy=(왼다리,오른다리) 수직오프셋.

    X좌표는 cx=8(캔버스 폭 16의 중앙) 기준 재설계: 머리/몸통 8px, 다리 6px, 팔 끝까지 12px
    (실체 약 12x28, STYLE_GUIDE 1-2). Y좌표는 구 32x32 규격과 동일하게 유지(세로는 미변경).
    """
    cx = CELL_W // 2  # 8
    ly, ry = leg_dy

    # 다리 (하단, 발밑 y=30 기준) - 다리 폭 2px씩
    rect(im, cx - 3, 22 + ly, cx - 1, 30 + ly, PANTS_SHADOW)
    rect(im, cx - 3, 22 + ly, cx - 2, 29 + ly, PANTS_BASE)
    rect(im, cx + 1, 22 + ry, cx + 3, 30 + ry, PANTS_SHADOW)
    rect(im, cx + 2, 22 + ry, cx + 3, 29 + ry, PANTS_BASE)

    top = 13 + bob
    bottom = 22 + bob
    # 몸통(갑옷) - 폭 8px(cx-4~cx+4)
    rect(im, cx - 4, top, cx + 4, bottom, ARMOR_SHADOW)
    rect(im, cx - 4, top, cx + 1, bottom, ARMOR_BASE)
    rect(im, cx - 4, top, cx - 3, bottom, ARMOR_HI)
    rect(im, cx - 2, top, cx + 2, top + 2, SCARF)  # 목 스카프 포인트

    # 팔 - 몸통 바깥 cx+-6까지(폭 12px 전신 실루엣의 최대폭, 캔버스 여백 2px는 무기 돌출용)
    rect(im, cx - 6 + arm_dx, top + 1, cx - 4 + arm_dx, top + 8, ARMOR_SHADOW)
    rect(im, cx + 4 - arm_dx, top + 1, cx + 6 - arm_dx, top + 8, ARMOR_BASE)

    # 머리 - 폭 8px(cx-4~cx+4), STYLE_GUIDE "머리 ~8px" 그대로 충족
    hy0, hy1 = 4 + bob, 13 + bob
    rect(im, cx - 4, hy0, cx + 4, hy1, SKIN_SHADOW)
    rect(im, cx - 4, hy0, cx + 2, hy1, SKIN_BASE)
    rect(im, cx - 4, hy0, cx - 3, hy1 - 3, SKIN_HI)
    rect(im, cx - 4, hy0, cx + 4, hy0 + 3, HAIR)  # 앞머리
    if direction == "up":
        rect(im, cx - 4, hy0, cx + 4, hy1 - 2, HAIR)  # 후면은 뒤통수 머리로 덮음
    elif direction == "down":
        rect(im, cx - 1, hy0 + 4, cx, hy0 + 5, OUTLINE)  # 눈
        rect(im, cx + 1, hy0 + 4, cx + 2, hy0 + 5, OUTLINE)


def draw_sword(im: Image.Image, direction: str, pose: str, arm_dx: int) -> None:
    if direction == "up":
        return  # 후면은 검이 등 뒤로 가려짐(단순화)
    cx = CELL_W // 2
    side_x = cx + 6 - arm_dx if direction != "side" else cx + 5
    if pose == "idle":
        rect(im, side_x, 11, side_x + 1, 22, BLADE)
        rect(im, side_x, 11, side_x + 1, 18, BLADE_HI)
        rect(im, side_x - 1, 21, side_x + 2, 23, HILT)
    elif pose == "windup":
        rect(im, side_x - 1, 6, side_x + 2, 9, BLADE)
        rect(im, side_x - 1, 6, side_x + 1, 8, BLADE_HI)
        rect(im, side_x - 2, 9, side_x + 1, 11, HILT)
    elif pose == "hit":
        rect(im, side_x, 13, side_x + 5, 15, BLADE)
        rect(im, side_x, 13, side_x + 5, 14, BLADE_HI)
        rect(im, side_x - 2, 14, side_x + 1, 16, HILT)
    elif pose == "recover":
        rect(im, side_x, 14, side_x + 1, 23, BLADE)
        rect(im, side_x - 1, 21, side_x + 2, 23, HILT)


def frame(direction: str, leg_dy=(0, 0), arm_dx=0, bob=0, sword="idle") -> Image.Image:
    im = blank()
    draw_body(im, direction, leg_dy, arm_dx, bob)
    draw_sword(im, direction, sword, arm_dx)
    return ensure_outline(im, OUTLINE)


def collapsed(direction: str, stage: int) -> Image.Image:
    """사망 모션 - 세워진 자세 대신 완전히 새로 그려서 회전/보간 없이 팔레트를 보장."""
    im = blank()
    cx = CELL_W // 2
    y = 24 + stage * 2
    w = 12 - stage
    rect(im, cx - w // 2, y, cx + w // 2, y + 4, ARMOR_SHADOW)
    rect(im, cx - w // 2, y, cx + w // 2 - 2, y + 3, ARMOR_BASE)
    rect(im, cx - w // 2 - 4, y + 1, cx - w // 2, y + 4, SKIN_SHADOW)
    rect(im, cx - w // 2 - 5, y + 1, cx - w // 2 - 3, y + 3, SKIN_BASE)
    rect(im, cx - w // 2 - 5, y + 1, cx - w // 2 - 3, y + 2, HAIR)
    return ensure_outline(im, OUTLINE)


DIRECTIONS = ["down", "side", "up"]


def build_idle() -> dict[str, list[Image.Image]]:
    bobs = [0, -1, 0, -1]
    return {d: [frame(d, bob=b) for b in bobs] for d in DIRECTIONS}


def build_walk() -> dict[str, list[Image.Image]]:
    cycle = [
        ((0, -2), 1, 0),
        ((1, -1), 1, -1),
        ((2, 0), 0, 0),
        ((0, 2), -1, 0),
        ((-1, 1), -1, -1),
        ((-2, 0), 0, 0),
    ]
    out = {}
    for d in DIRECTIONS:
        out[d] = [frame(d, leg_dy=(l, r), arm_dx=a, bob=b) for (l, r), a, b in cycle]
    return out


def build_attack() -> dict[str, list[Image.Image]]:
    seq = ["windup", "hit", "recover", "recover"]
    out = {}
    for d in DIRECTIONS:
        out[d] = [frame(d, sword=p, bob=(-1 if p == "windup" else 0)) for p in seq]
    return out


def build_hit() -> dict[str, list[Image.Image]]:
    return {d: [frame(d, leg_dy=(1, 1), bob=1)] for d in DIRECTIONS}


def build_death() -> dict[str, list[Image.Image]]:
    out = {}
    for d in DIRECTIONS:
        f1 = frame(d, leg_dy=(1, 1), bob=1)
        f2 = collapsed(d, 0)
        f3 = collapsed(d, 1)
        f4 = fade(collapsed(d, 1), 0.5)
        out[d] = [f1, f2, f3, f4]
    return out


def make_sheet(by_direction: dict[str, list[Image.Image]]) -> Image.Image:
    cols = max(len(v) for v in by_direction.values())
    sheet = new_sheet(cols, 3, (CELL_W, CELL_H))
    for row, d in enumerate(DIRECTIONS):
        for col, fr in enumerate(by_direction[d]):
            sheet.paste(fr, (col * CELL_W, row * CELL_H))
    return sheet


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    save_with_preview(make_sheet(build_idle()), OUT_DIR / "player_warrior_idle.png")
    save_with_preview(make_sheet(build_walk()), OUT_DIR / "player_warrior_walk.png")
    save_with_preview(make_sheet(build_attack()), OUT_DIR / "player_warrior_attack.png")
    save_with_preview(make_sheet(build_hit()), OUT_DIR / "player_warrior_hit.png")
    save_with_preview(make_sheet(build_death()), OUT_DIR / "player_warrior_death.png")
    total = (4 + 6 + 4 + 1 + 4) * 3
    print(f"전사 플레이어 플레이스홀더 생성 완료(16x32 신규격): {OUT_DIR} (총 {total}프레임)")


if __name__ == "__main__":
    main()
