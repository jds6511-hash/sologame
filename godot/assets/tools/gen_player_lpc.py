"""전사·궁수 정식 스프라이트 생성 (M3 3-A, LPC 손그림 베이스 -> 20x36 EDG32).

- 계획서: `docs\\art\\m3-character-art-plan.md` 5장(전사 90프레임)·6장(궁수 90프레임)·10장(파일명 규약)
- 규격: `docs\\art\\STYLE_GUIDE.md` 1-2(20x36)·3-1(아웃라인)·3-2-1(4단 램프)·3-3(프레임 수)·7-1(시트 규약)
- 소스·라이선스: `docs\\art\\ASSET_SOURCES.md` 10장 (LPC = B등급, CC-BY-SA 3.0 선택)

선행 조건: `python fetch_lpc_layers.py` (원본은 `_raw_src\\lpc\\`, 저장소 커밋 금지)

사용법:
    python gen_player_lpc.py                # 전사 + 궁수 전체
    python gen_player_lpc.py --job warrior  # 한 직업만
    python gen_player_lpc.py --report       # 생성 없이 프레임 수·클리핑만 점검
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from lpc_common import (  # noqa: E402
    ASSETS_DIR,
    DIRECTIONS,
    FRAME_H,
    FRAME_W,
    Layer,
    StateSpec,
    Weapon,
    bands_from,
    build_sheet,
    collect_luminance,
    compose_frame,
    crop_to_frame,
    downscale,
    ensure_outline,
    foot_row_check,
    material_ids,
    palette_violations,
    recolor,
    rotate_pair,
)

OUT_DIR = ASSETS_DIR / "sprites" / "player"

# ---------------------------------------------------------------- 캐릭터 레이어

# 합성 순서(아래 -> 위). LPC 표준 순서: 몸 -> 하의 -> 신발 -> 상의 -> 머리 -> 머리카락
def char_layers(torso: str, torso_material: str, quiver: bool = False) -> list[Layer]:
    layers = [Layer("body", "body/bodies/male/{anim}.png", "skin")]
    if quiver:
        layers.append(Layer("quiver", "quiver/{anim}/quiver.png", "boots"))
    layers += [
        Layer("legs", "legs/pants/male/{anim}.png", "pants"),
        Layer("feet", "feet/boots/basic/male/{anim}.png", "boots"),
        Layer("torso", torso, torso_material),
        Layer("head", "head/heads/human/male/{anim}.png", "skin"),
        Layer("hair", "hair/buzzcut/adult/{anim}.png", "hair"),
    ]
    return layers


WARRIOR_LAYERS = char_layers("torso/armour/plate/male/{anim}.png", "torso")
ARCHER_LAYERS = char_layers("torso/clothes/longsleeve/longsleeve/male/{anim}.png", "torso", quiver=True)

# 재질 이름 -> EDG32 램프.
# 재질을 부위별로 쪼개 두는 이유: 램프 밴드가 재질별 휘도 분포에서 따로 잡히므로,
# 부위를 합치면(예: 바지+부츠를 한 재질로) 둘이 같은 명도로 뭉개져 실루엣이 사라진다.
# 인접 부위는 반드시 **다른 색 계열**로 배정해 20x36에서도 부위 경계가 읽히게 한다.
WARRIOR_RAMPS = {
    "skin": "skin",
    "hair": "hair_dark",  # 피부와 붙어 있으므로 확실히 어두운 계열
    "torso": "steel",  # 판금 상의 — 밝은 회청으로 상체를 눈에 띄게
    "pants": "trouser_dark",  # 하체는 어둡게 -> 발밑이 무거워 보이고 상체가 도드라진다
    "boots": "leather",
    "steel": "steel_bright",  # 검 — 상의보다 더 밝게 해서 무기가 분리돼 보이게
}
ARCHER_RAMPS = {
    "skin": "skin",
    "hair": "hair_dark",
    "torso": "cloth_green",  # 수림 궁수 — 전사(회청 판금)와 색 계열로 즉시 구분
    "pants": "trouser_dark",
    "boots": "leather",
    "wood": "wood",  # 활·화살통
}

# ---------------------------------------------------------------- 무기 정의

SW = "weapon/sword/arming"


def sword_universal(anim: str) -> Weapon:
    """검을 뽑아 든 대기·이동·피격용 (셀 64). arming 세트만 이 커버리지를 갖는다."""
    return Weapon(
        fg=f"{SW}/universal/fg/{anim}/steel.png",
        bg=f"{SW}/universal/bg/{anim}/steel.png",
        cell=64,
        material="steel",
    )


def sword_attack(kind: str) -> Weapon:
    """공격 3종 (셀 128 oversize). kind: attack_slash / attack_halfslash / attack_backslash"""
    return Weapon(fg=f"{SW}/{kind}/fg.png", bg=f"{SW}/{kind}/bg.png", cell=128, material="steel")


BOW_SHOOT = Weapon(
    fg="weapon/ranged/bow/normal/universal/foreground/shoot.png",
    bg="weapon/ranged/bow/normal/universal/background/shoot.png",
    cell=64,
    material="wood",
    extra="weapon/ranged/bow/arrow/shoot/arrow.png",
)
BOW_WALK = Weapon(
    fg="weapon/ranged/bow/normal/walk/foreground.png",
    bg="weapon/ranged/bow/normal/walk/background.png",
    cell=128,
    material="wood",
)
BOW_HURT = Weapon(
    fg="weapon/ranged/bow/normal/universal/foreground/hurt.png",
    bg="weapon/ranged/bow/normal/universal/background/hurt.png",
    cell=64,
    material="wood",
)

# `jump`·`spellcast` 는 무기 시트가 없다. 다른 애니메이션의 무기 프레임을 얹으면
# 손에서 떨어져 공중에 뜬다(실측 확인). 그래서 아래 보정표로 손 위치에 맞춘다.
DODGE_SWORD_OFFSET = {
    ("front", 0): (0, -1), ("front", 1): (1, -4), ("front", 2): (1, -3),
    ("side", 0): (0, -1), ("side", 1): (2, -4), ("side", 2): (2, -3),
    ("back", 0): (0, -1), ("back", 1): (-1, -4), ("back", 2): (-1, -3),
}
DODGE_BOW_OFFSET = {
    ("front", 0): (0, -1), ("front", 1): (0, -4), ("front", 2): (0, -3),
    ("side", 0): (0, -1), ("side", 1): (1, -4), ("side", 2): (1, -3),
    ("back", 0): (0, -1), ("back", 1): (0, -4), ("back", 2): (0, -3),
}

# ---------------------------------------------------------------- 상태 명세

# LPC walk 9프레임 중 0=정지 제외, 8프레임 사이클에서 6개 균등 추출
WALK_FRAMES = [1, 2, 4, 5, 6, 8]

# 아래 프레임 선택은 **최종 20x36 출력을 눌러보고** 고른 값이다. 원본에서 자연스러워도
# 20px 캔버스에서는 무기가 프레임 밖으로 나가 "무기가 사라진" 프레임이 생기기 때문이다
# (예: LPC slash f4·f5 는 궤적만 남고 칼날이 프레임 밖이라 제외했다).
WARRIOR_STATES = [
    StateSpec("idle", "combat_idle", [0, 1, 0, 1], sword_universal("combat_idle"),
              note="검을 뽑아 든 전투 대기 2포즈 호흡 루프 (LPC combat_idle 원본이 2프레임)"),
    StateSpec("walk", "walk", WALK_FRAMES, sword_universal("walk")),
    StateSpec("attack", "slash", [0, 1, 2, 3], sword_attack("attack_slash"),
              note="내려베기 — 선딜1 + 타격1 + 후딜2. f4·f5 는 칼날이 프레임 밖이라 제외"),
    StateSpec("attack2", "halfslash", [0, 1, 2, 5], sword_attack("attack_halfslash"),
              note="수평 횡베기 — 1타(내려베기)와 실루엣이 명확히 다름. f3·f4 는 칼날이 프레임 밖"),
    StateSpec("hit", "hurt", [0], sword_universal("hurt"),
              note="LPC hurt 원본은 front 1행뿐 -> 3방향 공유"),
    StateSpec("death", "hurt", [1, 2, 3, 5], sword_universal("hurt"),
              note="비틀림 -> 무릎 -> 붕괴 -> 지면"),
    StateSpec("dodge", "jump", [1, 2, 3], sword_universal("idle"),
              weapon_frames=[0, 0, 0], weapon_offset=DODGE_SWORD_OFFSET, airborne=True,
              note="도약1+공중1+착지1. jump 전용 검 시트가 없어 idle 검을 손 위치로 보정"),
    StateSpec("charge", "backslash", [2, 3], sword_attack("attack_backslash"),
              note="차지 홀드 — 상체를 젖히고 검을 뒤로 당겨 버틴 정지(슈퍼아머가 자세로 읽힘)"),
    StateSpec("cast", "backslash", [7, 8], sword_attack("attack_backslash"),
              note="포효/함성 — 검을 앞으로 뻗어 든 2프레임 루프. charge(뒤로 젖힘)와 정반대 실루엣"),
]

ARCHER_STATES = [
    StateSpec("idle", "idle", [0, 1, 0, 1], BOW_WALK, weapon_frames=[0, 0, 0, 0],
              note="활을 몸 옆으로 내려 든 정지 (전사 검 대기와 실루엣 구분)"),
    StateSpec("walk", "walk", WALK_FRAMES, BOW_WALK),
    StateSpec("attack", "shoot", [4, 6, 9, 11], BOW_SHOOT, hide_fg_dirs=("front",),
              note="draw 1 + full draw 1 + release 1 + recovery 1. 정면은 활 fg 가 얼굴을 "
                   "완전히 덮어(실측) bg 만 써서 활을 몸 뒤로 넘긴다"),
    StateSpec("aim", "shoot", [4, 5], BOW_SHOOT, hide_fg_dirs=("front",),
              note="반쯤 당긴 무방비 조준 스탠스 2프레임 루프 (전사 charge 와 정반대로 몸을 세움)"),
    StateSpec("hit", "hurt", [0], BOW_HURT, note="LPC hurt 원본은 front 1행뿐 -> 3방향 공유"),
    StateSpec("death", "hurt", [1, 2, 3, 5], BOW_HURT),
    StateSpec("dodge", "jump", [1, 2, 3], BOW_WALK, weapon_frames=[0, 0, 0],
              weapon_offset=DODGE_BOW_OFFSET, airborne=True,
              note="후방 점프 — 도약1+공중1+착지1. 뒤로 뛰는 방향감은 이동·vfx 가 보조"),
    StateSpec("rollshot", "shoot", [5, 7, 9, 11], BOW_SHOOT, hide_fg_dirs=("front",),
              tilt=[-16.0, -7.0, 6.0, 0.0],
              note="곡예 사격 — 사격 자세에 프레임별 기울기를 넣어 구르는 중 상체 비틀림을 근사"),
    StateSpec("cast", "spellcast", [4, 5], BOW_WALK, weapon_frames=[0, 0],
              note="매의 눈 자가 버프 — 활은 반대 손에 들려 있어 walk 활 프레임이 그대로 맞는다"),
]

JOBS = {
    "warrior": ("player_warrior_v2", WARRIOR_LAYERS, WARRIOR_RAMPS, WARRIOR_STATES),
    "archer": ("player_archer", ARCHER_LAYERS, ARCHER_RAMPS, ARCHER_STATES),
}


def build_job(job: str, report_only: bool) -> tuple[int, list[str]]:
    prefix, layers, ramp_of, states = JOBS[job]
    weapons = [s.weapon for s in states if s.weapon]
    mats = material_ids(layers, weapons)

    # 1패스: 전 상태·전 방향 합성 + 축소 (재질별 휘도 표본 수집)
    composed: dict[str, dict[str, list[tuple[Image.Image, Image.Image]]]] = {}
    shrink: dict[str, float] = {}
    for spec in states:
        composed[spec.state] = {}
        for d in DIRECTIONS:
            seq = []
            for i in range(len(spec.frames)):
                rgba, idm, k = compose_frame(layers, spec, d, i, mats)
                if k < 1.0:
                    shrink[spec.state] = min(shrink.get(spec.state, 1.0), k)
                if spec.tilt:
                    rgba, idm = rotate_pair(rgba, idm, spec.tilt[i])
                seq.append(downscale(rgba, idm, mats))
            composed[spec.state][d] = seq

    flat = [f for st in composed.values() for seq in st.values() for f in seq]
    bands = {mid: bands_from(l) for mid, l in collect_luminance(flat, mats).items()}

    # 2패스: 재색상 -> 아웃라인 -> 크롭 -> 시트
    total = 0
    issues: list[str] = []
    for spec in states:
        by_dir: dict[str, list[Image.Image]] = {}
        clipped_max = 0
        for d in DIRECTIONS:
            out = []
            for rgba, idm in composed[spec.state][d]:
                colored = recolor(rgba, idm, mats, bands, ramp_of)
                colored = ensure_outline(colored)
                frame, clipped = crop_to_frame(colored)
                clipped_max = max(clipped_max, clipped)
                out.append(frame)
            by_dir[d] = out
        sheet = build_sheet(by_dir)
        cols = len(spec.frames)
        expect = (cols * FRAME_W, 3 * FRAME_H)
        if sheet.size != expect:
            issues.append(f"{prefix}_{spec.state}: 시트 크기 {sheet.size} != 기대 {expect}")
        bad = palette_violations(sheet)
        if bad:
            issues.append(f"{prefix}_{spec.state}: 팔레트 위반 {sum(bad.values())}px {list(bad)[:3]}")
        issues += [f"{prefix}_{spec.state}: {p}" for p in foot_row_check(sheet, cols, spec.airborne)]
        if clipped_max:
            issues.append(f"{prefix}_{spec.state}: 무기 돌출 {clipped_max}px 가로 클리핑 (20px 캔버스 한계)")
        total += cols * 3
        if spec.state in shrink:
            print(f"    (무기 주축 단축 k={shrink[spec.state]:.2f} — 20x36 프레임 수용)")
        if not report_only:
            OUT_DIR.mkdir(parents=True, exist_ok=True)
            path = OUT_DIR / f"{prefix}_{spec.state}.png"
            sheet.save(path)
            sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(
                path.with_name(f"_preview_{path.name}")
            )
        print(f"  {prefix}_{spec.state}.png  {sheet.size[0]}x{sheet.size[1]}  {cols}프레임x3방향={cols * 3}")
    return total, issues


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--job", choices=list(JOBS) + ["all"], default="all")
    ap.add_argument("--report", action="store_true", help="파일을 쓰지 않고 검사만")
    args = ap.parse_args()

    jobs = list(JOBS) if args.job == "all" else [args.job]
    grand = 0
    all_issues: list[str] = []
    for job in jobs:
        print(f"[{job}]")
        total, issues = build_job(job, args.report)
        print(f"  -> 합계 {total}프레임")
        grand += total
        all_issues += issues
    print(f"\n총 {grand}프레임")
    if all_issues:
        print(f"\n점검 사항 {len(all_issues)}건:")
        for msg in all_issues:
            print(f"  - {msg}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
