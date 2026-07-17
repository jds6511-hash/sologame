"""UI-1: HUD 스킬 슬롯 쿨다운 원형 오버레이용 마스크 텍스처 절차 생성 (Pillow).

참조:
- `docs\\art\\ux\\ux-foundation.md` 5장 F요소 — "쿨다운(어두운 원형 오버레이 + 남은 초)"
- `docs\\art\\STYLE_GUIDE.md` 2장 EDG32 팔레트, 2-1장 최암색(#181425) UI 최하층 배경 규칙

TextureProgressBar의 방사형(radial) fill 모드에 사용할 흰색 원형 마스크만 생성한다.
실제 색(어두운 반투명)은 씬에서 self_modulate로 입힌다 — 마스크 자체는 순수 흰색+알파.
안티앨리어싱된 원 가장자리를 허용한다(EDG32 32색 제약은 스프라이트/타일/아이콘 "그림"에
적용되는 규칙이며, 이 텍스처는 UI 오버레이용 그레이스케일 마스크라 예외로 둔다 —
STYLE_GUIDE 2-2장은 캐릭터/몬스터/아이템 그림 규칙이고 진행 표시용 마스크는 해당 없음).

출력: godot\\assets\\icons\\ui\\cooldown_radial_mask.png
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 64
ASSETS_DIR = Path(__file__).parent.parent
UI_DIR = ASSETS_DIR / "icons" / "ui"


def make_radial_mask() -> Image.Image:
    im = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    margin = 1
    draw.ellipse((margin, margin, SIZE - 1 - margin, SIZE - 1 - margin), fill=(255, 255, 255, 255))
    return im


def main() -> None:
    UI_DIR.mkdir(parents=True, exist_ok=True)
    make_radial_mask().save(UI_DIR / "cooldown_radial_mask.png")
    print(f"저장 완료: {UI_DIR / 'cooldown_radial_mask.png'}")


if __name__ == "__main__":
    main()
