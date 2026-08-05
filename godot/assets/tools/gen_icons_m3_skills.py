"""M3 3-B P0-1: 2차 전직 스킬 아이콘 8종 절차 생성 (검투사 4 + 궁수 4, 16x16).

참조:
- `docs\\art\\m3-character-art-plan.md` 15-3장 P0-1 (스킬바 식별 불가가 "스킬이 재미없다"로
  오독되는 것을 막는 것이 이 자산의 목적 — 비용 대비 판정 영향 최대)
- `docs\\design\\systems\\m3-warrior-tier2-skills.md` 4장 (검투사 스킬 4종)
- `docs\\design\\systems\\m3-archer-skills.md` 4장 (궁수 스킬 4종)
- `docs\\art\\STYLE_GUIDE.md` 1-2(아이콘 16x16) · 2장(EDG32) · 3-1(1px 외곽선 #181425)
  · 3-2(아이콘은 3단 램프 고정 — 4단은 캐릭터·몬스터 전용) · 6-1(색 위계) · 6-1-1(붉은색 예외)

**색 규칙 (art-director 판정 준수 — 이 파일의 가장 중요한 제약)**:
플레이어 스킬은 청·시안 통일(6-1 3순위)이고, 붉은색은 6-1-1 화이트리스트 3범주
(A 자원 게이지 / B 자기 상태 오라 / C 1~2프레임 섬광)에서만 허용된다.
**아이콘은 그 3범주에 없다** — 따라서 분노 계열(처형 일격·혈투의 함성)도 아이콘 자체는
청·시안으로 그린다. `#ff0044`·`#e43b44`·`#a22633` 는 이 파일에서 1픽셀도 쓰지 않는다.
예외 2건은 문서가 명시 허용한 것만이다:
  - 흡혈 회복 표식 = `#63c74d` (6-1 4순위 "회복·버프". 8-4장이 "흡혈이 테마상 붉더라도
    회복 신호의 색 소유권이 우선"이라고 못박았다)
  - 궁극기 테두리 = `#feae34` (6-1 6순위 중립 정보. 기존 `skill_ultimate_ground_smash`
    아이콘이 이미 쓴 선례를 계승 — 궁극기 1종만 갖는 표식이라 식별 신호를 겸한다)

**식별은 형태로 한다** (8개가 스킬바에서 한눈에 구분되어야 한다):
| 아이콘 | 1차 형태 신호 | 혼동 방지 대비 |
|---|---|---|
| 검투 선풍 | **닫힌 원형 링 2px** + 링을 뚫고 나가는 대검 | 곡예 사격(열린 호)과 링의 개폐로 구분 |
| 난입 강타 | **가로 화살표**(우향) + 상단 대검 | 처형(세로)과 축으로 구분 |
| 혈투의 함성 | **상승 이중 쐐기** + 좌우 방사 호 | 매의 눈(눈 형태)과 구분 |
| 처형 일격 | **아래로 꽂힌 대검**(세로) + 하단 충격 쐐기 | 난입(가로)과 축으로 구분 |
| 속사 | **평행 화살 3발** | 관통 폭사(1발 장척)와 발수로 구분 |
| 곡예 사격 | **열린 곡선 궤적 + 화살촉** + 대각 화살 | 선풍(닫힌 링)과 구분 |
| 매의 눈 | **눈 + 십자 조준 눈금** | 유일한 눈 형태 |
| 관통 폭사 | **화면 관통 장척 화살 1발 + 관통 표식 3개 + 금색 코너** | 유일한 코너 프레임 |

출력: godot\\assets\\icons\\skills\\*.png (8개) + `_preview_m3_4x.png`
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from edg32_palette import RGB, OUTLINE_RGB  # noqa: E402

SIZE = 16
ASSETS_DIR = Path(__file__).parent.parent
SKILLS_DIR = ASSETS_DIR / "icons" / "skills"

# 청·시안 램프 (3단 — 아이콘은 3단 고정)
CYAN = RGB["cyan"]  # #2ce8f5 하이라이트
BLUE = RGB["blue"]  # #0099db 기본
NAVY = RGB["navy"]  # #124e89 그림자
NAVY_GRAY = RGB["navy_gray"]  # #3a4466 최암 그림자(패널 위에서 형태 받침)
# 강철 램프 3단 (무기)
STEEL_HI = RGB["light_blue_gray"]  # #c0cbdc
STEEL = RGB["blue_gray"]  # #8b9bb4
STEEL_DK = RGB["dark_blue_gray"]  # #5a6988
WHITE = RGB["white"]
WOOD = RGB["tan"]  # #c28569 화살대
WOOD_DK = RGB["ochre"]  # #b86f50
GREEN = RGB["fresh_green"]  # #63c74d 회복(흡혈) 표식 — 6-1 4순위
GOLD = RGB["gold"]  # #feae34 궁극기 표식 — 6-1 6순위


def new_icon() -> Image.Image:
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def px(img: Image.Image, x: int, y: int, color: tuple[int, int, int]) -> None:
    if 0 <= x < SIZE and 0 <= y < SIZE:
        img.putpixel((x, y), (*color, 255))


def pxs(img: Image.Image, pts: list[tuple[int, int]], color: tuple[int, int, int]) -> None:
    for x, y in pts:
        px(img, x, y, color)


def add_outline(img: Image.Image) -> Image.Image:
    """불투명 픽셀에 8방향 인접한 투명 픽셀을 #181425로 채워 1px 외곽선을 만든다.

    `generate_icons_skills_items.py` 와 동일 구현 — 외곽선 규칙(3-1)을 손으로 그리지 않고
    항상 정확히 만족시키기 위한 것이다.
    """
    out = img.copy()
    src = img.load()
    dst = out.load()
    for y in range(SIZE):
        for x in range(SIZE):
            if src[x, y][3] != 0:
                continue
            found = False
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < SIZE and 0 <= ny < SIZE and src[nx, ny][3] != 0:
                        found = True
                        break
                if found:
                    break
            if found:
                dst[x, y] = (*OUTLINE_RGB, 255)
    return out


def arrow_right(
    img: Image.Image,
    x0: int,
    x1: int,
    y: int,
    shaft: tuple[int, int, int],
    head: tuple[int, int, int],
    fletch: bool = True,
) -> None:
    """가로 화살 1발 (촉이 x1). 화살 = 궁수 스킬의 공통 어휘라 모양을 한 함수로 고정한다."""
    for x in range(x0, x1 - 1):
        px(img, x, y, shaft)
    # 촉 (3px 삼각)
    px(img, x1, y, head)
    px(img, x1 - 1, y - 1, head)
    px(img, x1 - 1, y + 1, head)
    if fletch:
        px(img, x0, y - 1, WHITE)
        px(img, x0, y + 1, WHITE)


# ---------------------------------------------------------------- 검투사 4종


def skill_whirlwind() -> Image.Image:
    """검투 선풍 — 자기 중심 360° 광역. **교차 대검(X) + 상단 스윕 호**.

    시안 2회를 폐기한 기록: 링(원)을 그리고 대검을 대각으로 관통시키면 **"통행금지 표지"로
    읽힌다**(원 + 지름 대각선의 게슈탈트). 대검이 지나는 지점에서 링을 끊어도 대검이 그 자리를
    덮어 개폐가 보이지 않았다. 따라서 **원형 궤적을 링이 아니라 "상단 스윕 호"로 축약**하고,
    광역·난전 정체성은 8종 중 유일한 **X자 교차 실루엣**이 담당한다. 원형 링은 곡예 사격
    (회전 화살)에 양보했다 — 둘이 같은 링을 쓰면 서로 구분되지 않기 때문이다.
    """
    img = new_icon()
    d = ImageDraw.Draw(img)
    # 상단 스윕 호 2줄 (360° 회전 궤적의 축약 — 잔상이라 얇게)
    d.arc([1, 1, 14, 13], start=195, end=345, fill=(*BLUE, 255), width=1)
    d.arc([3, 3, 12, 11], start=200, end=340, fill=(*NAVY, 255), width=1)
    pxs(img, [(5, 1), (6, 1), (9, 1), (10, 1)], CYAN)
    pxs(img, [(2, 4), (13, 4), (1, 6), (14, 6)], CYAN)  # 호 양단 = 회전이 계속됨
    # 교차 대검 2자루 (자루는 아래, 칼끝은 위) — 8종 중 유일한 X 실루엣
    d.line([(3, 14), (10, 4)], fill=(*STEEL, 255), width=2)
    d.line([(12, 14), (5, 4)], fill=(*STEEL, 255), width=2)
    d.line([(4, 13), (10, 5)], fill=(*STEEL_HI, 255), width=1)
    d.line([(11, 13), (5, 5)], fill=(*STEEL_HI, 255), width=1)
    px(img, 10, 3, WHITE)
    px(img, 5, 3, WHITE)
    pxs(img, [(2, 14), (13, 14), (2, 13), (13, 13)], STEEL_DK)  # 자루 2개
    return add_outline(img)


def skill_charge_slam() -> Image.Image:
    """난입 강타 — 돌진 + 그로기. **가로 화살표(이동) + 상단 대검**."""
    img = new_icon()
    d = ImageDraw.Draw(img)
    # 상단: 앞으로 내민 대검 (완만한 대각 — 세로축의 처형 일격과 구분)
    d.line([(3, 6), (11, 2)], fill=(*STEEL, 255), width=2)
    d.line([(4, 6), (11, 3)], fill=(*STEEL_HI, 255), width=1)
    px(img, 12, 2, WHITE)
    pxs(img, [(2, 6), (2, 7), (3, 7)], STEEL_DK)  # 가드·자루
    # 하단: 돌진 화살표 (우향, 두껍게) + 후행 잔상
    d.polygon([(14, 11), (9, 8), (9, 14)], fill=(*BLUE, 255))
    pxs(img, [(10, 11), (11, 11), (12, 11), (10, 10), (11, 10)], CYAN)
    d.rectangle([2, 10, 9, 12], fill=(*BLUE, 255))
    for x in range(2, 9):
        px(img, x, 10, CYAN)
    for x in range(2, 9):
        px(img, x, 12, NAVY)
    pxs(img, [(1, 8), (2, 8), (1, 14), (2, 14)], NAVY_GRAY)  # 흙먼지(후행)
    return add_outline(img)


def skill_blood_shout() -> Image.Image:
    """혈투의 함성 — 흡혈 버프. **상승 이중 쐐기 + 좌우 방사 호**.

    분노 계열 스킬이지만 **아이콘은 6-1-1 화이트리스트 3범주 밖**이라 붉은색을 쓰지 않는다.
    흡혈(회복)만 `#63c74d` 1~2px 로 표기한다(6-1 4순위 · 8-4장 판정).
    """
    img = new_icon()
    d = ImageDraw.Draw(img)
    # 상승 쐐기 2단 (버프 = 위로) — 위 쐐기를 밝게
    d.line([(4, 7), (7, 4)], fill=(*CYAN, 255), width=2)
    d.line([(8, 4), (11, 7)], fill=(*CYAN, 255), width=2)
    d.line([(4, 11), (7, 8)], fill=(*BLUE, 255), width=2)
    d.line([(8, 8), (11, 11)], fill=(*BLUE, 255), width=2)
    # 방사 호 (함성) — 좌우로 퍼지는 2단
    pxs(img, [(1, 5), (1, 6), (2, 7), (2, 8), (1, 9), (1, 10)], NAVY)
    pxs(img, [(14, 5), (14, 6), (13, 7), (13, 8), (14, 9), (14, 10)], NAVY)
    # 흡혈 회복 표식 — 하단 중앙 십자 2x2 (색+형태 이중 신호)
    pxs(img, [(7, 13), (8, 13), (7, 14), (8, 14)], GREEN)
    px(img, 6, 13, GREEN)
    px(img, 9, 13, GREEN)
    return add_outline(img)


def skill_execution() -> Image.Image:
    """처형 일격 — 분노 피니셔. **아래로 꽂힌 대검(세로) + 하단 충격**.

    붉은색 금지(6-1-1). "가장 센 스킬"의 위상은 색이 아니라 **칼날 길이(11px)와 충격 쐐기**로 만든다.
    """
    img = new_icon()
    d = ImageDraw.Draw(img)
    # 자루 + 십자 가드 (상단)
    d.rectangle([7, 1, 8, 2], fill=(*STEEL_DK, 255))
    d.rectangle([4, 3, 11, 4], fill=(*STEEL_DK, 255))
    px(img, 5, 3, STEEL)
    px(img, 10, 3, STEEL)
    # 칼날 세로 (길게 = 대검) — 촉이 아래
    d.rectangle([6, 5, 9, 12], fill=(*STEEL, 255))
    d.rectangle([6, 5, 7, 12], fill=(*STEEL_HI, 255))  # 광원 위쪽·왼쪽 (3-2)
    px(img, 7, 13, WHITE)
    px(img, 8, 13, WHITE)
    # 하단 충격 쐐기 (꽂힌 순간) — 청·시안
    pxs(img, [(4, 12), (3, 11), (11, 12), (12, 11)], CYAN)
    pxs(img, [(2, 13), (5, 14), (13, 13), (10, 14)], BLUE)
    return add_outline(img)


# ---------------------------------------------------------------- 궁수 4종


def skill_rapid_shot() -> Image.Image:
    """속사 — 3연사. **평행 화살 3발**이 1차 신호(발수로 관통 폭사와 구분)."""
    img = new_icon()
    for y in (3, 7, 11):
        arrow_right(img, 2, 13, y, WOOD, STEEL_HI)
    # 연사 리듬 — 각 화살 뒤에 시안 잔상 1px
    pxs(img, [(1, 3), (1, 7), (1, 11)], CYAN)
    # 화살대 그림자로 3단 (아이콘 3단 램프)
    for y in (4, 8, 12):
        for x in range(3, 11):
            px(img, x, y, WOOD_DK)
    return add_outline(img)


def skill_acrobatic_shot() -> Image.Image:
    """곡예 사격 — 구르며 쏘기. **열린 곡선 궤적 + 궤적 촉** + 대각 화살.

    선풍(닫힌 링)과의 혼동을 막기 위해 궤적을 **좌하단 열린 호**로만 그린다.
    """
    img = new_icon()
    d = ImageDraw.Draw(img)
    # 구르는 궤적 = **큰 회전 화살**(3/4 링 + 진행 촉). 링은 아이콘 전체를 쓴다 —
    # 선풍이 링을 포기하고 X자로 갔으므로(위 참조) 원형 링은 이 아이콘의 전용 신호다.
    d.arc([1, 1, 14, 14], start=35, end=330, fill=(*BLUE, 255), width=2)
    pxs(img, [(6, 1), (7, 1), (8, 1), (3, 3), (2, 4)], CYAN)
    pxs(img, [(12, 3), (13, 4), (13, 2)], CYAN)  # 링 끝 진행 촉 (반시계 = 구르는 방향)
    # 발사된 화살 — 중심에서 우상단으로 **반지름 방향**으로만 뻗는다.
    # 지름(양단 관통)으로 그리면 "금지 표지"가 되므로(선풍 폐기 시안의 교훈) 반지름만 쓴다.
    for i in range(4):
        px(img, 8 + i, 8 - i, WOOD)
        px(img, 7 + i, 8 - i, WOOD_DK)
    pxs(img, [(12, 4), (12, 3), (11, 4), (13, 4)], STEEL_HI)  # 촉
    px(img, 13, 3, WHITE)
    pxs(img, [(6, 9), (7, 10)], WHITE)  # 깃
    # 회전 중심 (몸) — 링과 화살이 한 동작임을 묶는다
    pxs(img, [(6, 11), (7, 11), (6, 12), (7, 12)], NAVY_GRAY)
    return add_outline(img)


def skill_hawk_eye() -> Image.Image:
    """매의 눈 — 치명타 버프. **눈 + 십자 조준 눈금**(8종 중 유일한 눈 형태)."""
    img = new_icon()
    d = ImageDraw.Draw(img)
    # 눈꺼풀 (렌즈형)
    d.polygon([(3, 8), (7, 4), (12, 8), (7, 12)], fill=(*NAVY, 255))
    d.polygon([(5, 8), (7, 6), (10, 8), (7, 10)], fill=(*STEEL_HI, 255))
    # 홍채 시안 + 흰 반사 1px
    pxs(img, [(7, 7), (8, 7), (7, 8), (8, 8)], CYAN)
    px(img, 7, 7, WHITE)
    # 상단 눈꺼풀 하이라이트 (광원 위쪽)
    pxs(img, [(5, 6), (6, 5), (8, 5), (9, 6)], BLUE)
    # 십자 조준 눈금 (4방향) — "조준·치명"의 형태 신호
    pxs(img, [(0, 8), (1, 8), (14, 8), (15, 8), (7, 1), (7, 2), (7, 14), (7, 15)], CYAN)
    return add_outline(img)


def skill_ultimate_piercing_burst() -> Image.Image:
    """관통 폭사 — 궁극기(무제한 관통). **장척 화살 1발 + 관통 표식 3 + 금색 코너**.

    금색 코너는 기존 `skill_ultimate_ground_smash` 의 궁극기 강조 선례 계승(6-1 6순위).
    궁극기가 1종뿐이라 코너 프레임 자체가 "궁극기 슬롯" 식별 신호를 겸한다.
    """
    img = new_icon()
    d = ImageDraw.Draw(img)
    # 관통된 표식 3개 (짧은 세로 바 — 화살보다 뒤 레이어). 화살대에서 위아래로만 튀어나오게
    # 짧게 잡는다 — 길면 화살 좌우 끝의 잔상과 합쳐져 "아령"처럼 보인다(1차 시안 실측)
    for x in (4, 8, 12):
        d.line([(x, 6), (x, 11)], fill=(*NAVY_GRAY, 255), width=1)
        px(img, x, 6, NAVY)
    # 장척 화살 1발 (프레임 전체를 가로지름 = 무제한 관통)
    for x in range(2, 12):
        px(img, x, 8, STEEL_HI)
        px(img, x, 9, STEEL)
    # 촉 (4px 삼각 — 크게 잡아 진행 방향을 확정)
    pxs(img, [(12, 8), (12, 9), (13, 8), (13, 9), (14, 8), (12, 7), (12, 10)], STEEL_HI)
    pxs(img, [(13, 8), (14, 8)], WHITE)
    # 발사 잔상 = 좌측 V자 깃 (세로 바로 그리면 우측 촉과 대칭이 되어 아령이 된다)
    pxs(img, [(1, 6), (2, 7), (1, 11), (2, 10)], CYAN)
    # 궁극기 코너 프레임 (4각 2px)
    for cx, cy in [(0, 0), (15, 0), (0, 15), (15, 15)]:
        px(img, cx, cy, GOLD)
        px(img, cx + (1 if cx == 0 else -1), cy, GOLD)
        px(img, cx, cy + (1 if cy == 0 else -1), GOLD)
    return add_outline(img)


SKILLS = [
    ("skill_whirlwind", skill_whirlwind),
    ("skill_charge_slam", skill_charge_slam),
    ("skill_blood_shout", skill_blood_shout),
    ("skill_execution", skill_execution),
    ("skill_rapid_shot", skill_rapid_shot),
    ("skill_acrobatic_shot", skill_acrobatic_shot),
    ("skill_hawk_eye", skill_hawk_eye),
    ("skill_ultimate_piercing_burst", skill_ultimate_piercing_burst),
]


def save_preview(entries: list[tuple[str, Image.Image]], out_path: Path) -> None:
    cols, margin = 4, 4
    rows = (len(entries) + cols - 1) // cols
    cell = SIZE + margin
    sheet = Image.new("RGBA", (cols * cell, rows * cell), (*RGB["dark_navy"], 255))
    for i, (_name, img) in enumerate(entries):
        c, r = i % cols, i // cols
        sheet.paste(img, (c * cell + margin // 2, r * cell + margin // 2), img)
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(out_path)


def main() -> int:
    SKILLS_DIR.mkdir(parents=True, exist_ok=True)
    imgs = []
    for name, gen in SKILLS:
        img = gen()
        # 규격 자기검사: 16x16 · 코너 외곽선 여유 확인은 validate_palette.py 가 담당
        assert img.size == (SIZE, SIZE)
        img.save(SKILLS_DIR / f"{name}.png")
        imgs.append((name, img))
        print(f"저장 완료: {SKILLS_DIR / f'{name}.png'}")
    save_preview(imgs, SKILLS_DIR / "_preview_m3_4x.png")
    print(f"프리뷰 시트 저장 완료: {SKILLS_DIR / '_preview_m3_4x.png'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
