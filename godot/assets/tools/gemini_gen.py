"""Gemini 이미지 생성 → EDG32 양자화 파이프라인 (pixel-artist 도구).

Gemini 이미지 생성 API로 원화를 뽑고, 프로젝트 규격(EDG32 32색)으로
후처리해 저장한다. 애니메이션 스프라이트시트에는 부적합 — 초상화/타일
텍스처/배경/아이콘 원화 등 정지 이미지 용도로만 쓸 것 (프레임 간 일관성 없음).

사용법:
    python gemini_gen.py "<프롬프트>" <출력.png> [--size WxH] [--model 모델명] [--raw]

    --size 32x32   생성 원본을 이 크기로 축소(BOX) 후 양자화 (생략 시 원본 크기 유지)
    --model        기본 gemini-3.1-flash-image
    --raw          양자화 생략, 생성 원본만 저장 (컨셉 확인용)

요구 사항:
    - 환경변수 GEMINI_API_KEY (키를 저장소에 커밋하지 말 것)
    - Google 계정에 결제(billing) 활성화 — 무료 티어는 이미지 모델 쿼터 0
    - 생성 원본은 <출력이름>_raw.png로 함께 저장됨 (재양자화용)
    - 저장 후 validate_palette.py로 검증할 것
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import os
import sys
import urllib.request
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from edg32_palette import RGB

API_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
DEFAULT_MODEL = "gemini-3.1-flash-image"

# 프롬프트 앞에 항상 붙는 스타일 지시 (STYLE_GUIDE.md 요약)
STYLE_PREFIX = (
    "16-bit retro pixel art for a 2D fantasy RPG, limited 32-color palette, "
    "flat colors with no gradients or anti-aliasing, dark outline, "
    "top-left light source. "
)


def generate(prompt: str, model: str) -> Image.Image:
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise SystemExit("환경변수 GEMINI_API_KEY가 없습니다.")
    body = json.dumps(
        {"contents": [{"parts": [{"text": STYLE_PREFIX + prompt}]}]}
    ).encode("utf-8")
    req = urllib.request.Request(
        API_URL.format(model=model),
        data=body,
        headers={"x-goog-api-key": api_key, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = json.load(resp)
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")[:400]
        raise SystemExit(f"API 오류 {e.code}: {detail}")

    for part in data["candidates"][0]["content"]["parts"]:
        if "inlineData" in part:
            return Image.open(io.BytesIO(base64.b64decode(part["inlineData"]["data"])))
    raise SystemExit(f"응답에 이미지가 없습니다: {json.dumps(data)[:400]}")


def quantize_to_edg32(img: Image.Image) -> Image.Image:
    """모든 불투명 픽셀을 EDG32 최근접 색으로 매핑 (디더링 없음)."""
    pal_img = Image.new("P", (1, 1))
    flat: list[int] = []
    for rgb in RGB.values():
        flat.extend(rgb)
    pal_img.putpalette(flat + [0, 0, 0] * (256 - len(RGB)))

    rgba = img.convert("RGBA")
    alpha = rgba.getchannel("A")
    mapped = rgba.convert("RGB").quantize(palette=pal_img, dither=Image.NONE).convert("RGB")
    mapped.putalpha(alpha.point(lambda a: 0 if a < 128 else 255))
    return mapped


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("prompt")
    parser.add_argument("output", type=Path)
    parser.add_argument("--size", help="WxH, 예: 32x32")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--raw", action="store_true", help="양자화 생략")
    args = parser.parse_args()

    img = generate(args.prompt, args.model)
    raw_path = args.output.with_name(args.output.stem + "_raw.png")
    img.save(raw_path)
    print(f"생성 원본 저장: {raw_path} ({img.size[0]}x{img.size[1]})")

    if args.raw:
        return 0

    if args.size:
        w, h = (int(v) for v in args.size.lower().split("x"))
        img = img.resize((w, h), Image.BOX)
    img = quantize_to_edg32(img)
    img.save(args.output)
    print(f"양자화 저장: {args.output} ({img.size[0]}x{img.size[1]}) — validate_palette.py로 검증하세요.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
