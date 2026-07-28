"""LPC(Universal LPC Spritesheet) 정적 레이어 PNG 다운로더.

`docs\\art\\ASSET_SOURCES.md` 10-3·10-4·11장 참조.

M2에서는 "LPC 생성기가 인터랙티브 JS 웹앱이라 자동화 불가"로 소싱을 포기했다.
그 우회로가 이 스크립트다 — 생성기를 돌리지 않고 **리포지토리의 레이어별 정적 PNG를
GitHub raw로 직접 내려받아** Pillow로 합성한다(합성은 `gen_player_lpc.py`).

라이선스: OGA-BY 3.0 / CC-BY-SA 3.0 / GPL 3.0 택1 — 본 프로젝트는 **CC-BY-SA 3.0** 선택.
저작자 표기는 `godot\\assets\\CREDITS.md`에 기록한다(B등급 의무).

원본은 `_raw_src\\lpc\\` 아래 리포지토리와 같은 경로 구조로 저장하며 **저장소에 커밋하지 않는다.**

사용법:
    python fetch_lpc_layers.py            # 필요한 레이어만 내려받기 (이미 있으면 건너뜀)
    python fetch_lpc_layers.py --force    # 다시 내려받기
    python fetch_lpc_layers.py --credits  # 저작자·라이선스 확인용 CREDITS.csv도 내려받기
"""

from __future__ import annotations

import argparse
import urllib.error
import urllib.request
from pathlib import Path

RAW_BASE = (
    "https://raw.githubusercontent.com/LiberatedPixelCup/"
    "Universal-LPC-Spritesheet-Character-Generator/master"
)
DEST = Path(__file__).parent / "_raw_src" / "lpc"

# 우리 상태 시트에 필요한 원본 애니메이션 (LPC 이름)
ANIMS = ["idle", "walk", "slash", "thrust", "shoot", "spellcast", "hurt", "jump", "run"]

# 캐릭터 레이어: 위 ANIMS 전부에 대해 같은 파일명이 존재한다
CHARACTER_LAYERS = [
    "body/bodies/male",
    "head/heads/human/male",
    "hair/plain/adult",
    "torso/armour/legion/male",
    "torso/clothes/longsleeve/longsleeve/male",
    "legs/pants/male",
    "feet/boots/basic/male",
]

# 무기·소품 레이어: 경로 규칙이 캐릭터 레이어와 다르다.
#   `<무기>/<동작>/<변형>.png` 이며, `<동작>` 자체가 폴더다.
#   (`weapon/sword/longsword/walk.png` 같은 평평한 경로는 404 — `CREDITS.csv`의 filename 열은
#    변형 파일명을 생략한 표기라 그대로 URL에 쓰면 안 된다. 실측으로 확인한 아래 경로가 정답이다.)
EXTRA_FILES = [
    # 검 (전사). `walk`/`hurt` 는 64x64 셀, `attack_*` 는 **128x128 oversize 셀**.
    # `behind/` = 몸 뒤로 가려지는 부분(몸보다 먼저 합성해야 한다).
    "weapon/sword/longsword/walk/longsword.png",
    "weapon/sword/longsword/hurt/longsword.png",
    "weapon/sword/longsword/attack_slash/longsword.png",
    "weapon/sword/longsword/attack_slash/behind/longsword.png",
    "weapon/sword/longsword/attack_slash_reverse/longsword.png",
    "weapon/sword/longsword/attack_slash_reverse/behind/longsword.png",
    "weapon/sword/longsword/attack_thrust/longsword.png",
    "weapon/sword/longsword/attack_thrust/behind/longsword.png",
    # 활 (궁수) — 손 앞(foreground)/뒤(background) 2레이어
    "weapon/ranged/bow/normal/universal/background/shoot.png",
    "weapon/ranged/bow/normal/universal/background/hurt.png",
    "weapon/ranged/bow/normal/universal/foreground/shoot.png",
    "weapon/ranged/bow/normal/universal/foreground/hurt.png",
    "weapon/ranged/bow/normal/walk/background.png",
    "weapon/ranged/bow/normal/walk/foreground.png",
    "weapon/ranged/bow/arrow/shoot/arrow.png",
    # 화살통 (궁수 실루엣 보강)
    "quiver/walk/quiver.png",
    "quiver/shoot/quiver.png",
    "quiver/hurt/quiver.png",
    "quiver/spellcast/quiver.png",
]


def wanted_files() -> list[str]:
    files = [f"{layer}/{a}.png" for layer in CHARACTER_LAYERS for a in ANIMS]
    return files + EXTRA_FILES


def fetch(rel: str, force: bool) -> str:
    out = DEST / rel
    if out.exists() and not force:
        return "skip"
    out.parent.mkdir(parents=True, exist_ok=True)
    url = f"{RAW_BASE}/spritesheets/{rel}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "sologame-pixel-artist"})
        with urllib.request.urlopen(req, timeout=90) as resp:
            out.write_bytes(resp.read())
        return "ok"
    except urllib.error.HTTPError as exc:
        return f"HTTP {exc.code}"
    except OSError as exc:
        return f"ERR {exc}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--credits", action="store_true", help="CREDITS.csv(약 4MB)도 내려받는다")
    args = ap.parse_args()

    files = wanted_files()
    counts = {"ok": 0, "skip": 0, "fail": 0}
    failures: list[tuple[str, str]] = []
    for rel in files:
        status = fetch(rel, args.force)
        if status == "ok":
            counts["ok"] += 1
        elif status == "skip":
            counts["skip"] += 1
        else:
            counts["fail"] += 1
            failures.append((rel, status))

    if args.credits:
        out = DEST / "CREDITS.csv"
        if args.force or not out.exists():
            req = urllib.request.Request(
                f"{RAW_BASE}/CREDITS.csv", headers={"User-Agent": "sologame-pixel-artist"}
            )
            with urllib.request.urlopen(req, timeout=180) as resp:
                out.write_bytes(resp.read())
            print(f"CREDITS.csv 저장: {out}")

    print(f"대상 {len(files)}개 — 신규 {counts['ok']} / 기존 {counts['skip']} / 실패 {counts['fail']}")
    for rel, status in failures:
        print(f"  [실패] {status}  {rel}")
    print(f"저장 위치: {DEST}  (저장소 커밋 금지)")
    return 1 if counts["fail"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
