"""LPC 레이어 합성 -> 20x36 EDG32 스프라이트 변환 공용 모듈 (M3 3-A).

`docs\\art\\m3-character-art-plan.md` 4-3절 7단계 파이프라인의 3~6단계를 담당한다.
**처리 순서 엄수: 합성 -> 축소 -> EDG32 재색상 -> 아웃라인.**
(재색상을 축소보다 먼저 하면 축소 보간으로 32색 밖 색이 다시 생긴다 — M2에서 확인된 함정.)

핵심 설계 — **재질(material) 맵을 축소까지 함께 끌고 간다**:
    LPC는 몸/머리/옷/무기가 레이어로 분리돼 있다. 이 정보를 버리고 합성 결과에
    휘도 램프 하나만 적용하면(M2 몬스터 방식) 피부·강철·천이 모두 한 색 계열로
    뭉개진다. 그래서 합성 시 픽셀마다 "가장 위에 있는 레이어의 재질 ID"를 기록한
    맵을 함께 만들고, 축소도 함께 수행한 뒤 **재질별 4단 램프**로 재색상한다
    (`STYLE_GUIDE` 3-2-1 캐릭터 4단 램프).

축소는 NEAREST가 아니라 **BOX(면적 평균)** 를 쓴다. r=0.70 같은 비정수 비율에서
NEAREST는 1px 선(칼날·아웃라인)을 통째로 버려 형태가 끊긴다. BOX로 줄이고
바로 뒤에서 팔레트 재양자화 + 아웃라인 강제를 하므로 중간색은 남지 않는다.
"""

from __future__ import annotations

import math
import sys
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from edg32_palette import ALLOWED_RGB_SET  # noqa: E402

TOOLS_DIR = Path(__file__).parent
ASSETS_DIR = TOOLS_DIR.parent
LPC_DIR = TOOLS_DIR / "_raw_src" / "lpc"

CELL = 64
CANVAS = 128  # 무기 oversize 셀이 128이라 합성 캔버스를 128로 잡는다
OUTLINE = (0x18, 0x14, 0x25)  # #181425 — STYLE_GUIDE 3-1 아웃라인 표준색

# LPC 시트의 행 = 방향. 우리 규약(행 0 front / 1 side / 2 back)으로 매핑한다.
LPC_ROW = {"front": 2, "side": 3, "back": 0}
DIRECTIONS = ["front", "side", "back"]  # 우리 시트 행 순서 (STYLE_GUIDE 7-1)

# 목표 규격 (STYLE_GUIDE 1-2)
FRAME_W, FRAME_H = 20, 36

# LPC 원본 실측값 (measure_source_bbox.py) — 알파 bbox y=15..62, 중심 x=32, 실체높이 47.
# bbox 하단은 **배타적**이므로 발밑 픽셀이 있는 마지막 행은 61이다.
SRC_FOOT_Y = 61
SRC_CENTER_X = 32
SCALE_NUM, SCALE_DEN = 45, 64  # 0.7031 — 47 * 0.7031 = 33.0 (목표 실체 높이 33)


def hx(s: str) -> tuple[int, int, int]:
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


# 재질별 4단 램프 (밝음 -> 어두움). 전부 EDG32 내 인접 명도만 사용 (STYLE_GUIDE 3-2-1 2항).
# `#181425` 는 아웃라인 전용이라 램프에 넣지 않는다 (3-1 "내부에 #181425 남용 금지").
RAMPS: dict[str, tuple[str, str, str, str]] = {
    "skin": ("#e8b796", "#e4a672", "#d77643", "#b86f50"),
    # 머리카락: 최암부만으로 채우면 후면 프레임의 머리가 **검은 덩어리**가 되어 두상이
    # 안 읽힌다(실측). 밝은 갈색을 하이라이트로 넣어 4단 볼륨을 살리되, 최명부를 피부
    # 최암부(#b86f50)보다 어둡게 유지해 얼굴과 머리의 경계는 그대로 남긴다.
    "hair_dark": ("#b86f50", "#733e39", "#3e2731", "#262b44"),
    "steel": ("#8b9bb4", "#5a6988", "#3a4466", "#262b44"),
    "steel_bright": ("#ffffff", "#c0cbdc", "#8b9bb4", "#5a6988"),
    "leather": ("#b86f50", "#733e39", "#3e2731", "#262b44"),
    "trouser_dark": ("#5a6988", "#3a4466", "#262b44", "#3e2731"),
    "cloth_green": ("#63c74d", "#3e8948", "#265c42", "#193c3e"),
    # 전사 받침옷 — 짙은 남색 천. `STYLE_GUIDE` 2장의 청 계열(아군/플레이어 식별색)에
    # 속하면서, 갈색(부츠·머리)·회청 판금·초록(궁수)과 모두 계열이 달라 부위 경계가 읽힌다.
    # 고채도 `#0099db` 는 램프에서 제외한다 — 어깨에 발광하는 시안 반점처럼 보인다(실측).
    "cloth_blue": ("#124e89", "#3a4466", "#262b44", "#3e2731"),
    "wood": ("#c28569", "#b86f50", "#733e39", "#3e2731"),
}


@dataclass(frozen=True)
class Layer:
    """캐릭터 레이어 1장. `path_tpl` 의 `{anim}` 은 LPC 애니메이션 이름으로 치환된다."""

    name: str
    path_tpl: str
    material: str


@dataclass(frozen=True)
class Weapon:
    """무기/소품 레이어. 상태마다 경로·셀 크기가 달라서 StateSpec 이 들고 있는다."""

    fg: str  # 몸보다 앞에 합성 (필수)
    bg: str | None  # 몸보다 뒤에 합성
    cell: int
    material: str
    extra: str | None = None  # 화살 등 추가 fg 레이어 (셀 64 고정)


@dataclass
class StateSpec:
    """우리 상태 시트 1개의 제작 명세."""

    state: str  # 파일명·애니메이션 키 (STYLE_GUIDE 3-3-1 확정 어휘만)
    anim: str  # 몸 레이어가 쓸 LPC 애니메이션
    frames: list[int]  # 원본에서 뽑을 프레임 인덱스 (순서 = 재생 순서)
    weapon: Weapon | None = None
    weapon_frames: list[int] | None = None  # None = frames 와 동일
    # 무기 위치 보정 {(방향, 프레임순서): (dx, dy)} — 원본 64px 좌표계 기준
    weapon_offset: dict[tuple[str, int], tuple[int, int]] = field(default_factory=dict)
    tilt: list[float] = field(default_factory=list)  # 프레임별 회전(도) — 곡예 자세
    # 이 방향들에서는 무기 fg(몸 앞) 레이어를 빼고 bg 만 쓴다 — 무기가 얼굴을 덮는 정면 사격 등
    hide_fg_dirs: tuple[str, ...] = ()
    airborne: bool = False  # 공중 프레임이 있는 상태(점프 회피) — 발밑 하단 접촉 검사 면제
    note: str = ""


def load_cached(rel: str, _cache: dict[str, Image.Image] = {}) -> Image.Image:  # noqa: B006
    if rel not in _cache:
        p = LPC_DIR / rel
        if not p.exists():
            raise FileNotFoundError(
                f"LPC 레이어 없음: {p}\n먼저 `python fetch_lpc_layers.py` 를 실행하세요."
            )
        _cache[rel] = Image.open(p).convert("RGBA")
    return _cache[rel]


def grab(rel: str, col: int, row: int, cell: int) -> Image.Image:
    """시트에서 (col,row) 셀을 잘라낸다.

    시트 높이가 셀 1개분이면(예: `hurt.png` 는 front 1행뿐) row 를 0으로 강제한다 —
    그 결과 3방향 모두 정면 붕괴 모션을 공유한다(LPC 원본 한계, 문서에 기록).
    """
    im = load_cached(rel)
    r = 0 if im.height == cell else row
    if (col + 1) * cell > im.width or (r + 1) * cell > im.height:
        return Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
    return im.crop((col * cell, r * cell, col * cell + cell, r * cell + cell))


def material_ids(layers: list[Layer], weapons: list[Weapon]) -> dict[str, int]:
    names = sorted({layer.material for layer in layers} | {w.material for w in weapons})
    return {n: i + 1 for i, n in enumerate(names)}


class _Part:
    """합성 파츠 1개 (RGBA + 재질 ID 맵). 무기 파츠만 따로 변형하기 위해 분리해 둔다."""

    def __init__(self) -> None:
        self.rgba = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        self.idmap = Image.new("L", (CANVAS, CANVAS), 0)

    def put(self, tile: Image.Image, cell: int, mid: int, off: tuple[int, int] = (0, 0)) -> None:
        base = (CANVAS - cell) // 2
        pos = (base + off[0], base + off[1])
        self.rgba.alpha_composite(tile, pos)
        self.idmap.paste(mid, pos, tile.split()[-1].point(lambda v: 255 if v >= 128 else 0))

    def mask(self) -> Image.Image:
        return self.rgba.split()[-1].point(lambda v: 255 if v >= 128 else 0)

    def transform(self, matrix: tuple[float, ...]) -> None:
        size = (CANVAS, CANVAS)
        self.rgba = self.rgba.transform(size, Image.AFFINE, matrix, resample=Image.BILINEAR)
        self.idmap = self.idmap.transform(size, Image.AFFINE, matrix, resample=Image.NEAREST)


# ------------------------------------------------------------- 무기 축방향 단축
# 20x36 프레임의 가로 여백은 실체 15px 기준 좌우 2~3px뿐이다. LPC 원본의 검 스윙·정면
# 활은 이 창(가로 28px, 세로 51px 원본 좌표계)을 15~47px 초과해 **칼날이 프레임 밖에서
# 잘린 막대**가 된다(실측 — 결과 보고 참조). 균등 축소로 맞추면 1px 칼날이 소실되므로,
# **무기의 주축(길이 방향)만 단축하고 두께는 유지**한다. 자세(손·팔·몸)는 LPC 원본
# 그대로 남으므로 손그림 모션의 값어치는 훼손되지 않고, 무기는 프레임 안에서 읽힌다.


def _axis_and_grip(weapon: Image.Image, body: Image.Image) -> tuple[tuple[float, float], tuple[float, float]]:
    """무기의 주축 단위벡터와 손잡이 지점을 추정한다.

    손잡이 = **몸과 맞닿은 무기 픽셀들의 중심**(무기는 손에서 잡히므로 몸 실루엣과
    겹치거나 인접한다). 접점이 없으면 몸 중심에 가장 가까운 무기 픽셀로 대체한다.
    """
    wp, bp = weapon.load(), body.load()
    pts = [(x, y) for y in range(CANVAS) for x in range(CANVAS) if wp[x, y]]
    if not pts:
        return (0.0, 1.0), (CANVAS / 2, CANVAS / 2)

    touch = [
        (x, y)
        for x, y in pts
        if any(
            0 <= x + ox < CANVAS and 0 <= y + oy < CANVAS and bp[x + ox, y + oy]
            for ox in (-2, -1, 0, 1, 2)
            for oy in (-2, -1, 0, 1, 2)
        )
    ]
    if touch:
        grip = (sum(p[0] for p in touch) / len(touch), sum(p[1] for p in touch) / len(touch))
    else:
        bb = body.getbbox() or (0, 0, CANVAS, CANVAS)
        bc = ((bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2)
        grip = min(pts, key=lambda p: (p[0] - bc[0]) ** 2 + (p[1] - bc[1]) ** 2)

    # 주축 = 손잡이 기준 2차 모멘트의 주고유벡터
    sxx = syy = sxy = 0.0
    for x, y in pts:
        dx, dy = x - grip[0], y - grip[1]
        sxx += dx * dx
        syy += dy * dy
        sxy += dx * dy
    n = len(pts)
    sxx, syy, sxy = sxx / n, syy / n, sxy / n
    theta = 0.5 * math.atan2(2 * sxy, sxx - syy)
    return (math.cos(theta), math.sin(theta)), grip


def _shrink_matrix(grip: tuple[float, float], axis: tuple[float, float], k: float) -> tuple[float, ...]:
    """손잡이를 고정하고 주축 방향으로만 k배 단축하는 아핀 역행렬 (PIL 은 역매핑을 받는다)."""
    ux, uy = axis
    m = 1.0 / k - 1.0
    a, b = 1 + m * ux * ux, m * ux * uy
    d, e = m * ux * uy, 1 + m * uy * uy
    gx, gy = grip
    return (a, b, gx - (a * gx + b * gy), d, e, gy - (d * gx + e * gy))


def _fits(bbox: tuple[int, int, int, int] | None) -> bool:
    """합성 bbox 가 20x36 크롭 창 안에 들어오는지 **축소 후 좌표계에서** 판정한다.

    원본(128) 좌표계에서 분수 경계와 비교하면 배타적 bbox 하단이 항상 경계를 1px 넘어
    영원히 실패한다 — 반드시 축소 후 정수 픽셀로 환산해 비교한다.
    """
    if bbox is None:
        return True
    s = SCALE_NUM / SCALE_DEN
    off = (CANVAS - CELL) // 2
    x0 = round((off + SRC_CENTER_X) * s) - FRAME_W // 2
    y0 = round((off + SRC_FOOT_Y) * s) - (FRAME_H - 1)
    fx0, fx1 = math.floor(bbox[0] * s), math.floor((bbox[2] - 1) * s)
    fy0, fy1 = math.floor(bbox[1] * s), math.floor((bbox[3] - 1) * s)
    return fx0 >= x0 and fx1 < x0 + FRAME_W and fy0 >= y0 and fy1 < y0 + FRAME_H


def _solid_bbox(im: Image.Image) -> tuple[int, int, int, int] | None:
    """재색상 단계와 **같은 알파 임계값(96)** 으로 실체 bbox 를 구한다.

    `getbbox()` 는 알파 1도 포함해서, LPC 원본의 반투명 1px 프린지가 발밑 경계를 1px
    밀어낸다. 그 프린지는 재색상에서 버려지므로 맞춤 판정에 넣으면 영원히 실패한다.
    """
    return im.split()[-1].point(lambda v: 255 if v >= 96 else 0).getbbox()


def _fit_weapon(parts: list[_Part], body: _Part) -> float:
    """프레임에 들어올 때까지 무기를 주축 단축한다. 반환값 = 적용한 k (1.0 = 무변형).

    판정 대상은 **무기만**이다. LPC 원본의 팔 스윙·발끝은 포즈에 따라 20x36 창을 1px
    넘어서는데(실측: walk/attack 정면 폭 21px), 그건 손그림 자세 자체라 건드리지 않는다.
    몸까지 판정에 넣으면 조건이 영원히 거짓이 되어 무기가 최소값까지 쪼그라든다.
    """
    live = [p for p in parts if _solid_bbox(p.rgba)]
    if not live:
        return 1.0

    def union() -> tuple[int, int, int, int] | None:
        boxes = [b for b in (_solid_bbox(p.rgba) for p in live) if b]
        if not boxes:
            return None
        return (
            min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes),
        )

    if _fits(union()):
        return 1.0

    merged = Image.new("L", (CANVAS, CANVAS), 0)
    for p in live:
        merged.paste(p.mask(), (0, 0), p.mask())
    axis, grip = _axis_and_grip(merged, body.mask())
    saved = [(p.rgba, p.idmap) for p in live]

    k = 1.0
    for cand in [0.85, 0.7, 0.6, 0.5, 0.42, 0.36, 0.3, 0.25]:
        for p, (rgba, idmap) in zip(live, saved):
            p.rgba, p.idmap = rgba, idmap
        mtx = _shrink_matrix(grip, axis, cand)
        for p in live:
            p.transform(mtx)
        k = cand
        if _fits(union()):
            break
    return k


def compose_frame(
    layers: list[Layer], spec: StateSpec, direction: str, order: int, mats: dict[str, int],
    fit_weapon: bool = True, weapon_mode: str = "composite",
) -> tuple[Image.Image, Image.Image, dict]:
    """레이어를 합성해 (RGBA, 재질 ID 맵, 부가정보) 를 반환. 캔버스 128x128.

    `weapon_mode`:
      - `"composite"`: LPC 무기 레이어를 그대로 합성한다(주축 단축 적용).
      - `"probe"`: 무기를 합성하지 **않고** 손잡이 좌표만 재서 돌려준다. 무기는 이후
        최종 20x36 해상도에서 직접 그린다(`draw_sword`·`draw_bow`).
    부가정보 = `{"k": 단축률, "grip": (x, y) 캔버스 좌표 or None}`.
    """
    row = LPC_ROW[direction]
    bframe = spec.frames[order]
    wf = spec.weapon_frames if spec.weapon_frames is not None else spec.frames
    wframe = wf[order] if order < len(wf) else wf[-1]
    dx, dy = spec.weapon_offset.get((direction, order), (0, 0))
    w = spec.weapon

    body = _Part()
    for layer in layers:
        rel = layer.path_tpl.format(anim=spec.anim)
        if not (LPC_DIR / rel).exists():
            continue
        body.put(grab(rel, bframe, row, CELL), CELL, mats[layer.material])

    wbg, wfg = _Part(), _Part()
    if w:
        mid = mats[w.material]
        if w.bg:
            wbg.put(grab(w.bg, wframe, row, w.cell), w.cell, mid, (dx, dy))
        if direction not in spec.hide_fg_dirs:
            wfg.put(grab(w.fg, wframe, row, w.cell), w.cell, mid, (dx, dy))
            if w.extra:
                wfg.put(grab(w.extra, wframe, row, CELL), CELL, mid, (dx, dy))

    grip: tuple[float, float] | None = None
    if w and weapon_mode == "probe":
        merged = Image.new("L", (CANVAS, CANVAS), 0)
        for p in (wbg, wfg):
            merged.paste(p.mask(), (0, 0), p.mask())
        if merged.getbbox():
            _, grip = _axis_and_grip(merged, body.mask())
        parts: tuple[_Part, ...] = (body,)
        k = 1.0
    else:
        k = _fit_weapon([wbg, wfg], body) if (w and fit_weapon) else 1.0
        parts = (wbg, body, wfg)

    rgba = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    idmap = Image.new("L", (CANVAS, CANVAS), 0)
    for part in parts:
        rgba.alpha_composite(part.rgba)
        idmap.paste(part.idmap, (0, 0), part.mask())
    return rgba, idmap, {"k": k, "grip": grip}


def rotate_pair(
    rgba: Image.Image, idmap: Image.Image, deg: float
) -> tuple[Image.Image, Image.Image]:
    """발밑 지점을 중심으로 회전 (곡예 자세용). idmap 은 NEAREST 로 같이 돌린다."""
    if not deg:
        return rgba, idmap
    off = (CANVAS - CELL) // 2
    center = (off + SRC_CENTER_X, off + SRC_FOOT_Y - 12)
    return (
        rgba.rotate(deg, resample=Image.BILINEAR, center=center),
        idmap.rotate(deg, resample=Image.NEAREST, center=center),
    )


def downscale(rgba: Image.Image, idmap: Image.Image, mats: dict[str, int]) -> tuple[Image.Image, Image.Image]:
    """BOX 축소. 재질 맵은 재질별 커버리지를 BOX로 줄인 뒤 최대 커버리지 재질을 채택한다."""
    dst = round(CANVAS * SCALE_NUM / SCALE_DEN)
    small = rgba.resize((dst, dst), Image.BOX)
    best = Image.new("L", (dst, dst), 0)
    bp = best.load()
    cov_max = [[0] * dst for _ in range(dst)]
    for name, mid in mats.items():
        mask = idmap.point(lambda v, m=mid: 255 if v == m else 0)
        if not mask.getbbox():
            continue
        cov = mask.resize((dst, dst), Image.BOX).load()
        for y in range(dst):
            row = cov_max[y]
            for x in range(dst):
                v = cov[x, y]
                if v > row[x]:
                    row[x] = v
                    bp[x, y] = mid
    return small, best


def luminance(r: int, g: int, b: int) -> float:
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0


def collect_luminance(
    frames: list[tuple[Image.Image, Image.Image]], mats: dict[str, int]
) -> dict[int, list[float]]:
    """전 프레임에서 재질별 휘도 표본을 모은다 (프레임마다 밴드가 달라지면 색이 튄다)."""
    out: dict[int, list[float]] = {mid: [] for mid in mats.values()}
    for rgba, idm in frames:
        px, ip = rgba.load(), idm.load()
        for y in range(rgba.height):
            for x in range(rgba.width):
                mid = ip[x, y]
                if mid == 0:
                    continue
                r, g, b, a = px[x, y]
                if a < 96:
                    continue
                out[mid].append(luminance(r, g, b))
    return out


def bands_from(lums: list[float]) -> tuple[float, float, float]:
    """재질별 휘도 분포에서 4단 램프 경계를 분위수로 정한다.

    고정 임계값을 쓰면 어두운 재질(가죽·머리카락)은 전부 최암부로, 밝은 재질(강철)은
    전부 하이라이트로 몰린다. 분위수를 쓰면 재질마다 4단이 고르게 배분돼 볼륨이 산다.
    """
    if not lums:
        return (0.25, 0.5, 0.75)
    s = sorted(lums)
    n = len(s)
    return (s[int(n * 0.28)], s[int(n * 0.58)], s[min(n - 1, int(n * 0.86))])


def recolor(
    rgba: Image.Image,
    idmap: Image.Image,
    mats: dict[str, int],
    bands: dict[int, tuple[float, float, float]],
    ramp_of: dict[str, str],
    alpha_threshold: int = 96,
) -> Image.Image:
    """재질별 4단 램프로 EDG32 재색상 (파이프라인 5단계)."""
    id_to_mat = {v: k for k, v in mats.items()}
    ramps = {
        mid: tuple(hx(c) for c in RAMPS[ramp_of[id_to_mat[mid]]])
        for mid in mats.values()
        if id_to_mat.get(mid) in ramp_of
    }
    out = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    px, ip, op = rgba.load(), idmap.load(), out.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = px[x, y]
            if a < alpha_threshold:
                continue
            ramp = ramps.get(ip[x, y])
            if ramp is None:
                continue
            lo, mid_t, hi = bands[ip[x, y]]
            lum = luminance(r, g, b)
            if lum >= hi:
                color = ramp[0]
            elif lum >= mid_t:
                color = ramp[1]
            elif lum >= lo:
                color = ramp[2]
            else:
                color = ramp[3]
            op[x, y] = (*color, 255)
    return out


def ensure_outline(im: Image.Image) -> Image.Image:
    """실루엣 최외곽 1px 을 #181425 로 강제 (파이프라인 6단계, STYLE_GUIDE 3-1)."""
    w, h = im.size
    out = im.copy()
    px, op = im.load(), out.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if nx < 0 or ny < 0 or nx >= w or ny >= h or px[nx, ny][3] == 0:
                    op[x, y] = (*OUTLINE, 255)
                    break
    return out


def crop_to_frame(im: Image.Image) -> tuple[Image.Image, int]:
    """축소 이미지에서 20x36 프레임을 잘라낸다. 발밑 = 캔버스 하단 중앙 고정.

    두 번째 반환값은 **가로로 잘려나간 픽셀 수**(무기 돌출분) — 규격 검사·보고용.
    """
    s = SCALE_NUM / SCALE_DEN
    off = (CANVAS - CELL) // 2
    foot_y = round((off + SRC_FOOT_Y) * s)
    cx = round((off + SRC_CENTER_X) * s)
    x0 = cx - FRAME_W // 2
    y0 = foot_y - (FRAME_H - 1)

    clipped = 0
    bbox = im.split()[-1].getbbox()
    if bbox:
        clipped = max(0, x0 - bbox[0]) + max(0, bbox[2] - (x0 + FRAME_W))

    frame = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    frame.paste(im.crop((x0, y0, x0 + FRAME_W, y0 + FRAME_H)), (0, 0))
    return frame, clipped


def build_sheet(frames_by_dir: dict[str, list[Image.Image]]) -> Image.Image:
    """`(프레임 수 x 20) x (3 x 36)` 시트로 합친다 (STYLE_GUIDE 7-1: 행 0 front / 1 side / 2 back)."""
    cols = len(frames_by_dir[DIRECTIONS[0]])
    sheet = Image.new("RGBA", (cols * FRAME_W, len(DIRECTIONS) * FRAME_H), (0, 0, 0, 0))
    for r, d in enumerate(DIRECTIONS):
        for c, frame in enumerate(frames_by_dir[d]):
            sheet.paste(frame, (c * FRAME_W, r * FRAME_H))
    return sheet


# =============================================================== 무기 직접 작화
# 왜 무기를 원본에서 안 가져오고 직접 그리는가 (계획서 4-1절 "경로 4 = 실루엣 위 재작화"):
#   LPC 무기 시트는 64~128px 캔버스에서 그려져 있어 20x36으로 줄이면 ① 칼날이 프레임을
#   15~47px 벗어나 잘리고 ② 활은 정면·후면에서 형체 없는 검은 쐐기가 된다(둘 다 실측).
#   반면 검·활은 **직선과 호(弧)로 된 규칙적 형태**라 절차 생성이 가장 강한 영역이다
#   (계획서 1장 표). 그래서 **자세(몸·팔·손)는 LPC 손그림 그대로 쓰고, 무기만 최종
#   20x36 해상도에서 직접 그린다.** 손 위치는 LPC 무기 레이어에서 실측한 손잡이 좌표를
#   쓰므로 무기가 손에서 떨어지지 않는다.
#   부수 이득: 프레임별 검 각도를 직접 지정할 수 있어 **공격 실루엣이 프레임마다 확실히
#   변한다** — 디렉터가 지적한 "정면 검 든 모습 어색"의 직접적 원인이 이것이었다.

BLADE = hx("#c0cbdc")
BLADE_TIP = hx("#ffffff")
GUARD = hx("#5a6988")
GRIP_C = hx("#733e39")
BOW_LIMB = hx("#b86f50")
BOW_LIMB_HI = hx("#c28569")
BOW_STRING = hx("#c0cbdc")
ARROW_SHAFT = hx("#c28569")


def frame_point(pt: tuple[float, float]) -> tuple[float, float]:
    """캔버스(128) 좌표 -> 최종 20x36 프레임 좌표. `crop_to_frame` 과 같은 수식을 쓴다."""
    s = SCALE_NUM / SCALE_DEN
    off = (CANVAS - CELL) // 2
    x0 = round((off + SRC_CENTER_X) * s) - FRAME_W // 2
    y0 = round((off + SRC_FOOT_Y) * s) - (FRAME_H - 1)
    return (pt[0] * s - x0, pt[1] * s - y0)


def rotate_point(pt: tuple[float, float], deg: float) -> tuple[float, float]:
    """`rotate_pair` 와 동일한 중심·부호로 점을 회전 (곡예 자세의 손 위치 추적용)."""
    if not deg:
        return pt
    off = (CANVAS - CELL) // 2
    cx, cy = off + SRC_CENTER_X, off + SRC_FOOT_Y - 12
    a = math.radians(deg)
    dx, dy = pt[0] - cx, pt[1] - cy
    return (cx + dx * math.cos(a) - dy * math.sin(a), cy + dx * math.sin(a) + dy * math.cos(a))


def facing_dir(direction: str, angle_deg: float) -> tuple[float, float]:
    """측면 기준 각도를 방향별 단위벡터로 변환.

    정면·후면은 스윙이 시청자 쪽(화면 깊이 방향)으로 일어나므로 가로 성분을 0.55배로
    압축해 **원근 단축**을 흉내낸다. 후면은 좌우가 뒤집힌다.
    """
    a = math.radians(angle_deg)
    x, y = math.cos(a), math.sin(a)
    if direction == "front":
        x *= 0.55
    elif direction == "back":
        x *= -0.55
    n = math.hypot(x, y) or 1.0
    return (x / n, y / n)


def _line(p0: tuple[float, float], p1: tuple[float, float]) -> list[tuple[int, int]]:
    n = max(2, int(math.hypot(p1[0] - p0[0], p1[1] - p0[1]) * 2) + 1)
    return [
        (round(p0[0] + (p1[0] - p0[0]) * i / (n - 1)), round(p0[1] + (p1[1] - p0[1]) * i / (n - 1)))
        for i in range(n)
    ]


def _bezier(
    p0: tuple[float, float], p1: tuple[float, float], p2: tuple[float, float]
) -> list[tuple[int, int]]:
    pts = []
    for i in range(25):
        t = i / 24
        u = 1 - t
        pts.append(
            (
                round(u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0]),
                round(u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]),
            )
        )
    return pts


def _max_len(hand: tuple[float, float], d: tuple[float, float], want: float) -> float:
    """아웃라인 1px 여유를 두고 프레임 안에 들어오는 최대 길이. 잘린 무기를 원천 차단한다."""
    lo, hi = 1.0, 1.0
    while hi <= want:
        tx, ty = hand[0] + d[0] * hi, hand[1] + d[1] * hi
        if not (1 <= tx <= FRAME_W - 2 and 1 <= ty <= FRAME_H - 2):
            break
        lo = hi
        hi += 0.5
    return lo


def _stamp(frame: Image.Image, strokes: list[tuple[list[tuple[int, int]], tuple[int, int, int]]]) -> None:
    """획 목록을 프레임에 찍고, 그 실루엣 바깥 1px 을 `#181425` 아웃라인으로 감싼다."""
    paint: dict[tuple[int, int], tuple[int, int, int]] = {}
    for pts, color in strokes:
        for x, y in pts:
            if 0 <= x < FRAME_W and 0 <= y < FRAME_H:
                paint[(x, y)] = color
    if not paint:
        return
    px = frame.load()
    for (x, y) in paint:
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if (nx, ny) not in paint and 0 <= nx < FRAME_W and 0 <= ny < FRAME_H:
                px[nx, ny] = (*OUTLINE, 255)
    for (x, y), color in paint.items():
        px[x, y] = (*color, 255)


def draw_sword(frame: Image.Image, hand: tuple[float, float], d: tuple[float, float], want: float) -> None:
    """손잡이에서 방향 `d` 로 뻗은 검 1자루. 칼날 1px + 칼끝 하이라이트 + 가드 + 손잡이."""
    length = _max_len(hand, d, want)
    if length < 3:
        return
    perp = (-d[1], d[0])
    tip = (hand[0] + d[0] * length, hand[1] + d[1] * length)
    guard_c = (hand[0] + d[0] * 1.5, hand[1] + d[1] * 1.5)
    blade0 = (hand[0] + d[0] * 2.5, hand[1] + d[1] * 2.5)
    _stamp(
        frame,
        [
            # 손잡이 — 손에서 반대 방향으로 2px
            (_line(hand, (hand[0] - d[0] * 2, hand[1] - d[1] * 2)), GRIP_C),
            # 가드 — 날에 수직으로 3px
            (
                _line(
                    (guard_c[0] - perp[0] * 1.5, guard_c[1] - perp[1] * 1.5),
                    (guard_c[0] + perp[0] * 1.5, guard_c[1] + perp[1] * 1.5),
                ),
                GUARD,
            ),
            (_line(blade0, tip), BLADE),
            # 칼끝 2px 만 흰색 — 20px 안에서 "베는 방향"이 읽히게 하는 최소 단서
            (_line((tip[0] - d[0] * 1.5, tip[1] - d[1] * 1.5), tip), BLADE_TIP),
        ],
    )


def draw_bow(
    frame: Image.Image, hand: tuple[float, float], bulge: float, size: float,
    draw_amt: float, arrow: bool,
) -> None:
    """수직 활. `bulge` = 활배가 향하는 화면 x 방향(+1/-1), `draw_amt` = 당김 정도 0~1.

    림(限)을 세로로 두는 이유: 20px 폭 안에서 활을 가로로 놓으면 몸통에 겹쳐 형체가
    사라진다. 세로 배치는 36px 세로 여유를 쓰므로 3방향 모두 활 실루엣이 남는다.
    """
    top = (hand[0], hand[1] - size)
    bot = (hand[0], hand[1] + size)
    ctrl = (hand[0] + bulge * size * 1.5, hand[1])
    nock = (hand[0] - bulge * (1.0 + draw_amt * 3.5), hand[1])
    strokes = [
        (_bezier(top, ctrl, bot), BOW_LIMB),
        (_bezier((top[0], top[1] + 1), (ctrl[0] - bulge, ctrl[1]), (bot[0], bot[1] - 1)), BOW_LIMB_HI),
    ]
    if draw_amt > 0.05:
        strokes += [(_line(top, nock), BOW_STRING), (_line(nock, bot), BOW_STRING)]
    else:
        strokes.append((_line(top, bot), BOW_STRING))
    if arrow:
        d = (bulge, 0.0)
        alen = _max_len(nock, d, size * 2.2)
        atip = (nock[0] + d[0] * alen, nock[1])
        strokes.append((_line(nock, atip), ARROW_SHAFT))
        strokes.append((_line((atip[0] - d[0], atip[1]), atip), BLADE))
    _stamp(frame, strokes)


EYE = hx("#3e2731")
_SKIN_SET = {hx(c) for c in ("#e8b796", "#e4a672", "#d77643")}


def draw_eyes(frame: Image.Image, direction: str) -> bool:
    """얼굴에 1px 눈 점을 찍는다 (계획서 4-2절 경로 4: "머리 1~2px 눈 점 + 헤어 실루엣").

    64px 원본의 눈은 0.70배 축소 + 4단 양자화에서 살아남지 못해 얼굴이 **빈 살색 덩어리**가
    된다. 눈 점 1px 은 20x36에서 얼굴 방향을 읽히게 하는 최소 단서다.
    **후면은 찍지 않는다** — 눈 유무 자체가 앞/뒤 구분 신호가 된다.
    피부색 행을 실측해 배치하므로 머리카락·투구 위에 눈이 찍히는 일은 없다.
    """
    if direction == "back":
        return True
    px = frame.load()

    def skin_run(y: int) -> list[int]:
        return [x for x in range(FRAME_W) if px[x, y][3] == 255 and px[x, y][:3] in _SKIN_SET]

    brow = next((y for y in range(FRAME_H // 2) if len(skin_run(y)) >= 4), None)
    if brow is None:
        return False
    ey = brow + 2
    row = skin_run(ey) if ey < FRAME_H else []
    if len(row) < 3:
        return False
    lo, hi = min(row), max(row)
    if direction == "front":
        cx = (lo + hi) // 2
        xs = [cx - 2, cx + 2] if cx - 2 >= lo and cx + 2 <= hi else [cx - 1, cx + 1]
    else:
        xs = [hi - 1]  # 측면은 보이는 쪽 눈 1개만
    for x in xs:
        if lo <= x <= hi:
            px[x, ey] = (*EYE, 255)
    return True


def palette_violations(im: Image.Image) -> dict[tuple[int, int, int], int]:
    bad: dict[tuple[int, int, int], int] = {}
    for r, g, b, a in im.convert("RGBA").getdata():
        if a == 0:
            continue
        if (r, g, b) not in ALLOWED_RGB_SET:
            bad[(r, g, b)] = bad.get((r, g, b), 0) + 1
    return bad


def foot_row_check(sheet: Image.Image, cols: int, airborne: bool = False) -> list[str]:
    """전 프레임의 발밑 y좌표가 동일한지 검사 (파이프라인 4단계 검증 조건).

    `airborne=True`(점프 회피)는 **공중 프레임이 의도된 상태**라 하단 접촉을 면제한다 —
    도약·체공 프레임에서 발이 떠 있는 것이 정상이며, 대신 첫 프레임(도약 준비)이 지면에
    닿아 있는지만 확인한다.
    """
    problems: list[str] = []
    alpha = sheet.split()[-1]
    for r, d in enumerate(DIRECTIONS):
        for c in range(cols):
            box = alpha.crop((c * FRAME_W, r * FRAME_H, (c + 1) * FRAME_W, (r + 1) * FRAME_H)).getbbox()
            if box is None:
                problems.append(f"{d} 프레임{c}: 빈 프레임")
                continue
            if airborne and c > 0:
                continue
            if box[3] != FRAME_H:
                problems.append(f"{d} 프레임{c}: 발밑이 하단에 닿지 않음 (bottom={box[3]}, 기대 {FRAME_H})")
    return problems
