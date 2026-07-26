"""AR-1: 전사 플레이어 스프라이트 - Pillow 절차 생성 **플레이스홀더**.

**플레이스홀더 — 추후 교체 필요**
CC0/무료 소싱을 우선 시도했으나 판타지 대검 전사 + idle/walk/attack/hit/death 5종 애니메이션을
모두 갖춘 정적 CC0 스프라이트시트를 확보하지 못해(사유: ASSET_SOURCES.md 2장), 실루엣·크기
규격·팔레트만 맞춘 절차 생성 플레이스홀더를 제작한다. 추후 정식 원화 확보 시 이 스크립트의
출력만 교체하면 된다(파일명·시트 규격 유지).

**2026-07-27 개정 (스톤샤드식 안 1, STYLE_GUIDE 1-2·1-2-2·3-2-1장 디렉터 확정)**:
캔버스가 **16x32 -> 20x36(~3.3등신)** 로 상향됐다. 디렉터 승인 샘플(전사 20x36, 대검·파란
스카프·청회색 판금·적갈 머리)의 정면/측면 디자인을 정식 애니메이션(3방향 x idle/walk/attack/
hit/death)으로 확장했다. 파일명·행 구성(하/측/상)·프레임 수(idle4/walk6/attack4/hit1/death4)·
애니메이션 순서는 구 규격과 동일, 셀 크기와 명암 단수만 신규격으로 바꿨다.

STYLE_GUIDE.md 준수:
- 1-2장: 캔버스 20x36(~1.25타일 x 2.25타일), 실체 약 15x33(~3.3등신, 머리 ~10px), 발밑 원점(하단 중앙)
- 2장: EDG32 32색만 사용 (직접 RGB 튜플만 그려 안티앨리어싱 원천 차단)
- 3-1장: 1px 아웃라인 #181425 (내부 선은 램프 그림자색 사용)
- 3-2-1장: 캐릭터 4단 램프 - 피부/갑옷을 EDG32 내 인접 명도 4색으로 셰이딩(광원 위쪽·약간 왼쪽)
- 3-3장: 플레이어 프레임 예산 - idle4/walk6/attack4/hit1/death4 x3방향 = 57프레임 (90 이내)

출력: godot\\assets\\sprites\\player\\player_warrior_{idle,walk,attack,hit,death}.png
      (각 3행[하/측/상] x N열, 20x36 셀) + 각 파일의 4배 확대 프리뷰(_preview_ 접두사)
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from edg32_palette import RGB
from sprite_source_common import ASSETS_DIR, ensure_outline, fade, new_sheet, save_with_preview

CELL_W = 20
CELL_H = 36
OUT_DIR = ASSETS_DIR / "sprites" / "player"

OUTLINE = RGB["darkest"]
# 피부 4단 (STYLE_GUIDE 3-2-1 램프 예시)
SKIN_HI = RGB["light_apricot"]
SKIN_BASE = RGB["apricot"]
SKIN_MID = RGB["tan"]
SKIN_SHADOW = RGB["ochre"]
# 머리(적갈)
HAIR = RGB["red_brown_dark"]
HAIR_DARK = RGB["dark_maroon"]
# 갑옷 4단 (청회색 램프 — 전사 정체성)
ARMOR_HI = RGB["light_blue_gray"]
ARMOR_BASE = RGB["blue_gray"]
ARMOR_SHADOW = RGB["dark_blue_gray"]
ARMOR_DARK = RGB["navy_gray"]
# 스카프(아군 식별 포인트, STYLE_GUIDE 6-1)
SCARF = RGB["blue"]
SCARF_HI = RGB["cyan"]
# 바지/부츠
PANTS_BASE = RGB["navy_gray"]
PANTS_SHADOW = RGB["dark_navy"]
BOOT = RGB["dark_navy"]
# 대검
BLADE = RGB["light_blue_gray"]
BLADE_HI = RGB["white"]
BLADE_SHADOW = RGB["blue_gray"]
HILT = RGB["tan"]
HILT_DARK = RGB["red_brown_dark"]
POMMEL = RGB["gold"]
BELT = RGB["red_brown_dark"]

CX = CELL_W // 2  # 10


def blank() -> Image.Image:
    return Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))


def rect(im: Image.Image, x0: int, y0: int, x1: int, y1: int, color: tuple[int, int, int]) -> None:
    px = im.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            if 0 <= x < CELL_W and 0 <= y < CELL_H:
                px[x, y] = (*color, 255)


# ---------------------------------------------------------------- 다리(공통)
def draw_legs(im: Image.Image, ldy: int, rdy: int) -> None:
    cx = CX
    # 왼다리
    rect(im, cx - 4, 24 + ldy, cx - 1, 33 + ldy, PANTS_SHADOW)
    rect(im, cx - 4, 24 + ldy, cx - 2, 32 + ldy, PANTS_BASE)
    # 오른다리
    rect(im, cx + 1, 24 + rdy, cx + 4, 33 + rdy, PANTS_SHADOW)
    rect(im, cx + 1, 24 + rdy, cx + 3, 32 + rdy, PANTS_BASE)
    # 부츠
    rect(im, cx - 4, 31 + ldy, cx - 1, 33 + ldy, BOOT)
    rect(im, cx + 1, 31 + rdy, cx + 4, 33 + rdy, BOOT)


# ---------------------------------------------------------------- 정면(down)
def draw_body_down(im: Image.Image, bob: int, arm_dx: int) -> None:
    cx = CX
    b = bob
    # 몸통 갑옷 4단 (y=13~24)
    rect(im, cx - 5, 13 + b, cx + 5, 24 + b, ARMOR_DARK)
    rect(im, cx - 5, 13 + b, cx + 4, 24 + b, ARMOR_SHADOW)
    rect(im, cx - 5, 13 + b, cx + 2, 24 + b, ARMOR_BASE)
    rect(im, cx - 5, 13 + b, cx - 3, 22 + b, ARMOR_HI)  # 왼쪽 하이라이트
    rect(im, cx - 1, 15 + b, cx, 22 + b, ARMOR_DARK)  # 중앙 이음선
    # 벨트
    rect(im, cx - 5, 22 + b, cx + 5, 24 + b, BELT)
    rect(im, cx - 1, 22 + b, cx + 1, 24 + b, POMMEL)  # 버클
    # 견갑 + 팔
    rect(im, cx - 7 - arm_dx, 13 + b, cx - 4, 18 + b, ARMOR_SHADOW)  # 왼 견갑
    rect(im, cx - 7 - arm_dx, 13 + b, cx - 5, 17 + b, ARMOR_BASE)
    rect(im, cx + 4, 13 + b, cx + 7 + arm_dx, 18 + b, ARMOR_DARK)  # 오른 견갑
    rect(im, cx + 4, 13 + b, cx + 6 + arm_dx, 17 + b, ARMOR_SHADOW)
    rect(im, cx - 7 - arm_dx, 18 + b, cx - 4, 24 + b, ARMOR_SHADOW)  # 왼팔
    rect(im, cx - 7 - arm_dx, 18 + b, cx - 6 - arm_dx, 23 + b, ARMOR_BASE)
    rect(im, cx + 5, 18 + b, cx + 7 + arm_dx, 24 + b, ARMOR_DARK)  # 오른팔(검 쥔 쪽)
    # 손(피부 3단)
    rect(im, cx - 7 - arm_dx, 23 + b, cx - 4, 26 + b, SKIN_MID)
    rect(im, cx - 7 - arm_dx, 23 + b, cx - 5 - arm_dx, 25 + b, SKIN_BASE)
    # 목/스카프
    rect(im, cx - 3, 11 + b, cx + 3, 14 + b, SCARF)
    rect(im, cx - 3, 11 + b, cx, 12 + b, SCARF_HI)
    # 머리(피부 4단, y=2~12)
    rect(im, cx - 4, 4 + b, cx + 4, 12 + b, SKIN_SHADOW)
    rect(im, cx - 4, 4 + b, cx + 3, 12 + b, SKIN_MID)
    rect(im, cx - 4, 4 + b, cx + 2, 12 + b, SKIN_BASE)
    rect(im, cx - 4, 4 + b, cx - 2, 11 + b, SKIN_HI)  # 왼뺨 하이라이트
    # 머리카락
    rect(im, cx - 5, 2 + b, cx + 5, 6 + b, HAIR)
    rect(im, cx - 5, 2 + b, cx - 2, 9 + b, HAIR)
    rect(im, cx + 4, 3 + b, cx + 5, 9 + b, HAIR)
    rect(im, cx - 5, 2 + b, cx - 3, 5 + b, HAIR_DARK)
    rect(im, cx - 4, 6 + b, cx + 4, 7 + b, HAIR)
    # 눈
    rect(im, cx - 3, 8 + b, cx - 2, 9 + b, OUTLINE)
    rect(im, cx + 1, 8 + b, cx + 2, 9 + b, OUTLINE)


# ---------------------------------------------------------------- 측면(side, 우향)
def draw_body_side(im: Image.Image, bob: int, arm_dx: int) -> None:
    cx = CX
    b = bob
    # 몸통 갑옷(측면 폭 좁게, 4단)
    rect(im, cx - 3, 13 + b, cx + 4, 24 + b, ARMOR_DARK)
    rect(im, cx - 3, 13 + b, cx + 3, 24 + b, ARMOR_SHADOW)  # 등(뒤) 그림자
    rect(im, cx - 1, 13 + b, cx + 4, 24 + b, ARMOR_BASE)
    rect(im, cx + 2, 13 + b, cx + 4, 22 + b, ARMOR_HI)  # 앞가슴 하이라이트
    rect(im, cx - 3, 15 + b, cx - 2, 22 + b, ARMOR_DARK)  # 등 최암부
    # 벨트
    rect(im, cx - 3, 22 + b, cx + 4, 24 + b, BELT)
    # 팔(검 쥔 앞팔)
    rect(im, cx + 1 + arm_dx, 14 + b, cx + 4 + arm_dx, 20 + b, ARMOR_SHADOW)
    rect(im, cx + 2 + arm_dx, 14 + b, cx + 4 + arm_dx, 19 + b, ARMOR_BASE)
    rect(im, cx + 2 + arm_dx, 20 + b, cx + 5 + arm_dx, 26 + b, SKIN_MID)  # 손
    rect(im, cx + 2 + arm_dx, 20 + b, cx + 4 + arm_dx, 24 + b, SKIN_BASE)
    # 스카프
    rect(im, cx - 3, 11 + b, cx + 4, 14 + b, SCARF)
    rect(im, cx - 4, 12 + b, cx - 1, 15 + b, SCARF)  # 뒤로 날리는 자락
    rect(im, cx, 11 + b, cx + 3, 12 + b, SCARF_HI)
    # 머리(측면 프로필, 피부 4단)
    rect(im, cx - 3, 4 + b, cx + 3, 12 + b, SKIN_SHADOW)
    rect(im, cx - 1, 4 + b, cx + 3, 12 + b, SKIN_MID)
    rect(im, cx, 4 + b, cx + 3, 12 + b, SKIN_BASE)
    rect(im, cx + 1, 4 + b, cx + 3, 10 + b, SKIN_HI)  # 앞뺨 하이라이트
    rect(im, cx + 3, 7 + b, cx + 4, 10 + b, SKIN_BASE)  # 코
    # 머리카락(뒤통수)
    rect(im, cx - 3, 2 + b, cx + 3, 6 + b, HAIR)
    rect(im, cx - 3, 2 + b, cx, 11 + b, HAIR)
    rect(im, cx - 3, 2 + b, cx - 1, 6 + b, HAIR_DARK)
    rect(im, cx - 1, 6 + b, cx + 2, 7 + b, HAIR)
    # 눈
    rect(im, cx + 1, 8 + b, cx + 2, 9 + b, OUTLINE)


# ---------------------------------------------------------------- 후면(up)
def draw_body_up(im: Image.Image, bob: int, arm_dx: int) -> None:
    cx = CX
    b = bob
    # 몸통 갑옷(뒷면, 정면과 같은 실루엣이나 하이라이트 절제)
    rect(im, cx - 5, 13 + b, cx + 5, 24 + b, ARMOR_DARK)
    rect(im, cx - 5, 13 + b, cx + 3, 24 + b, ARMOR_SHADOW)
    rect(im, cx - 5, 13 + b, cx + 1, 24 + b, ARMOR_BASE)
    rect(im, cx - 5, 13 + b, cx - 3, 22 + b, ARMOR_HI)
    rect(im, cx - 1, 15 + b, cx, 22 + b, ARMOR_DARK)  # 등 중앙 이음선
    # 벨트
    rect(im, cx - 5, 22 + b, cx + 5, 24 + b, BELT)
    # 견갑 + 팔
    rect(im, cx - 7 - arm_dx, 13 + b, cx - 4, 18 + b, ARMOR_SHADOW)
    rect(im, cx - 7 - arm_dx, 13 + b, cx - 5, 17 + b, ARMOR_BASE)
    rect(im, cx + 4, 13 + b, cx + 7 + arm_dx, 18 + b, ARMOR_DARK)
    rect(im, cx + 4, 13 + b, cx + 6 + arm_dx, 17 + b, ARMOR_SHADOW)
    rect(im, cx - 7 - arm_dx, 18 + b, cx - 4, 24 + b, ARMOR_SHADOW)
    rect(im, cx + 5, 18 + b, cx + 7 + arm_dx, 24 + b, ARMOR_DARK)
    # 손(피부)
    rect(im, cx - 7 - arm_dx, 23 + b, cx - 4, 26 + b, SKIN_MID)
    rect(im, cx + 5, 23 + b, cx + 7 + arm_dx, 26 + b, SKIN_MID)
    # 스카프(목 뒤)
    rect(im, cx - 3, 11 + b, cx + 3, 14 + b, SCARF)
    rect(im, cx - 3, 12 + b, cx + 3, 13 + b, SCARF_HI)
    # 뒤통수(전부 머리카락)
    rect(im, cx - 5, 2 + b, cx + 5, 12 + b, HAIR)
    rect(im, cx - 5, 2 + b, cx - 2, 12 + b, HAIR_DARK)  # 왼쪽 그림자결
    rect(im, cx - 3, 4 + b, cx + 3, 10 + b, HAIR)
    rect(im, cx - 1, 5 + b, cx + 2, 9 + b, HAIR_DARK)  # 뒤통수 가마


# ---------------------------------------------------------------- 대검
def draw_sword(im: Image.Image, direction: str, pose: str, arm_dx: int) -> None:
    if direction == "up":
        # 후면: 대검을 등에 비스듬히 멘 자락만 표현(정체성 유지)
        rect(im, CX + 2, 6, CX + 4, 24, BLADE_SHADOW)
        rect(im, CX + 2, 6, CX + 3, 24, BLADE)
        rect(im, CX + 1, 24, CX + 5, 26, HILT_DARK)
        return
    cx = CX
    if direction == "side":
        bx = cx + 3 + arm_dx  # 검 기준 x(측면)
        if pose == "idle":
            rect(im, bx, 5, bx + 3, 24, BLADE_SHADOW)
            rect(im, bx, 5, bx + 2, 24, BLADE)
            rect(im, bx, 5, bx + 1, 24, BLADE_HI)
            rect(im, bx, 3, bx + 2, 6, BLADE)
            rect(im, bx, 2, bx + 1, 4, BLADE_HI)
            rect(im, bx - 1, 24, bx + 4, 26, HILT_DARK)
            rect(im, bx - 1, 24, bx + 4, 25, HILT)
            rect(im, bx + 1, 26, bx + 2, 30, HILT)
            rect(im, bx, 30, bx + 3, 32, POMMEL)
        elif pose == "windup":  # 뒤로 치켜듦
            rect(im, cx - 6, 2, cx - 3, 5, BLADE)
            rect(im, cx - 6, 2, cx - 4, 4, BLADE_HI)
            rect(im, cx - 5, 5, cx - 2, 14, BLADE_SHADOW)
            rect(im, cx - 5, 5, cx - 3, 14, BLADE)
            rect(im, cx - 3, 14, cx, 16, HILT)
        elif pose == "hit":  # 앞으로 크게 베기(수평)
            rect(im, cx + 4, 12, cx + 12, 14, BLADE_SHADOW)
            rect(im, cx + 4, 12, cx + 12, 13, BLADE_HI)
            rect(im, cx + 10, 10, cx + 13, 16, BLADE)  # 검신 끝 넓힘
            rect(im, cx + 2, 13, cx + 5, 16, HILT)
        elif pose == "recover":  # 앞아래로 내림
            rect(im, cx + 4, 16, cx + 7, 32, BLADE_SHADOW)
            rect(im, cx + 4, 16, cx + 6, 32, BLADE)
            rect(im, cx + 3, 16, cx + 7, 18, HILT)
        return
    # ----- down -----
    if pose == "idle":
        rect(im, cx + 6, 5, cx + 9, 24, BLADE_SHADOW)
        rect(im, cx + 6, 5, cx + 8, 24, BLADE)
        rect(im, cx + 6, 5, cx + 7, 24, BLADE_HI)
        rect(im, cx + 6, 3, cx + 8, 6, BLADE)
        rect(im, cx + 6, 2, cx + 7, 4, BLADE_HI)
        rect(im, cx + 5, 24, cx + 10, 26, HILT_DARK)
        rect(im, cx + 5, 24, cx + 10, 25, HILT)
        rect(im, cx + 7, 26, cx + 8, 30, HILT)
        rect(im, cx + 6, 30, cx + 9, 32, POMMEL)
    elif pose == "windup":  # 머리 위로 치켜듦
        rect(im, cx + 5, 0, cx + 8, 3, BLADE)
        rect(im, cx + 5, 0, cx + 7, 2, BLADE_HI)
        rect(im, cx + 4, 3, cx + 7, 13, BLADE_SHADOW)
        rect(im, cx + 4, 3, cx + 6, 13, BLADE)
        rect(im, cx + 4, 3, cx + 5, 13, BLADE_HI)
        rect(im, cx + 3, 13, cx + 7, 15, HILT)
    elif pose == "hit":  # 앞으로 내려침(정면 사선)
        rect(im, cx + 5, 14, cx + 8, 30, BLADE_SHADOW)
        rect(im, cx + 5, 14, cx + 7, 30, BLADE)
        rect(im, cx + 5, 14, cx + 6, 30, BLADE_HI)
        rect(im, cx + 4, 12, cx + 8, 16, HILT)
    elif pose == "recover":
        rect(im, cx + 6, 16, cx + 9, 30, BLADE_SHADOW)
        rect(im, cx + 6, 16, cx + 8, 30, BLADE)
        rect(im, cx + 5, 24, cx + 10, 26, HILT)


DRAW = {"down": draw_body_down, "side": draw_body_side, "up": draw_body_up}
DIRECTIONS = ["down", "side", "up"]


def frame(direction: str, ldy=0, rdy=0, arm_dx=0, bob=0, sword="idle") -> Image.Image:
    im = blank()
    # 검을 몸 뒤에서 세워 드는 idle/walk는 몸보다 먼저(뒤 레이어), 앞으로 내치는 공격은 몸 뒤에 두되
    # 겹침이 자연스럽도록 idle/windup은 몸 전에, hit/recover는 몸 후에 그린다.
    if sword in ("idle", "windup"):
        draw_sword(im, direction, sword, arm_dx)
        draw_legs(im, ldy, rdy)
        DRAW[direction](im, bob, arm_dx)
    else:
        draw_legs(im, ldy, rdy)
        DRAW[direction](im, bob, arm_dx)
        draw_sword(im, direction, sword, arm_dx)
    return ensure_outline(im, OUTLINE)


def collapsed(direction: str, stage: int) -> Image.Image:
    """사망 - 주저앉는 자세를 새로 그려 회전/보간 없이 팔레트 보장."""
    im = blank()
    cx = CX
    y = 26 + stage * 3
    w = 15 - stage * 2
    # 쓰러진 몸통(청회 4단 약식)
    rect(im, cx - w // 2, y, cx + w // 2, y + 5, ARMOR_DARK)
    rect(im, cx - w // 2, y, cx + w // 2 - 2, y + 4, ARMOR_SHADOW)
    rect(im, cx - w // 2, y, cx + w // 2 - 4, y + 3, ARMOR_BASE)
    # 머리(왼쪽으로 떨군)
    rect(im, cx - w // 2 - 5, y + 1, cx - w // 2, y + 5, SKIN_SHADOW)
    rect(im, cx - w // 2 - 4, y + 1, cx - w // 2 - 1, y + 4, SKIN_MID)
    rect(im, cx - w // 2 - 5, y, cx - w // 2 - 1, y + 2, HAIR)
    # 떨어진 대검
    rect(im, cx + w // 2 - 1, y + 3, cx + w // 2 + 6, y + 5, BLADE)
    rect(im, cx + w // 2 - 1, y + 3, cx + w // 2 + 6, y + 4, BLADE_HI)
    return ensure_outline(im, OUTLINE)


# ---------------------------------------------------------------- 애니메이션 빌드
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
    return {
        d: [frame(d, ldy=l, rdy=r, arm_dx=a, bob=b) for (l, r), a, b in cycle]
        for d in DIRECTIONS
    }


def build_attack() -> dict[str, list[Image.Image]]:
    seq = ["windup", "hit", "recover", "recover"]
    return {
        d: [frame(d, sword=p, bob=(-1 if p == "windup" else 0)) for p in seq]
        for d in DIRECTIONS
    }


def build_hit() -> dict[str, list[Image.Image]]:
    return {d: [frame(d, ldy=1, rdy=1, bob=1)] for d in DIRECTIONS}


def build_death() -> dict[str, list[Image.Image]]:
    out = {}
    for d in DIRECTIONS:
        f1 = frame(d, ldy=1, rdy=1, bob=1)
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
    print(f"전사 플레이어 플레이스홀더 생성 완료(20x36 신규격, 4단 명암): {OUT_DIR} (총 {total}프레임)")


if __name__ == "__main__":
    main()
