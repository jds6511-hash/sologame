"""CC0/무료 소싱 스프라이트 -> EDG32 팔레트 재색상화 공용 유틸.

AR-2(몬스터 3종) 파이프라인에서 공용으로 쓰는 함수 모음.
소싱 원본은 각기 다른 색·명암 단계를 쓰므로, 휘도(luminance) 기준으로
outline/shadow/base/highlight 4단계로 양자화한 뒤 EDG32 색으로 치환한다
(STYLE_GUIDE.md 3-2장 "재질당 3단 램프" + 3-1장 아웃라인 규칙에 맞춤).

`edg32_palette.py`의 EDG32/RGB를 그대로 사용한다.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

TOOLS_DIR = Path(__file__).parent
ASSETS_DIR = TOOLS_DIR.parent
RAW_SRC_DIR = TOOLS_DIR / "_raw_src"


def load_rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def crop_cell(im: Image.Image, x: int, y: int, w: int, h: int) -> Image.Image:
    return im.crop((x, y, x + w, y + h))


def autotrim(im: Image.Image) -> Image.Image:
    """알파>0 픽셀 bbox로 자르기 (셀 안 여백 제거)."""
    alpha = im.split()[-1]
    bbox = alpha.getbbox()
    if bbox is None:
        return im
    return im.crop(bbox)


def paste_centered(canvas: Image.Image, sprite: Image.Image, bottom_y: int) -> None:
    """캔버스 하단 중앙 기준으로 스프라이트를 붙인다 (발밑 원점 규칙, STYLE_GUIDE 1-2장)."""
    x = (canvas.width - sprite.width) // 2
    y = bottom_y - sprite.height
    canvas.paste(sprite, (x, y), sprite)


def recolor_by_luminance(
    im: Image.Image,
    outline_rgb: tuple[int, int, int],
    shadow_rgb: tuple[int, int, int],
    base_rgb: tuple[int, int, int],
    highlight_rgb: tuple[int, int, int],
    t_outline: float = 0.16,
    t_shadow: float = 0.45,
    t_highlight: float = 0.78,
) -> Image.Image:
    """휘도 기준 4단계 양자화 후 EDG32 색으로 치환 (알파는 원본 유지, 반투명은 128 기준 이분화).

    t_outline/t_shadow/t_highlight: 0~1 휘도 경계값. 소싱 원본마다 명암 분포가
    다르므로 호출부에서 미세 조정 가능.
    """
    src = im.convert("RGBA")
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    px_in = src.load()
    px_out = out.load()
    for yy in range(src.height):
        for xx in range(src.width):
            r, g, b, a = px_in[xx, yy]
            if a == 0:
                continue
            lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            if lum < t_outline:
                color = outline_rgb
            elif lum < t_shadow:
                color = shadow_rgb
            elif lum < t_highlight:
                color = base_rgb
            else:
                color = highlight_rgb
            out_a = 255 if a >= 128 else 0
            px_out[xx, yy] = (*color, out_a)
    return out


def ensure_outline(im: Image.Image, outline_rgb: tuple[int, int, int]) -> Image.Image:
    """실루엣 가장 바깥 테두리 1px을 outline_rgb로 강제 (재색상화 후 경계가 무뎌진 경우 보강)."""
    src = im.convert("RGBA")
    w, h = src.size
    out = src.copy()
    px_in = src.load()
    px_out = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px_in[x, y]
            if a == 0:
                continue
            neighbors = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
            touches_bg = False
            for nx, ny in neighbors:
                if nx < 0 or ny < 0 or nx >= w or ny >= h:
                    touches_bg = True
                    break
                if px_in[nx, ny][3] == 0:
                    touches_bg = True
                    break
            if touches_bg:
                px_out[x, y] = (*outline_rgb, 255)
    return out


def resize_nearest(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    return im.resize(size, Image.NEAREST)


def new_sheet(cols: int, rows: int, cell: int) -> Image.Image:
    return Image.new("RGBA", (cols * cell, rows * cell), (0, 0, 0, 0))


def paste_frame(sheet: Image.Image, frame: Image.Image, col: int, row: int, cell: int) -> None:
    """프레임을 셀(col,row)의 하단 중앙에 정렬해서 붙인다 (발밑 원점)."""
    x0 = col * cell
    y0 = row * cell
    x = x0 + (cell - frame.width) // 2
    y = y0 + cell - frame.height
    # 마스크 없이 그대로 덮어쓰기: 대상 캔버스는 항상 투명 배경이므로 마스크 합성(블렌딩)이
    # 필요 없다. 마스크를 주면 반투명(페이드) 픽셀이 배경(투명=검정)과 블렌딩되어
    # 팔레트 밖 색이 생기는 버그가 있었다 (death 페이드 프레임에서 발견).
    sheet.paste(frame, (x, y))


def snap_to_colors(im: Image.Image, colors: list[tuple[int, int, int]], alpha_threshold: int = 64) -> Image.Image:
    """회전/리사이즈 등으로 생긴 보간색을 가장 가까운 팔레트 색으로 강제 스냅.

    회전(rotate)·리사이즈 연산 뒤에는 반드시 이 함수를 거쳐야 EDG32 준수가 유지된다.
    """
    src = im.convert("RGBA")
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    px_in = src.load()
    px_out = out.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px_in[x, y]
            if a < alpha_threshold:
                continue
            best = min(colors, key=lambda c: (c[0] - r) ** 2 + (c[1] - g) ** 2 + (c[2] - b) ** 2)
            px_out[x, y] = (*best, 255)
    return out


def fade(im: Image.Image, alpha_mult: float) -> Image.Image:
    r, g, b, a = im.split()
    a = a.point(lambda v: int(v * alpha_mult))
    return Image.merge("RGBA", (r, g, b, a))
