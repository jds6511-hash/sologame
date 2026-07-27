# M3 성장↔장비 스탯 배선 확정 (책임 분리)

- **최종 수정일**: 2026-07-27
- **담당**: systems-designer
- **의존 문서**:
  - `docs\design\systems\growth.md` (1-2 파생 공식·2-2 검산표·3장 장비 8슬롯 기준선)
  - `docs\design\systems\m3-leveling-spec.md` (5-2 책임 분리·7-3 gear 기준선·7-5 기존 리소스 연동)
  - `docs\design\systems\combat.md` (6장 데미지 공식·8-1 기준선 "동렙 B급, 장신구·칭호·펫 제외")
  - `docs\design\economy\economy-foundation.md` (2장 등급 배율·2-6 "동렙 B급 8슬롯 자연 유지")
  - `docs\design\M3_PLAN.md` (1-4 명시적 제외·B-2 검증 기준·Phase D)
  - 구현체: `godot\scripts\progression\stat_growth_formula.gd`, `stat_growth_calculator.gd`, `player_stat_growth.gd`, `godot\scripts\items\inventory_component.gd`, `godot\scripts\combat\combatant_stats.gd`
- **변경 이력**:
  - 2026-07-27: 최초 작성 — B-2(커밋 8738b24) 이중 계산 충돌 해소. 검산표 해석 확정(동렙 B급 포함), M3 즉시 배선(성장 단독 권위·인벤토리 combat_stats 비배선) + Post-M3 목표(책임 완전 분리) 2단계 확정, dev 구현 지시.

---

## 0. 결론 요약 (TL;DR)

1. **검산표 해석**: growth.md 2-2는 **"동렙 B급 장비 착용" 상태**다(순수 성장 아님). 공격력·방어력에 B급 장비분이 포함돼 있다 — 문서 명문 + 검산 산술 + combat.md 8-1 기준선이 모두 일치. **디렉터 결정 불요(사실 판정).**
2. **M3 배선(즉시)**: 성장 계층(StatGrowthFormula.gear_*)이 **B급 장비 기준선을 계속 공급**하고, **InventoryComponent는 공유 CombatantStats에 쓰지 않는다**(scene에서 `combat_stats` 미할당). → 이중 계산·스테일 base 둘 다 원천 소멸, 플레이어가 검산표에 정확히 안착.
3. **Post-M3 목표(장비→전투 도입 시)**: gear_*→0(성장=순수 스탯), InventoryComponent가 장비분 전량을 절댓값으로 공급 + base 재캡처. 이관 명세는 4-2장.
4. **Phase D 전제**: D-1/D-3 실측 전 위 2번(인벤토리 비배선)이 반드시 적용돼야 한다. 안 그러면 TTK·피격 예산 측정이 오염된다.

---

## 1. 검산표 해석 확정 — "동렙 B급 장비 착용"

growth.md 2-2 검산표(및 이를 재현한 m3-leveling-spec 2-3)는 **장비 미착용 순수 성장이 아니라, 동렙 B급 장비를 착용한 최종 전투 스탯**이다. 근거 3중:

**① 문서 명문**
- growth.md 2-2 제목: "기준선 검산표 (전사, **동렙 B급 장비** — combat.md 8-2와 동일 모델)".
- growth.md 1-2 공격력 공식: `무기 공격력 + 주스탯×2` — **무기항이 공식에 명시**되어 있다.
- combat.md 8-1: 몬스터 곡선의 플레이어 기준선 = "전사 + **동렙 B급 무기/방어구**, 장신구·칭호·펫 제외". 검산표 = 이 곡선의 입력값.

**② 산술 검산 (공격력·방어력에 장비분이 실재)**

| 항목 | 순수 스탯분 | B급 장비분 | 합(=검산표) |
|---|---:|---:|---:|
| Lv1 공격력 | 힘8×2 = 16 | 무기 8+1.6×1 = 9.6 | 25.6 → **26** ✓ |
| Lv1 방어력 | 체력8×1 = 8 | 방어구 5+1.5×1 = 6.5 | 14.5 → **14** ✓ |
| Lv100 공격력 | 힘246.5×2 = 493 | 무기 8+1.6×100 = 168 | **661** ✓ |

- growth.md 4장이 직접 확인: "Lv100 전사 기준 **무기 168 : 스탯 493**" → 합 661. 순수 성장이라면 493이어야 하나 표는 661 → **장비분 168이 표에 포함**됨이 확정.

**③ HP/MP/치명타는 장비항 없음(순수)**
- HP `50+체력×10+레벨×5`(Lv1=135), MP `30+지력×5+레벨×2`, 치명타 `5+민첩×0.05`에는 장비항이 없다. **B급 4부위 방어구 기준선은 방어력에만, B급 무기는 공격력에만** 기여한다(장신구는 기준선 제외 → HP/MP/치명타에 기준선 가산 없음).
- **따라서 배선 결정이 건드리는 필드는 `attack_power`와 `defense` 둘뿐이다.** `max_hp`·`max_mp`·`agility`(치명타 경유)는 어느 안에서도 순수 성장 그대로다.

**결론**: 검산표 = 성장(순수 스탯) + 동렙 B급 장비. 현행 StatGrowthCalculator.apply가 `gear_weapon_attack`/`gear_armor_defense`를 더해 이 값을 재현하는 것은 **검산표와 정합**이며, B-2 구현이 표를 맞추려 gear_*를 공급한 것은 잘못이 아니다. 문제는 "장비분을 성장 계층과 인벤토리가 동시에 공급"하는 이중 배선뿐이다.

---

## 2. 충돌의 정확한 구조 (사실 확인)

두 계층이 같은 CombatantStats의 `attack_power`·`defense`에 동시에 쓴다.

- **성장 계층** `StatGrowthCalculator.apply`(player_stat_growth.gd가 `leveled_up` 구독):
  `attack_power = (8+1.6L) + 주스탯×2`, `defense = (5+1.5L) + 체력×1` — **B급 장비분 포함**.
- **인벤토리 계층** `InventoryComponent._recompute_equipment_stats`:
  `attack_power = _base_attack_power + Σ아이템`, `_base_*`는 `_ready()`에서 **1회만** 캡처.

| # | 충돌 | 원인 |
|---|---|---|
| (a) 스테일 base | 레벨업 후 장비 착·탈 시 인벤토리가 `_ready` 시점의 Lv1 base로 덮어써 성장분 소실 | `_base_*`를 재캡처하지 않음 |
| (b) 이중 계산 | 실제 무기/방어구 착용 시, 성장의 gear_* 기준선 위에 아이템분이 또 더해짐 | 장비분을 두 계층이 각각 공급 |

---

## 3. M3 배선 확정 (즉시 적용 — Phase D 블로커)

**성장 계층이 전투 스탯의 단독 권위이며 B급 장비 기준선을 계속 공급한다. InventoryComponent는 M3 동안 공유 CombatantStats에 쓰지 않는다.**

- StatGrowthFormula.gear_* **유지**(변경 없음) → 성장 결과가 검산표(=combat.md 8장 곡선 입력값)에 정확히 안착.
- InventoryComponent를 공유 CombatantStats에서 **분리**(scene의 `combat_stats` export 미할당) → `_ready`·`_recompute_equipment_stats`의 기존 null 가드로 자동 no-op. 줍기·골드·가방·장착 딕셔너리·UI 시그널은 그대로 동작(드랍은 M3 포함 — M3_PLAN 1-4).
- Lv1 스냅샷 `warrior_lv1_combatant_stats.tres`(공격 26/방어 14, B급 포함) **유지** → 성장 재계산(Lv2~)과 연속(불일치 없음).

**근거(왜 M3에서 완전 분리 대신 인벤토리 비배선인가)**
- M3_PLAN 1-4가 **장비/인벤토리를 전투에 반영하는 시스템을 M3 범위 밖으로 명시 제외**(명성·영지·펫·칭호·도감 등과 함께). 드랍만 포함. → M3 G3 게이트(레벨업 성장감·2직업 차별화·전투 다양성·난이도 곡선)에 "장비→전투" 판정 축이 없다.
- 이 안은 코드 변경 0(성장 계층 불변) + scene 1줄(인벤토리 combat_stats 미할당)으로 충돌 (a)(b)를 **동시에** 제거한다. 플레이어가 검산표에 자동 안착하므로 Phase D가 별도 셋업 없이 유효(3장 이유).
- 완전 분리(gear_*→0)는 시작 장비 지급·B급 테스트 아이템 수치 저작·Lv1 .tres 재생성을 M3에 끌어와야 해 범위·오차원이 늘고, 이득(장비→전투)은 M3 게이트에 불필요. → CLAUDE.md "Simplicity First"에 따라 Post-M3로 미룬다.

**한계(의도된 것, 4장 플래그 참조)**: M3에서 아이템을 장착해도 전투 스탯은 변하지 않는다. M3 승인 범위(1-4)와 정합하나 디렉터 체감상 유의할 항목.

---

## 4. 구현 지시 (dev)

실제 코드는 후속 태스크(B-5 / 후속 dev). 본 장은 명세.

### 4-1. M3 즉시 (충돌 해소)

| 대상 파일 | 소관 | 지시 |
|---|---|---|
| `stat_growth_formula.gd` | systems (본인 영역) | **변경 없음.** gear_* 유지. 상단 주석의 "인벤토리 배선 시 0 처리"는 Post-M3(4-2) 조건으로 유효 — M3에서는 아직 0으로 두지 말 것. |
| `stat_growth_calculator.gd` / `player_stat_growth.gd` | systems | **변경 없음.** 현행 `apply`가 검산표를 정확히 재현. |
| InventoryComponent가 배치된 **scene** (player.tscn 또는 world) | systems-dev (지침만) | InventoryComponent 노드의 `combat_stats` export를 **미할당(null)로 둔다** — 공유 CombatantStats 인스턴스를 넣지 말 것. 기존 null 가드(`_ready`·`_recompute_equipment_stats`)로 전투 스탯 미기입. 코드 수정 불요, scene 배선만. |
| `inventory_component.gd` | systems-dev (지침만) | **코드 변경 없음.** combat_stats가 null이면 자동 no-op. |
| `warrior_lv1_combatant_stats.tres` | systems-dev | **변경 없음.** |

- 검증: 레벨업 시 `attack_power`·`defense`·`max_hp`·`max_mp`가 m3-leveling-spec 2-3 검산표(=growth.md 2-2)와 일치(B-2 기준 그대로). 아이템 장착이 이 값들을 바꾸지 않음을 확인.

### 4-2. Post-M3 목표 (장비→전투 도입 시 이관 — 미리 확정)

장비가 전투에 반영되는 시스템이 스코프에 들어오면 아래로 전환한다. **책임 분리(m3-leveling-spec 5-2)의 완성형.**

| 대상 | 지시 |
|---|---|
| `stat_growth_formula.gd` | `weapon_attack_base/per_level`·`armor_defense_base/per_level`을 **0으로** 설정(또는 `apply`가 gear 항을 빼도록). 이후 성장 = 순수 스탯분만(`attack_power=주스탯×2`, `defense=체력×1`). HP/MP/치명타 불변. |
| `player_stat_growth.gd` | (a) `recompute_stats()` 말미에 `signal base_stats_recomputed` 발신 추가(레벨업·세이브 로드·전직 재계산 전부 포괄). (b) `_ready()`에서 `recompute_stats(current_level)` 호출 → Lv1 base도 성장이 저작(순수), .tres 의존 제거. |
| `inventory_component.gd` (지침만) | (a) `_base_*` 1회 캡처를 폐기하고 **`base_stats_recomputed` 구독** → 발신 때마다 `_base_*`를 공유 CombatantStats에서 재캡처 후 `_recompute_equipment_stats()` 재적용. 순서 보장: 성장이 순수 base를 쓴 뒤 시그널을 내므로, 인벤토리는 항상 최신 순수 base 위에 장비 절댓값을 얹는다(충돌 a 해소). (b) 아이템 값은 economy 규칙대로 **절댓값**(무기 attack, 방어구 defense) — gear_*=0이므로 이중 계산 없음(충돌 b 해소). |
| `warrior_lv1_combatant_stats.tres` | 순수 Lv1(공격 16·방어 8·HP 135·MP 72·민첩 8)로 재생성하거나 폴백으로 강등(성장이 Lv1 저작). |
| 시작 장비 (신규 의존) | 검산표=B급 착용 전제이므로, 플레이어가 시작 시 ~B급 무기/방어구를 착용해야 곡선에 안착. economy-designer(시작 인벤토리)·quest-designer(튜토리얼 지급) 협의. 권장 기본값: 기본 무기+방어구 B급 상당 지급(표준 RPG 관례). 미지급(맨몸 시작)을 원하면 초반 곡선 재튜닝 필요 → 그때만 디렉터 상정. |

- **HP/MP % 장신구 관련 주의(Post-M3)**: InventoryComponent가 목걸이 MAX_HP를 base에 곱한다. base 재캡처 후 곱하는 순서면 정합. 단 `player_stat_growth._on_leveled_up`의 "레벨업 회복 연출"(늘어난 max_hp만큼 현재값 가산)은 **순수 base 증가분**으로 계산하도록(장비 % 변동을 회복분에 섞지 말 것) — 연출 목적·밸런스 무영향(spec 8-3)이라 경미하나 B-4/B-5에서 순수 base 기준으로 정리.

---

## 5. Phase D 전제 (반드시 선행)

- D-1(공격 중 이동 재검증)·D-3(GUT+통합 리포트)의 TTK·피격 예산 실측은 **플레이어 스탯 = combat.md 8장 곡선 입력값(=검산표)**임을 전제로 한다.
- **M3 배선(3장)이 적용되면 플레이어는 검산표에 자동 안착**하므로 Phase D가 추가 셋업 없이 유효하다. 반대로 인벤토리 비배선이 누락돼 아이템이 스탯을 덮어쓰면(충돌 a/b), TTK 측정이 오염돼 D-1/D-3 판정이 무효가 된다.
- **필수**: 3장 배선(인벤토리 `combat_stats` 미할당)이 D-1/D-3 착수 전 완료·검증돼야 한다.

---

## 6. 권한·플래그

- **검산표 해석(1장)·내부 배선 아키텍처(3·4장)는 systems-designer 권한으로 확정**(디렉터 결정 불요). 검산표 수치는 변경하지 않았다(해석·배선만 확정).
- **[디렉터 체감 플래그 — 비차단]** M3에서 아이템 장착이 전투 스탯을 바꾸지 않는다(3장 한계). M3_PLAN 1-4 승인 범위와 정합하나, G3-1 플레이 세션에서 "장비 성장"을 느끼게 하려면 Post-M3 완전 분리(4-2) + 시작 장비를 M3로 끌어와야 한다(스코프 확장). 원하면 디렉터 상정.
- **[경제 교차 확인]** 검산표의 B급 기준선은 economy-foundation 2장(등급 배율 B=1.00)·2-6("동렙 B급 8슬롯 자연 유지")과 동일 전제. Post-M3에서 아이템 절댓값이 무기 `8+1.6L`·방어구 `(5+1.5L)×슬롯%`(growth.md 3장)와 정합해야 곡선 유지 — economy 아이템 수치 저작 시 준수. **현 전제 불일치 없음.**
