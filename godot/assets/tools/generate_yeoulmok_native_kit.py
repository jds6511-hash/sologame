"""여울목 비교용 원본 픽셀 작화. 기존 생성 그림의 축소/가공이 아니다.

정수 좌표와 공용 EDG32로 직접 그린다. 제품 assets에는 쓰지 않는다.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw
from edg32_palette import RGB

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "docs/art/concepts/yeoulmok/native-kit"
C = {key: (*value, 255) for key, value in RGB.items()}
INK, DARK, WOOD, LIGHT = (C[k] for k in ("dark_maroon", "red_brown_dark", "ochre", "apricot"))
STONE, SHADE = C["blue_gray"], C["dark_blue_gray"]


def building(workshop=False):
    image = Image.new("RGBA", (64, 64))
    d = ImageDraw.Draw(image)
    top = 40 if workshop else 36
    d.rectangle((12, top, 51, 59), fill=INK)
    d.rectangle((13, top+1, 50, 56), fill=LIGHT)
    for y in range(top+4, 56, 5):
        d.line((14, y, 49, y), fill=WOOD)
    # 돌 기초와 굵은 목재 틀은 벽 충돌 범위에 맞춘다.
    d.rectangle((13, 56, 50, 59), fill=SHADE)
    for x in range(14, 51, 8):
        d.rectangle((x, 56, min(x+5, 50), 58), fill=STONE)
    for x in (13, 23, 48):
        d.rectangle((x, top, x+2, 55), fill=DARK)
        d.line((x, top+1, x, 54), fill=WOOD)
    d.rectangle((27, 43, 38, 59), fill=INK)
    d.rectangle((28, 44, 37, 59), fill=DARK)
    for x in (29, 32, 35):
        d.line((x, 45, x, 58), fill=WOOD)
    d.point((36, 52), fill=LIGHT)
    d.rectangle((25, 60, 40, 62), fill=SHADE)
    d.line((26, 60, 39, 60), fill=STONE)
    d.rectangle((16, 42, 21, 49), fill=INK)
    d.rectangle((17, 43, 20, 47), fill=SHADE)
    d.line((18, 43, 18, 48), fill=WOOD)
    d.line((15, 50, 22, 50), fill=DARK)
    if workshop:
        # 낮은 경사 지붕과 깊은 차양. 벽 충돌은 기존 부지를 지킨다.
        roof = [(7, 17), (48, 13), (58, 36), (5, 39)]
        d.polygon(roof, fill=INK)
        d.polygon([(9, 18), (47, 15), (55, 34), (8, 36)], fill=DARK)
        for y in (20, 25, 30):
            d.line((10, y, 49+(y-20)//3, y-2), fill=WOOD)
            for x in range(15+(y%2)*4, 50, 9):
                d.line((x, y-3, x+1, y), fill=INK)
        d.line((7, 37, 56, 35), fill=LIGHT)
        # 수선한 판자와 매달린 간판. 글자나 발광색은 쓰지 않는다.
        d.polygon([(37, 24), (45, 23), (47, 29), (39, 30)], fill=WOOD)
        d.line((40, 25, 45, 27), fill=LIGHT)
        d.rectangle((44, 40, 50, 47), fill=DARK)
        d.line((46, 41, 48, 45), fill=LIGHT)
    else:
        # 윗면이 읽히는 맞배지붕. 비대칭 수선과 굴뚝으로 생활 흔적을 표현한다.
        d.polygon([(7, 34), (16, 11), (45, 11), (57, 34), (57, 38), (7, 38)], fill=INK)
        d.polygon([(9, 34), (17, 13), (43, 13), (54, 34)], fill=DARK)
        for y in range(17, 35, 5):
            inset = max(0, (34-y)//3)
            d.line((10+inset, y, 53-inset, y), fill=WOOD)
            for x in range(15+(y%2)*4, 51-inset, 8):
                d.line((x, y-3, x, y-1), fill=INK)
        d.line((17, 12, 43, 12), fill=LIGHT)
        d.line((8, 36, 55, 36), fill=WOOD)
        d.line((9, 37, 54, 37), fill=LIGHT)
        d.rectangle((42, 5, 48, 19), fill=INK)
        d.rectangle((43, 7, 47, 18), fill=SHADE)
        d.line((43, 7, 43, 17), fill=STONE)
        d.rectangle((41, 4, 49, 6), fill=DARK)
        d.polygon([(17, 23), (24, 23), (21, 30), (14, 30)], fill=WOOD)
        d.line((18, 24, 22, 25), fill=LIGHT)
    return image


def prop(kind):
    image = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(image)
    if kind == "barrel":
        d.rounded_rectangle((10, 10, 22, 26), radius=3, fill=INK)
        d.rectangle((11, 13, 21, 24), fill=WOOD)
        for x in (12, 16, 20):
            d.line((x, 13, x, 24), fill=DARK)
        for y in (15, 22):
            d.line((10, y, 22, y), fill=STONE)
        d.ellipse((11, 10, 21, 14), fill=DARK, outline=LIGHT)
    elif kind == "crate":
        d.rectangle((9, 13, 23, 26), fill=INK)
        d.rectangle((10, 14, 22, 25), fill=WOOD)
        for x in (14, 18):
            d.line((x, 15, x, 24), fill=DARK)
        d.line((11, 15, 21, 24), fill=LIGHT, width=2)
        d.line((10, 14, 22, 14), fill=LIGHT)
    elif kind == "logs":
        for x, y in ((5, 22), (12, 22), (9, 17)):
            d.rectangle((x, y, x+12, y+4), fill=INK)
            d.line((x+1, y+1, x+10, y+1), fill=WOOD)
            d.rectangle((x+10, y+1, x+12, y+3), fill=LIGHT)
            d.point((x+11, y+2), fill=DARK)
    elif kind == "basket":
        d.arc((10, 13, 22, 25), 180, 360, fill=LIGHT, width=2)
        d.polygon([(9, 19), (23, 19), (21, 26), (11, 26)], fill=DARK)
        d.rectangle((11, 20, 21, 24), fill=WOOD)
        for x in (12, 16, 20):
            d.line((x, 20, x, 24), fill=LIGHT)
        d.line((10, 19, 22, 19), fill=LIGHT)
    else:
        d.rectangle((6, 19, 8, 26), fill=DARK)
        d.rectangle((24, 19, 26, 26), fill=DARK)
        d.rectangle((4, 16, 28, 20), fill=INK)
        d.rectangle((5, 16, 27, 18), fill=WOOD)
        d.line((5, 16, 27, 16), fill=LIGHT)
        d.rectangle((11, 13, 18, 15), fill=SHADE)
        d.line((15, 14, 22, 14), fill=LIGHT)
    return image


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (160, 96))
    sheet.paste(building(), (0, 0))
    sheet.paste(building(True), (64, 0))
    data = {"version": 1, "image": "environment.png", "buildings": {}, "props": {}}
    for name, x, origin, footprint in (
        ("House", 0, [72, 424], [12, 36, 40, 24]),
        ("Workshop", 64, [248, 424], [12, 40, 40, 20]),
    ):
        data["buildings"][name] = {
            "region": [x, 0, 64, 64], "anchor": [32, 60],
            "threshold": [32, 60], "wall_bottom": 60,
            "footprint": footprint, "origin": origin,
            "roof_overhang": [5 if x else 7, 13 if x else 11, 54 if x else 51, 27 if x else 28],
        }
    for index, kind in enumerate(("barrel", "crate", "logs", "basket", "bench")):
        sheet.paste(prop(kind), (index*32, 64))
        data["props"][kind] = {"region": [index*32, 64, 32, 32], "anchor": [16, 27]}
    sheet.save(OUT / "environment.png")
    (OUT / "manifest.json").write_text(json.dumps(data, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print("YEOULMOK_NATIVE_KIT_GENERATED", OUT)


if __name__ == "__main__":
    main()
