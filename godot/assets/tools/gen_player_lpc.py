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
    draw_bow,
    draw_eyes,
    draw_sword,
    facing_dir,
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
SLEEVE = "torso/clothes/longsleeve/longsleeve/male/{anim}.png"


def char_layers(
    torso: str, torso_material: str, quiver: bool = False, sleeve: bool = False
) -> list[Layer]:
    layers = [Layer("body", "body/bodies/male/{anim}.png", "skin")]
    if quiver:
        layers.append(Layer("quiver", "quiver/{anim}/quiver.png", "boots"))
    layers.append(Layer("legs", "legs/pants/male/{anim}.png", "pants"))
    layers.append(Layer("feet", "feet/boots/basic/male/{anim}.png", "boots"))
    if sleeve:
        # 판금 아래 받쳐 입는 긴팔(gambeson). LPC 의 `plate`·`legion` 은 **가슴판만** 있고
        # 소매가 없어서, 그것만 쓰면 맨팔이 된다 -> 20x36에서 팔이 살색 지느러미처럼
        # 펄럭여 보행 사이클이 어색해진다(실측). 받침옷을 깔면 팔에 구조가 생긴다.
        layers.append(Layer("sleeve", SLEEVE, "sleeve"))
    layers += [
        Layer("torso", torso, torso_material),
        Layer("head", "head/heads/human/male/{anim}.png", "skin"),
        Layer("hair", "hair/buzzcut/adult/{anim}.png", "hair"),
    ]
    return layers


WARRIOR_LAYERS = char_layers("torso/armour/plate/male/{anim}.png", "torso", sleeve=True)
ARCHER_LAYERS = char_layers(SLEEVE, "torso", quiver=True)

# 재질 이름 -> EDG32 램프.
# 재질을 부위별로 쪼개 두는 이유: 램프 밴드가 재질별 휘도 분포에서 따로 잡히므로,
# 부위를 합치면(예: 바지+부츠를 한 재질로) 둘이 같은 명도로 뭉개져 실루엣이 사라진다.
# 인접 부위는 반드시 **다른 색 계열**로 배정해 20x36에서도 부위 경계가 읽히게 한다.
WARRIOR_RAMPS = {
    "skin": "skin",
    "hair": "hair_dark",  # 피부와 붙어 있으므로 확실히 어두운 계열
    "sleeve": "cloth_blue",  # 판금 아래 받침옷 — 팔이 맨살로 안 보이게, 부츠·머리와 다른 계열
    "torso": "steel",  # 판금 가슴판 — 밝은 회청으로 상체를 눈에 띄게
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

# ---------------------------------------------------------------- 무기 포즈 표
# 무기는 최종 20x36에서 직접 그린다(`lpc_common` 무기 직접 작화 절 참조). 아래 표가
# 그 각도·길이를 프레임 단위로 지정한다 — **여기가 "공격이 공격처럼 보이는지"를 만드는
# 실제 지점**이다. 각도는 측면(오른쪽 바라봄) 기준, 0도 = 오른쪽, 양수 = 아래.

# 손 위치는 **직접 지정한다.** LPC 무기 레이어에서 손잡이를 자동 추정해 봤지만,
# 128px 공격 시트는 무기 그래픽에 스윙 궤적이 함께 그려져 있어 궤적이 몸을 광범위하게
# 덮는다 -> 접점 중심이 손이 아니라 몸통 중앙으로 끌려간다(실측). 그래서 좌표를 표로
# 못박고, **손이 실제로 LPC 몸의 손 위에 있는지 자동 검사**한다(`hand_on_body_check`).
#
# 표기: (hx, hy) — hx = 몸 중심선에서 바깥쪽 거리, hy = 발밑에서 위로 올라간 높이.
# 방향 변환: side/back 은 화면 오른쪽(+), front 는 화면 왼쪽(-) — 캐릭터의 무기 손이
# 정면에서는 화면 좌측에 오기 때문이다(LPC 원본과 동일).

# 검: (각도, 칼 길이, hx, hy)
SWORD_POSE: dict[str, list[tuple[float, float, float, float]]] = {
    # 대기 — 칼끝을 앞아래로 내린 전투 준비. 호흡에 맞춰 3도·1px만 흔든다
    "idle": [(52, 11, 4, 15), (49, 11, 4, 16), (52, 11, 4, 15), (49, 11, 4, 16)],
    "walk": [(58, 10, 4, 15), (54, 10, 4, 16), (50, 10, 4, 16),
             (58, 10, 4, 15), (54, 10, 4, 16), (50, 10, 4, 16)],
    # 1타 = 머리 위 내려베기. 선딜(치켜듦) -> 타격(앞으로) -> 후딜 2.
    # 타격 프레임의 각도를 수평보다 아래로 잡는 게 중요하다 — 위로 잡으면 칼날이
    # **자기 얼굴을 가로지른다**(실측 확인).
    "attack": [(-118, 13, 2, 23), (10, 14, 6, 20), (55, 12, 5, 16), (45, 11, 4, 15)],
    # 2타 = 낮은 횡베기. 1타가 "칼날이 머리 위"라면 2타는 **전 프레임 칼날이 허리 아래**로
    # 지나가게 각도대를 분리한다 — 이 대비가 콤보 2타의 무게를 만든다(계획서 5-1 신규 사유).
    "attack2": [(150, 12, 1, 18), (104, 13, 3, 17), (46, 13, 5, 16), (22, 11, 5, 15)],
    "hit": [(80, 8, 4, 13)],
    "death": [(88, 10, 4, 12), (108, 9, 4, 9), (128, 8, 5, 6), (142, 7, 5, 3)],
    "dodge": [(62, 9, 4, 14), (80, 9, 4, 17), (56, 9, 4, 13)],
    # 차지 홀드 — 뒤로 완전히 당겨 버틴 정지(슈퍼아머). 검이 뒤를 향해 "아직 안 쳤다"가 읽힘
    "charge": [(-155, 13, 0, 22), (-150, 13, 0, 23)],
    # 포효 — 검을 위로 치켜든 함성. charge(뒤) 와 정반대 방향이라 실루엣이 안 겹친다
    "cast": [(-82, 14, 3, 22), (-76, 14, 3, 23)],
}

# 활: (활 크기, 당김 0~1, 화살 표시, hx, hy). 활 손은 표적을 향해 뻗은 앞손이다.
BOW_POSE: dict[str, list[tuple[float, float, bool, float, float]]] = {
    "idle": [(5, 0.0, False, 4, 16)] * 4,
    "walk": [(5, 0.0, False, 4, 16)] * 6,
    # draw -> full draw -> release(시위 직선·화살 없음) -> recovery
    "attack": [(6, 0.45, True, 6, 19), (6, 1.0, True, 6, 19),
               (6, 0.0, False, 6, 19), (5, 0.0, False, 5, 17)],
    # 반쯤 당긴 무방비 스탠스 (계획서 6장) — 미세 흔들림 2프레임 루프
    "aim": [(6, 0.55, True, 6, 19), (6, 0.62, True, 6, 18)],
    "hit": [(4, 0.0, False, 4, 14)],
    "death": [(4, 0.0, False, 4, 12), (4, 0.0, False, 4, 9),
              (3, 0.0, False, 5, 6), (3, 0.0, False, 5, 4)],
    "dodge": [(5, 0.0, False, 4, 15), (5, 0.0, False, 4, 18), (5, 0.0, False, 4, 14)],
    "rollshot": [(6, 0.6, True, 5, 18), (6, 1.0, True, 6, 18),
                 (6, 0.0, False, 6, 18), (5, 0.0, False, 4, 16)],
    "cast": [(5, 0.0, False, 4, 20), (5, 0.0, False, 4, 21)],
}


def hand_xy(direction: str, hx: float, hy: float) -> tuple[float, float]:
    """(hx, hy) 를 프레임 좌표로. 정면은 무기 손이 화면 좌측(LPC 원본과 동일)."""
    sign = -1.0 if direction == "front" else 1.0
    return (FRAME_W / 2 + sign * hx, FRAME_H - 1 - hy)


def hand_on_body_check(frame: Image.Image, hand: tuple[float, float]) -> bool:
    """지정한 손 좌표가 실제로 몸 픽셀 위(또는 2px 이내)인지 — 무기가 공중에 뜨는 것 방지."""
    px = frame.load()
    hx, hy = round(hand[0]), round(hand[1])
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            x, y = hx + dx, hy + dy
            if 0 <= x < FRAME_W and 0 <= y < FRAME_H and px[x, y][3] > 0:
                return True
    return False


def draw_weapon(
    job: str, spec: StateSpec, direction: str, order: int, frame: Image.Image
) -> bool:
    """최종 프레임에 무기를 직접 그린다. 반환값 = 손이 몸 위에 있었는지(검사용)."""
    if job == "warrior":
        pose = SWORD_POSE.get(spec.state)
        if not pose:
            return True
        angle, want, hx, hy = pose[min(order, len(pose) - 1)]
        hand = hand_xy(direction, hx, hy)
        ok = hand_on_body_check(frame, hand)
        draw_sword(frame, hand, facing_dir(direction, angle), want)
        return ok
    pose_b = BOW_POSE.get(spec.state)
    if not pose_b:
        return True
    size, amt, arrow, hx, hy = pose_b[min(order, len(pose_b) - 1)]
    hand = hand_xy(direction, hx, hy)
    ok = hand_on_body_check(frame, hand)
    # 활배는 항상 몸 바깥쪽을 향한다
    bulge = 1.0 if hand[0] >= FRAME_W / 2 else -1.0
    # 정면·후면은 화살이 화면 깊이 방향이라 그리지 않는다(가로로 그리면 방향이 거짓말)
    draw_bow(frame, hand, bulge, size, amt, arrow and direction == "side")
    return ok


def build_job(job: str, report_only: bool) -> tuple[int, list[str]]:
    prefix, layers, ramp_of, states = JOBS[job]
    weapons = [s.weapon for s in states if s.weapon]
    mats = material_ids(layers, weapons)

    # 1패스: 전 상태·전 방향 몸 합성 + 축소 (재질별 휘도 표본 수집 + 손잡이 좌표 실측)
    composed: dict[str, dict[str, list[tuple[Image.Image, Image.Image]]]] = {}
    for spec in states:
        composed[spec.state] = {}
        for d in DIRECTIONS:
            seq = []
            for i in range(len(spec.frames)):
                rgba, idm, _ = compose_frame(layers, spec, d, i, mats, weapon_mode="probe")
                if spec.tilt:
                    rgba, idm = rotate_pair(rgba, idm, spec.tilt[i])
                seq.append(downscale(rgba, idm, mats))
            composed[spec.state][d] = seq

    flat = [f for st in composed.values() for seq in st.values() for f in seq]
    bands = {mid: bands_from(l) for mid, l in collect_luminance(flat, mats).items()}

    # 2패스: 재색상 -> 아웃라인 -> 크롭 -> 시트
    total = 0
    issues: list[str] = []
    eyeless: list[str] = []
    for spec in states:
        by_dir: dict[str, list[Image.Image]] = {}
        clipped_max = 0
        for d in DIRECTIONS:
            out = []
            for i, (rgba, idm) in enumerate(composed[spec.state][d]):
                colored = recolor(rgba, idm, mats, bands, ramp_of)
                colored = ensure_outline(colored)
                frame, clipped = crop_to_frame(colored)
                clipped_max = max(clipped_max, clipped)
                # death 후반(붕괴·지면) 프레임은 얼굴이 안 보이는 게 정상이라 면제한다
                if not draw_eyes(frame, d) and not (spec.state == "death" and i >= 2):
                    eyeless.append(f"{spec.state}/{d}{i}")
                if not draw_weapon(job, spec, d, i, frame):
                    issues.append(f"{prefix}_{spec.state}: {d} 프레임{i} 손 좌표가 몸 밖 (무기 부유)")
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
            issues.append(
                f"{prefix}_{spec.state}: 실체 가로 돌출 {clipped_max}px — LPC 원본 팔/발 스윙이 "
                f"20px 창을 넘는다(무기는 프레임 안에 맞춰 그려지므로 무기 잘림 아님)"
            )
        total += cols * 3
        if not report_only:
            OUT_DIR.mkdir(parents=True, exist_ok=True)
            path = OUT_DIR / f"{prefix}_{spec.state}.png"
            sheet.save(path)
            sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(
                path.with_name(f"_preview_{path.name}")
            )
        print(f"  {prefix}_{spec.state}.png  {sheet.size[0]}x{sheet.size[1]}  {cols}프레임x3방향={cols * 3}")
    if eyeless:
        issues.append(f"{prefix}: 눈 점 배치 실패 {len(eyeless)}프레임 {eyeless[:6]}")
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
