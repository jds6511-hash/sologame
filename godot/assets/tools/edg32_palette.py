"""EDG32 (Endesga 32) 공용 팔레트 정의.

`docs\\art\\STYLE_GUIDE.md` 2장의 마스터 팔레트(32색)를 그대로 코드로 옮긴 단일 소스.
타일셋/아이콘 생성 스크립트와 팔레트 검증 스크립트가 모두 이 모듈을 임포트해서 쓴다.
색을 추가/변경하려면 STYLE_GUIDE.md 개정 후 이 파일도 함께 갱신할 것.
"""

# 이름 -> HEX (STYLE_GUIDE.md 2장 표 순서 그대로)
EDG32 = {
    "brick_red": "#be4a2f",
    "orange_brown": "#d77643",
    "sand_cream": "#ead4aa",
    "apricot": "#e4a672",
    "ochre": "#b86f50",
    "red_brown_dark": "#733e39",
    "dark_maroon": "#3e2731",
    "blood_red": "#a22633",
    "scarlet": "#e43b44",
    "flame_orange": "#f77622",
    "gold": "#feae34",
    "bright_yellow": "#fee761",
    "fresh_green": "#63c74d",
    "green": "#3e8948",
    "deep_green": "#265c42",
    "black_green": "#193c3e",
    "navy": "#124e89",
    "blue": "#0099db",
    "cyan": "#2ce8f5",
    "white": "#ffffff",
    "light_blue_gray": "#c0cbdc",
    "blue_gray": "#8b9bb4",
    "dark_blue_gray": "#5a6988",
    "navy_gray": "#3a4466",
    "dark_navy": "#262b44",
    "darkest": "#181425",
    "warning_red": "#ff0044",
    "dark_purple": "#68386c",
    "purple": "#b55088",
    "pink": "#f6757a",
    "light_apricot": "#e8b796",
    "tan": "#c28569",
}

assert len(EDG32) == 32, f"EDG32는 32색이어야 함 (현재 {len(EDG32)}색)"


def hex_to_rgb(hex_str: str) -> tuple[int, int, int]:
    h = hex_str.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


# 자주 쓰는 색은 RGB 튜플로도 접근 가능하게 노출
RGB = {name: hex_to_rgb(h) for name, h in EDG32.items()}

# 검증 스크립트용: 허용된 RGB 색 집합 (알파 채널 무시, 완전 투명 픽셀은 별도 취급)
ALLOWED_RGB_SET = set(RGB.values())

# 스타일 가이드 3-1장 고정 아웃라인 색
OUTLINE_RGB = RGB["darkest"]

# 4장 동부 변경 서브 팔레트 (주조색 5 + 포인트색 1)
EASTERN_FRONTIER_SUBPALETTE = [
    "ochre",
    "tan",
    "red_brown_dark",
    "apricot",
    "fresh_green",
]
EASTERN_FRONTIER_POINT = "bright_yellow"
