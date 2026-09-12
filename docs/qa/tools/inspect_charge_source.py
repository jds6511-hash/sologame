"""전사 차지의 변환 직후 몸과 현재 무기 배치를 로컬 QA 이미지로 저장한다."""
from pathlib import Path
import sys
from dataclasses import replace
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "godot/assets/tools"))
import gen_player_lpc as generator


def main():
    output = ROOT / "docs/qa/screenshots/charge-source"
    output.mkdir(parents=True, exist_ok=True)
    original = generator.draw_weapon
    original_job = generator.JOBS["warrior"]
    bodies = []
    if "--candidates" in sys.argv:
        prefix, layers, ramps, states = generator.JOBS["warrior"]
        charge = next(state for state in states if state.state == "charge")
        generator.JOBS["warrior"] = (
            prefix, layers, ramps,
            [replace(charge, frames=list(range(13)), direction_frames={})],
        )

    def inspect(job, spec, direction, order, frame):
        selected = job == "warrior" and spec.state == "charge" and direction == "front"
        if selected:
            bodies.append(frame.copy())
            frame.resize((224, 288), resample=0).save(output / f"body-{order}.png")
            skin = {(232, 183, 150), (228, 166, 114), (215, 118, 67), (184, 111, 80)}
            points = [(x, y) for y in range(14, 30) for x in range(28)
                      if frame.getpixel((x, y))[3] == 255 and frame.getpixel((x, y))[:3] in skin]
            print(f"차지 정면{order} 아래쪽 피부 후보: {points}")
        result = original(job, spec, direction, order, frame)
        if selected:
            frame.resize((224, 288), resample=0).save(output / f"weapon-{order}.png")
        return result

    generator.draw_weapon = inspect
    try:
        _, issues = generator.build_job("warrior", True, pending={})
        print(issues)
        grid = Image.new("RGBA", (224 * 4, 320 * ((len(bodies) + 3) // 4)), (50, 50, 50, 255))
        draw = ImageDraw.Draw(grid)
        for index, body in enumerate(bodies):
            x, y = (index % 4) * 224, (index // 4) * 320
            grid.alpha_composite(body.resize((224, 288), resample=0), (x, y))
            draw.text((x + 8, y + 292), str(index), fill="white")
        grid.save(output / "body-candidates.png")
    finally:
        generator.draw_weapon = original
        generator.JOBS["warrior"] = original_job


if __name__ == "__main__":
    main()
