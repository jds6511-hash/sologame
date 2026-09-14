# -*- coding: utf-8 -*-
"""M3 D-3 재스폰 페이스 계산기 — 구현체(.tres / .tscn / monster_spawner.gd)를 직접 읽어 산출한다.

산출 문서: docs\\design\\levels\\m3-respawn-spec.md (level-designer)
실행:      PYTHONIOENCODING=utf-8 python docs\\qa\\tools\\m3_respawn_pace_calc.py

`docs\\qa\\tools\\m3_phase_d_balance_calc.py`(systems-designer, Phase D)와 **같은 방식**으로
리소스를 파싱하며, 파싱 헬퍼·성장 공식 재현부는 그 스크립트에서 그대로 가져왔다. Phase D와
다른 점은 하나다: **재스폰 공급 상한을 모델에 넣는다.**

Phase D 3-5장은 "재스폰이 없다"는 전제로 빌드 전체 EXP 재고(10,688)를
계산해 "정상 플레이로 Lv10 도달 불가"를 판정했다. 재스폰이 들어오면 재고는 유한하지 않고
**시간당 공급률**이 되므로, 판정 기준도 "재고 총량"에서 "공급률이 플레이어 사냥 속도를
가로막는가"로 바뀐다. 본 스크립트는 그 공급률을 마커 실측 × 쿨다운으로 산출한다.

출력 섹션:
  1  구현에서 읽은 재스폰 파라미터
  2  시작 지역 스폰 마커 실측 → 종별 개체 수·공급률
  3  재스폰 공급 vs 플레이어 사냥 속도 (병목이 어디인가)
  4  Lv1→Lv10 페이스 (재스폰 공급 상한 반영, 오버헤드 × 퀘스트 비중)
  5  양학 점검 — 재스폰 쿨다운이 정예 캠핑 효율에 미치는 영향
  6  판정 요약

한계: 플레이어 행동(회피 성공률·실제 동선·루팅 시간)은 모델링하지 않는다. 사냥 대상 선택은
      "치사성 게이트를 통과하는 종 중 EXP/초 최대"를 공급 상한까지 채우는 탐욕 배분으로 둔다.
"""
import os
import re

ROOT = r"C:\Users\UserK\Desktop\game\godot"
SPAWNER = "scripts/world/monster_spawner.gd"
START_AREA = "scenes/world/eastern_frontier_starting_area.tscn"
INITIAL_STOCK_EXP = 10688


# ---------- 파싱 (Phase D 스크립트와 동일 방식) ----------
def parse_tres(path):
    src = open(os.path.join(ROOT, path), encoding="utf-8").read()
    body = src[src.rindex("[resource]"):]
    out = {}
    for m in re.finditer(r"^(\w+) = (.+)$", body, flags=re.M):
        k, v = m.group(1), m.group(2).strip()
        if v.startswith("Packed"):
            inner = v[v.index("(") + 1:v.rindex(")")]
            out[k] = [float(x) for x in re.findall(r"-?[\d.]+", inner)]
        elif v.startswith('"') or v.startswith('&"'):
            out[k] = v.strip('&"')
        elif v in ("true", "false"):
            out[k] = v == "true"
        else:
            try:
                out[k] = float(v)
            except ValueError:
                out[k] = v
    return out


def parse_combo(path):
    src = open(os.path.join(ROOT, path), encoding="utf-8").read()
    dflt = dict(damage_coefficient=1.0, startup_sec=0.15, active_sec=0.10, recovery_sec=0.25)
    subs = {}
    for blk in re.split(r"^\[sub_resource ", src, flags=re.M)[1:]:
        sid = re.search(r'id="([^"]+)"', blk.split("]")[0]).group(1)
        d = dict(dflt)
        for m in re.finditer(r"^(\w+) = ([-\d.]+)$", blk.split("[resource]")[0], flags=re.M):
            if m.group(1) in d:
                d[m.group(1)] = float(m.group(2))
        subs[sid] = d
    order = re.findall(r'SubResource\("([^"]+)"\)', src[src.rindex("[resource]"):])
    steps = [subs[o] for o in order]
    coef = sum(s["damage_coefficient"] for s in steps)
    time = sum(s["startup_sec"] + s["active_sec"] + s["recovery_sec"] for s in steps)
    return coef, time, coef / time


def parse_gd_consts(path, names):
    """monster_spawner.gd의 `const NAME := 30.0` 형태 상수를 읽는다(문서 수치 재입력 방지)."""
    src = open(os.path.join(ROOT, path), encoding="utf-8").read()
    out = {}
    for n in names:
        m = re.search(r"^const %s\s*:?=\s*([\d.]+)" % n, src, flags=re.M)
        out[n] = float(m.group(1))
    return out


def parse_pack_sizes(path):
    """`const WOLF_PACK_SIZE := Vector2i(2, 4)` → ("WOLF", (2, 4))"""
    src = open(os.path.join(ROOT, path), encoding="utf-8").read()
    out = {}
    for m in re.finditer(r"^const (\w+)_(?:PACK_SIZE|ESCORT_SIZE) := Vector2i\((\d+), (\d+)\)",
                         src, flags=re.M):
        out[m.group(1)] = (int(m.group(2)), int(m.group(3)))
    return out


def parse_markers(scene_path):
    """씬의 마커 그룹 → [Vector2(px) …]. Marker2D 노드의 parent/position만 본다."""
    src = open(os.path.join(ROOT, scene_path), encoding="utf-8").read()
    groups = {}
    blocks = re.split(r"^\[node ", src, flags=re.M)[1:]
    for blk in blocks:
        head = blk.split("]")[0]
        if 'type="Marker2D"' not in head:
            continue
        parent = re.search(r'parent="([^"]+)"', head)
        if parent is None:
            continue
        pos = re.search(r"^position = Vector2\(([-\d.e]+), ([-\d.e]+)\)", blk, flags=re.M)
        xy = (float(pos.group(1)), float(pos.group(2))) if pos else (0.0, 0.0)
        groups.setdefault(parent.group(1), []).append(xy)
    return groups


# ---------- 리소스 로드 ----------
LC = parse_tres("data/progression/level_curve.tres")
LDC = parse_tres("data/progression/level_diff_curve.tres")
SGF = parse_tres("data/progression/stat_growth_formula.tres")
JOBS = {j: parse_tres(f"data/progression/job_growth_{j}.tres")
        for j in ("adventurer", "warrior", "archer")}
COMBOS = {n: parse_combo(f"data/player/{n}_basic_combo.tres")
          for n in ("adventurer", "warrior")}

RESPAWN = parse_gd_consts(SPAWNER, ["RESPAWN_TICK_SEC", "NORMAL_RESPAWN_SEC",
                                    "ELITE_RESPAWN_SEC", "RESPAWN_GATE_MARGIN_TILES",
                                    "MAX_RESPAWNS_PER_TICK"])
PACK = parse_pack_sizes(SPAWNER)

MON_FILES = {
    "뿔토끼": ("rabbit_stats", "rabbit_drop_table"),
    "들개 마수": ("wolf_stats", "wolf_drop_table"),
    "균열 점액": ("slime_stats", "rift_slime_drop_table"),
    "숲거미": ("forest_spider_stats", "forest_spider_drop_table"),
    "그림자 숲거미": ("shadow_forest_spider_stats", "shadow_forest_spider_drop_table"),
    "무법자": ("outlaw_stats", "outlaw_drop_table"),
    "노상강도": ("highwayman_stats", "highwayman_drop_table"),
    "밀렵꾼": ("poacher_stats", "poacher_drop_table"),
    "임프": ("imp_stats", "imp_drop_table"),
    "포효 임프장": ("imp_lord_stats", "imp_lord_drop_table"),
}
MONS = {}
for name, (sf, df) in MON_FILES.items():
    s = parse_tres(f"data/monsters/{sf}.tres")
    d = parse_tres(f"data/drops/{df}.tres")
    MONS[name] = dict(hp=s["max_hp"], atk=s["attack_power"], defense=s["defense"],
                      level=int(d["monster_level"]), elite=bool(s.get("is_elite", False)),
                      perception=s.get("perception_range_tiles", 0.0))


# ---------- 구현 공식 재현 (Phase D와 동일) ----------
def req(L):
    multiplier = (LC.get("pre_transition_req_multiplier", 1.0)
                  if L < LC.get("first_transition_level", 0.0) else 1.0)
    return round(LC["req_coefficient"] * L ** LC["req_exponent"] * multiplier)


def mob_exp(L):
    return round(LC["mob_exp_coefficient"] * L ** LC["mob_exp_exponent"])


def leveldiff_mult(d):
    if d >= LDC["up_cap_diff"]:
        return LDC["up_cap_mult"]
    if d >= LDC["neutral_min"]:
        return 1.0
    idx = int(LDC["neutral_min"]) - 1 - d
    dm = LDC["down_mults"]
    return dm[idx] if 0 <= idx < len(dm) else LDC["floor_mult"]


MAIN_KEY = {0: "str", 1: "agi", 2: "int", 3: "vit"}


def primary(level, job, key):
    J = JOBS[job]
    adv = min(level - 1, int(J["transition_level"]) - 1)
    jl = max(level - int(J["transition_level"]), 0)
    return SGF["initial_stat"] + adv * SGF["adventurer_growth"] + jl * J[f"growth_{key}"]


def job_at(level):
    return "adventurer" if level < 10 else "warrior"


def player_attack(level):
    job = job_at(level)
    main = primary(level, job, MAIN_KEY[int(JOBS[job]["main_stat"])])
    return (SGF["weapon_attack_base"] + level * SGF["weapon_attack_per_level"]
            + main * SGF["attack_per_main_stat"])


def player_hp(level):
    return (SGF["hp_base"] + primary(level, job_at(level), "vit") * SGF["hp_per_vit"]
            + level * SGF["hp_per_level"])


def player_def(level):
    return (SGF["armor_defense_base"] + level * SGF["armor_defense_per_level"]
            + primary(level, job_at(level), "vit") * SGF["defense_per_vit"])


def ttk(level, mon, night=False):
    cps = COMBOS[job_at(level)][2]
    mit = 100.0 / (100.0 + mon["defense"])
    return mon["hp"] * (1.2 if night else 1.0) / (player_attack(level) * cps * mit)


def survivable_hits(level, mon, night=False):
    dmg = mon["atk"] * (1.2 if night else 1.0) * 100.0 / (100.0 + player_def(level))
    return player_hp(level) / dmg


def exp_gain(mon, level, night):
    base = mob_exp(mon["level"])
    grade = LC["elite_multiplier"] if mon["elite"] else 1.0
    nm = LC["night_exp_multiplier"] if night else 1.0
    return max(1, round(base * grade * leveldiff_mult(mon["level"] - level) * nm))


# ---------- 시작 지역 배치 실측 ----------
GROUPS = parse_markers(START_AREA)
GROUP_SPECIES = {
    "Markers/MonsterSpawns_뿔토끼": ("뿔토끼", 1.0, RESPAWN["NORMAL_RESPAWN_SEC"]),
    "Markers/MonsterSpawns_들개마수": ("들개 마수", sum(PACK["WOLF"]) / 2.0,
                                   RESPAWN["NORMAL_RESPAWN_SEC"]),
    "Markers/MonsterSpawns_균열점액": ("균열 점액", 1.0, RESPAWN["NORMAL_RESPAWN_SEC"]),
    "Markers/MonsterSpawns_숲거미": ("숲거미", 1.0, RESPAWN["NORMAL_RESPAWN_SEC"]),
}
## 야간 전용 종은 재스폰 슬롯 대상이 아니므로 공급 모델에서 제외한다(있으면 더 빨라질 뿐 —
## 보수적 계산). 그림자 숲거미 마커는 참고로만 센다.
NIGHT_GROUP = "Markers/MonsterSpawns_그림자숲거미_야간"

POOL = {}  # 종 → dict(markers, per_marker, population, delay, supply_per_sec)
for group, (species, per_marker, delay) in GROUP_SPECIES.items():
    markers = len(GROUPS.get(group, []))
    pop = markers * per_marker
    POOL[species] = dict(markers=markers, per_marker=per_marker, population=pop,
                         delay=delay, supply=pop / delay if delay > 0 else 0.0)

ACTIVITY_RATIO = 0.5          # growth.md 5-3
NIGHT_SHARE = 1.0 / 3.0       # 게임 하루 30분 중 밤 10분
LETHALITY_MIN_HITS = 4.0      # Phase D 3-6장 치사성 게이트


def hr(t):
    print("\n" + "=" * 78 + "\n" + t + "\n" + "=" * 78)


## 사냥 대상 선택 모델 3종. 어느 것도 "플레이어가 실제로 무엇을 죽이는가"를 알 수는 없으므로,
## 세 개의 서로 다른 전제로 상·하한을 감싼다(Phase D 1-1장 신뢰도 등급 B = 모델 계산).
##   normal — **정상 동선**: 레벨 차 보정이 1.00인 종(d = −4~+4)만 사냥한다. 게임 자신의
##            레벨 차 표를 기준으로 "양학(상향 1.20)도 저레벨 재방문(하향)도 아닌" 구간을
##            정의한 것이라 임의성이 가장 적다. 본 문서의 대표값.
##   band   — Phase D 3-2장과 동일: |d|가 최소인 **단일 종**만 사냥(동률 시 낮은 레벨).
##            Phase D의 1.933h와 직접 비교하기 위한 모델.
##   greedy — 치사성 게이트만 통과하면 EXP/초 최대 종을 고른다(= 양학 허용 상한).
def candidates(level, model):
    names = list(POOL)
    if model == "band":
        best = min(names, key=lambda n: (abs(MONS[n]["level"] - level), MONS[n]["level"]))
        return [best]
    if model == "normal":
        return [n for n in names if abs(MONS[n]["level"] - level) <= 4]
    return names


def alloc(level, overhead, night, model="normal", cap_supply=True):
    """대상 후보를 EXP/초 내림차순으로, 재스폰 공급 상한까지 시간 예산(1초)에 채운다.

    반환: (EXP/초, [(종, 초당 처치 수, 병목)])
    """
    cands = []
    for name in candidates(level, model):
        mon = MONS[name]
        if survivable_hits(level, mon, night) < LETHALITY_MIN_HITS:
            continue
        cycle = ttk(level, mon, night) + overhead
        gain = exp_gain(mon, level, night)
        cands.append((gain / cycle, name, cycle, gain, POOL[name]["supply"]))
    cands.sort(reverse=True)
    budget, rate, rows = 1.0, 0.0, []
    for _eff, name, cycle, gain, supply in cands:
        if budget <= 1e-9:
            break
        want = budget / cycle
        take = min(want, supply) if cap_supply else want
        if take <= 0:
            continue
        rate += take * gain
        budget -= take * cycle
        rows.append((name, take, "재스폰 공급" if cap_supply and take < want - 1e-9 else "사냥 속도"))
    return rate, rows


def blended_rate(level, overhead, model="normal", cap_supply=True):
    day, _ = alloc(level, overhead, False, model, cap_supply)
    nite, _ = alloc(level, overhead, True, model, cap_supply)
    return day * (1 - NIGHT_SHARE) + nite * NIGHT_SHARE


def hours_to_10(overhead, quest_share, model="normal", cap_supply=True):
    total = 0.0
    for L in range(1, 10):
        rate = blended_rate(L, overhead, model, cap_supply)
        total += req(L) * (1 - quest_share) / rate / 3600.0 / ACTIVITY_RATIO
    return total


# ============================================================ 출력
hr("1. 구현에서 읽은 재스폰 파라미터 (monster_spawner.gd)")
for k, v in RESPAWN.items():
    print(f"  {k:28s} = {v:g}")
print(f"  무리 크기 상수                 = {PACK}")

hr("2. 시작 지역 스폰 마커 실측 → 종별 공급률")
print(f"{'종':12s}{'Lv':>4}{'마커':>6}{'마커당':>8}{'개체 수':>9}"
      f"{'쿨다운':>8}{'공급(마리/시간)':>16}")
for name, info in POOL.items():
    print(f"{name:12s}{MONS[name]['level']:>4}{info['markers']:>6}{info['per_marker']:>8.1f}"
          f"{info['population']:>9.1f}{info['delay']:>7.0f}s{info['supply'] * 3600:>16.0f}")
print(f"\n  (참고) 야간 전용 그림자 숲거미 마커 {len(GROUPS.get(NIGHT_GROUP, []))}개 — 재스폰 슬롯 "
      f"대상이 아니라 공급 모델에서 제외(보수적)")
print(f"  전 종 합계 공급 = {sum(i['supply'] for i in POOL.values()) * 3600:.0f}마리/시간 "
      f"(growth.md 5-3 전제 300마리/시간의 "
      f"{sum(i['supply'] for i in POOL.values()) * 3600 / 300:.1f}배)")

hr("3. 병목 판정 — 재스폰 공급 vs 플레이어 사냥 속도 (정상 동선 |d|<=4, 주간)")
print(f"{'플Lv':>5}{'오버헤드':>9}{'EXP/초':>9}{'공급 무제한':>13}{'손실':>8}   배분(종 마리/시간, 병목)")
for L in range(1, 10):
    for ov in (7.0, 3.0):
        capped, rows = alloc(L, ov, False, "normal", True)
        free, _ = alloc(L, ov, False, "normal", False)
        detail = " / ".join(f"{n} {x * 3600:.0f}({b})" for n, x, b in rows)
        print(f"{L:>5}{ov:>8.0f}s{capped:>9.2f}{free:>13.2f}"
              f"{(1 - capped / free) * 100:>7.1f}%   {detail}")
print("\n  '재스폰 공급'이 병목인 행이 곧 재스폰 대기로 손실이 생기는 구간이다.")

hr("4. Lv1 → Lv10 도달 시간(h)   [growth.md 5-2 목표 = 1.8h (퀘스트 45% 전제)]")
for model, title in (("normal", "정상 동선 (레벨 차 보정 1.00 구간만 = |d| <= 4) ← 대표값"),
                     ("band", "Phase D 배치종 동선 (|d| 최소 단일 종) — Phase D 1.933h와 직접 비교"),
                     ("greedy", "탐욕 최적 동선 (치사성 게이트만 = 양학 허용 상한)")):
    print(f"\n  [{title}]")
    print(f"{'오버헤드':>10}{'퀘스트 0%':>14}{'퀘스트 30%':>14}{'퀘스트 45%':>14}   비고")
    for ov in (3.0, 5.0, 7.0, 9.0, 12.0):
        line = f"{ov:>9.0f}s"
        for q in (0.0, 0.30, 0.45):
            line += f"{hours_to_10(ov, q, model):>14.3f}"
        note = "← M3 실측 기하(Phase D 3-4)" if ov == 3.0 else (
            "← growth.md 5-3 설계 가정" if ov == 7.0 else "")
        print(line + f"   {note}")
print("\n  [참조] Phase D 모델(재스폰 없음 가정, 퀘스트 45%): 설계 곡선 1.622h / 배치종 동선 1.933h")
print("  [참조] M3 빌드에는 퀘스트 시스템이 없으므로(M3_PLAN 1-4) 실제 G3-1 세션은 '퀘스트 0%' 열이다.")
print("\n  [재스폰 공급 상한의 페이스 기여] 상한을 제거(무한 공급)했을 때와의 차이:")
for model in ("normal", "band"):
    for ov in (7.0, 3.0):
        capped = hours_to_10(ov, 0.0, model, True)
        free = hours_to_10(ov, 0.0, model, False)
        print(f"    {model:7s} 오버헤드 {ov:>4.0f}s 퀘스트 0% → {capped:5.3f}h vs 무한 공급 "
              f"{free:5.3f}h ({(capped / free - 1) * 100:+.1f}%)")
print("\n  [사냥 사이클 환산] growth.md 5-3 전제 = 12초/마리(300마리·시간)")
for L in (1, 5, 8):
    for model in ("normal", "band"):
        _, rows = alloc(L, 7.0, False, model, True)
        kills = sum(x for _n, x, _b in rows)
        print(f"    Lv{L:<2} {model:7s} 오버헤드 7s → {1.0 / kills:5.2f}초/마리 "
              f"({kills * 3600:.0f}마리/시간)")

hr("5. 양학 점검 — 재스폰 쿨다운이 정예 캠핑에 미치는 영향")
lord = MONS["포효 임프장"]
imp = MONS["임프"]
for L in (11, 16):
    t_lord = ttk(L, lord)
    camp_only = exp_gain(lord, L, False) / (t_lord + RESPAWN["ELITE_RESPAWN_SEC"])
    phase_d = exp_gain(lord, L, False) / (t_lord + 7.0)
    normal = exp_gain(imp, L, False) / (ttk(L, imp) + 7.0)
    print(f"  플레이어 Lv{L}: 정예 캠프 반복 사냥 {camp_only:5.2f} EXP/초 "
          f"(Phase D 쿨다운 미반영 값 {phase_d:5.2f}) vs 동렙 일반 임프 {normal:5.2f} EXP/초"
          f" → {'억제됨' if camp_only < normal else '양학 성립'}")
print("\n  일반종 양학 배수 — 탐욕 최적(치사성 게이트만) / 정상 동선. 둘 다 재스폰 공급 상한 반영:")
print(f"{'플Lv':>5}{'정상 EXP/초':>13}{'최적 EXP/초':>13}{'배수':>7}   Phase D 3-6장(단일 종 기준) 대비")
PHASE_D_MULT = {1: 18.6, 2: 24.9, 3: 3.7, 5: 5.3, 6: 6.2}
for L in (1, 2, 3, 5, 6, 8, 9):
    n_rate = blended_rate(L, 7.0, "normal")
    g_rate = blended_rate(L, 7.0, "greedy")
    ref = f"Phase D {PHASE_D_MULT[L]:.1f}배" if L in PHASE_D_MULT else ""
    print(f"{L:>5}{n_rate:>13.2f}{g_rate:>13.2f}{g_rate / n_rate:>7.2f}   {ref}")
print("  (Phase D는 '|d| 최소 단일 종'을 기준선으로 삼아 배수가 크게 나왔다. 같은 권역의 여러 종을"
      " 함께 사냥하는 정상 동선을 기준선으로 하면 배수가 훨씬 작다.)")

print(f"\n  치사성 게이트(허용 피격 >= {LETHALITY_MIN_HITS:.0f}대) — 재스폰은 이 값을 바꾸지 않는다:")
print(f"{'플Lv':>5}" + "".join(f"{n:>12s}" for n in POOL))
for L in (1, 2, 5, 8, 10):
    line = f"{L:>5}"
    for n in POOL:
        h = survivable_hits(L, MONS[n])
        line += f"{h:>10.1f}대" if h >= LETHALITY_MIN_HITS else f"{h:>9.1f}대X"
    print(line)

hr("6. 판정 요약")
need10 = sum(req(L) for L in range(1, 10))
print(f"  Lv10 도달 필요 누적 EXP = {need10:,}")
stock_ratio = INITIAL_STOCK_EXP / need10 * 100.0
print(
    f"  Phase D(재스폰 없음) 빌드 전체 EXP 재고 = {INITIAL_STOCK_EXP:,} "
    f"(충족률 {stock_ratio:.1f}%) → 도달 불가"
)
supply_exp_per_hour = sum(
    POOL[n]["supply"] * exp_gain(MONS[n], 5, False) for n in POOL) * 3600
print(f"  재스폰 적용 후 시작 지역 EXP 공급 상한 = 약 {supply_exp_per_hour:,.0f} EXP/시간 "
      f"(플레이어 Lv5 기준, 전 종 동시 소비 가정)")
print(f"  → EXP 재고는 유한 총량이 아니라 공급률이 되므로 Lv10 도달 **가능**.")
print(f"     정상 동선 대표값: 오버헤드 7s·퀘스트 0%(= M3 빌드 실제 조건) "
      f"{hours_to_10(7.0, 0.0, 'normal'):.2f}h / "
      f"오버헤드 3s·퀘스트 0% {hours_to_10(3.0, 0.0, 'normal'):.2f}h")
print(f"     같은 조건에서 퀘스트 45%를 얹으면 {hours_to_10(7.0, 0.45, 'normal'):.2f}h ~ "
      f"{hours_to_10(3.0, 0.45, 'normal'):.2f}h (목표 1.8h)")
