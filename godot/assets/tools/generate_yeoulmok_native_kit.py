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
    elif kind == "well":
        d.ellipse((5, 17, 27, 28), fill=DARK, outline=INK)
        d.ellipse((5, 12, 27, 23), fill=STONE, outline=SHADE)
        d.ellipse((9, 15, 23, 21), fill=C["navy_gray"])
        d.line((7, 12, 7, 4), fill=DARK, width=2)
        d.line((25, 12, 25, 4), fill=DARK, width=2)
        d.line((7, 4, 25, 4), fill=WOOD, width=2)
        d.line((16, 4, 16, 17), fill=LIGHT)
        d.rectangle((14, 17, 18, 20), fill=WOOD)
    elif kind == "rack":
        for x in (4, 27):
            d.line((x, 4, x, 27), fill=DARK, width=2)
        d.line((4, 5, 27, 5), fill=WOOD)
        for x in (8, 17):
            d.rectangle((x, 6, x+6, 20), fill=C["tan"])
            d.line((x+1, 8, x+1, 19), fill=LIGHT)
    elif kind == "sign":
        d.rectangle((15, 13, 17, 27), fill=DARK)
        d.polygon([(6, 5), (23, 5), (28, 9), (23, 13), (6, 13)], fill=DARK)
        d.line((7, 6, 23, 6), fill=WOOD)
        d.line((10, 9, 21, 9), fill=LIGHT)
    else:
        d.rectangle((6, 19, 8, 26), fill=DARK)
        d.rectangle((24, 19, 26, 26), fill=DARK)
        d.rectangle((4, 16, 28, 20), fill=INK)
        d.rectangle((5, 16, 27, 18), fill=WOOD)
        d.line((5, 16, 27, 16), fill=LIGHT)
        d.rectangle((11, 13, 18, 15), fill=SHADE)
        d.line((15, 14, 22, 14), fill=LIGHT)
    return image


def tile(kind):
    image = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(image)
    if kind.startswith("water"):
        # STYLE_GUIDE의 물 예외: 청색189/남색51/회청16, 3단 램프 유지.
        image.paste(C["blue"], (0, 0, 16, 16))
        for y, start, end in ((4, 1, 11), (5, 3, 10), (10, 0, 8), (11, 2, 11), (14, 7, 15), (2, 2, 5)):
            d.line((start, y, end, y), fill=C["navy"])
        for y, start in ((3, 2), (9, 4)):
            d.line((start, y, start+7, y), fill=STONE)
        return image if kind.endswith("0") else image.transpose(Image.Transpose.ROTATE_180)
    if kind.startswith("sand") or kind.startswith("paving"):
        sand = kind.startswith("sand")
        image.paste(C["tan"] if sand else SHADE, (0, 0, 16, 16))
        points = [(3, 4), (10, 11)] if kind.endswith("0") else [(8, 5), (2, 12)]
        for x, y in points:
            d.line((x, y, x+2, y), fill=LIGHT if sand else C["navy_gray"])
        return image
    if kind.startswith("boundary_"):
        d.rectangle((0, 0, 15, 5), fill=C["dark_navy"])
        d.polygon([(0, 0), (5, 0), (7, 3), (5, 7), (1, 8), (0, 6)], fill=SHADE)
        d.polygon([(8, 1), (14, 0), (15, 2), (15, 8), (10, 7), (7, 4)], fill=C["navy_gray"])
        d.line((1, 1, 4, 1), fill=STONE)
        d.line((9, 2, 13, 1), fill=SHADE)
        rotation = {"n": None, "e": Image.Transpose.ROTATE_270,
                    "s": Image.Transpose.ROTATE_180, "w": Image.Transpose.ROTATE_90}[kind[-1]]
        return image if rotation is None else image.transpose(rotation)
    if kind.startswith("road_") or kind.startswith("shore_"):
        shore = kind.startswith("shore_")
        direction = kind.split("_")[1]
        if len(direction) == 2:
            for dy in range(3):
                for dx in range(3-dy):
                    x = 15-dx if "e" in direction else dx
                    y = 15-dy if "s" in direction else dy
                    d.point((x, y), fill=WOOD if shore else C["green"])
            return image
        d.line((0, 0, 15, 0), fill=WOOD if shore else C["green"])
        for x in (1, 2, 6, 10, 11, 14):
            d.point((x, 1), fill=C["navy"] if shore else C["green"])
        rotation = {"n": None, "e": Image.Transpose.ROTATE_270,
                    "s": Image.Transpose.ROTATE_180, "w": Image.Transpose.ROTATE_90}[kind[-1]]
        return image if rotation is None else image.transpose(rotation)
    if kind.startswith("grass"):
        image.paste(C["green"], (0, 0, 16, 16))
        points = [(3, 4), (11, 10)] if kind.endswith("0") else [(7, 3), (3, 12)]
        for x, y in points:
            d.line((x, y, x+1, y), fill=C["deep_green"])
    elif kind.startswith("dirt"):
        image.paste(WOOD, (0, 0, 16, 16))
        points = [(4, 7), (12, 12)] if kind.endswith("0") else [(9, 4), (2, 11)]
        for x, y in points:
            d.line((x, y, x+2, y), fill=C["tan"])
    elif kind.startswith("fence"):
        d.rectangle((0, 6, 15, 7), fill=WOOD)
        d.rectangle((0, 10, 15, 11), fill=DARK)
        for x in (2, 12):
            d.rectangle((x, 3, x+2, 14), fill=DARK)
            d.line((x, 3, x, 13), fill=LIGHT)
        if kind == "fence_end":
            d.rectangle((5, 0, 15, 15), fill=(0, 0, 0, 0))
        elif kind == "fence_corner":
            d.rectangle((2, 0, 4, 13), fill=WOOD)
            d.line((2, 0, 2, 13), fill=LIGHT)
    elif kind.startswith("shrub"):
        d.polygon([(2, 12), (1, 7), (4, 5), (5, 2), (11, 3), (14, 7), (13, 13)], fill=C["deep_green"])
        d.polygon([(3, 7), (6, 4), (11, 5), (12, 9), (7, 11), (3, 10)], fill=C["green"])
        if kind.endswith("1"):
            d.line((6, 5, 9, 5), fill=C["fresh_green"])
    else:
        for x, y in ((3, 6), (7, 3), (11, 5)):
            d.line((x, y, x+1, 14), fill=C["deep_green"])
            d.line((x, y, x, y+3), fill=WOOD)
    return image


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (160, 192))
    sheet.paste(building(), (0, 0))
    sheet.paste(building(True), (64, 0))
    data = {"version": 5, "image": "environment.png", "buildings": {}, "props": {}, "tiles": {}}
    for name, x, origin, footprint in (
        ("House", 0, [72, 424], [12, 36, 40, 24]),
        ("Workshop", 64, [248, 424], [12, 40, 40, 20]),
    ):
        data["buildings"][name] = {
            "region": [x, 0, 64, 64], "anchor": [32, 60],
            "threshold": [32, 60], "wall_bottom": 60,
            "footprint": footprint, "origin": origin,
            "roof_bounds": [5 if x else 7, 13 if x else 4, 54 if x else 51, 27 if x else 35],
            "visible_wall": [12, 40 if x else 39, 40, 20 if x else 21],
            "steps": [25, 60, 16, 3],
        }
    for index, kind in enumerate(("barrel", "crate", "logs", "basket", "bench")):
        sheet.paste(prop(kind), (index*32, 64))
        data["props"][kind] = {"region": [index*32, 64, 32, 32], "anchor": [16, 27]}
    for index, kind in enumerate(("grass0", "grass1", "dirt0", "dirt1", "fence", "fence_end", "fence_corner", "shrub0", "shrub1", "reeds")):
        sheet.paste(tile(kind), (index*16, 96))
        data["tiles"][kind] = {"region": [index*16, 96, 16, 16], "anchor": [0, 0]}
    for index, kind in enumerate(("road_n", "road_e", "road_s", "road_w", "shore_n", "shore_e", "shore_s", "shore_w")):
        sheet.paste(tile(kind), (index*16, 112))
        data["tiles"][kind] = {"region": [index*16, 112, 16, 16], "anchor": [0, 0]}
    for index, kind in enumerate(("road_ne", "road_se", "road_sw", "road_nw", "shore_ne", "shore_se", "shore_sw", "shore_nw")):
        sheet.paste(tile(kind), (index*16, 128))
        data["tiles"][kind] = {"region": [index*16, 128, 16, 16], "anchor": [0, 0]}
    for index, kind in enumerate(("water0", "water1", "sand0", "sand1", "paving0", "paving1", "boundary_n", "boundary_e", "boundary_s", "boundary_w")):
        sheet.paste(tile(kind), (index*16, 144))
        data["tiles"][kind] = {"region": [index*16, 144, 16, 16], "anchor": [0, 0]}
    for index, kind in enumerate(("well", "rack", "sign")):
        sheet.paste(prop(kind), (index*32, 160))
        data["props"][kind] = {"region": [index*32, 160, 32, 32], "anchor": [16, 27]}
    sheet.save(OUT / "environment.png")
    (OUT / "manifest.json").write_text(json.dumps(data, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print("YEOULMOK_NATIVE_KIT_GENERATED", OUT)


if __name__ == "__main__":
    main()
