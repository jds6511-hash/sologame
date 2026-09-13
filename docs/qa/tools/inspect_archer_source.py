"""궁수 후면 사격의 몸·무기 배치를 원본 변환 경로로 비교한다."""
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
    pairs = []

    def inspect(job, spec, direction, order, frame):
        selected = direction == "back" and spec.state in ("attack", "rollshot")
        body = frame.copy()
        result = original(job, spec, direction, order, frame)
        if selected:
            pairs.append((f"{spec.state}/{direction}/{order}", body, frame.copy()))
            skin = {(232, 183, 150), (228, 166, 114), (215, 118, 67), (184, 111, 80)}
            points = [(x, y) for y in range(14, 30) for x in range(28)
                      if body.getpixel((x, y))[3] == 255 and body.getpixel((x, y))[:3] in skin]
            print(f"{spec.state}/{direction}/{order}: 피부={points}, 검사={result}")
        return result

    generator.draw_weapon = inspect
    try:
        _, issues = generator.build_job("archer", True, pending={})
        print(issues)
    finally:
        generator.draw_weapon = original
    grid = Image.new("RGBA", (224 * 4, 320 * 4), (50, 50, 50, 255))
    draw = ImageDraw.Draw(grid)
    for index, (label, body, weapon) in enumerate(pairs):
        x, y = (index % 4) * 224, (index // 4) * 640
        grid.alpha_composite(body.resize((224, 288), resample=0), (x, y))
        grid.alpha_composite(weapon.resize((224, 288), resample=0), (x, y + 320))
        draw.text((x + 8, y + 292), label, fill="white")
    grid.save(output / "comparison.png")


if __name__ == "__main__":
    main()
