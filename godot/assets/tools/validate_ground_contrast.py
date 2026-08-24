"""대면적 지면 대비 검증 스크립트 (STYLE_GUIDE.md 3-2-3장 · 7장 5-2 게이트).

**왜 이 검사가 존재하는가 (재발 방지 기록)**:
2026-08-20 중간 검수에서 지형 타일이 3~4색을 명도 100 범위에 벌려 하드 스텝을 만들고
있다는 사실이 드러났다 — 대면적 지면 9종의 면적가중 명도 표준편차가 22.4~32.6 으로
레퍼런스 지면(2~5 대역)의 5~15배였다. 대면적 지면은 시야 대부분을 채우므로 이 대비가
그대로 눈 피로가 된다. 기존 검증(`validate_palette.py` = 32색 준수, `validate_clipping.py`
= 잘린 단면)은 **색이 팔레트 안에 있는지만 보고 그 색들이 얼마나 벌어져 있는지는 보지
않았기 때문에** 전부 통과했다. 이 스크립트가 그 빈칸을 메운다.

판정 규칙 (STYLE_GUIDE 7장 5-2, 하드 실패 4종):
    (1) 면적가중 명도 표준편차 σ_L > 10  (예외·완화 없음)
        σ_L = √( Σ pᵢ (Lᵢ − L̄)² ),  L = Rec.601 luma,  pᵢ = 불투명 픽셀 면적비
        예산식 `Σ p·Δ² ≤ 100` 과 동치이므로 예산 합계도 함께 출력한다.
    (2) 단일 색의 Δ 절대값 > 40  (하드 상한. 정수 배율 스크롤 시 반짝임)
        예외 = grass_flower 의 꽃 `#f6757a` 가 면적 **0.8% 이하**일 때만
    (3) 대면적 지면에 `#ffffff` 가 1픽셀이라도 사용됨
    (4) **초원 2종의 허용 색 목록 위반** (2026-08-24 신설) — grass_base·grass_flower 에
        `#3e8948`·`#265c42`(+꽃 `#f6757a`) 외의 색이 1픽셀이라도 있으면 실패.
        신설 근거: 이 두 타일의 결함은 **σ_L 로 검출되지 않는다.** 등명도 교차 색조
        배합(`#5a6988` 30% + `#be4a2f` 10%)은 σ_L 1.35 로 10종 최우수였으면서도
        초원이 초록으로 읽히지 않는 반점밭이었다 — 지표는 명도만 보고 색조는 보지
        않기 때문이다. **색조 회귀는 색 목록으로만 잡힌다**(3-2-3-4 D).

명도 폭 span 은 **게이트가 아니다** — 1픽셀로 값이 결정돼 회귀 검출에 쓸 수 없으므로
측정해서 병기 기록만 한다(3-2-3-1절).

**프롭·구조물 7종은 이 게이트의 대상이 아니다** — 대비 유지가 규정이다(3-2-3-6절).
검사 대상은 3-2-3-6절이 정의한 대면적 지면 **9종**이며, 타일 키는 타일셋 매니페스트
(`<시트명>.json`)에서 읽는다.

**river_water 는 2026-08-24 정정으로 게이트 대상에서 빠졌다**(3-2-3-6 예외 1 — 좁은 띠라
정의에 들지 않고 EDG32 청색 계열로는 상한 달성이 불가능하다). σ_L·span·색 구성은
**계속 측정·출력**하되 판정과 종료 코드에서 제외한다 — 회귀 추적용이며 수치가 상한을
넘어도 실패가 아니다.

부가 측정(게이트 아님): 2x2 체커 패턴 비율. 3-2 표가 대면적 지면의 규칙적 체커를
금지한 근거(정수 배율 스크롤 시 패턴 크롤링)를 수치로 추적하기 위한 참고값이다.

사용법:
    python validate_ground_contrast.py                     # 기본 대상(동부 변경 타일셋)
    python validate_ground_contrast.py <sheet.png> [...]   # 지정 시트만 (같은 이름 .json 필요)

종료 코드: 0 = 전부 통과, 1 = 위반 발견.
"""

from __future__ import annotations

import glob
import json
import sys
from pathlib import Path

from PIL import Image

TOOLS_DIR = Path(__file__).parent
ASSETS_DIR = TOOLS_DIR.parent

DEFAULT_TARGETS = [str(ASSETS_DIR / "tiles" / "eastern_frontier_tileset.png")]

# STYLE_GUIDE 3-2-3-6: 적용 대상 = 지형 레이어에 4타일 이상 연속으로 깔릴 수 있는 타일.
# 키 -> σ_L 상한. 신규 타일이 이 정의에 들면 여기에 1행 등록한다.
SIGMA_LIMIT = 10.0
GROUND_TILES: tuple[str, ...] = (
    "grass_base",
    "grass_flower",
    "dirt_path",
    "dirt_pebble",
    "tilled_soil",
    "cracked_ground",
    "riverbank_sand",
    "stone_floor",
    "wood_plank",
)

# 측정만 하고 판정하지 않는 타일(3-2-3-6 예외 1). 프롭 취급이라 상한이 없다.
MEASURE_ONLY: tuple[str, ...] = ("river_water",)

DELTA_HARD_CAP = 40.0
WHITE = (0xFF, 0xFF, 0xFF)

GREEN = (0x3E, 0x89, 0x48)
DEEP_GREEN = (0x26, 0x5C, 0x42)
FLOWER_PINK = (0xF6, 0x75, 0x7A)

# 3-2-3-4 (D) 단색조 처방 대상의 허용 색 목록. 지정 색 외 1픽셀도 실패다.
# 대상 확대·축소는 art-director 소관이므로 여기서 임의로 늘리지 않는다.
MONOCHROME_ALLOWED: dict[str, set[tuple[int, int, int]]] = {
    "grass_base": {GREEN, DEEP_GREEN},
    "grass_flower": {GREEN, DEEP_GREEN, FLOWER_PINK},
}

# 3-2-3-5 비고: 꽃은 지면 질감이 아니라 지면 위 미세 프롭이므로 Δ 하드 상한의 예외.
# **면적 0.8% 캡이 반짝임을 막는 유일한 조건**이라 캡을 넘으면 예외가 소멸한다
# (2026-08-24 정정: (D) 배합 위에서는 1.5% 를 쓰면 σ_L 이 상한을 넘는다).
DELTA_EXEMPT = {("grass_flower", FLOWER_PINK): 0.8}


def luma(rgb: tuple[int, int, int]) -> float:
    """Rec.601 luma (0~255). sRGB 8bit 값 그대로 — STYLE_GUIDE 3-2-3-1 정의."""
    r, g, b = rgb
    return 0.299 * r + 0.587 * g + 0.114 * b


def histogram(img: Image.Image, ox: int, oy: int, size: int) -> dict[tuple[int, int, int], int]:
    """타일 1장의 불투명 픽셀 색 분포(알파 0 제외 — 3-2-3-1 측정 모집단)."""
    px = img.load()
    hist: dict[tuple[int, int, int], int] = {}
    for y in range(oy, oy + size):
        for x in range(ox, ox + size):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            hist[(r, g, b)] = hist.get((r, g, b), 0) + 1
    return hist


def measure(hist: dict[tuple[int, int, int], int]) -> dict:
    total = sum(hist.values())
    entries = [(rgb, n, n / total, luma(rgb)) for rgb, n in hist.items()]
    mean = sum(p * lum for _, _, p, lum in entries)
    budget = sum(p * (lum - mean) ** 2 for _, _, p, lum in entries)
    lumas = [lum for _, _, _, lum in entries]
    return {
        "total": total,
        "mean": mean,
        "sigma": budget**0.5,
        "budget": budget,
        "span": max(lumas) - min(lumas),
        "colors": sorted(entries, key=lambda e: -e[1]),
    }


def checker_rate(img: Image.Image) -> tuple[int, int]:
    """시트 전역 2x2 슬라이딩 윈도로 체커 패턴(대각 동색 + 인접 이색) 수를 센다.

    창의 4픽셀 중 투명이 하나라도 있으면 모집단에서 제외한다(프롭 여백 배제).
    반환값 = (체커 창 수, 유효 창 수).
    """
    px = img.load()
    hit = total = 0
    for y in range(img.height - 1):
        for x in range(img.width - 1):
            a, b, c, d = px[x, y], px[x + 1, y], px[x, y + 1], px[x + 1, y + 1]
            if 0 in (a[3], b[3], c[3], d[3]):
                continue
            total += 1
            if a[:3] == d[:3] and b[:3] == c[:3] and a[:3] != b[:3]:
                hit += 1
    return hit, total


def hex_of(rgb: tuple[int, int, int]) -> str:
    return "#{:02x}{:02x}{:02x}".format(*rgb)


def check_tile(key: str, hist: dict[tuple[int, int, int], int]) -> tuple[dict, list[str]]:
    """측정값과 위반 목록을 반환. `MEASURE_ONLY` 타일은 위반 목록이 항상 비어 있다."""
    m = measure(hist)
    if key in MEASURE_ONLY:
        return m, []

    problems: list[str] = []

    if m["sigma"] > SIGMA_LIMIT:
        problems.append(
            f"σ_L {m['sigma']:.2f} > 상한 {SIGMA_LIMIT:.0f} (예산 Σp·Δ² {m['budget']:.1f})"
        )

    allowed = MONOCHROME_ALLOWED.get(key)
    if allowed is not None:
        for rgb, n, p, _lum in m["colors"]:
            if rgb not in allowed:
                problems.append(
                    f"단색조 처방 허용 색 목록 위반: {hex_of(rgb)} {n}px ({p * 100:.2f}%)"
                    f" — 허용 = {', '.join(sorted(hex_of(c) for c in allowed))}"
                )

    for rgb, n, p, lum in m["colors"]:
        delta = lum - m["mean"]
        if abs(delta) <= DELTA_HARD_CAP:
            continue
        cap = DELTA_EXEMPT.get((key, rgb))
        if cap is not None and p * 100 <= cap:
            continue
        note = f" (예외 조건 면적 {cap}% 초과)" if cap is not None else ""
        problems.append(f"Δ 하드 상한 위반: {hex_of(rgb)} Δ{delta:+.1f} 면적 {p * 100:.2f}%{note}")

    if WHITE in hist:
        problems.append(f"대면적 지면에 #ffffff 사용: {hist[WHITE]}px")

    return m, problems


def check_sheet(path: Path) -> tuple[int, int, list[str]]:
    """시트 1장을 검사해 (검사한 타일 수, 실패 타일 수, 요약행 목록)을 반환."""
    manifest_path = path.with_suffix(".json")
    if not manifest_path.exists():
        print(f"[SKIP] {path.name} — 매니페스트 {manifest_path.name} 없음(타일 키를 알 수 없다)")
        return 0, 0, []

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    size = manifest["tile_size"]
    img = Image.open(path).convert("RGBA")

    checked = failed = 0
    lines: list[str] = []
    for entry in manifest["tiles"]:
        key = entry["key"]
        if key not in GROUND_TILES and key not in MEASURE_ONLY:
            continue  # 프롭·구조물은 게이트 대상이 아니다 (3-2-3-6)
        hist = histogram(img, entry["col"] * size, entry["row"] * size, size)
        if not hist:
            print(f"[SKIP] {key} — 불투명 픽셀 없음")
            continue
        m, problems = check_tile(key, hist)
        if key in MEASURE_ONLY:
            status, limit_txt = "측정", "게이트 아님"
        else:
            checked += 1
            status = "FAIL" if problems else "PASS"
            if problems:
                failed += 1
            limit_txt = f"상한 {SIGMA_LIMIT:>4.1f}"
        print(
            f"[{status}] {key:<16} σ_L {m['sigma']:>5.2f} ({limit_txt})"
            f"  span {m['span']:>6.1f}  Σp·Δ² {m['budget']:>6.1f}  L̄ {m['mean']:>6.1f}"
        )
        for rgb, n, p, lum in m["colors"]:
            print(
                f"       · {hex_of(rgb)}  면적 {p * 100:>5.1f}% ({n:>3d}px)"
                f"  L {lum:>6.1f}  Δ{lum - m['mean']:>+7.1f}  p·Δ² {p * (lum - m['mean']) ** 2:>6.1f}"
            )
        for problem in problems:
            print(f"       ! {problem}")
        lines.append(f"{key:<16} σ_L {m['sigma']:>5.2f}  span {m['span']:>6.1f}")

    hit, total = checker_rate(img)
    rate = hit / total * 100 if total else 0.0
    print(f"       [참고] 시트 전역 2x2 체커율 {rate:.2f}% ({hit}/{total} 창) — 게이트 아님")
    return checked, failed, lines


def main(argv: list[str]) -> int:
    files: list[Path] = []
    for pattern in argv[1:] or DEFAULT_TARGETS:
        files.extend(Path(p) for p in glob.glob(pattern))
    # 프리뷰 시트(_preview_*, *_4x)는 검수용 산출물이라 대상에서 제외
    files = [f for f in files if not f.name.startswith("_") and not f.stem.endswith("_4x")]
    if not files:
        print("검사 대상 파일이 없습니다.")
        return 1

    checked = failed = 0
    for path in sorted(files):
        print(f"=== {path.name} ===")
        c, f, _ = check_sheet(path)
        checked += c
        failed += f
        print()

    if checked == 0:
        print("대면적 지면 타일을 찾지 못했습니다(매니페스트 키 확인).")
        return 1
    if failed:
        print(f"지면 대비 검증 실패: {failed}/{checked}개 타일이 게이트를 넘지 못했습니다.")
        return 1
    print(f"지면 대비 게이트 통과: 대면적 지면 {checked}종 전부 σ_L 상한 이내.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
