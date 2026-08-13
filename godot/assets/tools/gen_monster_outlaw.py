"""M3 3-B P0-2: 무법자(인간형 적) 57프레임 생성 — LPC 베이스 -> 28x36 EDG32.

- 계획서: `docs\\art\\m3-character-art-plan.md` 7-1·7-3장(무법자 28x36 · 57프레임) ·
  7-2장(인간형 적 3중 신호) · 15-3장 P0-2(판정 오염 1순위) · 15-4장 착수 규격
- 규격: `docs\\art\\STYLE_GUIDE.md` 1-2(인간형 캔버스 28x36) · 3-1(아웃라인) ·
  3-2-1(4단 램프) · 3-3(잡몹 idle4/walk4/attack5/death4 + 유틸 6) · 3-3-1-1(`guard` 제작 필수) ·
  6-3-1(인간형 적 3중 신호) · 7-1(시트 규약)
- 소스·라이선스: LPC (B등급, CC-BY-SA 3.0 선택) — `docs\\art\\ASSET_SOURCES.md` 10장

**왜 플레이어 파이프라인을 그대로 쓰는가**: 무법자는 인간형이라 캔버스·척도가 플레이어와
동일하다(`STYLE_GUIDE` 1-2-3 가드레일 ①). 그래서 `lpc_common` 의 합성->축소->재색상->
아웃라인 파이프라인과 상수(FRAME_W/H, SCALE, 발밑 앵커)를 **1개도 바꾸지 않고** 재사용한다.
이 파일이 추가하는 것은 세 가지뿐이다 — ① 무법자용 레이어·램프·상태 명세
② **3중 신호 작화**(후드 실루엣 + `#e43b44` 액센트) ③ **가드 자세 작화**.

**`guard` 가 이 파일의 존재 이유다** (`STYLE_GUIDE` 3-3-1-1 판정): `guard` 의 코드 폴백은
`idle`(정지 자세)이라 "막고 있음"이 **전혀 전달되지 않는다.** 정면 ±60° 방향 의존
메커니즘인데 신호가 없으면 플레이어는 "왜 데미지가 안 들어가지"만 겪고, 그것을 난이도
문제로 오독한다. 그래서 가드는 팔·무기로 **정면을 가리는 밝은 금속 가로 바 + 세운 칼날**
로 그려 실루엣만으로 읽히게 한다(6-3 "색은 보조 수단").

사용법:
    python gen_monster_outlaw.py           # 5시트 57프레임 생성
    python gen_monster_outlaw.py --report  # 파일을 쓰지 않고 검사만
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from lpc_common import (  # noqa: E402
    ASSETS_DIR,
    CLAMP_TOL,
    DIRECTIONS,
    FRAME_H,
    FRAME_W,
    Layer,
    StateSpec,
    _line,
    _max_len,
    _SKIN_SET,
    _stamp,
    bands_from,
    build_sheet,
    collect_luminance,
    compose_frame,
    crop_to_frame,
    downscale,
    draw_eyes,
    ensure_outline,
    facing_dir,
    foot_row_check,
    hx,
    material_ids,
    narrow_to_frame,
    palette_violations,
    recolor,
)

OUT_DIR = ASSETS_DIR / "sprites" / "monsters"
PREFIX = "mob_outlaw_thug"  # 계획서 10장 파일명 마스터 표 (아종 = mob_outlaw_highwayman/poacher)

OUTLINE = hx("#181425")

# 후드 (3중 신호 ①). 균열·야간 톤이 아니라 **어두운 갈색 천**이다 — 임프(자주·암자색)와
# 색 계열이 갈려 같은 화면에서 구분된다(6-3 팔레트 분리).
HOOD_HI = hx("#733e39")
HOOD_BASE = hx("#3e2731")
HOOD_DARK = hx("#262b44")
# 적 액센트 (3중 신호 ②) — `#e43b44` 는 2장이 "적(敵) 식별 기본색"으로 규정한 색이다.
# `#ff0044`(예고 전용)는 절대 쓰지 않는다.
ACCENT = hx("#e43b44")
# 가드 금속 (밝게 = 배경·의상과 최대 대비. "막는 판"이 실루엣으로 읽혀야 한다)
GUARD_HI = hx("#c0cbdc")
GUARD_LO = hx("#8b9bb4")
# 단검 (3중 신호 ① — 플레이어 대검(긴 직선)·활(비대칭 곡선)과 다른 짧고 굽은 형태)
DAGGER = hx("#c0cbdc")
DAGGER_TIP = hx("#ffffff")
DAGGER_GUARD = hx("#5a6988")
DAGGER_GRIP = hx("#733e39")

# ---------------------------------------------------------------- 레이어·램프

# 합성 순서(아래 -> 위). 판금(전사)·화살통(궁수)을 쓰지 않고 **긴팔 천 + 가죽 톤**으로
# 간다 — 무법자는 정규 장비가 아닌 노상 강도이고, 팔레트가 플레이어 2직업과 겹치지 않는다.
OUTLAW_LAYERS = [
    Layer("body", "body/bodies/male/{anim}.png", "skin"),
    Layer("legs", "legs/pants/male/{anim}.png", "pants"),
    Layer("feet", "feet/boots/basic/male/{anim}.png", "boots"),
    Layer("torso", "torso/clothes/longsleeve/longsleeve/male/{anim}.png", "torso"),
    Layer("head", "head/heads/human/male/{anim}.png", "skin"),
    Layer("hair", "hair/buzzcut/adult/{anim}.png", "hair"),
]

# 인접 부위는 다른 색 계열로 — 전사(회청 판금)·궁수(초록 천)와도 계열이 갈린다.
OUTLAW_RAMPS = {
    "skin": "skin",
    "hair": "hair_dark",
    "torso": "leather",  # 가죽 조끼 — 갈색
    "pants": "trouser_dark",  # 회청 바지 (상의와 명도·색 계열 분리 -> 허리선이 읽힌다)
    "boots": "leather",
}

# ---------------------------------------------------------------- 상태 명세 (57프레임)
#
# 프레임 선택 근거(LPC 원본 실측 — `thrust` 8프레임의 자세를 눌러 확인했다):
#   thrust 0 = 기립 / 1 = 살짝 웅크림 / 2 = 깊게 웅크리고 팔 뒤로 / 3 = 앞다리 내며 돌진 /
#   4 = 완전히 뻗은 돌진 정점 / 5~6 = 회수 / 7 = 기립 복귀
# 그래서 attack = [1, 2, 3, 4, 6] 이 `STYLE_GUIDE` 3-3 몬스터 attack 규격
# **"예고 2 + 발동 2 + 회수 1"** 에 1:1로 대응한다(예고 = 웅크림·무기 뒤로, 3-3장 지시).
OUTLAW_STATES = [
    StateSpec("idle", "idle", [0, 1, 0, 1],
              note="LPC idle 원본이 2프레임이라 2포즈 호흡 루프. 후드 실루엣 확립 프레임"),
    StateSpec("walk", "walk", [1, 3, 5, 7], note="잡몹 walk 4프레임 (3-3 'CC0 소싱 몬스터는 4 허용')"),
    StateSpec("attack", "thrust", [1, 2, 3, 4, 6],
              note="돌진 — 예고2(웅크림+단검 뒤로) + 돌진2(앞다리·뻗음) + 후딜1. "
                   "벽 충돌 추가 경직은 후딜 프레임 홀드로 처리(계획서 7-3)"),
    StateSpec("death", "hurt", [1, 2, 3, 4],
              note="LPC hurt 원본은 front 1행뿐 -> 3방향 공유(플레이어와 같은 원본 한계). "
                   "비틀림 -> 웅크림 -> 무릎 -> 붕괴"),
    StateSpec("guard", "combat_idle", [0, 1],
              note="가드 2프레임 루프. combat_idle(전투 스탠스)에 가로 금속 바 + 세운 칼날을 "
                   "얹어 정면을 가린다. idle(팔 내림)과 실루엣이 확실히 다르다"),
]

# 단검 포즈표: 상태 -> 프레임별 (각도, 칼날 길이 요청값, hx, hy).
# 각도는 측면(오른쪽 바라봄) 기준 0도 = 오른쪽 · 양수 = 아래 (`facing_dir` 규약).
# hx = 몸 중심선에서 바깥쪽 거리, hy = 발밑에서 위로 올라간 높이.
#
# 길이 요청값을 8~9로 두는 것이 **플레이어 대검(요청 22)과의 실루엣 대비**를 만든다 —
# 6-3-1 ①이 요구한 "짧고 굽은 무기"다. 칼날은 `_max_len` 으로 프레임 안에 clamp 된다.
DAGGER_POSE: dict[str, list[tuple[float, float, float, float]]] = {
    # 대기·이동 — 단검을 허리 옆에 낮게 든다(플레이어 전사의 "세워 든 대검"과 정반대)
    "idle": [(35, 8, 5, 12), (30, 8, 5, 13), (35, 8, 5, 12), (30, 8, 5, 13)],
    "walk": [(35, 8, 5, 12), (25, 8, 5, 13), (40, 8, 5, 12), (30, 8, 5, 13)],
    # 예고 2프레임은 단검을 **뒤로 완전히 당긴다**(각도 205~215 = 뒤·위). 3-3장이 요구한
    # "실루엣이 명확히 변하는 예고"의 실체가 이 2프레임이다.
    "attack": [(210, 8, 4, 15), (215, 9, 3, 16), (5, 9, 6, 14), (0, 9, 7, 13), (40, 8, 5, 12)],
    "death": [(60, 8, 4, 11), (90, 7, 4, 8), (130, 7, 5, 5), (165, 6, 5, 3)],
    # 가드 — 칼날을 세워 정면을 가린다(가드 바와 함께 T자 금속 실루엣을 만든다)
    "guard": [(-80, 7, 3, 19), (-84, 7, 3, 20)],
}


def hand_xy(direction: str, hx_off: float, hy_off: float) -> tuple[float, float]:
    """(hx, hy) -> 프레임 좌표. 정면은 무기 손이 화면 좌측(LPC 원본과 동일, 플레이어와 같은 규약)."""
    sign = -1.0 if direction == "front" else 1.0
    return (FRAME_W / 2 + sign * hx_off, FRAME_H - 1 - hy_off)


# ---------------------------------------------------------------- 3중 신호 ① 후드


def _top_row(px, w: int = FRAME_W, h: int = FRAME_H) -> int | None:
    for y in range(h):
        if any(px[x, y][3] for x in range(w)):
            return y
    return None


def _eye_row(px, direction: str) -> int | None:
    """`draw_eyes` 가 눈을 찍은 행. **색으로 찾지 않는다.**

    EYE(`#3e2731`)는 `hair_dark` 램프의 어두운 단계와 **같은 값**이다. 그래서 색을 위에서부터
    스캔하면 눈이 아니라 정수리 머리카락을 먼저 잡아 `eye_y = top + 1` 이 되고, 후드가 덮을
    범위(`eye_y - top`)가 1행으로 쪼그라들어 `draw_hood` 가 전량 실패한다(실측: 57프레임 중
    56건). 그래서 `draw_eyes` 와 **같은 방식**(피부 행 실측 -> brow + 2)으로 되짚는다.

    후면은 `draw_eyes` 가 눈을 찍지 않으므로(눈 유무가 앞/뒤 신호) None을 돌려주고,
    호출부가 "두상 6행 전부 덮기"로 처리한다.
    """
    if direction == "back":
        return None

    def skin_run(y: int) -> list[int]:
        return [x for x in range(FRAME_W) if px[x, y][3] == 255 and px[x, y][:3] in _SKIN_SET]

    brow = next((y for y in range(FRAME_H // 2) if len(skin_run(y)) >= 4), None)
    return None if brow is None else brow + 2


def _row_pixels(px, y: int, skip_outline: bool = True) -> list[int]:
    return [
        x
        for x in range(FRAME_W)
        if px[x, y][3] and not (skip_outline and px[x, y][:3] == OUTLINE)
    ]


def draw_hood(frame: Image.Image, direction: str) -> bool:
    """머리 위쪽을 후드로 덮는다 — 인간형 적 3중 신호 ①(6-3-1).

    **눈을 찍은 뒤에 호출한다.** 후드가 덮는 범위를 "눈 행 위쪽"으로 한정하면 눈 점
    (앞/뒤 판별 신호, 3-2-2절)이 살아남으면서 "그늘 속 얼굴"이 된다. 후드를 먼저 그리면
    `draw_eyes` 가 피부 행을 못 찾아 실패한다(실측).

    구성: ① 정수리~이마를 후드천으로 치환(위 밝음/아래 어두움 = 광원 위쪽, 3-2)
    ② 뒤쪽으로 1px 솟은 **뾰족한 꼭지** ③ 눈 행 아래 3행의 뒤쪽 1px **목덜미 천**.
    실체 높이는 꼭지 1px 만 늘어난다(천이지 몸이 아니므로 두신 3.3 판정에는 영향 없음).
    """
    px = frame.load()
    top = _top_row(px)
    if top is None:
        return False
    eye_y = _eye_row(px, direction)
    if eye_y is None:  # 후면(눈 없음) — 두상 6행을 전부 덮는다(가장 강한 후드 실루엣)
        eye_y = top + 6
    if eye_y - top < 2:
        return False

    # ① 정수리~이마 치환
    for y in range(top, eye_y):
        xs = _row_pixels(px, y)
        if not xs:
            continue
        if y <= top + 1:
            color = HOOD_HI
        elif y >= eye_y - 1:
            color = HOOD_DARK  # 얼굴 위로 떨어지는 그늘
        else:
            color = HOOD_BASE
        for x in xs:
            px[x, y] = (*color, 255)

    # ② 뾰족한 꼭지 — 뒤쪽(측면은 왼쪽, 정면·후면은 중앙)으로 1px
    back = -1 if direction == "side" else 0
    xs_top = _row_pixels(px, top, skip_outline=False)
    if xs_top and top >= 1:
        cx = (min(xs_top) + max(xs_top)) // 2 + back
        for x in (cx, cx + 1):
            if 1 <= x < FRAME_W - 1:
                px[x, top - 1] = (*HOOD_HI, 255)

    # ③ 목덜미로 늘어지는 천 (계획서 7-2 "목덜미로 늘어지는 천 2~3px")
    for i in range(3):
        y = eye_y + i
        if y >= FRAME_H:
            break
        xs = _row_pixels(px, y, skip_outline=False)
        if not xs:
            continue
        edges = [min(xs) - 1] if direction == "side" else [min(xs) - 1, max(xs) + 1]
        for x in edges:
            if 1 <= x < FRAME_W - 1 and px[x, y][3] == 0:
                px[x, y] = (*(HOOD_BASE if i < 2 else HOOD_DARK), 255)
    return True


# ---------------------------------------------------------------- 3중 신호 ② 적 액센트


def draw_accent(frame: Image.Image, direction: str) -> bool:
    """어깨 2점 + 허리 띠에 `#e43b44` 1~2px — 인간형 적 3중 신호 ②(6-3-1).

    **아웃라인 강제(`ensure_outline`) 뒤에** 호출해야 한다. 액센트는 실루엣 내부 픽셀에만
    찍으므로(아웃라인 픽셀 제외) 1px 폐곡선 외곽선 규정(3-1)을 건드리지 않는다.

    어깨·허리 위치를 눈 행에서 되짚으므로 `_eye_row` 와 같은 방향 인자가 필요하다(후면은
    눈이 없어 `top + 4` 로 대체한다).
    """
    px = frame.load()
    top = _top_row(px)
    if top is None:
        return False
    eye_y = _eye_row(px, direction) or (top + 4)
    painted = False

    # 어깨 — 두상 아래 첫 '넓어지는' 행. 좌우 최외곽 내부 픽셀 1px씩
    for dy in (3, 4):
        y = eye_y + dy
        if y >= FRAME_H:
            break
        xs = _row_pixels(px, y)
        if len(xs) >= 6:
            for x in (min(xs), max(xs)):
                px[x, y] = (*ACCENT, 255)
            painted = True
            break

    # 허리 띠 — 상의/하의 경계 근처 가로 2~3px (중앙)
    for dy in (10, 11, 9):
        y = eye_y + dy
        if y >= FRAME_H:
            continue
        xs = _row_pixels(px, y)
        if len(xs) >= 5:
            c = (min(xs) + max(xs)) // 2
            for x in (c - 1, c, c + 1):
                if x in xs:
                    px[x, y] = (*ACCENT, 255)
            painted = True
            break
    return painted


# ---------------------------------------------------------------- 가드 자세 작화


def draw_guard_bar(frame: Image.Image, order: int, direction: str) -> bool:
    """가슴 높이에 **가로 금속 바**(팔+무기로 정면을 가린 형태)를 그린다.

    `STYLE_GUIDE` 3-3-1-1 이 `guard` 를 제작 필수로 판정한 이유가 "폴백(`idle`)이 막고
    있음을 전혀 전달하지 못한다"였다. 그 신호를 만드는 것이 이 함수다 —
    **몸 폭보다 1px 넓은 밝은 가로 바**는 정지 자세와 실루엣이 겹치지 않고, 어두운 후드·
    가죽 위에서 명도 대비가 가장 큰 요소라 화면에서 먼저 눈에 들어온다.
    2프레임 루프는 바를 1px 올려/내려 긴장을 준다(정지 그림으로 보이지 않게).
    """
    px = frame.load()
    top = _top_row(px)
    if top is None:
        return False
    eye_y = _eye_row(px, direction) or (top + 4)
    y0 = eye_y + 5 - (1 if order else 0)
    if y0 + 1 >= FRAME_H:
        return False
    xs = _row_pixels(px, y0, skip_outline=False)
    if len(xs) < 5:
        return False
    x0, x1 = max(1, min(xs) - 1), min(FRAME_W - 2, max(xs) + 1)
    _stamp(
        frame,
        [
            (_line((x0, y0), (x1, y0)), GUARD_HI),
            (_line((x0, y0 + 1), (x1, y0 + 1)), GUARD_LO),
        ],
    )
    return True


# ---------------------------------------------------------------- 단검 작화


def draw_dagger(
    frame: Image.Image, hand: tuple[float, float], d: tuple[float, float], want: float
) -> float:
    """손잡이에서 방향 `d` 로 뻗은 **단검** 1자루. 반환값 = 실제로 그린 칼날 길이(px).

    플레이어 대검(`lpc_common.draw_sword`: 칼날 2px 폭 · 십자 가드 5px · 황금 폼멜)과
    **의도적으로 다른 규격**이다 — 칼날 1px 폭 · 짧은 가드 3px · 폼멜 없음 + 칼날 중간을
    1px 굽혀 "짧고 굽은 단검"(6-3-1 ①)으로 읽히게 한다. 무기 형태가 플레이어와 같으면
    3중 신호 ①이 성립하지 않는다.
    """
    length = _max_len(hand, d, want, margin=1)
    if length < 3:
        return 0.0
    perp = (-d[1], d[0])
    if (perp[0] > 0) != (hand[0] >= FRAME_W / 2):
        perp = (-perp[0], -perp[1])
    guard_c = (hand[0] + d[0] * 1.5, hand[1] + d[1] * 1.5)
    blade0 = (hand[0] + d[0] * 2.5, hand[1] + d[1] * 2.5)
    # 굽은 칼날 = 시작->중간(수직으로 1px 밀림)->끝 2단 직선
    mid = (
        hand[0] + d[0] * (length * 0.6) + perp[0],
        hand[1] + d[1] * (length * 0.6) + perp[1],
    )
    tip = (hand[0] + d[0] * length, hand[1] + d[1] * length)
    butt = (hand[0] - d[0] * 2, hand[1] - d[1] * 2)
    _stamp(
        frame,
        [
            (_line(hand, butt), DAGGER_GRIP),
            (
                _line(
                    (guard_c[0] - perp[0] * 1.5, guard_c[1] - perp[1] * 1.5),
                    (guard_c[0] + perp[0] * 1.5, guard_c[1] + perp[1] * 1.5),
                ),
                DAGGER_GUARD,
            ),
            (_line(blade0, mid), DAGGER),
            (_line(mid, tip), DAGGER),
            (_line(tip, tip), DAGGER_TIP),
        ],
    )
    return length


def clipping_report(sheet: Image.Image, cols: int) -> list[str]:
    """`validate_clipping.py` 와 **같은 규칙**을 생성 시점에 적용한다(7장 5-1 게이트).

    프레임 경계에 아웃라인색이 아닌 불투명 픽셀이 있으면 잘린 단면이다.
    """
    px = sheet.convert("RGBA").load()
    out: list[str] = []
    for r in range(3):
        for c in range(cols):
            ox, oy = c * FRAME_W, r * FRAME_H
            cut: dict[str, int] = {}
            for x in range(FRAME_W):
                for y, k in ((0, "상"), (FRAME_H - 1, "하")):
                    rr, gg, bb, aa = px[ox + x, oy + y]
                    if aa and (rr, gg, bb) != OUTLINE:
                        cut[k] = cut.get(k, 0) + 1
            for y in range(FRAME_H):
                for x, k in ((0, "좌"), (FRAME_W - 1, "우")):
                    rr, gg, bb, aa = px[ox + x, oy + y]
                    if aa and (rr, gg, bb) != OUTLINE:
                        cut[k] = cut.get(k, 0) + 1
            if cut:
                out.append(f"행{r} 열{c}: " + " ".join(f"{k}{v}px" for k, v in cut.items()))
    return out


def build(report_only: bool) -> tuple[int, list[str]]:
    mats = material_ids(OUTLAW_LAYERS, [])

    # 1패스: 몸 합성 + 축소 (재질별 휘도 표본 수집)
    composed: dict[str, dict[str, list[tuple[Image.Image, Image.Image]]]] = {}
    narrowed: list[str] = []
    for spec in OUTLAW_STATES:
        composed[spec.state] = {}
        for d in DIRECTIONS:
            seq = []
            for i in range(len(spec.frames)):
                rgba, idm, _ = compose_frame(
                    OUTLAW_LAYERS, spec, d, i, mats, weapon_mode="probe"
                )
                rgba, idm, k = narrow_to_frame(rgba, idm)
                if k < 1.0:
                    narrowed.append(f"{spec.state}/{d}{i}={k:.2f}")
                seq.append(downscale(rgba, idm, mats))
            composed[spec.state][d] = seq

    flat = [f for st in composed.values() for seq in st.values() for f in seq]
    bands = {mid: bands_from(lums) for mid, lums in collect_luminance(flat, mats).items()}

    # 2패스: 재색상 -> 아웃라인 -> 크롭 -> 3중 신호 -> 무기 -> 시트
    total = 0
    issues: list[str] = []
    for spec in OUTLAW_STATES:
        by_dir: dict[str, list[Image.Image]] = {}
        clips: list[str] = []
        for d in DIRECTIONS:
            out = []
            for i, (rgba, idm) in enumerate(composed[spec.state][d]):
                colored = ensure_outline(recolor(rgba, idm, mats, bands, OUTLAW_RAMPS))
                frame, (cl, cr) = crop_to_frame(colored)
                if max(cl, cr) > CLAMP_TOL:
                    clips.append(f"{d}{i}(좌{cl}/우{cr})")
                frame = ensure_outline(frame)  # 크롭 단면을 다시 폐곡선으로 닫는다(3-1)
                if not draw_eyes(frame, d) and not (spec.state == "death" and i >= 2):
                    issues.append(f"{PREFIX}_{spec.state}: {d}{i} 눈 점 배치 실패")
                if not draw_hood(frame, d):
                    issues.append(f"{PREFIX}_{spec.state}: {d}{i} 후드 작화 실패(3중 신호 ①)")
                frame = ensure_outline(frame)
                if not draw_accent(frame, d):
                    issues.append(f"{PREFIX}_{spec.state}: {d}{i} 적 액센트 실패(3중 신호 ②)")
                if spec.state == "guard" and not draw_guard_bar(frame, i, d):
                    issues.append(f"{PREFIX}_{spec.state}: {d}{i} 가드 바 작화 실패")
                pose = DAGGER_POSE[spec.state]
                angle, want, hxo, hyo = pose[min(i, len(pose) - 1)]
                if not draw_dagger(frame, hand_xy(d, hxo, hyo), facing_dir(d, angle), want):
                    issues.append(f"{PREFIX}_{spec.state}: {d}{i} 단검이 그려지지 않음")
                out.append(frame)
            by_dir[d] = out
        sheet = build_sheet(by_dir)
        cols = len(spec.frames)
        expect = (cols * FRAME_W, 3 * FRAME_H)
        if sheet.size != expect:
            issues.append(f"{PREFIX}_{spec.state}: 시트 크기 {sheet.size} != 기대 {expect}")
        bad = palette_violations(sheet)
        if bad:
            issues.append(f"{PREFIX}_{spec.state}: 팔레트 위반 {sum(bad.values())}px {list(bad)[:3]}")
        issues += [f"{PREFIX}_{spec.state}: {p}" for p in foot_row_check(sheet, cols)]
        issues += [f"{PREFIX}_{spec.state}: 클리핑 {p}" for p in clipping_report(sheet, cols)]
        if clips:
            issues.append(f"{PREFIX}_{spec.state}: 가로 돌출이 clamp 허용치({CLAMP_TOL}px) 초과 {clips}")
        total += cols * 3
        if not report_only:
            OUT_DIR.mkdir(parents=True, exist_ok=True)
            path = OUT_DIR / f"{PREFIX}_{spec.state}.png"
            sheet.save(path)
            sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(
                path.with_name(f"_preview_{path.name}")
            )
        print(f"  {PREFIX}_{spec.state}.png  {sheet.size[0]}x{sheet.size[1]}  {cols}프레임x3방향={cols * 3}")
    if narrowed:
        print(f"  [자세 가로 클램프 {len(narrowed)}프레임] {' '.join(narrowed)}")
    return total, issues


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", action="store_true", help="파일을 쓰지 않고 검사만")
    args = ap.parse_args()
    print("[무법자 mob_outlaw_thug]")
    total, issues = build(args.report)
    print(f"  -> 합계 {total}프레임 (계획서 7-3장 57 기대)")
    if issues:
        print(f"\n점검 사항 {len(issues)}건:")
        for m in issues:
            print(f"  - {m}")
        return 0
    print("\n점검 사항 0건 — 팔레트·발밑·클리핑 전부 통과")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
