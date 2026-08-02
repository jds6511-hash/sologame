"""프레임 클리핑 검증 스크립트 (STYLE_GUIDE.md 7장 5-1 클리핑 게이트).

**왜 이 검사가 존재하는가 (재발 방지 기록)**:
2026-07-30 검수에서 인간형 캔버스 20x36 규격이 실체(17~19px)에 동작 여백을 전혀 주지
않았다는 사실이 드러났다 — 237프레임 중 144프레임이 프레임 경계에 **아웃라인 없는 잘린
단면**을 갖고 있었고, `walk` 는 전 프레임에서 주먹이 잘려 있었다. 그런데도 기존 검증
(`validate_palette.py` = 팔레트 + 캔버스 크기)은 전부 통과했다. **캔버스 크기만 보고
내용이 잘렸는지는 보지 않았기 때문이다.** 이 스크립트가 그 빈칸을 메운다.

판정 규칙:
    프레임 경계(첫/마지막 행·열)에 **불투명하면서 아웃라인색(#181425)이 아닌 픽셀**이
    있으면 클리핑 위반이다. 실루엣이 경계에 닿는 것 자체는 정상이지만(발밑은 항상 닿는다),
    그 자리는 `STYLE_GUIDE` 3-1 의 1px 아웃라인이어야 한다. 살색·금속색 단면이 노출돼
    있다면 그 부위(주먹·칼날·발끝)가 캔버스 밖에서 잘려 나갔다는 뜻이다.

처방 순서는 `STYLE_GUIDE` 1-2-3 원칙 4 그대로다 —
    (1) 자세 재작화(스윙 호를 프레임 안으로) -> (2) 실체 목표 하향 -> (3) 캔버스 조정(상한 내).
캔버스 확대를 1순위 처방으로 쓰지 않는다.

사용법:
    python validate_clipping.py                          # 기본 대상(플레이어·몬스터 시트) 전체
    python validate_clipping.py <file_or_glob> [...]      # 지정 파일만 (규격은 파일명으로 추론)
    python validate_clipping.py --frame 28x36 <file> ...  # 프레임 규격을 직접 지정

종료 코드: 0 = 위반 0건, 1 = 위반 발견.
"""

from __future__ import annotations

import glob
import sys
from pathlib import Path

from PIL import Image

TOOLS_DIR = Path(__file__).parent
ASSETS_DIR = TOOLS_DIR.parent
OUTLINE = (0x18, 0x14, 0x25)  # STYLE_GUIDE 3-1 아웃라인 표준색

# 파일명 접두사 -> 프레임 규격 (STYLE_GUIDE 1-2). 새 액터를 추가하면 여기에 1행 등록한다.
# **긴 접두사가 먼저 매칭된다**(`frame_spec`) — 예외 규격을 일반 규격보다 앞세우기 위해서다.
PREFIX_FRAME: dict[str, tuple[int, int]] = {
    "player_": (28, 36),  # 인간형 (2026-07-30 개정: 구 20x36)
    # M2 구 전사(절차 생성물). 폐기 판정된 20x36 규격이지만 회귀 안전장치로 보존 중이라
    # 검사에서 제외하지 않고 **당시 규격 그대로** 검사한다.
    "player_warrior_v2_": (28, 36),
    "player_warrior_": (20, 36),
    "mob_outlaw_": (28, 36),  # 인간형 적 — 플레이어와 동일 캔버스
    "mob_spider_": (28, 24),
    "mob_imp_": (24, 28),
    "mob_rabbit_": (20, 20),
    "mob_wolf_": (36, 28),
    "mob_slime_": (36, 36),
}

DEFAULT_TARGETS = [
    str(ASSETS_DIR / "sprites" / "player" / "*.png"),
    str(ASSETS_DIR / "sprites" / "monsters" / "*.png"),
]


def frame_spec(path: Path) -> tuple[int, int] | None:
    for prefix in sorted(PREFIX_FRAME, key=len, reverse=True):
        if path.name.startswith(prefix):
            return PREFIX_FRAME[prefix]
    return None


def check_sheet(img: Image.Image, fw: int, fh: int) -> list[str]:
    """시트를 프레임 격자로 나눠 각 프레임 경계의 잘린 단면을 찾는다."""
    rgba = img.convert("RGBA")
    problems: list[str] = []
    if rgba.width % fw or rgba.height % fh:
        return [f"시트 크기 {rgba.size} 가 프레임 {fw}x{fh} 의 정수배가 아님"]

    px = rgba.load()
    for row in range(rgba.height // fh):
        for col in range(rgba.width // fw):
            ox, oy = col * fw, row * fh
            cut: dict[str, int] = {}
            for x in range(fw):
                for y in (0, fh - 1):
                    r, g, b, a = px[ox + x, oy + y]
                    if a and (r, g, b) != OUTLINE:
                        cut["상" if y == 0 else "하"] = cut.get("상" if y == 0 else "하", 0) + 1
            for y in range(fh):
                for x in (0, fw - 1):
                    r, g, b, a = px[ox + x, oy + y]
                    if a and (r, g, b) != OUTLINE:
                        cut["좌" if x == 0 else "우"] = cut.get("좌" if x == 0 else "우", 0) + 1
            if cut:
                detail = " ".join(f"{k}{v}px" for k, v in cut.items())
                problems.append(f"행{row} 열{col}: 아웃라인 없는 잘린 단면 — {detail}")
    return problems


def main(argv: list[str]) -> int:
    args = argv[1:]
    forced: tuple[int, int] | None = None
    if args and args[0] == "--frame":
        w, h = args[1].lower().split("x")
        forced = (int(w), int(h))
        args = args[2:]

    files: list[Path] = []
    for pattern in args or DEFAULT_TARGETS:
        files.extend(Path(p) for p in glob.glob(pattern))
    # 프리뷰 시트(_preview_*)는 검수용 산출물이라 대상에서 제외
    files = [f for f in files if not f.name.startswith("_")]
    if not files:
        print("검사 대상 파일이 없습니다.")
        return 1

    checked = skipped = fail_files = total_frames = 0
    for path in sorted(files):
        spec = forced or frame_spec(path)
        if spec is None:
            print(f"[SKIP] {path.name} — 프레임 규격 미등록(PREFIX_FRAME 참조)")
            skipped += 1
            continue
        img = Image.open(path)
        problems = check_sheet(img, *spec)
        checked += 1
        total_frames += (img.width // spec[0]) * (img.height // spec[1])
        if problems:
            fail_files += 1
            print(f"[FAIL] {path.name} ({spec[0]}x{spec[1]})")
            for p in problems[:12]:
                print(f"  - {p}")
            if len(problems) > 12:
                print(f"  - ... 외 {len(problems) - 12}건")
        else:
            print(f"[PASS] {path.name} ({spec[0]}x{spec[1]})")

    print()
    if fail_files:
        print(f"클리핑 검증 실패: {fail_files}/{checked}개 파일에서 잘린 단면 발견.")
        return 1
    print(f"클리핑 위반 0건: {checked}개 파일 / {total_frames}프레임 통과 (건너뜀 {skipped}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
