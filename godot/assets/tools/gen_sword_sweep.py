"""기존 LPC 몸으로 낮은 검 보행과 체중이동 공격을 64×64에 생성한다.

몸은 확대하지 않고 발을 기준으로 중앙 패딩한다. 공격은 몸·손을 함께 기울인다.
gen_player_lpc.py 다음, gen_player_spriteframes.py 전에 실행.
"""
import contextlib
import io
import math
from pathlib import Path

from PIL import Image, ImageDraw

import gen_player_lpc as base
from lpc_common import DIRECTIONS, BLADE, BLADE_DARK, BLADE_TIP, GRIP_C, GUARD, POMMEL, RAMPS, hx, head_mask

SIZE = 64
PAD = (18, 14)
# 선딜 2 / 판정 3 / 후딜 3. 마지막은 기존 대기 셀 그대로 복귀한다.
ANGLES = {
    "attack": [-78, -110, -55, 5, 65, 80, 0, -78],
    "attack2": [-78, 65, 35, -20, -75, -110, -90, -78],
}
BODY_ORDERS = [0, 0, 1, 3, 2, 2, 0, 0]
# 발은 고정하고 어깨를 뒤로 당겼다가 타격 방향으로 싣는다. 손도 같은 변환을 쓴다.
BODY_LEAN = [0, -3, -1, 3, 4, 2, -1, 0]
# 몸만 렌더한 표에서 확인한 무기 손 근방. 가장 가까운 실제 피부 픽셀을 사용하고,
# 3px보다 멀면 생성 실패 처리한다. 얼굴 회피를 이유로 손잡이를 옮기지 않는다.
HANDS = {
    ("attack", "front"): [(6, 24), (7, 23), (13, 25), (19, 25)],
    ("attack", "side"): [(8, 25), (10, 26), (10, 24), (25, 23)],
    ("attack", "back"): [(6, 24), (7, 25), (10, 24), (8, 25)],
    ("attack2", "front"): [(13, 25), (6, 19), (12, 25), (6, 22)],
    ("attack2", "side"): [(20, 21), (19, 21), (22, 23), (25, 21)],
    ("attack2", "back"): [(19, 27), (24, 20), (22, 20), (24, 20)],
}


def hand_pixel(body, target):
    skin = {hx(color) for color in RAMPS["skin"]}
    points = [(x, y) for y in range(14, 30) for x in range(28)
              if body.getpixel((x, y))[:3] in skin and body.getpixel((x, y))[3]]
    hand = min(points, key=lambda p: (p[0]-target[0])**2 + (p[1]-target[1])**2)
    if math.dist(hand, target) > 3:
        raise ValueError(f"손 피부 접점 없음: {target}")
    return hand


def sword_layer(hand, angle, direction, length=22):
    # 측면의 검은 앞으로, 정면은 화면 아래, 후면은 화면 위로 부채꼴을 지난다.
    angle = angle + {"front": 90, "side": 0, "back": -90}[direction]
    dx, dy = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    px, py = -dy, dx
    def point(distance, width=0):
        return (round(hand[0]+dx*distance+px*width), round(hand[1]+dy*distance+py*width))
    layer = Image.new("RGBA", (SIZE, SIZE))
    draw = ImageDraw.Draw(layer)
    strokes = [(point(-3), point(2), GRIP_C, 2),
               (point(2, -3), point(2, 3), GUARD, 1),
               (point(3), point(length), BLADE_DARK, 3),
               (point(3, -1), point(length-1, -1), BLADE, 1),
               (point(length-2), point(length), BLADE_TIP, 1),
               (point(-3), point(-3), POMMEL, 1)]
    for start, end, _, width in strokes:
        for p in (start, end):
            if not (2 <= p[0] < SIZE-2 and 2 <= p[1] < SIZE-2):
                raise ValueError(f"칼날 클리핑: {p}")
        draw.line((start, end), fill=(24, 20, 37, 255), width=width+2)
    for start, end, color, width in strokes:
        draw.line((start, end), fill=(*color[:3], 255), width=width)
    return layer


def body_point(point, lean):
    x, y = point
    return (x + PAD[0] + round(lean * max(0, 34-y) / 28), y + PAD[1])


def posed_body(body, lean):
    """소스 몸의 행을 발 기준으로 기울여 어깨·허리·손이 함께 움직이게 한다."""
    result = Image.new("RGBA", (SIZE, SIZE))
    for y in range(body.height):
        result.alpha_composite(body.crop((0, y, body.width, y+1)), body_point((0, y), lean))
    return result


def attack_body(bodies, state, direction, index):
    order = BODY_ORDERS[index]
    if state == "attack2" and direction == "back" and order == 2:
        order = 1
    body = bodies[(state, direction, order)]
    hand = hand_pixel(body, HANDS[(state, direction)][order])
    lean = BODY_LEAN[index] * (-1 if direction == "front" else 1)
    return body, posed_body(body, lean), body_point(hand, lean)


def build_walk(bodies):
    sheet = Image.new("RGBA", (6*SIZE, 3*SIZE))
    for row, direction in enumerate(DIRECTIONS):
        for index in range(6):
            body = bodies[("walk", direction, index)]
            hand = tuple(round(v) for v in base.WALK_SWORD_POSE[direction][index][-2:])
            grip = body_point(hand, 0)
            # 화면 각도 그대로 사용. 몸/손 원본은 걷기 사이클을 유지한다.
            weapon = sword_layer(grip, base.WALK_CARRY_ANGLES[direction][index], "side")
            frame = posed_body(body, 0)
            if direction == "back":
                weapon.alpha_composite(frame)
                frame = weapon
            else:
                frame.alpha_composite(weapon)
            frame.putpixel(grip, body.getpixel(hand))
            sheet.alpha_composite(frame, (index*SIZE, row*SIZE))
    return sheet


def build_sheets(bodies):
    sheets = {}
    idle = Image.open(base.OUT_DIR / "player_warrior_v2_idle.png").convert("RGBA")
    for state, angles in ANGLES.items():
        sheet = Image.new("RGBA", (8*SIZE, 3*SIZE))
        for row, direction in enumerate(DIRECTIONS):
            for index, angle in enumerate(angles):
                frame = Image.new("RGBA", (SIZE, SIZE))
                if index in (0, 7):
                    frame.alpha_composite(idle.crop((0, row*36, 28, (row+1)*36)), PAD)
                else:
                    if state == "attack" and direction == "back" and index == 1:
                        angle = -70
                    if index == 6:
                        angle = {("attack", "front"): 120,
                                 ("attack2", "front"): -150,
                                 ("attack2", "back"): -35}.get((state, direction), angle)
                    body, posed, grip = attack_body(bodies, state, direction, index)
                    # 뻗은 팔의 측면 타격은 원근상 칼날을 17px로 단축해 셀 경계를 지킨다.
                    length = 17 if index == 3 and direction == "side" else 22
                    weapon = sword_layer(grip, angle, direction, length)
                    # 후면은 몸 뒤의 검을 가리고, 손 접점만 맨 위로 복원한다.
                    if direction == "back":
                        frame.alpha_composite(weapon)
                        frame.alpha_composite(posed)
                    else:
                        frame.alpha_composite(posed)
                        frame.alpha_composite(weapon)
                    # 칼날이 얼굴을 스치는 프레임은 머리 뒤를 지나는 것으로 가린다.
                    # 손이나 칼 각도를 옮겨 접점을 끊는 머리 회피 보정은 하지 않는다.
                    lean = BODY_LEAN[index] * (-1 if direction == "front" else 1)
                    for x, y in head_mask(body):
                        frame.putpixel(body_point((x, y), lean), body.getpixel((x, y)))
                    frame.putpixel(grip, posed.getpixel(grip))
                sheet.alpha_composite(frame, (index*SIZE, row*SIZE))
        sheets[state] = sheet
    return sheets


def load_bodies():
    bodies = {}
    with contextlib.redirect_stdout(io.StringIO()):
        _, issues = base.build_job("warrior", True, {}, body_frames=bodies)
    if issues:
        raise ValueError(issues)
    return bodies


def body_board(bodies):
    board = Image.new("RGBA", (4 * 112, 6 * 160), (65, 65, 65, 255))
    draw = ImageDraw.Draw(board)
    for si, state in enumerate(ANGLES):
        for row, direction in enumerate(DIRECTIONS):
            for order in range(4):
                body = bodies[(state, direction, order)]
                x, y = order * 112, (si * 3 + row) * 160
                board.alpha_composite(body.resize((112, 144), Image.Resampling.NEAREST), (x, y+16))
                draw.text((x, y), f"{state}/{direction}/{order}", fill="white")
    return board


if __name__ == "__main__":
    output = Path(__file__).resolve().parents[3] / "docs/qa/screenshots/sword-sweep"
    output.mkdir(parents=True, exist_ok=True)
    bodies = load_bodies()
    body_board(bodies).save(output / "bodies.png")
    sheets = build_sheets(bodies)
    sheets["walk"] = build_walk(bodies)
    for state, sheet in sheets.items():
        suffix = "carry" if state == "walk" else "sweep"
        path = base.OUT_DIR / f"player_warrior_v2_{state}_{suffix}.png"
        sheet.save(path)
        sheet.resize((sheet.width*3, sheet.height*3), Image.Resampling.NEAREST).save(output / f"{state}.png")
        print(f"{path.name}: {sheet.width // SIZE}프레임 × 3방향, 64×64셀")
