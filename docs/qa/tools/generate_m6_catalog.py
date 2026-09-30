"""경제 정본의 C급 전 티어 공급 후보. 기존 리소스는 읽기만 한다."""
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ITEMS = ROOT / "godot/data/items"
OUTPUT = ROOT / "godot/data/economy/m6_catalog.json"


def number(value):
    return math.floor(value + 0.5)


def main():
    existing = {}
    families = {}
    for path in sorted(ITEMS.glob("*.tres")):
        text = path.read_text(encoding="utf-8-sig")
        match = re.search(r'^item_id = "(.*)"', text, re.M)
        if not match:
            continue
        key = match[1]
        existing[key] = "res://data/items/" + path.name
        if key.startswith("WPN-"):
            families[key] = {"SW": "sword", "GS": "greatsword", "BW": "bow"}[key.split("-")[1]]
    definitions = []
    prices = {}
    supply = {}
    slots = [
        ("WPN-SW", "소검", 0, 1, 1, 1, 60, "sword"),
        ("WPN-GS", "대검", 0, 1, 1, 1, 60, "greatsword"),
        ("WPN-BW", "활", 0, 1, 1, 1, 60, "bow"),
        ("ARM-BODY", "갑옷", 1, 2, 2, .4, 40, ""),
        ("ARM-LEG", "하의", 1, 3, 2, .25, 25, ""),
        ("ARM-HEAD", "모자", 1, 4, 2, .2, 20, ""),
        ("ARM-FOOT", "신발", 1, 5, 2, .15, 15, ""),
        ("ACC-RING", "반지", 2, 6, 3, 3.7, 25, ""),
        ("ACC-NECK", "목걸이", 2, 7, 4, 10, 25, ""),
    ]
    for tier in [1] + list(range(10, 101, 10)):
        supply[str(tier)] = {}
        for prefix, name, kind, slot, stat, factor, kills, family in slots:
            key = f"{prefix}-{tier:02d}-C"
            value = (8 + 1.6 * tier) if kind == 0 else (5 + 1.5 * tier) * factor
            value = number(value * .85)
            if kind == 2:
                value = number(factor * tier / 100 * .85 / 1.32 * 100) / 100
            if key not in existing:
                definitions.append(dict(item_id=key, item_name=f"기본 {name} {tier}", item_type=kind,
                                        grade=0, level_limit=tier, equip_slot=slot,
                                        main_stat_type=stat, main_stat_value=value,
                                        move_speed_bonus=2 if slot == 5 else 0))
            if family:
                families[key] = family
            price = kills * number(2 * tier ** 1.5)
            prices[key] = dict(buy=price, sell=price // 10, offered=tier <= 10,
                               source="economy-foundation §6-2 C급 정가/§6-4 판매10%")
            supply[str(tier)][prefix] = key
    for key, sell in [("MAT-RABBIT-FOOT", 4), ("MAT-DOG-FANG", 32), ("MAT-SLIME-CORE", 90)]:
        prices[key] = dict(buy=0, sell=sell, offered=False, source="economy-foundation §2-9 재료 판매가")
    prices["POT-HP-1"] = dict(buy=300, sell=30, offered=True, source="economy-foundation §5 포션")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(dict(existing=existing, definitions=definitions, families=families,
                                     prices=prices, supply=supply), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"M6_CATALOG: new={len(definitions)} supply={len(slots)*11}")


if __name__ == "__main__":
    main()
