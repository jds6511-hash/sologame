"""LPC 좌우 원본을 합성해 손잡이/앞뒤 무기 레이어를 비교한다. 제품 출력은 수정하지 않는다."""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "godot/assets/tools"))
import gen_player_lpc as base
import lpc_common as lpc


def main():
    output = ROOT / "docs/qa/screenshots/warrior-left"
    output.mkdir(parents=True, exist_ok=True)
    lpc.LPC_ROW["left"] = 1
    specs = [spec for spec in base.WARRIOR_STATES if spec.state in ("idle", "walk", "attack", "attack2")]
    mats = lpc.material_ids(base.WARRIOR_LAYERS, [spec.weapon for spec in specs if spec.weapon])
    board = Image.new("RGBA", (6 * 256, len(specs) * 280), (65, 65, 65, 255))
    draw = ImageDraw.Draw(board)
    report = []
    for row, spec in enumerate(specs):
        for order in range(min(3, len(spec.frames))):
            for side, direction in enumerate(("side", "left")):
                frame, _, meta = lpc.compose_frame(base.WARRIOR_LAYERS, spec, direction, order, mats)
                x = (order * 2 + side) * 256
                y = row * 280
                board.alpha_composite(frame.resize((256, 256), Image.Resampling.NEAREST), (x, y + 24))
                draw.text((x + 4, y + 4), f"{spec.state}/{direction}/{order}", fill="white")
                report.append({"state": spec.state, "direction": direction, "order": order, "weapon_scale": meta["k"]})
    board.save(output / "source-directions.png")
    (output / "source-directions.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"원본 좌우 합성 비교 {len(report)}개: {output}")


if __name__ == "__main__":
    main()
