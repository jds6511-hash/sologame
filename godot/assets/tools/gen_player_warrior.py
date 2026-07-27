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

**2026-07-27 측면 재디자인 (디렉터 지적: "전사 옆모습이 못생겼다")**:
측면 행(r=1)만 재설계했다 — (1) 스카프를 목~가슴 두꺼운 블록에서 목에 감긴 얇은 칼라(2px)
+ 뒤로 날리는 가는 자락으로 축소, (2) 앞가슴 림 하이라이트·등 최암부·위로 솟은 견갑·앞으로
뻗은 검 쥔 팔·앞/뒤 겹친 측면 다리(발끝 앞으로)로 옆선을 또렷하게, (3) attack 측면 스윙을
windup(뒤 위)→hit(두꺼운 전방 베기)→recover(앞아래 사선)→settle(곧게 내림) 4프레임으로
프레임 간 실루엣 차이를 크게. 정면(r=0)·후면(r=2)은 균형상 유지(손대지 않음). attack 시퀀스
recover×2 중복을 recover+settle로 대체(정면/후면은 settle을 recover와 동일 처리해 규격 유지).

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


# ------------------------------------------------------- 다리(측면: 앞/뒤 겹침)
def draw_legs_side(im: Image.Image, ldy: int, rdy: int) -> None:
    """측면 전용 다리 — 앞다리(밝음)와 뒷다리(어둠)를 겹쳐 세우고 발끝을 앞(우)으로
    내밀어 방향과 옆선을 또렷하게 한다. ldy=뒷다리, rdy=앞다리 상하 오프셋(걷기)."""
    cx = CX
    # 뒷다리(먼저, 어둡게)
    rect(im, cx - 2, 24 + ldy, cx + 1, 33 + ldy, PANTS_SHADOW)
    rect(im, cx - 2, 31 + ldy, cx + 2, 33 + ldy, BOOT)  # 뒤 부츠(발끝 앞으로)
    # 앞다리(밝게)
    rect(im, cx + 0, 24 + rdy, cx + 3, 33 + rdy, PANTS_BASE)
    rect(im, cx + 0, 24 + rdy, cx + 1, 32 + rdy, PANTS_SHADOW)  # 앞다리 뒤 결
    rect(im, cx + 0, 31 + rdy, cx + 4, 33 + rdy, BOOT)  # 앞 부츠(발끝 앞으로)


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
    """측면 재디자인(2026-07-27 디렉터 지적 반영): 앞가슴 볼록·등 곧은 옆선, 위로 솟은
    견갑, 앞으로 뻗은 검 쥔 팔로 '옆으로 선 전사'가 읽히게 한다. 스카프는 목에 감긴
    얇은 칼라(2px) + 뒤로 날리는 가는 자락으로 두께를 크게 줄였다."""
    cx = CX
    b = bob
    # ---- 몸통 갑옷(측면: 등[좌]은 곧게, 가슴[우]은 앞으로 볼록) ----
    rect(im, cx - 3, 14 + b, cx + 4, 24 + b, ARMOR_SHADOW)  # 전체 바탕(그림자)
    rect(im, cx - 1, 14 + b, cx + 4, 23 + b, ARMOR_BASE)  # 앞쪽 기본면
    rect(im, cx - 3, 15 + b, cx - 2, 23 + b, ARMOR_DARK)  # 등 최암부(뒤 옆선)
    rect(im, cx + 3, 15 + b, cx + 4, 21 + b, ARMOR_HI)  # 가슴 앞 림 하이라이트(옆선 강조)
    rect(im, cx + 1, 16 + b, cx + 2, 22 + b, ARMOR_SHADOW)  # 가슴판 세로 이음선
    # ---- 어깨 견갑(위로 볼록, 전사 실루엣) ----
    rect(im, cx - 2, 12 + b, cx + 4, 15 + b, ARMOR_SHADOW)
    rect(im, cx - 1, 12 + b, cx + 3, 14 + b, ARMOR_BASE)
    rect(im, cx - 1, 12 + b, cx + 2, 13 + b, ARMOR_HI)  # 견갑 상단 광
    # ---- 벨트 ----
    rect(im, cx - 3, 22 + b, cx + 4, 24 + b, BELT)
    rect(im, cx + 2, 22 + b, cx + 4, 24 + b, POMMEL)  # 버클
    # ---- 팔(검 쥔 앞팔) ----
    rect(im, cx + 2, 15 + b, cx + 5, 20 + b, ARMOR_SHADOW)
    rect(im, cx + 2, 15 + b, cx + 4, 19 + b, ARMOR_BASE)
    rect(im, cx + 3, 19 + b, cx + 6, 23 + b, ARMOR_DARK)  # 건틀릿
    rect(im, cx + 3, 19 + b, cx + 5, 22 + b, ARMOR_SHADOW)
    rect(im, cx + 3, 18 + b, cx + 6, 22 + b, SKIN_MID)  # 손
    rect(im, cx + 3, 18 + b, cx + 5, 21 + b, SKIN_BASE)
    # ---- 머리(측면 프로필, 우향) ----
    rect(im, cx - 3, 5 + b, cx + 3, 12 + b, SKIN_MID)  # 얼굴 바탕
    rect(im, cx + 0, 5 + b, cx + 3, 12 + b, SKIN_BASE)  # 앞 얼굴
    rect(im, cx + 2, 6 + b, cx + 3, 10 + b, SKIN_HI)  # 앞뺨 광
    rect(im, cx + 0, 10 + b, cx + 2, 12 + b, SKIN_MID)  # 턱 그림자
    rect(im, cx + 3, 8 + b, cx + 4, 10 + b, SKIN_BASE)  # 코(앞으로 돌출)
    # 머리카락
    rect(im, cx - 3, 2 + b, cx + 3, 5 + b, HAIR)  # 상단
    rect(im, cx - 3, 2 + b, cx + 0, 11 + b, HAIR)  # 뒤통수
    rect(im, cx - 3, 3 + b, cx - 1, 10 + b, HAIR_DARK)  # 뒤통수 결(어둠)
    rect(im, cx + 0, 4 + b, cx + 3, 5 + b, HAIR)  # 앞머리(이마 프린지)
    # 눈
    rect(im, cx + 1, 7 + b, cx + 2, 8 + b, OUTLINE)
    # ---- 스카프(얇게: 목 둘레 2px + 뒤로 날리는 가는 자락) ----
    rect(im, cx - 1, 11 + b, cx + 3, 13 + b, SCARF)  # 목 둘레(2px)
    rect(im, cx + 2, 11 + b, cx + 4, 13 + b, SCARF)  # 앞 매듭
    rect(im, cx - 1, 11 + b, cx + 2, 12 + b, SCARF_HI)  # 상단 광
    # 뒤로 날리는 자락(가늘게)
    rect(im, cx - 2, 12 + b, cx + 0, 14 + b, SCARF)
    rect(im, cx - 3, 14 + b, cx - 1, 16 + b, SCARF)
    rect(im, cx - 4, 15 + b, cx - 2, 18 + b, SCARF)
    rect(im, cx - 4, 15 + b, cx - 3, 17 + b, SCARF_HI)


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
        # 측면 재디자인(2026-07-27): 검 들기(windup, 뒤 위로)→앞으로 크게 베기(hit, 두껍게
        # 전방)→내리기(recover, 앞아래 사선)→갈무리(settle, 앞에 곧게)로 프레임 간 실루엣이
        # 확연히 달라지게 해 스윙 가독성을 높였다. idle/walk는 대검을 앞에 세운 대기 자세.
        if pose == "idle":
            bx = cx + 4  # 앞에 세운 대검
            rect(im, bx, 2, bx + 3, 16, BLADE_SHADOW)
            rect(im, bx, 2, bx + 2, 16, BLADE)
            rect(im, bx, 3, bx + 1, 15, BLADE_HI)  # 풀러(가운데 광)
            rect(im, bx, 1, bx + 1, 3, BLADE_HI)  # 칼끝
            rect(im, bx - 2, 16, bx + 4, 18, HILT_DARK)  # 코등이
            rect(im, bx - 2, 16, bx + 4, 17, HILT)
            rect(im, bx, 18, bx + 2, 22, HILT)  # 손잡이
            rect(im, bx - 1, 22, bx + 3, 24, POMMEL)  # 폼멜
        elif pose == "windup":  # 뒤 위로 치켜듦(손→어깨 너머 사선)
            rect(im, cx - 1, 12, cx + 3, 15, HILT_DARK)  # 손 근처 코등이
            rect(im, cx - 1, 13, cx + 2, 15, HILT)
            rect(im, cx - 2, 9, cx + 1, 13, BLADE_SHADOW)
            rect(im, cx - 2, 9, cx + 0, 12, BLADE)
            rect(im, cx - 4, 5, cx + 0, 10, BLADE_SHADOW)
            rect(im, cx - 4, 5, cx - 2, 9, BLADE)
            rect(im, cx - 4, 5, cx - 3, 9, BLADE_HI)
            rect(im, cx - 6, 1, cx - 3, 6, BLADE)  # 칼끝(뒤 위)
            rect(im, cx - 6, 1, cx - 4, 4, BLADE_HI)
        elif pose == "hit":  # 앞으로 크게 베기(두껍게, 칼끝 화면 끝까지)
            rect(im, cx + 2, 17, cx + 5, 21, HILT)  # 손 위치 코등이
            rect(im, cx + 4, 13, cx + 9, 19, BLADE_SHADOW)
            rect(im, cx + 4, 13, cx + 9, 18, BLADE)
            rect(im, cx + 4, 13, cx + 8, 14, BLADE_HI)  # 윗날 광
            rect(im, cx + 8, 14, cx + 9, 18, BLADE)  # 칼끝
        elif pose == "recover":  # 앞아래 사선으로 내림(휘두른 여파)
            rect(im, cx + 1, 17, cx + 4, 20, HILT)
            rect(im, cx + 2, 19, cx + 5, 24, BLADE_SHADOW)
            rect(im, cx + 2, 19, cx + 4, 23, BLADE)
            rect(im, cx + 3, 23, cx + 6, 30, BLADE_SHADOW)
            rect(im, cx + 3, 23, cx + 5, 30, BLADE)
            rect(im, cx + 4, 30, cx + 6, 33, BLADE)  # 칼끝(앞아래)
            rect(im, cx + 3, 20, cx + 4, 29, BLADE_HI)
        elif pose == "settle":  # 갈무리 — 앞에 곧게 내려 세움
            rect(im, cx + 3, 16, cx + 6, 18, HILT)
            rect(im, cx + 4, 18, cx + 7, 30, BLADE_SHADOW)
            rect(im, cx + 4, 18, cx + 6, 30, BLADE)
            rect(im, cx + 4, 19, cx + 5, 29, BLADE_HI)
            rect(im, cx + 4, 30, cx + 6, 32, BLADE)  # 칼끝
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
    elif pose in ("recover", "settle"):  # 정면은 settle을 recover와 동일 처리
        rect(im, cx + 6, 16, cx + 9, 30, BLADE_SHADOW)
        rect(im, cx + 6, 16, cx + 8, 30, BLADE)
        rect(im, cx + 5, 24, cx + 10, 26, HILT)


DRAW = {"down": draw_body_down, "side": draw_body_side, "up": draw_body_up}
DIRECTIONS = ["down", "side", "up"]


def frame(direction: str, ldy=0, rdy=0, arm_dx=0, bob=0, sword="idle") -> Image.Image:
    im = blank()

    def _legs() -> None:
        if direction == "side":
            draw_legs_side(im, ldy, rdy)
        else:
            draw_legs(im, ldy, rdy)

    # 레이어: idle은 손이 자루를 쥔 게 보이도록 검을 몸 뒤에 둔다. 스윙(windup/hit/recover/
    # settle)은 궤적이 몸 앞에 보이게 검을 몸 위에 그린다 — 단 측면 windup은 어깨 너머 궤적을
    # 보여야 하므로 앞 레이어로 뺀다(정면/후면 windup은 기존대로 뒤 레이어 유지).
    if direction == "side":
        sword_behind = sword == "idle"
    else:
        sword_behind = sword in ("idle", "windup")

    if sword_behind:
        draw_sword(im, direction, sword, arm_dx)
        _legs()
        DRAW[direction](im, bob, arm_dx)
    else:
        _legs()
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
    # 검 들기→앞으로 베기→내리기→갈무리로 프레임 간 실루엣 차이를 크게(측면 스윙 가독성).
    # 정면/후면은 settle을 recover와 동일 처리(draw_sword 참조)해 기존 4프레임 규격 유지.
    seq = ["windup", "hit", "recover", "settle"]
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
