"""팔레트/규격 검증 스크립트 (STYLE_GUIDE.md 2-2·7-5장).

기능:
1. 팔레트 검증: 지정한 PNG들의 모든 불투명 픽셀이 EDG32 32색 중 하나인지 확인.
   32색 외 색이 섞이면(안티앨리어싱 등) 파일명·위반 픽셀 수·발견된 이색(異色) 목록을 보고한다.
2. 아이콘 규격 검증: 16x16 원본인지 확인 (아이콘 파일 대상).

사용법:
    python validate_palette.py                       # 기본 대상(타일셋+아이콘) 전체 검사
    python validate_palette.py <file_or_glob> [...]   # 지정 파일만 검사

종료 코드: 0 = 전부 통과, 1 = 위반 발견.
"""

from __future__ import annotations

import sys
import glob
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from edg32_palette import ALLOWED_RGB_SET

TOOLS_DIR = Path(__file__).parent
ASSETS_DIR = TOOLS_DIR.parent

DEFAULT_TARGETS = [
    str(ASSETS_DIR / "tiles" / "*.png"),
    str(ASSETS_DIR / "icons" / "skills" / "*.png"),
    str(ASSETS_DIR / "icons" / "items" / "*.png"),
]

ICON_DIRS = {str(ASSETS_DIR / "icons" / "skills"), str(ASSETS_DIR / "icons" / "items")}


def check_palette(img: Image.Image) -> dict[tuple[int, int, int], int]:
    """불투명 픽셀 중 EDG32에 없는 색과 그 개수를 반환."""
    rgba = img.convert("RGBA")
    violations: dict[tuple[int, int, int], int] = {}
    for pixel in rgba.getdata():
        r, g, b, a = pixel
        if a == 0:
            continue  # 완전 투명은 검사 제외
        rgb = (r, g, b)
        if rgb not in ALLOWED_RGB_SET:
            violations[rgb] = violations.get(rgb, 0) + 1
    return violations


def check_icon_size(path: Path, img: Image.Image) -> str | None:
    if str(path.parent) in ICON_DIRS:
        if img.size != (16, 16):
            return f"아이콘 규격 위반: {img.size} (기대값 16x16)"
    return None


def main(argv: list[str]) -> int:
    targets = argv[1:] if len(argv) > 1 else DEFAULT_TARGETS
    files: list[Path] = []
    for pattern in targets:
        files.extend(Path(p) for p in glob.glob(pattern))
    # 프리뷰 시트(_preview_4x.png 등)는 검수용 산출물이라 규격 검증 대상에서 제외
    files = [f for f in files if not f.name.startswith("_")]

    if not files:
        print("검사 대상 파일이 없습니다.")
        return 1

    total_violation_files = 0
    for path in sorted(files):
        img = Image.open(path)
        violations = check_palette(img)
        size_error = check_icon_size(path, img)

        ok = not violations and not size_error
        status = "PASS" if ok else "FAIL"
        print(f"[{status}] {path}")

        if violations:
            total_pixels = sum(violations.values())
            print(f"  - 팔레트 위반 픽셀 수: {total_pixels}")
            for rgb, count in sorted(violations.items(), key=lambda kv: -kv[1])[:10]:
                print(f"    · RGB{rgb} x {count}")
            total_violation_files += 1
        if size_error:
            print(f"  - {size_error}")
            total_violation_files += 1

    print()
    if total_violation_files == 0:
        print(f"전체 통과: {len(files)}개 파일, 32색 외 색 0픽셀 확인.")
        return 0
    else:
        print(f"검증 실패: {total_violation_files}개 파일에서 위반 발견.")
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
