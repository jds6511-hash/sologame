"""전사·궁수 정식 스프라이트 생성 (M3 3-A, LPC 손그림 베이스 -> 28x36 EDG32).

- 계획서: `docs\\art\\m3-character-art-plan.md` 5장(전사 90프레임)·6장(궁수 90프레임)·10장(파일명 규약)
- 규격: `docs\\art\\STYLE_GUIDE.md` 1-2(20x36)·3-1(아웃라인)·3-2-1(4단 램프)·3-3(프레임 수)·7-1(시트 규약)
- 소스·라이선스: `docs\\art\\ASSET_SOURCES.md` 10장 (LPC = B등급, CC-BY-SA 3.0 선택)

선행 조건: `python fetch_lpc_layers.py` (원본은 `_raw_src\\lpc\\`, 저장소 커밋 금지)

사용법:
    python gen_player_lpc.py                # 전사 + 궁수 전체
    python gen_player_lpc.py --job warrior  # 한 직업만
    python gen_player_lpc.py --report       # 생성 없이 프레임 수·클리핑만 점검

검증 오류 시 종료 코드 1. 모든 선택 직업이 통과한 뒤에만 PNG를 저장한다.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import replace
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
    Weapon,
    bands_from,
    build_sheet,
    draw_bow,
    draw_eyes,
    draw_pauldrons,
    draw_sword,
    facing_dir,
    collect_luminance,
    compose_frame,
    crop_to_frame,
    downscale,
    ensure_outline,
    foot_row_check,
    head_mask,
    material_ids,
    narrow_to_frame,
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
    # 아래 두 줄이 계획서 14-4-3 처방 ③(금속/천 명도 대비 강화)의 실체다 —
    # 가슴판 하이라이트를 #c0cbdc 까지 올리고 받침옷을 #3a4466~#3e2731 로 낮춰
    # "천 위에 얹힌 금속"이 아니라 "금속이 주인"으로 읽히게 한다.
    "sleeve": "cloth_navy_dark",  # 판금 아래 받침옷 (구 cloth_blue)
    "torso": "steel_plate",  # 판금 가슴판 (구 steel)
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
              direction_frames={"front": [0, 0]},
              note="차지 홀드 — 정면은 손을 든 원본0을 유지. 측면/후면은 기존2·3 유지"),
    StateSpec("cast", "spellcast", [2, 3], sword_attack("attack_backslash"),
              note="포효/함성 — 양팔을 올려 외치는 2프레임 루프. charge(뒤로 젖힘)와 정반대 실루엣. "
                   "구 backslash[7,8]은 몸이 오른쪽으로 기울어 머리가 x14~22를 차지해 "
                   "치켜든 칼날이 머리를 피할 자리가 없었다(14-4-4 규칙 위반) -> 자세 교체"),
]

ARCHER_STATES = [
    StateSpec("idle", "idle", [0, 1, 0, 1], BOW_WALK, weapon_frames=[0, 0, 0, 0],
              note="활을 몸 옆으로 내려 든 정지 (전사 검 대기와 실루엣 구분)"),
    StateSpec("walk", "walk", WALK_FRAMES, BOW_WALK),
    StateSpec("attack", "shoot", [4, 6, 9, 11], BOW_SHOOT, hide_fg_dirs=("front",),
              direction_frames={"back": [4, 4, 9, 9]},
              note="draw 1 + full draw 1 + release 1 + recovery 1. 정면은 활 fg 가 얼굴을 "
                   "완전히 덮어(실측) bg 만 써서 활을 몸 뒤로 넘긴다"),
    StateSpec("aim", "shoot", [4, 5], BOW_SHOOT, hide_fg_dirs=("front",),
              direction_frames={"back": [4, 4]},
              note="반쯤 당긴 무방비 조준 스탠스 2프레임 루프 (전사 charge 와 정반대로 몸을 세움)"),
    StateSpec("hit", "hurt", [0], BOW_HURT, note="LPC hurt 원본은 front 1행뿐 -> 3방향 공유"),
    StateSpec("death", "hurt", [1, 2, 3, 4], BOW_HURT,
              note="붕괴 — 마지막을 f5(측면으로 완전히 뻗은 쓰러짐, 화살통이 28px 창을 3px 초과)"
                   "에서 f4(주저앉아 접힘)로 교체했다(계획서 14-3절 '세로 주저앉음')"),
    StateSpec("dodge", "jump", [1, 2, 3], BOW_WALK, weapon_frames=[0, 0, 0],
              weapon_offset=DODGE_BOW_OFFSET, airborne=True,
              note="후방 점프 — 도약1+공중1+착지1. 뒤로 뛰는 방향감은 이동·vfx 가 보조"),
    StateSpec("rollshot", "shoot", [5, 7, 9, 11], BOW_SHOOT, hide_fg_dirs=("front",),
              direction_frames={"back": [4, 4, 9, 9]},
              tilt=[-10.0, -4.0, 4.0, 0.0],
              note="곡예 사격 — 사격 자세에 프레임별 기울기를 넣어 구르는 중 상체 비틀림을 근사. "
                   "기울기는 14-3절 지시대로 회전 반경을 줄인 값(구 -16/-7/6)"),
    StateSpec("cast", "shoot", [0, 1], BOW_WALK, weapon_frames=[0, 0],
              note="매의 눈 자가 버프 — 활을 세워 들며 시선을 모으는 짧은 정지. 구 LPC spellcast"
                   "(양팔 벌림)는 계획서 6장 자세 지시와 불일치하고 폭이 35px였다(14-3절 판정)"),
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

# 검: (각도, 칼 길이 요청값, hx, hy)
#
# 2026-07-30 대검 재작화 (계획서 14-4-3 처방 ①). 길이 요청값은 전부 **22**로 두고
# `_max_len` 이 프레임 안에서 가능한 최대 길이로 clamp 하게 한다 — 28x36 창에서는
# **각도가 길이를 결정**하기 때문이다(세로로 세우면 20px 내외, 가로로 누우면 중심에서
# 13px 까지). 그래서 각도대를 "세로에 가깝게" 재설계해 대검 길이를 확보했다:
#   - 대기·이동: 칼끝을 지면 쪽으로 **거의 수직**으로 내려 짚은 자세 (구 52도 -> 84도)
#   - 1타: 치켜듦(위) -> **급경사 내려베기**(76도) -> 수직 마무리
#   - 2타: 뒤(160도)에서 앞(50도)까지 **110도 횡회전** — 가로 도달이 아니라 각도로 무게
#   - 죽음 마지막: 지면에 **누운 대검**(178도)이 17px 로 뻗는다
SWORD_POSE: dict[str, list[tuple[float, float, float, float]]] = {
    # 대기 — **대검을 세워 든** 전투 준비(칼끝이 머리 위로 올라간다). 손을 허리 높이에 두면
    # 위로 20px 여유가 생겨 대검 길이를 확보할 수 있다 — 가슴 높이에서 아래로 내리 꽂으면
    # 지면까지 13px 밖에 없어 대검이 단검처럼 보인다(실측). 호흡에 맞춰 2도·1px만 흔든다
    "idle": [(-78, 22, 5, 14), (-80, 22, 5, 15), (-78, 22, 5, 14), (-80, 22, 5, 15)],
    "walk": [(-78, 22, 5, 14), (-82, 22, 5, 15), (-75, 22, 5, 15),
             (-78, 22, 5, 14), (-82, 22, 5, 15), (-75, 22, 5, 15)],
    # 1타 = 머리 위 내려베기. 선딜(치켜듦) -> 타격(급경사) -> 후딜 2.
    # 타격 프레임의 각도를 수평보다 아래로 잡는 게 중요하다 — 위로 잡으면 칼날이
    # **자기 얼굴을 가로지른다**(실측 확인). 타격 프레임은 손을 머리 높이(hy=22)에 둬서
    # 아래로 20px 를 확보한다 = 대검이 가장 길게 보이는 순간이 곧 타격 순간이다.
    "attack": [(-115, 22, 3, 19), (70, 22, 4, 22), (84, 22, 5, 18), (80, 22, 5, 15)],
    # 2타 = 낮은 횡베기. 1타가 "칼날이 머리 위"라면 2타는 **전 프레임 칼날이 허리 아래**로
    # 지나가게 각도대를 분리한다 — 이 대비가 콤보 2타의 무게를 만든다(계획서 5-1 신규 사유).
    "attack2": [(160, 22, 2, 17), (120, 22, 3, 17), (65, 22, 4, 17), (50, 22, 1, 16)],
    "hit": [(92, 22, 4, 18)],
    "death": [(100, 22, 4, 14), (120, 22, 4, 10), (150, 22, 5, 6), (178, 22, 5, 3)],
    "dodge": [(75, 22, 4, 14), (60, 22, 4, 18), (80, 22, 4, 13)],
    # 차지 홀드 — 뒤로 완전히 당겨 버틴 정지(슈퍼아머). 검이 뒤를 향해 "아직 안 쳤다"가 읽힘
    # 손을 중심선(hx=0)에 두면 정면 프레임에서 칼날이 머리 위를 지나 얼굴을 지운다 -> hx=4
    "charge": [(-125, 22, 4, 18), (-121, 22, 4, 18)],
    # 포효 — 검을 위로 치켜든 함성. charge(뒤) 와 정반대 방향이라 실루엣이 안 겹친다
    "cast": [(-70, 22, 5, 18), (-76, 22, 5, 18)],
}

# 걷기 몸은 팔이 크게 교차하므로 방향 공용 hx/hy로는 같은 손을 따라갈 수 없다. 기존 좌표는
# 정면·측면에서 손이 아니라 가슴판 위에 손잡이를 찍었고, ±2px 불투명 허용 검사에 가려졌다.
# 아래 좌표는 최종 28x36 몸 프레임의 **실제 피부 손 픽셀**을 방향·프레임별로 직접 지정한다.
# 표기: (각도, 칼 길이 요청값, 최종 프레임 x, 최종 프레임 y).
WALK_SWORD_POSE: dict[str, list[tuple[float, float, float, float]]] = {
    "front": [
        (-78, 22, 7, 23), (-82, 22, 7, 24), (-75, 22, 7, 24),
        (-78, 22, 7, 23), (-82, 22, 7, 23), (-75, 22, 7, 23),
    ],
    "side": [
        (-102, 22, 13, 24), (-98, 22, 13, 25), (-105, 22, 8, 25),
        (-102, 22, 7, 25), (-98, 22, 8, 25), (-105, 22, 11, 24),
    ],
    "back": [
        (-102, 22, 20, 23), (-98, 22, 20, 22), (-105, 22, 20, 22),
        (-102, 22, 20, 23), (-98, 22, 20, 23), (-105, 22, 20, 23),
    ],
}

# 활: (활 크기, 당김 0~1, 화살 표시, hx, hy). 활 손은 표적을 향해 뻗은 앞손이다.
BOW_POSE: dict[str, list[tuple[float, float, bool, float, float]]] = {
    "idle": [(5, 0.0, False, 4, 16)] * 4,
    "walk": [(5, 0.0, False, 4, 16)] * 6,
    # draw -> full draw -> release(시위 직선·화살 없음) -> recovery
    "attack": [(6, 0.45, True, 6, 19), (6, 1.0, True, 6, 19),
               (6, 0.0, False, 6, 19), (6, 0.0, False, 5, 17)],
    # 반쯤 당긴 무방비 스탠스 (계획서 6장) — 미세 흔들림 2프레임 루프
    "aim": [(6, 0.55, True, 6, 19), (6, 0.62, True, 6, 18)],
    "hit": [(4, 0.0, False, 4, 14)],
    "death": [(4, 0.0, False, 4, 12), (4, 0.0, False, 4, 9),
              (3, 0.0, False, 5, 6), (3, 0.0, False, 5, 4)],
    "dodge": [(5, 0.0, False, 4, 15), (5, 0.0, False, 4, 18), (5, 0.0, False, 4, 14)],
    "rollshot": [(6, 0.6, True, 5, 18), (6, 1.0, True, 6, 18),
                 (6, 0.0, False, 6, 18), (6, 0.0, False, 4, 16)],
    # 활을 세워 든 짧은 정지. 손을 어깨선 아래로 내리고 몸 바깥으로 밀어 활이 얼굴을
    # 덮지 않게 한다(계획서 14-4-4). 구 (4,20)/(4,21) 은 활 림이 머리 행을 관통했다.
    "cast": [(5, 0.0, False, 5, 16), (5, 0.0, False, 5, 17)],
}

# 외부 LPC backslash/front/0의 손 내부 접점(3,15). 고정 자세에서 검 각도만 미세하게 바뀐다.
CHARGE_FRONT_POSE = [(-90, 22, 11, 20), (-94, 22, 11, 20)]

# 원본 shoot를 최종 변환한 뒤 확인한 피부 내부의 활 손 접점.
# 대기·이동은 활을 옆에 들거나 등에 건 자세라 이 표에 포함하지 않는다.
COMBAT_BOW_HANDS = {
    ("attack", "front"): [(8, 15), (9, 16), (8, 15), (10, 20)],
    ("attack", "side"): [(25, 17), (25, 14), (25, 17), (25, 17)],
    ("attack", "back"): [(19, 19), (19, 19), (19, 20), (19, 20)],
    ("aim", "front"): [(8, 15), (8, 18)],
    ("aim", "side"): [(25, 17), (25, 15)],
    ("aim", "back"): [(19, 19), (19, 19)],
    ("rollshot", "front"): [(9, 18), (8, 17), (8, 17), (10, 20)],
    ("rollshot", "side"): [(25, 18), (25, 15), (24, 16), (25, 17)],
    ("rollshot", "back"): [(21, 20), (20, 20), (18, 20), (19, 20)],
}

# (가로 원근 배율, 손 중심 회전각). 앞은 얼굴 바깥으로 비스듬히, 측면은 수직,
# 후면은 화면 깊이 방향을 짧게 표현한다.
COMBAT_BOW_GEOMETRY = {
    "front": (1.0, 45.0),
    "side": (0.65, 0.0),
    "back": (0.5, 60.0),
}


def hand_xy(direction: str, hx: float, hy: float) -> tuple[float, float]:
    """(hx, hy) 를 프레임 좌표로. 정면은 무기 손이 화면 좌측(LPC 원본과 동일)."""
    sign = -1.0 if direction == "front" else 1.0
    return (FRAME_W / 2 + sign * hx, FRAME_H - 1 - hy)


def sword_pose_for(
    state: str, direction: str, order: int
) -> tuple[float, float, float, float]:
    """검 포즈를 (각도, 길이, 최종 손 x, 최종 손 y)로 정규화한다."""
    if state == "walk":
        return WALK_SWORD_POSE[direction][order]
    angle, want, hx, hy = SWORD_POSE[state][min(order, len(SWORD_POSE[state]) - 1)]
    hand_x, hand_y = hand_xy(direction, hx, hy)
    return angle, want, hand_x, hand_y


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
) -> tuple[bool, bool, float]:
    """최종 프레임에 무기를 직접 그린다.

    반환값 = (손이 몸 위에 있었는지, 머리 겹침을 피했는지, 칼날 길이 px).
    머리 픽셀은 무기를 그리기 **전에** 재야 한다 — 무기를 얹은 뒤에는 머리 실루엣이
    무기에 오염돼 판정이 무의미해진다(계획서 14-4-4).
    """
    # 배치 중 머리 회피가 손잡이를 이동시킨다. 무기를 그리기 전 몸과 최종 좌표로 검사한다.
    body = frame.copy()
    head = head_mask(body)
    placed_hand: list[tuple[float, float]] = []
    if job == "warrior":
        pose = SWORD_POSE.get(spec.state)
        if not pose:
            return True, True, 0.0
        angle, want, hand_x, hand_y = sword_pose_for(spec.state, direction, order)
        locked = spec.state == "charge" and direction == "front"
        if locked:
            angle, want, hx, hy = CHARGE_FRONT_POSE[min(order, 1)]
            hand_x, hand_y = hand_xy(direction, hx, hy)
        hand = (hand_x, hand_y)
        blade, clear = draw_sword(
            frame, hand, facing_dir(direction, angle), want, head, placed_hand,
            lock_grip=locked or spec.state == "walk",
            guard_half_width=1.0 if locked else 2.5,
        )
        ok = bool(placed_hand) and hand_on_body_check(body, placed_hand[0])
        return ok, clear, blade
    pose_b = BOW_POSE.get(spec.state)
    if not pose_b:
        return True, True, 0.0
    size, amt, arrow, hx, hy = pose_b[min(order, len(pose_b) - 1)]
    hand = hand_xy(direction, hx, hy)
    # 사격 동작은 원본 변환 후 피부 내부 접점에 고정한다. 당김은 몸 자세와 시위로
    # 표현하며 머리 회피를 위해 활만 손에서 떼지 않는다.
    bow_key = (spec.state, direction)
    locked = bow_key in COMBAT_BOW_HANDS
    if locked:
        hand = COMBAT_BOW_HANDS[bow_key][order]
    width_scale, angle_deg = COMBAT_BOW_GEOMETRY.get(
        bow_key, COMBAT_BOW_GEOMETRY.get(direction, (1.0, 0.0))
    )
    # 활배는 항상 몸 바깥쪽을 향한다
    bulge = 1.0 if hand[0] >= FRAME_W / 2 else -1.0
    # 정면·후면은 화살이 화면 깊이 방향이라 그리지 않는다(가로로 그리면 방향이 거짓말)
    clear = draw_bow(
        frame, hand, bulge, size, amt, arrow and direction == "side", head, placed_hand,
        lock_grip=locked, width_scale=width_scale if locked else 1.0,
        angle_deg=angle_deg if locked else 0.0,
    )
    ok = bool(placed_hand) and hand_on_body_check(body, placed_hand[0])
    return ok, clear, 0.0


def build_job(
    job: str, report_only: bool, pending: dict[Path, Image.Image]
) -> tuple[int, list[str]]:
    prefix, layers, ramp_of, states = JOBS[job]
    weapons = [s.weapon for s in states if s.weapon]
    mats = material_ids(layers, weapons)

    # 1패스: 전 상태·전 방향 몸 합성 + 축소 (재질별 휘도 표본 수집 + 손잡이 좌표 실측)
    composed: dict[str, dict[str, list[tuple[Image.Image, Image.Image]]]] = {}
    narrowed: list[str] = []
    palette_reference: list[tuple[Image.Image, Image.Image]] = []
    for spec in states:
        composed[spec.state] = {}
        for d in DIRECTIONS:
            seq = []
            for i in range(len(spec.frames)):
                rgba, idm, _ = compose_frame(layers, spec, d, i, mats, weapon_mode="probe")
                if spec.tilt:
                    rgba, idm = rotate_pair(rgba, idm, spec.tilt[i])
                # 28px 창을 넘는 자세는 캔버스가 아니라 자세를 좁힌다(계획서 14-3절)
                rgba, idm, k = narrow_to_frame(rgba, idm)
                if k < 1.0:
                    narrowed.append(f"{spec.state}/{d}{i}={k:.2f}")
                seq.append(downscale(rgba, idm, mats))
                if d in spec.direction_frames:
                    # 한 방향의 자세 교체가 다른 88프레임의 색 밴드를 바꾸지 않게 한다.
                    reference, ref_ids, _ = compose_frame(
                        layers, replace(spec, direction_frames={}), d, i, mats,
                        weapon_mode="probe",
                    )
                    if spec.tilt:
                        reference, ref_ids = rotate_pair(reference, ref_ids, spec.tilt[i])
                    reference, ref_ids, _ = narrow_to_frame(reference, ref_ids)
                    palette_reference.append(downscale(reference, ref_ids, mats))
                else:
                    palette_reference.append(seq[-1])
            composed[spec.state][d] = seq

    bands = {mid: bands_from(l) for mid, l in collect_luminance(palette_reference, mats).items()}

    # 2패스: 재색상 -> 아웃라인 -> 크롭 -> 시트
    total = 0
    issues: list[str] = []
    eyeless: list[str] = []
    blades: list[float] = []
    for spec in states:
        by_dir: dict[str, list[Image.Image]] = {}
        clips: list[str] = []
        for d in DIRECTIONS:
            out = []
            for i, (rgba, idm) in enumerate(composed[spec.state][d]):
                colored = recolor(rgba, idm, mats, bands, ramp_of)
                colored = ensure_outline(colored)
                frame, (cl, cr) = crop_to_frame(colored)
                if max(cl, cr) > CLAMP_TOL:
                    clips.append(f"{d}{i}(좌{cl}/우{cr})")
                # 크롭으로 1px 잘린 단면을 다시 아웃라인으로 닫는다 (STYLE_GUIDE 3-1 폐곡선,
                # 7장 5-1 클리핑 게이트). 이 한 줄이 없으면 잘린 팔이 살색 단면으로 남는다.
                if job == "warrior" and not draw_pauldrons(frame):
                    issues.append(f"{prefix}_{spec.state}: {d} 프레임{i} 견갑 작화 실패(가슴판 미검출)")
                frame = ensure_outline(frame)
                # death 후반(붕괴·지면) 프레임은 얼굴이 안 보이는 게 정상이라 면제한다
                if not draw_eyes(frame, d) and not (spec.state == "death" and i >= 2):
                    eyeless.append(f"{spec.state}/{d}{i}")
                on_body, head_clear, blade = draw_weapon(job, spec, d, i, frame)
                if not on_body:
                    issues.append(f"{prefix}_{spec.state}: {d} 프레임{i} 손 좌표가 몸 밖 (무기 부유)")
                if not head_clear:
                    issues.append(f"{prefix}_{spec.state}: {d} 프레임{i} 무기가 머리와 겹친다(14-4-4)")
                if blade:
                    blades.append(blade)
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
        if clips:
            issues.append(
                f"{prefix}_{spec.state}: 실체 가로 돌출이 clamp 허용치({CLAMP_TOL}px)를 넘음 {clips}"
            )
        total += cols * 3
        if not report_only:
            path = OUT_DIR / f"{prefix}_{spec.state}.png"
            pending[path] = sheet
        print(f"  {prefix}_{spec.state}.png  {sheet.size[0]}x{sheet.size[1]}  {cols}프레임x3방향={cols * 3}")
    if eyeless:
        issues.append(f"{prefix}: 눈 점 배치 실패 {len(eyeless)}프레임 {eyeless[:6]}")
    if narrowed:
        print(f"  [자세 가로 클램프 {len(narrowed)}프레임] {' '.join(narrowed)}")
    if blades:
        long_ratio = sum(1 for b in blades if b >= 16) / len(blades)
        print(
            f"  [대검 칼날 길이] 최소 {min(blades):.0f}px / 최대 {max(blades):.0f}px / "
            f"평균 {sum(blades) / len(blades):.1f}px / 16px 이상 {long_ratio * 100:.0f}%"
        )
    return total, issues


def rear_shot_patches(pending: dict[Path, Image.Image]) -> dict[Path, Image.Image]:
    """검수한 후면 8셀만 기존 런타임 시트에 반영한다. 저장 전 두 기준 시트를 모두 검사한다.

    전체 재생성과 달리 기존 PNG가 기준이다. 아직 손 접점 검수가 끝나지 않은
    정면·측면 및 다른 동작에 공통 활 기하 보정을 적용하지 않는다.
    """
    patches = {}
    names = {"player_archer_attack.png", "player_archer_rollshot.png"}
    selected = {path: sheet for path, sheet in pending.items() if path.name in names}
    if len(selected) != 2:
        raise ValueError("궁수 공격·곡예 사격 후보 두 장이 필요합니다")
    for path, candidate in selected.items():
        with Image.open(path) as source:
            if source.size != (4 * FRAME_W, 3 * FRAME_H) or source.mode != "RGBA":
                raise ValueError(f"기준 시트 규격 오류: {path}")
            baseline = source.copy()
        if candidate.size != baseline.size:
            raise ValueError(f"후보 시트 규격 오류: {path}")
        rear = candidate.crop((0, 2 * FRAME_H, candidate.width, 3 * FRAME_H))
        baseline.paste(rear, (0, 2 * FRAME_H))
        patches[path] = baseline
    return patches


def combat_bow_patches(pending: dict[Path, Image.Image]) -> dict[Path, Image.Image]:
    """실제 손 접점을 확인한 공격·조준·곡예 사격 세 시트만 선택한다."""
    expected = {
        "player_archer_attack.png": (4 * FRAME_W, 3 * FRAME_H),
        "player_archer_aim.png": (2 * FRAME_W, 3 * FRAME_H),
        "player_archer_rollshot.png": (4 * FRAME_W, 3 * FRAME_H),
    }
    selected = {path: sheet for path, sheet in pending.items() if path.name in expected}
    if {path.name for path in selected} != set(expected):
        raise ValueError("궁수 공격·조준·곡예 사격 후보 세 장이 필요합니다")
    for path, candidate in selected.items():
        if candidate.mode != "RGBA" or candidate.size != expected[path.name]:
            raise ValueError(f"후보 시트 규격 오류: {path}")
    return selected


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--job", choices=list(JOBS) + ["all"], default="all")
    ap.add_argument("--report", action="store_true", help="파일을 쓰지 않고 검사만")
    modes = ap.add_mutually_exclusive_group()
    modes.add_argument("--rear-shots-only", action="store_true",
                       help="궁수 후면 사격 8셀만 기존 PNG에 반영. --job archer와 함께 사용")
    modes.add_argument("--combat-bow-only", action="store_true",
                       help="손 접점을 확인한 공격·조준·곡예 사격만 반영")
    args = ap.parse_args()
    if (args.rear_shots_only or args.combat_bow_only) and args.job != "archer":
        ap.error("궁수 선택 반영 모드는 --job archer가 필요합니다")

    jobs = list(JOBS) if args.job == "all" else [args.job]
    grand = 0
    all_issues: list[str] = []
    pending: dict[Path, Image.Image] = {}
    for job in jobs:
        print(f"[{job}]")
        selecting = args.rear_shots_only or args.combat_bow_only
        total, issues = build_job(job, args.report and not selecting, pending=pending)
        print(f"  -> 합계 {total}프레임")
        grand += total
        all_issues += issues
    print(f"\n총 {grand}프레임")
    if all_issues:
        print(f"\n점검 사항 {len(all_issues)}건:")
        for msg in all_issues:
            print(f"  - {msg}")
        print("\n출력 중단: 기존 PNG를 유지합니다.")
        return 1
    # 한 직업이라도 실패하면 다른 직업의 정상 PNG도 바꾸지 않는다.
    if args.rear_shots_only:
        try:
            pending = rear_shot_patches(pending)
        except (OSError, ValueError) as error:
            print(f"출력 중단: {error}")
            return 1
        print("적용 범위: 기존 궁수 공격·곡예 사격 시트의 후면 8셀")
    elif args.combat_bow_only:
        try:
            pending = combat_bow_patches(pending)
        except ValueError as error:
            print(f"출력 중단: {error}")
            return 1
        print("적용 범위: 궁수 공격·조준·곡예 사격 30셀")
    if not args.report:
        for path, sheet in pending.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            sheet.save(path)
            sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(
                path.with_name(f"_preview_{path.name}")
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
