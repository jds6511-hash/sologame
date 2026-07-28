# 신규 적 7종 배치 — 씬 조립 · 권역 배정 · 월드 배선 (M3 Phase C-10)

- **제목**: 신규 적 7종 배치 — 씬 조립 · 권역 배정 · 월드 배선 (M3 Phase C-10)
- **최종 수정일**: 2026-07-29
- **담당**: level-designer
- **의존 문서**:
  - `docs\design\systems\m3-monster-spec.md` (2장 스탯, 3장 신규 행동 블록, 4장 종별 상세·무리 구성, 5장 드랍, 7장 아종 4종 정식 스펙, 8-1 총괄표)
  - `docs\design\levels\world-structure.md` (2장 레벨 밴드 동선, 4장 패밀리 #4~#6 권역 배정, 5장 주야간 지역 영향, 1-1 "가도 안전 통행" 규칙)
  - `docs\design\levels\eastern-frontier-start-map.md` (1장 좌표 체계, 3장 구역표, 4장 충돌 지형, 5장 M2 스폰 마커, 7장 퀘스트 연계 지점)
  - `docs\design\quests\quest-structure.md` (3-2절 MQ-01-01~05 — 시작 지역 동선 충돌 확인)
  - `docs\design\systems\combat.md` (2-2 다수 교전·귀환, 2-3 야간 배율, 5-2 정예 슈퍼아머, 8-1 곡선)
  - 구현체: `godot\scripts\ai\forest_spider_monster.gd`·`outlaw_monster.gd`·`imp_monster.gd`(ai-dev C-8), `godot\scripts\world\monster_spawner.gd`, `godot\scenes\monsters\wolf.tscn`(씬 구조 선례)
- **변경 이력**:
  - 2026-07-29: 최초 작성 — C-10 완료물. 신규 적 7종 씬(.tscn) 조립 규격·임시 스프라이트 매핑(정식 교체 지점 포함), 시작 지역(노베라 들녘) 숲거미 계열 배치 좌표, 밴드 초과 5종의 정식 배치 규격 예약, 검증 필드 씬, 월드 배선(스포너·드랍·EXP·야간 전용 스폰), 밸런스 안전장치 실측 표 확정.

> **범위**: 본 문서는 `m3-monster-spec.md`가 확정한 신규 7종(숲거미·그림자 숲거미·무법자·노상강도·밀렵꾼·임프·포효 임프장)의 **씬 조립 규격**과 **배치**를 다룬다. 스탯·행동 블록 수치는 spec이 마스터이며 본 문서는 수치를 재정의하지 않는다. 밸런스 실측(TTK·피격 예산)은 **Phase D** 소관이다.

---

## 1. 결론 요약

| 항목 | 결과 |
|---|---|
| 씬 조립 | 7종 전부 완료 (`godot\scenes\monsters\`) — `wolf.tscn` 구조 그대로 |
| 스프라이트 | **M2 기존 시트 3종을 임시 재사용**(신규 PNG 제작 없음). 종 구분은 루트 `modulate` 색조. 2-2장에 정식 교체 지점 명시 |
| 시작 지역 배치 | **숲거미(3) + 그림자 숲거미(2, 야간 전용)만** — 밴드 8~16 하단만 Lv1~12와 겹친다 |
| 밴드 초과 5종 | 시작 지역에 넣지 않는다(즉사 방지). 정식 배치 좌표 규격을 4장에 예약하고, 검증은 5장 전용 필드 씬에서 |
| 월드 배선 | `MonsterSpawner` 확장 + `MonsterDropRegistry` 신설로 드랍·처치 EXP·어그로·야간 스폰 전부 기존 흐름에 접속 |
| 진행 불가 위험 | 없음 (7장 실측 표 — Lv1 동선에 신규 적 인지 범위가 닿지 않음) |

---

## 2. 씬 조립 규격 (7종)

### 2-1. 노드 구조 (전 종 공통 — `wolf.tscn` 선례 그대로)

```
<종>Monster (CharacterBody2D)          collision_layer=4 / collision_mask=7
│   script = scripts/ai/<...>_monster.gd
│   stats  = data/monsters/<...>_stats.tres
│   modulate = <종별 임시 색조>          ← 임시 스프라이트 식별용 (2-2장)
├─ CollisionShape2D (CapsuleShape2D)    height >= 2 * radius 준수
├─ Sprite (AnimatedSprite2D)            idle / walk / attack / death 4종
├─ AttackHitbox (Area2D)                layer=0 / mask=2 / monitoring=false
│   └─ CollisionShape2D                 ← 반경은 코드가 주입(_setup_attack_hitbox)
├─ MobStagger (MobStaggerComponent)     rules = 체급별 .tres
└─ AttackResolver (MonsterAttackResolver)  monster_path=".." / formula_data=damage_formula.tres
```

- `AttackHitbox`의 판정 반경은 씬에 굽지 않는다 — 숲거미는 도약 착지 반경(1.0타일), 무법자는 근접 사거리(1.5타일), 임프는 근접 스윙 사거리를 각 스크립트 `_ready()`가 주입한다. 밀렵꾼(원거리)은 히트박스를 쓰지 않지만 구조 통일을 위해 노드는 둔다.
- **루트 노드에 `modulate`를 준 이유**: `MonsterBase._disable_attack_hitbox()`가 공격 판정 종료 시 `Sprite.modulate`를 흰색으로 되돌리기 때문에, 스프라이트 노드에 색조를 주면 첫 공격 후 사라진다. 루트(CanvasItem) `modulate`는 자식에 곱해지며 코드가 건드리지 않아 유지된다. 정식 스프라이트가 오면 이 색조는 전부 제거한다(2-2장).

### 2-2. 종별 씬 파일 · 임시 스프라이트 매핑 (**정식 교체 지점**)

| 종 | 씬 파일 | 스크립트 | 스탯 .tres | **임시 스프라이트(M2 재사용)** | 임시 색조(루트 modulate) | 캡슐 r/h | 몸통 y / Sprite offset y | MobStagger rules |
|---|---|---|---|---|---|---|---|---|
| 숲거미 | `forest_spider.tscn` | `forest_spider_monster.gd` | `forest_spider_stats` | `mob_wolf_feral_*` (36×28, 측면 행 y=28) | `(0.80, 0.62, 0.95)` 연자색 | 7.0 / 18.0 | −12 / −14 | light |
| 그림자 숲거미 | `shadow_forest_spider.tscn` | 〃 | `shadow_forest_spider_stats` | `mob_wolf_feral_*` | `(0.40, 0.38, 0.62)` 어두운 남자색 | 7.0 / 18.0 | −12 / −14 | light |
| 무법자 | `outlaw.tscn` | `outlaw_monster.gd` | `outlaw_stats` | `mob_rabbit_horned_*` (20×20, y=20) | `(0.88, 0.80, 0.62)` 가죽 갈색 | 5.0 / 14.0 | −8 / −10 | 표준 |
| 노상강도 | `highwayman.tscn` | 〃 | `highwayman_stats` | `mob_rabbit_horned_*` | `(0.92, 0.50, 0.44)` 붉은 완장 | 5.0 / 14.0 | −8 / −10 | 표준 |
| 밀렵꾼 | `poacher.tscn` | 〃 | `poacher_stats` | `mob_rabbit_horned_*` | `(0.60, 0.82, 0.56)` 수림 위장 | 5.0 / 14.0 | −8 / −10 | 표준 |
| 임프 | `imp.tscn` | `imp_monster.gd` | `imp_stats` | `mob_slime_crack_*` (36×36, y=36) | `(1.00, 0.70, 0.50)` 균열 주황 | 6.0 / 14.0 | −8 / −16 | light |
| 포효 임프장 | `imp_lord.tscn` | 〃 | `imp_lord_stats` | `mob_slime_crack_*` | `(1.00, 0.40, 0.32)` 정예 적색 | 6.0 / 14.0 | −8 / −16 | light |

- **임시 스프라이트 선정 근거**: `m3-monster-spec.md` 8-5장의 실루엣 방향에 가장 가까운 기존 시트를 골랐다 — 숲거미(낮고 넓은 다리 많은 벌레형) ← 들개 마수(사족), 무법자 계열(직립 소형 인간형) ← 뿔토끼, 임프 계열(균열 계열·낮은 체고) ← 균열 점액(같은 균열 진영). 계열끼리는 같은 시트를 쓰고 **색조로만 구분**하므로, 화면상 종 식별은 정식 스프라이트가 오기 전까지 제한적이다(행동 패턴·배치 검증이 목적).
- **정식 교체 지점 (pixel-artist C-9 완료 시 해야 할 일)**:
  1. 각 씬의 `[ext_resource type="Texture2D" ...]` 4줄(idle/walk/attack/death)을 신규 시트 경로로 교체.
  2. `AtlasTexture` 서브리소스의 `region = Rect2(i*w, row_y, w, h)`를 신규 시트 규격으로 교체(현재 프레임 수 idle 4 / walk 4 / attack 5 / death 4).
  3. 루트 `modulate` 줄 **삭제**(팔레트가 스프라이트에 들어가므로 색조 불필요. 단 그림자 숲거미·포효 임프장은 팔레트 스왑 아종이므로 정식 스프라이트에서 색이 갈린다).
  4. spec 8-5장 신규 상태 프레임이 들어오면 `SpriteFrames`에 애니메이션 추가 — 코드 수정 불요. `MonsterBase._play_animation_or()`가 이름만 있으면 자동 승격한다(숲거미 `crouch`/`leap`/`land`, 무법자 `charge_telegraph`/`charge`/`guard`, 밀렵꾼 `aim`, 임프 `vanish`/`appear`/`roar`, 숲거미 `web`).
  5. 회귀 테스트 `test/world/test_m3_enemy_scene_wiring.gd`는 텍스처 경로를 검사하지 않으므로 교체해도 깨지지 않는다(애니메이션 4종 존재만 계약).

### 2-3. 콜리전 캡슐 규격 (M2 degenerate 캡슐 문제 재발 방지)

Godot의 `CapsuleShape2D`는 `height < 2*radius`면 반경이 강제로 줄어들어 실제 판정이 의도와 달라진다(M2에서 발생). 7종 전부 **height ≥ 2·radius**를 지켰고, 회귀 테스트가 이를 강제한다.

| 종 | radius | height | 2·radius | 여유 |
|---|---:|---:|---:|---:|
| 숲거미 · 그림자 숲거미 | 7.0 | 18.0 | 14.0 | +4.0 |
| 무법자 · 노상강도 · 밀렵꾼 | 5.0 | 14.0 | 10.0 | +4.0 |
| 임프 · 포효 임프장 | 6.0 | 14.0 | 12.0 | +2.0 |

### 2-4. 투사체 슬롯 (ai-dev 인수 사항 4 이행)

| 종 | 슬롯 | 임시 할당 | 피해 | 비고 |
|---|---|---|---|---|
| 숲거미 · 그림자 숲거미 | `web_projectile_scene` | `scenes/monsters/rift_slime_projectile.tscn` | **없음** | 스크립트가 `configure(0.0, null)`을 넘겨 직격 피해가 원천 차단된다(spec 3-2 무피해 원칙). 명중 시 둔화만 적용 |
| 밀렵꾼 | `projectile_scene` + `formula_data` | `rift_slime_projectile.tscn` + `data/combat/damage_formula.tres` | **있음** | `configure(effective_attack_power(), formula)` — spec 7-3 석궁 계수 1.0 |

- 정식 교체 지점: vfx-artist가 거미줄·석궁 볼트 전용 투사체 씬을 만들면 두 슬롯의 `PackedScene`만 갈아끼운다(스크립트 수정 불요 — `configure`/`launch`/`hit_target` duck-typing 계약 동일).

---

## 3. 시작 지역 배치 — 노베라 들녘 (Lv1~12)

### 3-1. 판단: 시작 지역에는 숲거미 계열만 넣는다

`world-structure.md` 2장 밴드 표에서 시작 지역(1번 항목 "노베라 들녘 · 여울목 옛 균열 굴")은 **Lv1~12**다. 신규 7종의 밴드/대표 레벨과 교집합을 보면:

| 종 | 밴드 (world-structure 4장) | 대표 Lv | Lv1~12와 교집합 | 시작 지역 배치 |
|---|---|---:|---|---|
| 숲거미 | 동부 들녘 숲 8~16 | 10 | **8~12 있음** | **배치** |
| 그림자 숲거미 | 동부 들녘 숲 8~16 (야간 전용) | 10 | **8~12 있음** | **배치**(야간 전용) |
| 무법자 | 동부 가도 10~18 | 14 | 밴드는 겹치나 **대표 Lv14 > 12** | 미배치 |
| 노상강도 | 중부 왕국 대로 (Lv20) | 20 | 없음 | 미배치 |
| 밀렵꾼 | 서부 수림길·대수림 외곽 (Lv36) | 36 | 없음 | 미배치 |
| 임프 | 균열 외곽 12~20 | 16 | 하한만 접함 | 미배치 |
| 포효 임프장 | 균열 외곽 던전·균열 포인트 (정예) | 16 | 없음 | 미배치 |

- **무법자를 시작 지역 대로 동단에 두지 않은 이유**: `world-structure.md` 1-1은 "가도 위와 주변 1~2타일은 해당 구간 밴드의 **하한** 레벨 몬스터만"이라고 규정하고, 시작 지역 맵의 동쪽 출구는 동부 가도가 아니라 **노베라 읍 방향**이다(`eastern-frontier-start-map.md` 3장). 즉 이 맵의 대로는 Lv1~12 구간의 안전 통행로이므로 Lv14 무법자를 두면 규정 위반이자, Lv1 모험가가 대로를 따라 동쪽으로 걷다 즉사할 수 있다(무법자 공격력 65 vs Lv1 플레이어 최대 HP 135 → 3대 사망). **미배치가 정답.**
- 임프(Lv16)의 밴드 하한 12가 시작 지역 상한 12와 맞닿지만, 임프의 서식 권역은 "균열 외곽(돌무지)"으로 **다음 지역**이다(world-structure 2장 2번 항목 Lv10~18). 시작 지역의 균열 굴 어귀에는 이미 M2 균열 점액(Lv8)이 "위험 신호"로 배치되어 있으므로 역할이 중복된다 — 임프는 균열 외곽 정식 배치를 기다린다(4장).

### 3-2. 숲거미 계열 배치 좌표

기존 맵 좌표계(`eastern-frontier-start-map.md` 1장 — 48×36타일, 타일 16px, 마커 위치는 타일 중심 = `tile*16 + 8`)를 그대로 쓴다. **여울목 개울(y=13~15, 도섭 지점 x=8~10만 통행)을 자연 게이트로 삼아 개울 북쪽에만 배치**한다.

| 그룹 (씬 노드 경로) | 마커 | 좌표 (x,y) 타일 | position (px) | 스폰 규칙 |
|---|---|---|---|---|
| `Markers/MonsterSpawns_숲거미` | `ForestSpiderSpawn_A` | (18, 9) | (296, 152) | 마커당 **1마리** (개별 급습 — 어그로 공유 없음) |
| 〃 | `ForestSpiderSpawn_B` | (23, 6) | (376, 104) | 〃 |
| 〃 | `ForestSpiderSpawn_C` | (21, 12) | (344, 200) | 〃 |
| `Markers/MonsterSpawns_그림자숲거미_야간` | `ShadowSpiderSpawn_A` | (25, 9) | (408, 152) | **야간에만** 마커당 1마리 |
| 〃 | `ShadowSpiderSpawn_B` | (20, 4) | (328, 72) | 〃 |

- **무리 규칙 재현 (spec 4-1 "2~3마리, 어그로 공유 없음, 각자 개별 급습")**: `PackAggroCoordinator`를 쓰지 않고(스크립트에 `pack_id` 개념 자체가 없다) 마커 3개를 **서로 4.5~5.8타일 간격**으로 묶어 배치했다. 인지 범위 6타일이라 플레이어가 숲 포켓 안으로 들어오면 2~3마리가 **각자 따로** 달려온다 — 무리 어그로 없이 "2~3마리 급습"이 성립한다.
- **야간 밀도(spec 7-1 "야간 스폰 밀도는 일반 숲거미 대비 상향, 정확한 밀도·교체 비율은 C-10 배치에서")**: 낮 3마리 → 밤 5마리(일반 3 + 야간 아종 2, **아종 비중 40%**)로 확정. `world-structure.md` 5장 "일반 필드 = ×1.2 + 야행 아종 일부 교체 스폰"에 대해 **교체가 아니라 추가**를 택했다 — 진짜 교체는 전투 중인 개체를 소멸시켜야 해서 연출이 부자연스럽고, 야간 아종 조우를 확실히 보장하는 편이 도감(`collection.md`) 수집에도 유리하다. 밀도 자체는 Phase D 튜닝 레버다.

### 3-3. ASCII 배치도 (기존 3장 스케치에 신규 배치를 얹은 것)

```
y=0   ┌──────────────────────────────────────────────┐  (맵 북쪽 경계 — 바위, 충돌)
      │        [균열 점액 지역]        ✦S그림자B(20,4)   │
      │   ▲슬라임A   ●균열굴어귀(9,5)  ▲슬라임B  ✦숲B(23,6) │  ← MQ-01-04 REACH
      │        (균열 흉터 대지 + 폐허 잔해 + 바위)          │
      │        │오솔길(x=9)   [★신규 — 동부 들녘 숲 Lv8~16] │
      │        │      ✦숲A(18,9)  ✦S그림자A(25,9)         │
y=12  │        │              ✦숲C(21,12)                │
      │  ══════╪═════ 여울목 개울물 (도섭 지점 x=8~10) ════╡ ← 자연 게이트
      │        │                    [들개 마수 지역]       │
y=18  │        │              ▲DogPackA  ▲DogPackB        │
      │  ┌───┐ │  [뿔토끼 서식지/개척 농지]                 │
      │  │부락│═╪══════ 대로(노베라 방향) ═════════════════╡→ 노베라 방향 출구
y=27  │  │Ｎ★│ │ ▲RabbitA ▲RabbitB ▲RabbitC               │   (신규 적 없음 — 3-1장)
      │  │Ｐ⚑│ 대문(17,27~29)                              │
      │  └───┘                                            │
y=35  └──────────────────────────────────────────────┘
      x=0                                              x=47
```

범례 추가: `✦`=신규 적 스폰 마커(숲=숲거미 / S그림자=그림자 숲거미 야간 전용). 나머지 기호는 `eastern-frontier-start-map.md` 2장과 동일.

---

## 4. 정식 배치 규격 — 지역 씬 미구현 5종 (예약)

해당 지역 씬이 만들어질 때 **아래 규격 그대로** 배치한다. 지금은 5장 검증 필드에서만 살아 있다.

| 종 | 정식 서식 권역 (world-structure) | 밴드 | 무리 규칙 (spawner 상수) | 배치 밀도·형태 규격 |
|---|---|---|---|---|
| 무법자 | 동부 가도 (노베라↔발크렌) | 14~20 | `OUTLAW_PACK_SIZE = 2~3`, 동일 `pack_id`, 공격 토큰 2 | 가도 **주변** 매복 지점 2~3곳. 가도 노면 및 좌우 1~2타일은 비운다(world-structure 1-1 안전 통행). 마커 간 12타일 이상 |
| 노상강도 | 중부 왕국 대로 (한길목~브란텔 근교) | 18~24 | `HIGHWAYMAN_PACK_SIZE = 3~4` | 대로 매복 지점 2곳 + 역참(한길목) 외곽 1곳. 무리가 1마리 많으므로 마커 간 14타일 이상 |
| 밀렵꾼 | 서부 수림길 · 대수림 외곽 | 33~43 | `POACHER_PACK_SIZE = 1~2` (매복형) | 사거리 6타일·인지 7타일이라 **엄폐물(나무·바위) 뒤 고지형**에 단독 배치. 근접 몹(가시덩굴 #14)과 4~6타일 떨어뜨려 "원거리+근접 협공"이 되게 함 |
| 임프 | 균열 외곽 (돌무지) | 12~20 | `IMP_PACK_SIZE = 2~4` | 소균열 오브젝트 주변 3~4곳. 순간이동 최대 5타일이라 마커 주변 6타일 안에 벽·지형을 두어 블링크 각을 제한(spec 6장 궁수 대응 "지형으로 블링크 각 제한") |
| 포효 임프장 | 균열 외곽 던전 심부 · 균열 포인트 | 정예 (Lv16) | `IMP_LORD_ESCORT_SIZE = 2~3` (임프장 1 + 호위 임프) | **권역당 1곳**. 정예이므로 던전 심부 또는 명확히 구분되는 균열 포인트에만. 호위 임프는 임프장 반경 1.25타일 원 둘레(포효 반경 6타일 안 → 버프가 항상 성립) |

- 무법자 계열 3종은 `outlaw_monster.gd` 하나를 공유하므로 `pack_id` 접두사만 종별로 다르게 준다(`outlawpack_` / `highwaymanpack_` / `poacherpack_`) — 서로 다른 종이 같은 무리로 묶이지 않게.
- 밀렵꾼(Lv36)은 서부 밴드다. **Lv5~20 구간 어디에도 배치 금지** — 공격력 224로 Lv10 플레이어(HP 315)를 2대에 죽인다.

---

## 5. 검증 필드 씬 (임시 무대)

`godot\scenes\world\m3_new_enemy_field.tscn` — 밴드 초과 5종을 시작 지역에 섞지 않고 검증하기 위한 **전용 씬**이다. 정식 지역 씬(동부 가도·중부 대로·서부 수림길·균열 외곽)이 만들어지면 4장 규격대로 옮기고 **이 필드는 폐기**한다.

- 한 구역 16×15타일, 3열 × 2행. 구역 간 16타일 = 최대 인지 범위(밀렵꾼 7타일)의 2배 이상이라 구역끼리 어그로가 새지 않는다(회귀 테스트가 강제).
- 플레이어 시작 (4,15)타일 = (72,248)px — 어느 구역 대표 마커에서도 10타일 이상 떨어져 진입 즉시 어그로되지 않는다.

```
        x=0        16         32         48    (타일)
  y=0   ┌──────────┬──────────┬──────────┐
        │[A1] 동부  │[A2] 동부  │[A3] 중부  │
        │ 들녘 숲   │ 가도      │ 왕국 대로 │
        │ Lv8~16   │ Lv10~18  │ Lv18~24  │
  y=7   │ ✦숲×3     │ ✦무법자   │ ✦노상강도 │
        │ ✦S그림자×2│  무리2~3  │  무리3~4  │
  y=15  ├─Ｐ(4,15)──┼──────────┼──────────┤
        │[B1] 서부  │[B2] 균열  │[B3] 균열  │
        │ 수림길    │ 외곽      │ 포인트    │
        │ Lv33~39  │ Lv12~20  │ (정예)    │
  y=23  │ ✦밀렵꾼   │ ✦임프     │ ✦임프장1  │
        │  1~2     │  무리2~4  │  +호위2~3 │
  y=30  └──────────┴──────────┴──────────┘
```

| 구역 | 그룹 노드 | 대표 마커 좌표 (타일) | position (px) | 스폰 |
|---|---|---|---|---|
| A1 | `Markers/MonsterSpawns_숲거미` | (8,7) (12,7) (10,4) | (136,120) (200,120) (168,72) | 마커당 1마리 = 3마리 |
| A1 | `Markers/MonsterSpawns_그림자숲거미_야간` | (8,10) (12,10) | (136,168) (200,168) | 야간 전용, 마커당 1마리 |
| A2 | `Markers/MonsterSpawns_무법자` | (26,7) | (424,120) | 무리 2~3 |
| A3 | `Markers/MonsterSpawns_노상강도` | (42,7) | (680,120) | 무리 3~4 |
| B1 | `Markers/MonsterSpawns_밀렵꾼` | (10,23) | (168,376) | 1~2 |
| B2 | `Markers/MonsterSpawns_임프` | (26,23) | (424,376) | 무리 2~4 |
| B3 | `Markers/MonsterSpawns_임프장균열포인트` | (42,23) | (680,376) | 임프장 1 + 호위 임프 2~3 (동일 `pack_id`) |

- 배경은 정식 타일셋이 아닌 체커 격자(`scripts\world\m3_enemy_field_grid.gd`) — 이동·사거리 감각 확인용.
- 스크린샷 재현: `godot --path godot res://scenes/world/m3_new_enemy_field.tscn -- --capture` (7장 참조).

---

## 6. 월드 배선

### 6-1. 스폰 (`godot\scripts\world\monster_spawner.gd`)

M2 3종 방식(마커 그룹 = `NodePath` export)을 그대로 확장했다. 신규 export 7개:

| export | 스폰 방식 | 상수 |
|---|---|---|
| `forest_spider_spawn_root_path` | 마커당 1마리 (개별 급습) | — |
| `shadow_forest_spider_night_spawn_root_path` | **야간 전용** — 마커당 1마리, 낮에 소멸 | — |
| `outlaw_pack_spawn_root_path` | 마커당 무리 + `pack_id` | `OUTLAW_PACK_SIZE = (2,3)` |
| `highwayman_pack_spawn_root_path` | 〃 | `HIGHWAYMAN_PACK_SIZE = (3,4)` |
| `poacher_spawn_root_path` | 〃 | `POACHER_PACK_SIZE = (1,2)` |
| `imp_pack_spawn_root_path` | 〃 | `IMP_PACK_SIZE = (2,4)` |
| `imp_lord_camp_spawn_root_path` | 마커 중심에 임프장 1 + 원 둘레에 호위 임프, **같은 `pack_id`** | `IMP_LORD_ESCORT_SIZE = (2,3)` |

- 무리 산개는 M2 들개 마수의 원 둘레 균등 배치(반경 1.25타일 + 각도 지터 20°)를 **공용 헬퍼로 승격**해 재사용한다 — 전 종 무리 상한이 4마리라 개체 간 최소 간격 1.4타일이 보장된다(개체가 완전히 겹쳐 보이던 M2 문제 방지).
- `pack_id`·`global_position`·`target`은 모두 `add_child()` **전에** 주입한다 — 각 몬스터 `_ready()`가 그 값으로 무리 그룹 등록·`home_position` 캡처를 하기 때문(귀환/도주 판정 기준점).
- 마커 그룹 단위로 한 프레임씩 양보(`await get_tree().process_frame`)해 진입 스톨을 피한다(M2 tech-artist 프로파일링 대응 방식 유지).

### 6-2. 야간 전용 스폰 (그림자 숲거미)

- `GameClock.night_started` → 야간 마커에서 스폰, `GameClock.day_started` → `queue_free()`로 소멸. 씬 진입 시점이 이미 밤이면 즉시 스폰한다.
- **소멸은 `died`를 발신하지 않으므로 낮 전환에 드랍·경험치가 붙지 않는다**(의도 — 밤을 넘겼다고 보상이 생기면 안 된다).
- 야간 신호가 중복으로 와도 개체가 누적되지 않게, 스폰 전 항상 이전 야간 개체를 정리한다.
- 야간 스탯 ×1.2 / EXP ×1.2 / 아이템 드랍 ×1.15는 `monster_base.gd`·`PlayerProgression`·`DropSystem`이 런타임에 적용하므로 배치 쪽 처리는 없다(spec 7-1과 정합).

### 6-3. 드랍 · 처치 경험치 (`godot\scripts\world\monster_drop_registry.gd` 신설)

M2는 월드 루트가 `is WolfMonster` 식 **클래스 분기**로 드랍 테이블을 골랐다. M3 신규 종은 한 스크립트가 여러 종을 담당하므로(ForestSpiderMonster = 숲거미·그림자 숲거미 / OutlawMonster = 무법자·노상강도·밀렵꾼 / ImpMonster = 임프·포효 임프장) 클래스로는 아종을 구분할 수 없다. 따라서 **`stats.display_name` → `DropTableData`** 매핑 레지스트리를 신설했다(10종 전부 `MonsterStatsData.display_name` == `DropTableData.monster_display_name`이 1:1로 일치함을 데이터에서 확인, 회귀 테스트가 보증).

```
MonsterSpawner.monster_spawned ─→ 월드 루트 _register_monster()
                                    ├─ MonsterDropRegistry.table_for(monster)
                                    ├─ DropSystem.register_monster(monster, table)      (골드·재료·포션·장비)
                                    └─ PlayerProgression.register_monster(monster, table) (처치 EXP)
```

- 시작 지역 씬(`eastern_frontier_starting_area.gd`)과 검증 필드 씬이 **같은 배선**을 쓴다. 신규 종을 추가할 때 레지스트리 표에 한 줄 넣으면 드랍·EXP가 함께 붙는다.
- 어그로: `target`(플레이어)은 기존과 동일하게 스포너가 외부 주입한다. 무리 어그로 공유는 각 몬스터가 `pack_id` 그룹으로 처리(`PackAggroCoordinator` 공격 토큰 2).

---

## 7. 밸런스 안전장치 — 진행 불가 검증

밸런스 실측은 Phase D 소관이므로, 여기서는 **배치가 진행을 막지 않는지**만 실측했다(회귀 테스트가 전부 자동 검증).

| 검증 항목 | 기준 | 실측 | 판정 |
|---|---|---|---|
| 신규 적이 Lv1 동선(부락·뿔토끼 서식지·대로)에 닿는가 | 인지 범위 6타일 밖 | 숲거미 계열 전부 개울 **북쪽**(y ≤ 12타일), Lv1 동선은 y ≥ 18타일 → 최소 6타일 + 개울(충돌 지형) 차단 | ✔ |
| 플레이어 시작 지점에서 최근접 신규 적 거리 | 즉시 조우 없음 | 시작 (9,31) → 최근접 숲거미 C(21,12) **22.5타일** | ✔ |
| 숲거미가 개울을 넘어 Lv1 구간까지 추격하는가 | 귀환 거리(leash) 8타일 이내 | C(21,12) → 도섭 지점(10,14) **11.2타일** > 8 → 도섭 남쪽 진입 전에 귀환 | ✔ |
| MQ-01-04 동선(균열 굴 REACH·INTERACT)과 충돌 | 인지 6타일 밖 | REACH(9,5) 최근접 9.9타일 / INTERACT(11,4) 최근접 8.1타일 | ✔ |
| 야간에 균열 점액(Lv8)과 그림자 숲거미 동시 조우 | 인지 6타일 밖 | 슬라임B(13,6) → 그림자B(20,4) **7.3타일** | ✔ |
| 신규 적 마커끼리 겹침 | 3타일 이상 | 최소 3.6타일 (그림자B–숲B) | ✔ |
| 밴드 초과 종이 시작 지역에 있는가 | 없어야 함 | 시작 지역 스포너에 무법자~임프장 배선 **없음** | ✔ |
| 검증 필드 구역 간 어그로 누출 | 최대 인지 7타일 초과 간격 | 최소 16타일 | ✔ |

- **Lv1 모험가 기준 즉사 위험 계산**: Lv1 최대 HP 135, 숲거미 공격력 45(야간 54) → 3대(야간 3대). 숲거미가 있는 개울 북쪽은 이미 M2에서 균열 점액(Lv8)이 배치된 "위험 신호" 구간이며, 플레이어는 도섭 지점을 **스스로 건너야** 진입한다. Lv10 전직 이후(HP 315) 3대→7대로 완화되어 밴드 8~16의 정상 난이도가 된다.
- 실제 렌더 검증에서 Lv1 모험가로 무법자(Lv14)·노상강도(Lv20)와 교전하면 HP 135 → 29까지 떨어졌고 상대 HP는 거의 줄지 않았다 — **시작 지역 미배치 판단이 옳았음을 실측으로 확인**.

---

## 8. 타 문서 연계 / 후속 작업

| 대상 | 내용 |
|---|---|
| pixel-artist (C-9) | 2-2장 "정식 교체 지점" 5단계. 계열별 실루엣은 spec 8-5장 규격, 아종은 팔레트 스왑 |
| vfx-artist | 2-4장 투사체 슬롯(거미줄·석궁 볼트 전용 씬), 순간이동 소멸/등장·포효 이펙트 |
| ai-dev | 9장 1번 항목(돌진 경로 판정의 엔진 경고) 처리 요청 |
| systems-designer / Phase D | 3-2장 야간 밀도(낮 3 → 밤 5), 4장 정식 배치 밀도는 밸런스 실측 튜닝 레버 |
| quest-designer | 시작 지역 신규 배치는 MQ-01-01~05 동선과 충돌하지 않음(7장 실측). 숲거미 계열을 KILL 대상으로 쓰는 서브퀘를 만들 경우 **Lv10 이후 권장**(개울 북쪽 = 전직 이후 사냥터) |
| level-designer (후속) | 4장 규격에 따른 동부 가도 · 중부 왕국 대로 · 서부 수림길 · 균열 외곽 맵 씬 제작 시 이관, 그 후 검증 필드 씬 폐기 |

---

## 9. 디렉터 결정 필요

- **없음** (본 문서는 `m3-monster-spec.md`·`world-structure.md` 확정 범위의 배치 구체화이며 게임 방향을 바꾸는 결정을 포함하지 않는다).

**개발 협의 사항 (디렉터 결정 아님)**

1. **돌진 경로 판정의 엔진 경고 — ai-dev 처리 요청**: 무법자·노상강도의 돌진이 플레이어에 접촉하는 순간 `ERROR: Function blocked during in/out signal. Use set_deferred("monitoring", true/false)`가 발생한다. `outlaw_monster.gd:250 _on_charge_path_hit` → `monster_base.gd:312 _disable_attack_hitbox`가 `body_entered` 시그널 처리 중에 `Area2D.monitoring`을 직접 끄기 때문이다(M2 3종은 히트박스를 블록 타이머에서 끄므로 발생하지 않았다). 기능은 동작하나(`_charge_hit_landed` 가드 + `_on_charge_ended`에서 정상 해제) 콘솔 오류가 남고, 돌진 중 플레이어가 히트박스를 나갔다 다시 들어오면 "접촉 시 1회" 규격이 깨질 수 있다. `scripts/ai`·`scripts/combat`은 본 태스크의 수정 금지 영역이라 손대지 않았다 — `set_deferred("monitoring", false)` 또는 `call_deferred`로 한 줄 수정이면 해소된다.
2. **검증 필드 씬의 수명**: 5장 필드는 정식 지역 씬이 생기면 폐기하는 임시물이다. Phase D 밸런스 실측·디렉터 확인 무대로 쓰다가, 4장 규격 이관이 끝나면 씬·스크립트·격자 배경을 함께 삭제한다.
