"""제품 JSON의 낮/C1 목표 처치 산술과 정식 A/B 민감도 손실을 재현한다.

실제 플레이·의뢰 건수 20% 생략·경로별 레벨차 재시뮬레이션이 아니다.
제품 데이터는 읽기만 한다. 출력: python docs/qa/tools/calc_act_two_growth.py
"""

import json
import math
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[3]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")


def half_up(value):
    return math.floor(value + 0.5)


def scalar(text, key):
    return float(re.search(rf"^{key} = ([\d.e+-]+)$", text, re.M)[1])


curve = read("godot/data/progression/level_curve.tres")
diff = read("godot/data/progression/level_diff_curve.tres")
down = [
    struct.unpack("f", struct.pack("f", float(value)))[0]
    for value in re.search(r"down_mults = PackedFloat32Array\((.*?)\)", diff)[1].split(",")
]


def req(level):
    multiplier = (
        scalar(curve, "pre_transition_req_multiplier")
        if level < scalar(curve, "first_transition_level") else 1.0
    )
    start = scalar(curve, "c1_blend_start_level")
    end = scalar(curve, "c1_blend_end_level")
    if scalar(curve, "profile") == 1 and level > start:
        multiplier *= scalar(curve, "c1_multiplier") ** min(1.0, (level - start) / (end - start))
    return half_up(scalar(curve, "req_coefficient") * level ** scalar(curve, "req_exponent") * multiplier)


THRESHOLDS = [0]
for level in range(1, 100):
    THRESHOLDS.append(THRESHOLDS[-1] + req(level))


def reached(total):
    return sum(total >= threshold for threshold in THRESHOLDS)


def kill_exp(mob_level, total):
    delta = mob_level - reached(total)
    if delta >= scalar(diff, "up_cap_diff"):
        mult = scalar(diff, "up_cap_mult")
    elif delta >= scalar(diff, "neutral_min"):
        mult = 1.0
    else:
        index = int(scalar(diff, "neutral_min") - 1 - delta)
        mult = down[index] if index < len(down) else scalar(diff, "floor_mult")
    base = half_up(scalar(curve, "mob_exp_coefficient") * mob_level ** scalar(curve, "mob_exp_exponent"))
    return max(1, half_up(base * mult))


chapters = {
    number: json.loads(read(f"godot/data/content/chapter_{name}.json"))
    for number, name in [(4, "four"), (5, "five"), (6, "six"), (7, "seven")]
}


def model(main_only=False):
    total = 79291
    rows = []
    for chapter, data in chapters.items():
        start = total
        kills = report = count = 0
        for quest in data["quests"]:
            if main_only and not quest["quest_id"].startswith("MQ-"):
                continue
            for kind, target, amount in zip(
                quest["objective_kinds"], quest["objective_targets"], quest["objective_counts"]
            ):
                if kind != "KILL":
                    continue
                level = data["constants"]["MONSTER_VARIANTS"][target]["level"]
                drop = read(f"godot/data/drops/{target}_drop_table.tres")
                assert int(scalar(drop, "monster_level")) == level
                # 대상은 일반 등급이다. 정예/보스는 이 산술에 포함하지 않는다.
                tier = re.search(r"^tier = (\d+)$", drop, re.M)
                assert tier is None or int(tier[1]) == 0
                for _ in range(amount):
                    gained = kill_exp(level, total)
                    total += gained
                    kills += gained
                    count += 1
            total += quest["reward_exp"]
            report += quest["reward_exp"]
        rows.append(dict(chapter=chapter, start=start, kills=kills, kill_count=count,
                         report=report, total=total, level=reached(total)))
    return rows


baseline = model()
main = model(True)
assert [row["total"] for row in baseline[:3]] == [283297, 704457, 1674227]
assert [row["total"] for row in main[:3]] == [200408, 451447, 1032517]
loss_rows = []
for match in re.finditer(r"^\| ([2-6]) \| ([\d,]+) \| ([\d,]+) \| ([\d,]+) \|", read("docs/design/100-hour-progression-budget.md"), re.M):
    chapter, _, report, kills = (int(value.replace(",", "")) for value in match.groups())
    side = half_up(report * 0.4)
    if chapter in chapters:
        assert chapters[chapter]["budget"]["side_exp"] == side
    loss_rows.append(dict(chapter=chapter, side_report=side, budget_kill_pool=kills,
                          loss_a=half_up(side * 0.2), loss_b=half_up((side + kills) * 0.2)))
assert len(loss_rows) == 5
first = chapters[7]["quests"][0]
assert first["quest_id"] == "MQ-07-01" and first["reward_exp"] == 1153000
assert "KILL" not in first["objective_kinds"]
assert chapters[7]["budget"]["main_exp"] == 1317896 + 500000
assert sum(q["reward_exp"] for q in chapters[7]["quests"] if q["quest_id"].startswith("MQ-")) == 1817896
g40 = THRESHOLDS[39]
gate_rows = []
for name, loss in [("baseline", 0), ("A", sum(r["loss_a"] for r in loss_rows)),
                   ("B", sum(r["loss_b"] for r in loss_rows))]:
    supply = baseline[2]["total"] + first["reward_exp"] - loss
    gate_rows.append(dict(route=name, loss=loss, supply=supply, level=reached(supply),
                          margin=supply-g40, one_percent_shortfall=max(0, math.ceil(g40*1.01)-supply)))
print(json.dumps(dict(baseline=baseline, main_only=main, official_loss_rows=loss_rows,
                     first_report_required_kills=0, G40=g40, acceptance=math.ceil(g40*1.01),
                     first_report_gate=gate_rows), ensure_ascii=False, indent=2))
