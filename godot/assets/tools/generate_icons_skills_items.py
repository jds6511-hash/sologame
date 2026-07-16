"""AR-3: 스킬 7종 + 스타터 아이템 9종 아이콘 절차 생성 (Pillow).

참조:
- `docs\\design\\systems\\m2-warrior-skills.md` 1장 슬롯 구성표 — 스킬 7종
  (강타/질주/응급 처치/분쇄 베기/돌격/결의의 외침/대지 분쇄, 궁극기 포함 개수 검산 "7개")
- `docs\\design\\economy\\economy-foundation.md` 3-1장 표 — 스타터 아이템 9종
- `docs\\art\\STYLE_GUIDE.md` 1-2장(아이콘 16x16 원본), 2장(EDG32 팔레트),
  2-1장(등급 S/A/B/C 역할 고정색), 3-1장(아이콘 1px 외곽선 #181425 필수)

아이콘 규칙:
- 캔버스 16x16, 실제 도형은 1px 외곽선 자리(가장자리)를 남기고 내부 14x14에 그린다.
- 외곽선은 도형을 다 그린 뒤 `add_outline()`으로 자동 부여(불투명 픽셀에 인접한 투명 픽셀을
  #181425로 채움) — 수동으로 그리지 않아 외곽선 규칙(3-1장)을 항상 정확히 만족.
- 아이템 아이콘에는 STYLE_GUIDE 2-1장 등급 고정색(C=#8b9bb4, B=#63c74d)을 우측 하단에
  2x2 표식으로 추가해 등급을 색+위치로 이중 신호(경제 문서 3-1장 등급과 매핑).

출력: godot\\assets\\icons\\skills\\*.png (7개), godot\\assets\\icons\\items\\*.png (9개),
      각 디렉터리에 프리뷰 시트(*_preview_4x.png)도 함께 저장.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from edg32_palette import RGB, OUTLINE_RGB

SIZE = 16
ASSETS_DIR = Path(__file__).parent.parent
SKILLS_DIR = ASSETS_DIR / "icons" / "skills"
ITEMS_DIR = ASSETS_DIR / "icons" / "items"

# 색 별칭
BLUE_GRAY = RGB["blue_gray"]
DARK_BLUE_GRAY = RGB["dark_blue_gray"]
LIGHT_BLUE_GRAY = RGB["light_blue_gray"]
TAN = RGB["tan"]
ORANGE_BROWN = RGB["orange_brown"]
RED_BROWN_DARK = RGB["red_brown_dark"]
OCHRE = RGB["ochre"]
WHITE = RGB["white"]
BRIGHT_YELLOW = RGB["bright_yellow"]
GOLD = RGB["gold"]
FRESH_GREEN = RGB["fresh_green"]
GREEN = RGB["green"]
DEEP_GREEN = RGB["deep_green"]
SCARLET = RGB["scarlet"]
BLOOD_RED = RGB["blood_red"]
BLUE = RGB["blue"]
CYAN = RGB["cyan"]
SAND_CREAM = RGB["sand_cream"]
APRICOT = RGB["apricot"]
NAVY = RGB["navy"]

GRADE_COLOR = {
    "C": BLUE_GRAY,
    "B": FRESH_GREEN,
    "A": BLUE,
    "S": GOLD,
}


def new_icon() -> Image.Image:
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def px(img: Image.Image, x: int, y: int, color: tuple[int, int, int]) -> None:
    if 0 <= x < SIZE and 0 <= y < SIZE:
        img.putpixel((x, y), (*color, 255))


def add_outline(img: Image.Image) -> Image.Image:
    """불투명 픽셀에 8방향으로 인접한 투명 픽셀을 #181425로 채워 1px 외곽선을 만든다."""
    out = img.copy()
    src = img.load()
    dst = out.load()
    for y in range(SIZE):
        for x in range(SIZE):
            if src[x, y][3] != 0:
                continue
            neighbor_opaque = False
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < SIZE and 0 <= ny < SIZE and src[nx, ny][3] != 0:
                        neighbor_opaque = True
                        break
                if neighbor_opaque:
                    break
            if neighbor_opaque:
                dst[x, y] = (*OUTLINE_RGB, 255)
    return out


def add_grade_marker(img: Image.Image, grade: str) -> Image.Image:
    """우측 하단 2x2 등급 표식 (STYLE_GUIDE 2-1장 역할 고정색)."""
    color = GRADE_COLOR[grade]
    for dx in range(2):
        for dy in range(2):
            px(img, SIZE - 3 + dx, SIZE - 3 + dy, color)
    return img


def finalize(img: Image.Image, grade: str | None = None) -> Image.Image:
    if grade:
        img = add_grade_marker(img, grade)
    return add_outline(img)


# ---------------------------------------------------------------------------
# 스킬 아이콘 7종
# ---------------------------------------------------------------------------


def skill_strike() -> Image.Image:
    """강타 - 대검을 내려찍는 즉발기. 대각선 칼날 + 타격 스파크."""
    img = new_icon()
    d = ImageDraw.Draw(img)
    # 칼날 (우상단 -> 좌하단)
    d.line([(12, 2), (4, 10)], fill=(*BLUE_GRAY, 255), width=2)
    d.line([(12, 2), (5, 9)], fill=(*LIGHT_BLUE_GRAY, 255), width=1)
    # 손잡이 + 가드
    d.line([(13, 2), (14, 1)], fill=(*TAN, 255), width=1)
    px(img, 12, 3, DARK_BLUE_GRAY)
    px(img, 13, 3, TAN)
    # 타격 스파크
    for x, y in [(3, 11), (2, 12), (4, 12), (3, 13)]:
        px(img, x, y, BRIGHT_YELLOW)
    px(img, 3, 12, WHITE)
    return finalize(img)


def skill_sprint() -> Image.Image:
    """질주 - 이동기. 부츠 + 후행 스피드 라인."""
    img = new_icon()
    d = ImageDraw.Draw(img)
    # 부츠 실루엣
    boot = [(8, 5), (11, 5), (11, 9), (12, 9), (12, 12), (7, 12), (7, 9), (8, 9)]
    d.polygon(boot, fill=(*ORANGE_BROWN, 255))
    d.line([(7, 11), (12, 11)], fill=(*RED_BROWN_DARK, 255), width=1)
    px(img, 8, 6, APRICOT)
    # 스피드 라인 (좌측으로 후행)
    for i, y in enumerate((5, 7, 9)):
        length = 4 - i
        for k in range(length):
            px(img, 6 - k, y, LIGHT_BLUE_GRAY if k < 2 else BLUE_GRAY)
    return finalize(img)


def skill_first_aid() -> Image.Image:
    """응급 처치 - 자가 회복. 흰 바탕 위 녹색 십자가."""
    img = new_icon()
    d = ImageDraw.Draw(img)
    d.ellipse([2, 2, 13, 13], fill=(*WHITE, 255))
    d.rectangle([6, 4, 9, 11], fill=(*FRESH_GREEN, 255))
    d.rectangle([4, 6, 11, 9], fill=(*FRESH_GREEN, 255))
    for x, y in [(6, 4), (9, 4), (6, 11), (9, 11), (4, 6), (4, 9), (11, 6), (11, 9)]:
        px(img, x, y, GREEN)
    return finalize(img)


def skill_cleave() -> Image.Image:
    """분쇄 베기 - 전사 1차 즉발기. 넓은 대검 + 넓은 호선 궤적."""
    img = new_icon()
    d = ImageDraw.Draw(img)
    # 넓은 칼날
    d.polygon([(4, 11), (10, 3), (12, 4), (6, 12)], fill=(*BLUE_GRAY, 255))
    d.line([(9, 4), (11, 5)], fill=(*LIGHT_BLUE_GRAY, 255), width=1)
    px(img, 12, 3, TAN)
    px(img, 13, 2, TAN)
    # 호선 궤적 (아크)
    arc_pixels = [(3, 4), (2, 6), (2, 8), (3, 10), (5, 12)]
    for x, y in arc_pixels:
        px(img, x, y, LIGHT_BLUE_GRAY)
    return finalize(img)


def skill_charge() -> Image.Image:
    """돌격 - 전사 1차 이동기. 전방을 향한 화살촉 + 몸통 + 뒤편 흙먼지."""
    img = new_icon()
    d = ImageDraw.Draw(img)
    # 화살촉 (우측 끝을 향함)
    d.polygon([(13, 8), (9, 5), (9, 11)], fill=(*LIGHT_BLUE_GRAY, 255))
    px(img, 10, 8, BLUE_GRAY)
    # 화살 몸통
    d.rectangle([3, 7, 9, 9], fill=(*OCHRE, 255))
    d.line([(3, 7), (9, 7)], fill=(*TAN, 255), width=1)
    d.line([(3, 9), (9, 9)], fill=(*RED_BROWN_DARK, 255), width=1)
    # 흙먼지 (후행)
    for x, y in [(2, 5), (1, 6), (2, 11), (1, 10), (3, 4)]:
        px(img, x, y, LIGHT_BLUE_GRAY)
    return finalize(img)


def skill_battle_shout() -> Image.Image:
    """결의의 외침 - 전사 1차 버프. 방패 + 방사형 오라 링."""
    img = new_icon()
    d = ImageDraw.Draw(img)
    d.polygon([(8, 3), (12, 5), (12, 9), (8, 13), (4, 9), (4, 5)], fill=(*BLUE_GRAY, 255))
    d.polygon([(8, 5), (10, 6), (10, 8), (8, 11), (6, 8), (6, 6)], fill=(*DARK_BLUE_GRAY, 255))
    # 오라 (금색 방사)
    for x, y in [(2, 8), (13, 8), (8, 1), (8, 14), (3, 3), (12, 13), (12, 3), (3, 13)]:
        px(img, x, y, GOLD)
    return finalize(img)


def skill_ultimate_ground_smash() -> Image.Image:
    """대지 분쇄 - 궁극기. 강한 지면 강타 + 균열 + 골드 임팩트(궁극기 강조)."""
    img = new_icon()
    d = ImageDraw.Draw(img)
    # 지면
    d.rectangle([1, 11, 14, 13], fill=(*OCHRE, 255))
    for x, y in [(3, 11), (7, 12), (11, 11), (5, 13), (9, 13)]:
        px(img, x, y, RED_BROWN_DARK)
    # 균열
    for x, y in [(7, 11), (6, 10), (8, 10), (7, 9)]:
        px(img, x, y, RED_BROWN_DARK)
    # 주먹/망치 (내려찍는 순간)
    d.rectangle([5, 3, 10, 8], fill=(*DARK_BLUE_GRAY, 255))
    d.rectangle([6, 4, 9, 7], fill=(*BLUE_GRAY, 255))
    # 궁극기 강조 - 골드 임팩트
    for x, y in [(4, 9), (11, 9), (2, 10), (13, 10)]:
        px(img, x, y, GOLD)
    px(img, 7, 8, WHITE)
    px(img, 8, 8, WHITE)
    return finalize(img)


# ---------------------------------------------------------------------------
# 스타터 아이템 아이콘 9종
# ---------------------------------------------------------------------------


def item_short_sword_c() -> Image.Image:
    """WPN-SW-01-C 낡은 소검 - 짧고 곧은 한손검(대검과 실루엣으로 구분)."""
    img = new_icon()
    d = ImageDraw.Draw(img)
    d.rectangle([7, 3, 8, 9], fill=(*BLUE_GRAY, 255))
    px(img, 7, 3, LIGHT_BLUE_GRAY)
    d.rectangle([5, 10, 10, 11], fill=(*RED_BROWN_DARK, 255))
    d.rectangle([7, 11, 8, 13], fill=(*TAN, 255))
    return finalize(img, grade="C")


def item_greatsword_c() -> Image.Image:
    """WPN-GS-10-C 투박한 대검 - 소검보다 훨씬 크고 두꺼운 대각선 양손검."""
    img = new_icon()
    d = ImageDraw.Draw(img)
    d.polygon([(13, 1), (14, 2), (7, 12), (5, 11)], fill=(*BLUE_GRAY, 255))
    d.line([(3, 8), (7, 5)], fill=(*RED_BROWN_DARK, 255), width=2)  # 가드(십자)
    d.rectangle([3, 9, 5, 13], fill=(*TAN, 255))  # 긴 손잡이
    return finalize(img, grade="C")


def item_greatsword_b() -> Image.Image:
    """WPN-GS-10-B 병사의 대검 (C와 동일 실루엣 + 하이라이트로 정련된 느낌 차별화)"""
    img = new_icon()
    d = ImageDraw.Draw(img)
    d.polygon([(13, 1), (14, 2), (7, 12), (5, 11)], fill=(*BLUE_GRAY, 255))
    d.line([(13, 1), (8, 10)], fill=(*LIGHT_BLUE_GRAY, 255), width=1)
    d.line([(3, 8), (7, 5)], fill=(*NAVY, 255), width=2)  # 가드(십자, 강철색 강조)
    d.rectangle([3, 9, 5, 13], fill=(*TAN, 255))
    return finalize(img, grade="B")


def item_chainmail_body_b() -> Image.Image:
    """ARM-BODY-10-B 병사의 사슬 갑옷"""
    img = new_icon()
    d = ImageDraw.Draw(img)
    d.polygon([(5, 3), (10, 3), (12, 5), (12, 11), (9, 13), (6, 13), (3, 11), (3, 5)],
              fill=(*BLUE_GRAY, 255))
    for y in range(4, 12, 2):
        for x in range(4, 12, 2):
            px(img, x, y, DARK_BLUE_GRAY)
    d.line([(5, 3), (7, 5), (9, 3)], fill=(*LIGHT_BLUE_GRAY, 255), width=1)
    return finalize(img, grade="B")


def item_leather_pants_c() -> Image.Image:
    """ARM-LEG-10-C 무두질 가죽 바지 - 허리 밴드 + 갈라진 두 다리."""
    img = new_icon()
    d = ImageDraw.Draw(img)
    d.rectangle([4, 3, 11, 5], fill=(*ORANGE_BROWN, 255))  # 허리 밴드
    d.line([(4, 3), (11, 3)], fill=(*TAN, 255), width=1)
    d.rectangle([4, 6, 6, 12], fill=(*ORANGE_BROWN, 255))  # 왼쪽 다리
    d.rectangle([9, 6, 11, 12], fill=(*ORANGE_BROWN, 255))  # 오른쪽 다리 (사이 간격으로 분리)
    d.line([(4, 6), (4, 12)], fill=(*RED_BROWN_DARK, 255), width=1)
    d.line([(11, 6), (11, 12)], fill=(*RED_BROWN_DARK, 255), width=1)
    px(img, 5, 8, TAN)
    px(img, 10, 8, TAN)
    return finalize(img, grade="C")


def item_iron_helmet_c() -> Image.Image:
    """ARM-HEAD-10-C 낡은 철모"""
    img = new_icon()
    d = ImageDraw.Draw(img)
    d.pieslice([3, 3, 12, 12], 180, 360, fill=(*BLUE_GRAY, 255))
    d.rectangle([3, 8, 12, 9], fill=(*DARK_BLUE_GRAY, 255))
    d.line([(6, 9), (6, 11)], fill=(*DARK_BLUE_GRAY, 255), width=1)
    d.line([(9, 9), (9, 11)], fill=(*DARK_BLUE_GRAY, 255), width=1)
    px(img, 5, 5, LIGHT_BLUE_GRAY)
    return finalize(img, grade="C")


def item_traveler_boots_c() -> Image.Image:
    """ARM-FOOT-10-C 여행자의 장화"""
    img = new_icon()
    d = ImageDraw.Draw(img)
    d.rectangle([5, 3, 9, 8], fill=(*ORANGE_BROWN, 255))
    d.polygon([(5, 8), (11, 8), (11, 11), (7, 11), (7, 12), (5, 12)], fill=(*ORANGE_BROWN, 255))
    d.line([(5, 9), (11, 9)], fill=(*RED_BROWN_DARK, 255), width=1)
    px(img, 6, 5, TAN)
    return finalize(img, grade="C")


def item_ring_crit_b() -> Image.Image:
    """ACC-RING-10-B 붉은 인장 반지"""
    img = new_icon()
    d = ImageDraw.Draw(img)
    d.ellipse([4, 6, 11, 13], outline=(*LIGHT_BLUE_GRAY, 255), width=2)
    d.ellipse([6, 3, 9, 6], fill=(*SCARLET, 255))
    px(img, 7, 4, BLOOD_RED)
    px(img, 7, 3, WHITE)
    return finalize(img, grade="B")


def item_amulet_hp_b() -> Image.Image:
    """ACC-NECK-10-B 참나무 부적"""
    img = new_icon()
    d = ImageDraw.Draw(img)
    d.arc([3, 1, 12, 8], start=20, end=160, fill=(*BLUE_GRAY, 255), width=1)
    d.polygon([(6, 7), (9, 7), (10, 10), (7, 13), (5, 10)], fill=(*RED_BROWN_DARK, 255))
    d.polygon([(6, 8), (9, 8), (9, 10), (7, 12), (6, 10)], fill=(*ORANGE_BROWN, 255))
    px(img, 7, 9, FRESH_GREEN)
    px(img, 7, 10, FRESH_GREEN)
    return finalize(img, grade="B")


SKILLS = [
    ("skill_strike", skill_strike),
    ("skill_sprint", skill_sprint),
    ("skill_first_aid", skill_first_aid),
    ("skill_cleave", skill_cleave),
    ("skill_charge", skill_charge),
    ("skill_battle_shout", skill_battle_shout),
    ("skill_ultimate_ground_smash", skill_ultimate_ground_smash),
]

ITEMS = [
    ("wpn_sw_01_c", item_short_sword_c),
    ("wpn_gs_10_c", item_greatsword_c),
    ("wpn_gs_10_b", item_greatsword_b),
    ("arm_body_10_b", item_chainmail_body_b),
    ("arm_leg_10_c", item_leather_pants_c),
    ("arm_head_10_c", item_iron_helmet_c),
    ("arm_foot_10_c", item_traveler_boots_c),
    ("acc_ring_10_b", item_ring_crit_b),
    ("acc_neck_10_b", item_amulet_hp_b),
]


def save_preview_sheet(entries: list[tuple[str, Image.Image]], out_path: Path, cols: int = 4) -> None:
    rows = (len(entries) + cols - 1) // cols
    margin = 4
    cell = SIZE + margin
    sheet = Image.new("RGBA", (cols * cell, rows * cell), (38, 43, 68, 255))  # dark_navy 배경
    for i, (_name, img) in enumerate(entries):
        col, row = i % cols, i // cols
        sheet.paste(img, (col * cell + margin // 2, row * cell + margin // 2), img)
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(out_path)


def main() -> None:
    SKILLS_DIR.mkdir(parents=True, exist_ok=True)
    ITEMS_DIR.mkdir(parents=True, exist_ok=True)

    skill_imgs = []
    for name, gen in SKILLS:
        img = gen()
        img.save(SKILLS_DIR / f"{name}.png")
        skill_imgs.append((name, img))
        print(f"저장 완료: {SKILLS_DIR / f'{name}.png'}")

    item_imgs = []
    for name, gen in ITEMS:
        img = gen()
        img.save(ITEMS_DIR / f"{name}.png")
        item_imgs.append((name, img))
        print(f"저장 완료: {ITEMS_DIR / f'{name}.png'}")

    save_preview_sheet(skill_imgs, SKILLS_DIR / "_preview_4x.png")
    save_preview_sheet(item_imgs, ITEMS_DIR / "_preview_4x.png")
    print("프리뷰 시트 저장 완료")


if __name__ == "__main__":
    main()
