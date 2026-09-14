"""궁수 전투 자세의 몸·손·활 배치를 외부 LPC 변환 경로로 비교한다."""
from pathlib import Path
import sys
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "godot/assets/tools"))
import gen_player_lpc as generator


def main():
    output = ROOT / "docs/qa/screenshots/archer-source"
    output.mkdir(parents=True, exist_ok=True)
    original = generator.draw_weapon
    pairs = {state: [] for state in ("attack", "aim", "rollshot")}

    def inspect(job, spec, direction, order, frame):
        key = (spec.state, direction)
        selected = key in generator.COMBAT_BOW_HANDS
        body = frame.copy()
        result = original(job, spec, direction, order, frame)
        if selected:
            hand = generator.COMBAT_BOW_HANDS[key][order]
            contact = body.getpixel(hand)
            pairs[spec.state].append((direction, order, hand, body, frame.copy()))
            print(f"{spec.state}/{direction}/{order}: 손={hand}, 픽셀={contact}, 검사={result}")
        return result

    generator.draw_weapon = inspect
    try:
        _, issues = generator.build_job("archer", True, pending={})
        print(issues)
    finally:
        generator.draw_weapon = original
    for state, entries in pairs.items():
        cols = max(order for _, order, *_ in entries) + 1
        grid = Image.new("RGBA", (224 * cols, 640 * 3), (50, 50, 50, 255))
        draw = ImageDraw.Draw(grid)
        for direction, order, hand, body, weapon in entries:
            row = generator.DIRECTIONS.index(direction)
            x, y = order * 224, row * 640
            grid.alpha_composite(body.resize((224, 288), resample=0), (x, y))
            grid.alpha_composite(weapon.resize((224, 288), resample=0), (x, y + 320))
            draw.text((x + 8, y + 292), f"{direction}/{order} hand={hand}", fill="white")
        grid.save(output / f"comparison-{state}.png")


if __name__ == "__main__":
    main()
