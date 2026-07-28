"""CC0/CC-BY 소싱 원본의 **실체(몸) 알파 bbox** 측정 도구.

`docs\\art\\m3-character-art-plan.md` 4-2절 "실체 bbox 측정 규칙"의 실행 도구다.
캔버스 크기(64x64 등)가 아니라 **실제 몸이 차지하는 픽셀 박스**를 재서 축소율 r을 산출하고,
계획서의 경로 분기(3 = 축소+정리 / 4 = 초벌+재작화 / 5 = 전량 재작화)를 판정한다.

    r = min(목표폭 / W0, 목표높이 / H0)
    r >= 0.8       -> 경로 3 (NEAREST 축소 후 수동 정리)
    0.5 <= r < 0.8 -> 경로 4 (축소를 초벌로 쓰고 재작화)
    r < 0.5        -> 경로 5 (전량 재작화, 자세·타이밍만 계승)

**주의 — r만 보면 오판한다.** r 공식은 "원본이 목표보다 크다(축소한다)"를 전제한다.
원본이 목표보다 작거나 두신(頭身) 비율이 다르면 r이 커도 픽셀 편입이 불가능하다.
그래서 본 도구는 r과 함께 **두신 추정치**와 **축소 후 실제 크기**를 항상 같이 출력한다.

사용법:
    python measure_source_bbox.py <png> --cell 64x64 [--target 15x33] [--rows 1,27,52]
    python measure_source_bbox.py <png> --cell 64x64 --grid     # 셀 전수 요약
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

# STYLE_GUIDE 1-2 인간형 실체 규격
DEFAULT_TARGET = (15, 33)


def parse_wh(s: str) -> tuple[int, int]:
    w, h = s.lower().split("x")
    return int(w), int(h)


def cell_bbox(alpha: Image.Image, col: int, row: int, cw: int, ch: int) -> tuple[int, int, int, int] | None:
    return alpha.crop((col * cw, row * ch, col * cw + cw, row * ch + ch)).getbbox()


def width_profile(alpha: Image.Image, col: int, row: int, cw: int, ch: int) -> list[int]:
    """실체 bbox 안에서 위->아래로 각 행의 실체 폭을 재서 목록으로 반환.

    두신(頭身) 비율을 **자동 판정하지 않는다** — 후드·투구·망토가 있으면 머리가 몸통보다
    넓어져 어떤 자동 휴리스틱도 어긋난다(Foozle 원본에서 실제로 오판을 확인했다).
    대신 폭 프로파일을 그대로 보여주고 두신 판단은 사람이 프리뷰를 보고 한다.
    """
    box = cell_bbox(alpha, col, row, cw, ch)
    if box is None:
        return []
    region = alpha.crop((col * cw + box[0], row * ch + box[1], col * cw + box[2], row * ch + box[3]))
    widths: list[int] = []
    for y in range(region.height):
        line = region.crop((0, y, region.width, y + 1)).getbbox()
        widths.append(0 if line is None else line[2] - line[0])
    return widths


def judge(r: float) -> str:
    if r >= 0.8:
        return "경로 3 (NEAREST 축소 + 수동 정리)"
    if r >= 0.5:
        return "경로 4 (축소를 초벌로, 실루엣 위 재작화)"
    return "경로 5 (전량 재작화 — 자세·타이밍만 계승)"


def report_cell(alpha: Image.Image, col: int, row: int, cw: int, ch: int, target: tuple[int, int], label: str) -> None:
    box = cell_bbox(alpha, col, row, cw, ch)
    if box is None:
        print(f"  {label:22s} (빈 셀)")
        return
    w0, h0 = box[2] - box[0], box[3] - box[1]
    r = min(target[0] / w0, target[1] / h0)
    short = ""
    if round(h0 * r) < target[1]:
        short = f"  [!] 높이 {target[1] - round(h0 * r)}px 미달 — 균등 축소로는 목표 비율에 도달 못함"
    print(
        f"  {label:22s} W0xH0={w0:3d}x{h0:3d}  r={r:.3f}  "
        f"축소후={round(w0 * r):2d}x{round(h0 * r):2d}  -> {judge(r)}{short}"
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("png", type=Path)
    ap.add_argument("--cell", default="64x64", help="원본 셀 크기 (예: 64x64)")
    ap.add_argument("--target", default="15x33", help="목표 실체 크기 (기본 15x33 = STYLE_GUIDE 1-2)")
    ap.add_argument("--rows", default="", help="검사할 행 목록 (쉼표 구분). 비우면 0행")
    ap.add_argument("--col", type=int, default=0, help="검사할 열 (기본 0)")
    ap.add_argument("--grid", action="store_true", help="전 행 요약 출력")
    args = ap.parse_args()

    cw, ch = parse_wh(args.cell)
    target = parse_wh(args.target)
    im = Image.open(args.png).convert("RGBA")
    alpha = im.split()[-1]
    cols, rows = im.width // cw, im.height // ch

    print(f"원본: {args.png}")
    print(f"시트 {im.width}x{im.height} = {cols}열 x {rows}행 (셀 {cw}x{ch}) / 목표 실체 {target[0]}x{target[1]}")
    print()

    if args.grid:
        for row in range(rows):
            filled = sum(1 for c in range(cols) if cell_bbox(alpha, c, row, cw, ch))
            if filled:
                report_cell(alpha, 0, row, cw, ch, target, f"row{row:<3d}(frames={filled})")
        return 0

    row_list = [int(x) for x in args.rows.split(",") if x.strip()] or [0]
    for row in row_list:
        report_cell(alpha, args.col, row, cw, ch, target, f"row{row}")
        prof = width_profile(alpha, args.col, row, cw, ch)
        if prof:
            print(f"    폭 프로파일(위->아래): {','.join(str(v) for v in prof)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
