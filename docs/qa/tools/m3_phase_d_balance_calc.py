# -*- coding: utf-8 -*-
"""M3 Phase D 밸런스 실측 계산기 — 구현체(.tres/씬)를 직접 읽어 산출한다.

산출 문서: docs\\design\\systems\\m3-balance-phase-d.md (systems-designer, 2026-07-31)
실행:      PYTHONIOENCODING=utf-8 python docs\\qa\\tools\\m3_phase_d_balance_calc.py

문서 수치를 재입력하지 않고 godot/ 아래의 리소스를 파싱하므로, 데이터가 바뀌면
재실행만으로 갱신된다(회귀 확인용으로 재사용할 것). 출력 11개 섹션:
  0  모델 캘리브레이션 (growth.md 5-3 유도식 재현 → 1.815h)
  1  콤보 계수/초 (기준 DPS 물공x1.7 대비 배수 — 이월 플래그 1)
  2  몬스터 스펙 + 동렙 TTK (명목 vs 실측)
  3  피격 예산 (combat.md 5-1 잡몹 10대)
  4  D-2 페이스 실측표 2모델 (설계 곡선 / 실제 배치종 동선)
  5  민감도 (오버헤드 x 퀘스트 비중 → Lv10 도달)
  6  Lv10 -> Lv20 구간
  7  양학 상한 (치사성 게이트 통과 종 중 최대 EXP/초)
  8  현 빌드 EXP 재고 (재스폰 없음 → 플레이 실측 가능성)
  9  D-1 이동 속도 (둔화 x 공격 중 x 조준 조합)
  10 D-1 판정 이탈 검산 (예고 중 정지하는 몹의 히트박스를 걸어서 벗어날 수 있는가)
  11 정예 그로기 재검산 (레벨 무관 — HP 비율만으로 결정)

한계: 플레이어 행동(회피 성공률·사냥터 선택·실제 오버헤드)은 모델링하지 않는다.
      그 부분은 산출 문서 9-2장의 G3-1 관찰 항목이다.
"""
import re, os, math, sys, json

## 리포지토리 위치가 바뀌면 이 경로만 고치면 된다.
ROOT = r"C:\Users\UserK\Desktop\game\godot"

def parse_tres(path):
    """[resource] 섹션의 스칼라/배열 필드를 dict로."""
    src = open(os.path.join(ROOT, path), encoding="utf-8").read()
    # 마지막 [resource] 블록
    idx = src.rindex("[resource]")
    body = src[idx:]
    out = {}
    for m in re.finditer(r'^(\w+) = (.+)$', body, flags=re.M):
        k, v = m.group(1), m.group(2).strip()
        if v.startswith("Packed"):
            inner = v[v.index("(") + 1:v.rindex(")")]
            out[k] = [float(x) for x in re.findall(r'-?[\d.]+', inner)]
        elif v.startswith('"') or v.startswith('&"'):
            out[k] = v.strip('&"')
        elif v in ("true", "false"):
            out[k] = (v == "true")
        else:
            try:
                out[k] = float(v)
            except ValueError:
                out[k] = v
    return out

def parse_combo(path):
    """콤보 .tres의 sub_resource 단계들을 순서대로 파싱 (기본값 보정 포함)."""
    src = open(os.path.join(ROOT, path), encoding="utf-8").read()
    # WarriorAttackStep 기본값 (warrior_attack_step.gd)
    dflt = dict(damage_coefficient=1.0, hitbox_range_tiles=1.8, hitbox_angle_deg=90.0,
                startup_sec=0.15, active_sec=0.10, recovery_sec=0.25)
    subs = {}
    for blk in re.split(r'^\[sub_resource ', src, flags=re.M)[1:]:
        head = blk.split("]")[0]
        sid = re.search(r'id="([^"]+)"', head).group(1)
        d = dict(dflt)
        for m in re.finditer(r'^(\w+) = ([-\d.]+)$', blk.split("[resource]")[0], flags=re.M):
            if m.group(1) in d:
                d[m.group(1)] = float(m.group(2))
        subs[sid] = d
    order = re.findall(r'SubResource\("([^"]+)"\)', src[src.rindex("[resource]"):])
    return [subs[o] for o in order]

def combo_metrics(steps):
    total_coef = sum(s["damage_coefficient"] for s in steps)
    total_time = sum(s["startup_sec"] + s["active_sec"] + s["recovery_sec"] for s in steps)
    return total_coef, total_time, total_coef / total_time

# ---------- 리소스 로드 ----------
LC   = parse_tres("data/progression/level_curve.tres")
LDC  = parse_tres("data/progression/level_diff_curve.tres")
SGF  = parse_tres("data/progression/stat_growth_formula.tres")
JOBS = {j: parse_tres(f"data/progression/job_growth_{j}.tres")
        for j in ("adventurer", "warrior", "archer")}
COMBOS = {n: combo_metrics(parse_combo(f"data/player/{n}_basic_combo.tres"))
          for n in ("adventurer", "warrior", "archer")}

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
                      level=int(d["monster_level"]), tier=int(d["tier"]),
                      elite=bool(s.get("is_elite", False)))

# ---------- 구현 공식 ----------
def req(L):  return round(LC["req_coefficient"] * L ** LC["req_exponent"])
def mob_exp(L): return round(LC["mob_exp_coefficient"] * L ** LC["mob_exp_exponent"])

def leveldiff_mult(d):
    if d >= LDC["up_cap_diff"]: return LDC["up_cap_mult"]
    if d >= LDC["neutral_min"]: return 1.0
    idx = int(LDC["neutral_min"]) - 1 - d
    dm = LDC["down_mults"]
    return dm[idx] if 0 <= idx < len(dm) else LDC["floor_mult"]

def exp_gain(base, grade, ld, night):
    return max(1, round(base * grade * ld * night))

def primary(level, job, key):
    J = JOBS[job]
    adv = min(level - 1, int(J["transition_level"]) - 1)
    jl = max(level - int(J["transition_level"]), 0)
    return SGF["initial_stat"] + adv * SGF["adventurer_growth"] + jl * J[f"growth_{key}"]

MAIN_KEY = {0: "str", 1: "agi", 2: "int", 3: "vit"}
def player_attack(level, job):
    J = JOBS[job]
    main = primary(level, job, MAIN_KEY[int(J["main_stat"])])
    return (SGF["weapon_attack_base"] + level * SGF["weapon_attack_per_level"]
            + main * SGF["attack_per_main_stat"])
def player_hp(level, job):
    return SGF["hp_base"] + primary(level, job, "vit") * SGF["hp_per_vit"] + level * SGF["hp_per_level"]
def player_def(level, job):
    return (SGF["armor_defense_base"] + level * SGF["armor_defense_per_level"]
            + primary(level, job, "vit") * SGF["defense_per_vit"])

def job_at(level):  # M3 동선: Lv1~9 모험가, Lv10+ 전사(기준선)
    return "adventurer" if level < 10 else "warrior"
def combo_at(level):
    return COMBOS["adventurer"] if level < 10 else COMBOS["warrior"]

def ttk(level, mon, night=False):
    atk = player_attack(level, job_at(level))
    cps = combo_at(level)[2]
    mit = 100.0 / (100.0 + mon["defense"])
    hp = mon["hp"] * (1.2 if night else 1.0)
    hp *= 6.0 if mon["elite"] else 1.0   # 정예 HP는 이미 .tres에 반영됨 → 아래 주석 참조
    return hp / (atk * cps * mit)

def ttk_real(level, mon, night=False):
    """정예 .tres HP는 이미 x6이 반영된 값이라 중복 곱을 제거한 버전."""
    atk = player_attack(level, job_at(level))
    cps = combo_at(level)[2]
    mit = 100.0 / (100.0 + mon["defense"])
    hp = mon["hp"] * (1.2 if night else 1.0)
    return hp / (atk * cps * mit)


# ============================================================ 출력
def hr(t):
    print("\n" + "=" * 78 + "\n" + t + "\n" + "=" * 78)


hr("1. 콤보 계수/초 (구현 .tres 실측) — 이월 플래그 1")
print(f"{'무기(콤보)':16s}{'타수':>5}{'총계수':>8}{'총시간':>9}{'계수/초':>9}{'기준DPS(x1.7) 대비':>20}")
for n, (c, t, cps) in COMBOS.items():
    nsteps = len(parse_combo(f"data/player/{n}_basic_combo.tres"))
    print(f"{n:16s}{nsteps:>5}{c:>8.2f}{t:>8.2f}s{cps:>9.3f}{cps / 1.7:>19.3f}배")

hr("2. 몬스터 스펙 + 동렙 TTK (주간, 동렙 B급 기준선, 구현 콤보)")
print(f"{'몬스터':16s}{'Lv':>4}{'HP':>7}{'공격':>6}{'방어':>6}{'EXP':>7}{'명목TTK':>9}{'실측TTK':>9}{'비율':>7}")
for n, m in MONS.items():
    L = m["level"]
    atk = player_attack(L, job_at(L))
    mit = 100.0 / (100.0 + m["defense"])
    nominal = m["hp"] / (atk * 1.7 * mit)
    real = ttk_real(L, m)
    e = mob_exp(L) * (6 if m["elite"] else 1)
    print(f"{n:16s}{L:>4}{m['hp']:>7.0f}{m['atk']:>6.0f}{m['defense']:>6.1f}"
          f"{e:>7}{nominal:>8.2f}s{real:>8.2f}s{nominal / real:>7.2f}")

hr("3. 피격 예산 (combat.md 5-1 잡몹 10대) — 동렙 조우, 실피해 1대당")
print(f"{'몬스터':16s}{'Lv':>4}{'플HP':>7}{'플방어':>7}{'실피해':>8}{'허용피격':>10}")
for n, m in MONS.items():
    L = m["level"]
    php, pdf = player_hp(L, job_at(L)), player_def(L, job_at(L))
    dmg = m["atk"] * 100.0 / (100.0 + pdf)
    print(f"{n:16s}{L:>4}{php:>7.0f}{pdf:>7.1f}{dmg:>8.1f}{php / dmg:>9.2f}대")

# ---------------- 사냥 대상 선택 모델 ----------------
PLACED = [n for n in MONS if n != "그림자 숲거미"]
BAND_POOL = [n for n in PLACED if not MONS[n]["elite"]]


def band_target(level):
    return min(BAND_POOL, key=lambda n: (abs(MONS[n]["level"] - level), MONS[n]["level"]))


def survivable(level, mon, min_hits):
    php, pdf = player_hp(level, job_at(level)), player_def(level, job_at(level))
    return php / (mon["atk"] * 100.0 / (100.0 + pdf)) >= min_hits


def optimum_target(level, overhead, min_hits=4.0):
    best = None
    for n in PLACED:
        m = MONS[n]
        if not survivable(level, m, min_hits):
            continue
        g = exp_gain(mob_exp(m["level"]), 6.0 if m["elite"] else 1.0,
                     leveldiff_mult(m["level"] - level), 1.0)
        rate = g / (ttk_real(level, m) + overhead)
        if best is None or rate > best[0]:
            best = (rate, n)
    return best


def rate_of(level, name, overhead, night):
    m = MONS[name]
    g = exp_gain(mob_exp(m["level"]), 6.0 if m["elite"] else 1.0,
                 leveldiff_mult(m["level"] - level), 1.2 if night else 1.0)
    return g / (ttk_real(level, m, night) + overhead)


def ideal_rate(level, overhead, night):
    atk = player_attack(level, job_at(level))
    mit = 100.0 / (100.0 + 0.5 * level)
    hp = atk * 1.7 * mit * 5.0 * (1.2 if night else 1.0)
    t = hp / (atk * combo_at(level)[2] * mit)
    return exp_gain(mob_exp(level), 1.0, 1.0, 1.2 if night else 1.0) / (t + overhead), t


NIGHT_SHARE = 1.0 / 3.0
## growth.md 5-3 "경험치 활동 비율 = 플레이 시간의 50%" — 사냥 실시간을 총 플레이 시간으로
## 환산하는 계수. 이 계수를 빼면 growth.md의 1.8h 목표와 비교할 수 없다(아래 0번 캘리브레이션).
ACTIVITY_RATIO = 0.5


def calibrate():
    """growth.md 5-3의 1.8h를 본 모델로 재현해 모델 자체가 맞는지 확인."""
    R = sum(11 * L for L in range(1, 10))          # 환산 처치 수 495
    rate_hunt = 3600.0 / 12.0                      # 사냥 사이클 12초 = 300마리/시간
    eff = rate_hunt / (1.0 - 0.45)                 # 퀘스트 45% 보전 = 545마리분/시간
    return R / eff / ACTIVITY_RATIO


hr("0. 모델 캘리브레이션 — growth.md 5-3 유도식 재현")
print(f"  환산 처치 수(Lv1->10) = 495 / 사냥 300마리·시간 / 퀘스트 45% / 활동 비율 50%")
print(f"  -> Lv10 도달 {calibrate():.3f}h   (growth.md 5-2 표기값 1.8h — 일치)")
print(f"  본 스크립트의 이후 표는 위 유도식에서 TTK·EXP·레벨차·야간만 구현 실측치로 대체한 것이다.")


def pace(lo, hi, overhead, quest_share, model):
    rows, total = [], 0.0
    for L in range(lo, hi):
        need = req(L) * (1.0 - quest_share)
        if model == "band":
            name = band_target(L)
            rate = (rate_of(L, name, overhead, False) * (1 - NIGHT_SHARE)
                    + rate_of(L, name, overhead, True) * NIGHT_SHARE)
            t = ttk_real(L, MONS[name])
            label = f"{name}(Lv{MONS[name]['level']})"
        else:
            rd, t = ideal_rate(L, overhead, False)
            rn, _ = ideal_rate(L, overhead, True)
            rate = rd * (1 - NIGHT_SHARE) + rn * NIGHT_SHARE
            label = "동렙 잡몹"
        hrs = need / rate / 3600.0 / ACTIVITY_RATIO
        total += hrs
        rows.append((L, label, t, need, rate, hrs, total))
    return rows, total


OVER = 7.0
for model, title in (("ideal", "설계 곡선 기준(동렙 잡몹·명목 HP 곡선)"),
                     ("band", "실제 배치종 동선 모델(|d| 최소 일반종)")):
    hr(f"4. D-2 페이스 — {title} / 오버헤드 {OVER:.0f}s / 퀘스트 45%")
    rows, tot = pace(1, 21, OVER, 0.45, model)
    print(f"{'Lv':>3}{'사냥 대상':>18}{'TTK':>8}{'REQ(L)':>10}"
          f"{'사냥 담당분':>12}{'EXP/s':>8}{'구간h':>8}{'누적h':>8}")
    for L, lab, t, need, rate, hrs, cum in rows:
        mark = ("  <- 이 행의 누적h = Lv10 도달" if L == 9
                else "  <- 이 행의 누적h = Lv20 도달" if L == 19 else "")
        print(f"{L:>3}{lab:>18}{t:>7.2f}s{req(L):>10,}{need:>12,.0f}"
              f"{rate:>8.2f}{hrs:>8.3f}{cum:>8.3f}{mark}")

hr("5. 민감도 — Lv10 도달 누적 시간(h)   [growth.md 5-2 목표 = 1.8h]")
for model, title in (("ideal", "설계 곡선"), ("band", "배치종 동선")):
    print(f"\n  [{title}]")
    print(f"{'오버헤드':>10}" + "".join(f"{'퀘스트 ' + str(int(q * 100)) + '%':>13}"
                                     for q in (0.0, 0.30, 0.45)))
    for ov in (3.0, 5.0, 7.0, 9.0, 12.0):
        line = f"{ov:>9.0f}s"
        for q in (0.0, 0.30, 0.45):
            _, t = pace(1, 10, ov, q, model)
            line += f"{t:>13.3f}"
        print(line)

hr("6. Lv10 -> Lv20 구간 소요 시간(h)   [설계값 = 7.656 - 1.813 = 5.84h]")
DESIGN_10_20 = sum(11 * L for L in range(10, 20)) / (3600.0 / 12.0 / 0.55) / ACTIVITY_RATIO
print(f"  (설계 유도식 재현: {DESIGN_10_20:.2f}h)")
for model in ("ideal", "band"):
    for ov in (5.0, 7.0, 9.0):
        for q in (0.0, 0.45):
            _, t = pace(10, 20, ov, q, model)
            dev = (t / DESIGN_10_20 - 1.0) * 100.0
            print(f"  {model:6s} 오버헤드 {ov:>4.0f}s 퀘스트 {int(q * 100):>2}%"
                  f" -> {t:6.2f}h  (설계 대비 {dev:+.1f}%)")

hr("7. 양학 상한 점검 — 치사성 게이트(허용 피격 >= 4대) 통과 종 중 최대 EXP/초")
print(f"{'플Lv':>5}{'동선 대상':>16}{'동선 EXP/s':>12}{'최적 대상':>16}{'최적 EXP/s':>12}{'배수':>7}")
for L in range(1, 21):
    bn = band_target(L)
    br = rate_of(L, bn, OVER, False)
    opt = optimum_target(L, OVER)
    print(f"{L:>5}{bn:>16}{br:>12.2f}{opt[1]:>16}{opt[0]:>12.2f}{opt[0] / br:>7.2f}")

hr("8. 현 빌드의 EXP 재고 — 플레이 실측 가능성")
POP = {"뿔토끼": 3, "들개 마수": 2 * 3, "균열 점액": 2, "숲거미": 3 + 3,
       "무법자": 1 * 2.5, "노상강도": 1 * 3.5, "밀렵꾼": 1 * 1.5,
       "임프": 1 * 3 + 2.5, "포효 임프장": 1}
tot_exp = 0.0
print("  (스폰 마커 실측 x monster_spawner.gd 무리 크기 평균, 플레이어 Lv1·주간·재스폰 없음)")
for n, cnt in POP.items():
    m = MONS[n]
    g = exp_gain(mob_exp(m["level"]), 6.0 if m["elite"] else 1.0,
                 leveldiff_mult(m["level"] - 1), 1.0)
    tot_exp += g * cnt
    print(f"    {n:16s} x{cnt:>5} x {g:>6} = {g * cnt:>9,.0f}")
need10 = sum(req(L) for L in range(1, 10))
print(f"    {'합계':16s}{'':>21}{tot_exp:>9,.0f}")
print(f"    Lv10 도달 필요 누적 EXP = {need10:,}  -> 재고 충족률 {tot_exp / need10 * 100:.1f}%")
g_shadow = exp_gain(mob_exp(10), 1.0, leveldiff_mult(10 - 1), 1.2)
nexp = g_shadow * 4
print(f"    야간 재스폰(그림자 숲거미 4마리/밤) = {nexp:,} EXP/게임밤")
print(f"    -> 부족분을 야간 반복으로만 채우려면 약 {(need10 - tot_exp) / nexp:.0f}밤 "
      f"= {(need10 - tot_exp) / nexp * 0.5:.1f} 실시간 시간")

# ---------------- D-1 ----------------
TILE = 16.0
walk = (TILE * 3.0 / 0.35) / 2.6 / TILE
dash = TILE * 3.0 / 0.35 / TILE
hr("9. D-1 이동 속도 실측 (tiles/s) — _resolve_move_speed_px 구현 그대로")
rows9 = [("기본 걷기", walk, "movement_data 역산 (16x3/0.35)/2.6"),
         ("공격 중 (x0.45)", walk * 0.45, "ATTACK_MOVE_SPEED_MULTIPLIER"),
         ("거미줄 둔화 (-40%)", walk * 0.6, "web_slow_pct 0.4 / 2.0s (야간 아종 3.0s)"),
         ("둔화 + 공격 중", walk * 0.6 * 0.45, "둔화는 곱연산 -> 0.45와 중첩"),
         ("궁수 조준 (x0.4)", walk * 0.4, "조준 배율이 0.45를 대체(곱하지 않음)"),
         ("둔화 + 조준", walk * 0.6 * 0.4, "둔화만 곱연산 중첩"),
         ("회피 대시", dash, "둔화·공격 중 무관(무적 이동기)")]
print(f"{'상태':22s}{'tiles/s':>10}{'기본 대비':>10}   근거")
for name, sp, note in rows9:
    print(f"{name:22s}{sp:>10.3f}{sp / walk * 100:>9.0f}%   {note}")
mspeeds = ", ".join(
    f"{n} {parse_tres('data/monsters/' + MON_FILES[n][0] + '.tres').get('combat_move_speed_tiles', 0):.1f}"
    for n in ("들개 마수", "숲거미", "무법자", "임프", "밀렵꾼"))
print(f"\n  [참조] 몬스터 전투 이동속도: {mspeeds} tiles/s")

PLAYER_R = 6.0 / TILE
hr("10. D-1 판정 이탈 검산 — 공격 중 이동만으로 예고를 흘릴 수 있는가")
print(f"  플레이어 캡슐 반경 {PLAYER_R:.3f}타일(6px) 포함. 몹은 예고~후딜 중 정지(velocity=ZERO).")
cases = [
    ("근접 스윙 (들개/임프, 예고 0.5s, 히트박스 1.5타일) — 사거리 경계에서 예고 시작", 0.5, 1.5, 1.5),
    ("근접 스윙 (같은 조건, 1.0타일까지 파고든 상태 = 소검 실전 거리)", 0.5, 1.5, 1.0),
    ("뿔토끼 박치기 (예고 0.4s)", 0.4, 1.5, 1.5),
    ("숲거미 도약 (예고 0.5 + 공중 0.35 = 0.85s, 착지 반경 1.0타일, 착지점=예고 시작 시 내 위치)",
     0.85, 1.0, 0.0),
    ("무법자·노상강도 돌진 (예고 0.6s, 경로 반경 1.5타일 — 측면 이탈)", 0.6, 1.5, 0.0),
]
speeds = [("정지(구 동작)", 0.0), ("공격 중 0.45", walk * 0.45),
          ("둔화+공격 중", walk * 0.6 * 0.45), ("걷기(비공격)", walk),
          ("둔화+걷기", walk * 0.6), ("조준(궁수)", walk * 0.4),
          ("둔화+조준", walk * 0.6 * 0.4)]
for label, t, radius, start in cases:
    need = radius + PLAYER_R - start
    print(f"\n  [{label}]")
    print(f"     필요 이탈 거리 {need:+.3f}타일 / 확보 시간 {t:.2f}초")
    for sname, sp in speeds:
        d = sp * t
        print(f"       {sname:16s} 이동 {d:6.3f}타일 -> {'이탈 성공' if d > need else '피격'}")

# ---------------- 그로기 ----------------
hr("11. 그로기 게이지 재검산 (레벨 무관 — HP 비율만으로 결정)")
G_RATIO, DUR, CD = 0.25, 3.0, 11.0
print(f"  게이지 최대 = 유효최대HP x {G_RATIO} / 지속 {DUR}s / 일반 타격 축적 = 최종 피해 1:1")
print(f"  난입 강타 쿨다운 {CD}s, 축적 = 게이지 최대치의 groggy_gain_ratio")
print("  모델: N x 최대게이지 = DPS x (TTK - 3.0xN) + 캐스트수 x ratio x 최대게이지")
print("        (그로기 중에는 add_groggy가 차단 -> 게이지 축적 없음. 구현 확인)")
print(f"\n{'정예 TTK 전제':>24}{'난입 축적비':>12}{'캐스트':>8}{'그로기':>9}{'무방비':>10}{'비중':>8}")
for ttk_e, lab in ((30.0, "설계 명목 30s"), (24.5, "구현 실측 24.5s")):
    for gain in (0.0, 0.20, 0.25):
        casts = (math.floor(ttk_e / CD) + 1) if gain > 0 else 0
        N = (1.0 + casts * gain * G_RATIO) / (G_RATIO + DUR / ttk_e)
        print(f"{lab:>24}{gain:>12.2f}{casts:>8}{N:>9.2f}{N * DUR:>9.1f}s"
              f"{N * DUR / ttk_e * 100:>7.1f}%")
print("\n  [레버 비교] groggy_gauge_hp_ratio 변경 (난입 0.25 유지, 명목 TTK 30s)")
print(f"{'ratio':>10}{'그로기 횟수':>14}{'무방비 시간':>14}{'무방비 비중':>14}")
for gr in (0.25, 0.30, 0.35):
    casts = math.floor(30.0 / CD) + 1
    N = (1.0 + casts * 0.25 * gr) / (gr + DUR / 30.0)
    print(f"{gr:>10.2f}{N:>14.2f}{N * DUR:>13.1f}s{N * DUR / 30.0 * 100:>13.1f}%")
