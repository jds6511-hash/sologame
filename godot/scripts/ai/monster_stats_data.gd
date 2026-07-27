## 몬스터 스탯·행동 파라미터 데이터 (Resource).
##
## m2-monster-spec.md 2·3·6장 표를 그대로 필드화했다. 뿔토끼·들개 마수·균열 점액
## 3종이 공유하는 단일 스키마이며, 특정 종에서 쓰이지 않는 필드는 기본값(0 또는 -1)
## 그대로 둔다(예: 뿔토끼/들개 마수에는 원거리·자폭 필드가 무의미).
##
## 주의(ai-dev 임시값): 예고(telegraph) 시간은 spec 3장 수치를 그대로 옮겼지만,
## 판정 지속(active)·후딜(recovery)은 spec에 수치가 없어 combat.md 9-2 "잡몹: 블록
## 2~3개, 예고 패턴 1개" 규격 내에서 ai-dev가 임시로 지정했다 — systems-designer의
## 후속 확인/튜닝 대상이며 디렉터 결정 사항은 아니다.
##
## M3(C-8) 확장: m3-monster-spec.md 8-4장 "MonsterStatsData 스키마 확장" 목록을 그대로
## 필드화해 숲거미·무법자·임프 + 아종 4종이 같은 스키마를 공유한다. 아종은 신규 필드 없이
## 아래 필드의 값만 교체한 .tres 복제본으로 만든다(spec 7장 물량 통제 원칙).
class_name MonsterStatsData
extends Resource

@export var display_name: String = ""
@export var tile_size_px: float = 16.0  ## STYLE_GUIDE.md 1장 — 월드 타일 크기

@export_group("스탯 (m2-monster-spec.md 2장)")
@export var max_hp: float = 100.0
@export var attack_power: float = 10.0
@export var defense: float = 0.0  ## CB-3 데미지 공식이 참조하는 방어력 값(참고용 노출)
## 보스 여부 — true면 MonsterBase가 야간 배율(combat.md 2-3 "보스 제외")을 적용하지
## 않는다. M2 3종(뿔토끼·들개 마수·균열 점액)은 전부 잡몹이라 기본값 false 그대로 둔다.
@export var is_boss: bool = false
## 정예 여부 (combat.md 5-2 정예 행 "평시 슈퍼아머") — true면 MonsterBase가 피격 경직·넉백을
## 무시한다. 그로기 게이지는 정예 공용 프레임(정예 20종 전체 기반, m3-monster-spec 7-5장)
## 소관이라 C-8에서는 구현하지 않는다. 야간 배율은 정예에도 적용된다(보스만 제외).
@export var is_elite: bool = false

@export_group("무리·감지 (6장 총괄표)")
@export var shares_pack_aggro: bool = false  ## 들개 마수만 true (combat.md 2-2 무리 어그로 공유)
@export var perception_range_tiles: float = 3.0
## 추적 한계(스폰 지점 기준 이탈 거리). -1 = 해당 없음(도주형·제자리형)
@export var leash_range_tiles: float = -1.0

@export_group("이동")
@export var wander_speed_tiles: float = 1.5
@export var combat_move_speed_tiles: float = 3.0  ## 추적/도주 시 이동 속도

@export_group("근접 공격 — 뿔토끼(박치기)·들개 마수(물기) 전용")
@export var melee_range_tiles: float = 1.5
@export var melee_telegraph_sec: float = 0.5  ## 예고 — spec 값 그대로 (0.4~0.8초 규격)
@export var melee_active_sec: float = 0.12  ## 판정 지속 — spec 미기재, 잡몹 표준 임시값
@export var melee_recovery_sec: float = 0.3  ## 후딜 — spec 미기재, 잡몹 표준 임시값

@export_group("도주 — 뿔토끼 전용")
@export var flee_duration_sec: float = 1.5

@export_group("원거리 공격(투사체) — 균열 점액 · 밀렵꾼(석궁) 공용")
## 돌진↔조준 사격 조합 스위치 (m3-monster-spec 7-3 밀렵꾼 아종) — true면 OutlawMonster가
## ChargeBlock 대신 AimFireBlock(석궁)을 데미지 예고 패턴으로 쓴다. 아래 projectile_* 필드가
## 석궁 파라미터(예고 0.7 / 사거리 6 / 속도 6.0 / 쿨다운 3.5)를 담는다.
@export var uses_ranged_attack: bool = false
@export var projectile_range_tiles: float = 5.0
@export var projectile_speed_tiles: float = 3.5
@export var projectile_telegraph_sec: float = 0.7  ## 조준 예고 — spec 값 그대로
@export var projectile_cooldown_sec: float = 1.2

@export_group("자폭/코어 파괴 — 균열 점액 전용 (후속 태스크가 실제 판정 구현)")
@export var self_destruct_telegraph_sec: float = 0.3
@export var self_destruct_radius_tiles: float = 1.5
@export var self_destruct_duration_sec: float = 2.0
@export var self_destruct_dps_ratio: float = 0.5  ## 초당 피해 = 몬스터 공격력 x 이 비율

@export_group("도약 (m3-monster-spec 3-1 · LeapBlock) — 숲거미 전용")
@export var leap_telegraph_sec: float = 0.5  ## 예고(웅크림) — 착지 지점 고정 시점
@export var leap_travel_sec: float = 0.35  ## 공중 이동 시간 (플레이어 대시와 동급 속도)
@export var leap_max_range_tiles: float = 4.0
@export var leap_min_range_tiles: float = 1.0  ## 근거리 "짧은 도약 물기"의 최소 이동 거리
@export var leap_land_radius_tiles: float = 1.0
@export var leap_active_sec: float = 0.15  ## 착지 판정 지속 (플레이어 회피 무적 0.25초보다 짧게)
@export var leap_recovery_sec: float = 0.4
@export var leap_damage_mult: float = 1.0
@export var leap_cooldown_sec: float = 3.5

@export_group("거미줄 둔화 (m3-monster-spec 3-2 · AimFireBlock 재사용) — 숲거미 전용")
@export var web_telegraph_sec: float = 0.6
@export var web_range_tiles: float = 4.0
@export var web_speed_tiles: float = 4.0
@export var web_slow_pct: float = 0.40  ## 이동속도 감소율
@export var web_slow_duration_sec: float = 2.0  ## 그림자 숲거미 아종만 3.0 (spec 7-1)
@export var web_damage_mult: float = 0.0  ## 무피해 원칙(spec 3-2) — G3-1 튜닝 시 0.3까지 여분
@export var web_cooldown_sec: float = 5.0

@export_group("돌진 (m3-monster-spec 3-3 · ChargeBlock) — 무법자 전용")
@export var charge_telegraph_sec: float = 0.6  ## 예고 중 돌진 방향 고정
@export var charge_speed_tiles: float = 8.0
@export var charge_distance_tiles: float = 6.0
@export var charge_min_distance_tiles: float = 2.0  ## 근거리 시 백스텝으로 확보할 활주로
@export var charge_recovery_sec: float = 0.5
@export var charge_wall_stun_sec: float = 0.8  ## 벽 충돌 시 후딜에 가산되는 추가 경직
@export var charge_damage_mult: float = 1.2
@export var charge_cooldown_sec: float = 4.0

@export_group("가드 (m3-monster-spec 3-4 · GuardBlock) — 무법자 전용")
@export var guard_enter_sec: float = 0.2
@export var guard_duration_sec: float = 1.5  ## 최대 지속 (또는 1회 피격까지)
@export var guard_frontal_arc_deg: float = 120.0  ## 정면 판정 각 (±60°)
@export var guard_damage_reduction_pct: float = 0.60
@export var guard_break_stun_sec: float = 1.0  ## 강 등급 피격 시 가드 브레이크 경직
@export var guard_recovery_sec: float = 0.4
@export var guard_cooldown_sec: float = 6.0

@export_group("순간이동 (m3-monster-spec 3-5 · BlinkBlock) — 임프 전용")
@export var blink_telegraph_sec: float = 0.3
@export var blink_max_range_tiles: float = 5.0
@export var blink_trigger_distance_tiles: float = 3.0  ## 카이팅 감지 거리
@export var blink_target_offset_tiles: float = 2.5  ## 플레이어 측면/후방 재등장 거리
@export var blink_recovery_sec: float = 0.3  ## 재등장 직후 무방비(딜찬스)
@export var blink_cooldown_sec: float = 4.5  ## 포효 임프장 아종만 6.0 (spec 7-4)

@export_group("포효 버프 (m3-monster-spec 3-6 · RoarBuffBlock) — 임프 전용")
@export var roar_telegraph_sec: float = 0.5
@export var roar_radius_tiles: float = 4.0  ## 포효 임프장 아종만 6.0 (spec 7-4)
@export var roar_atk_buff_pct: float = 0.15  ## 포효 임프장 아종만 0.20
@export var roar_speed_buff_pct: float = 0.15  ## 포효 임프장 아종만 0.20
@export var roar_buff_duration_sec: float = 6.0
@export var roar_cooldown_sec: float = 12.0  ## 지속 6초 < 쿨다운 12초 → 가동률 50%

@export_group("경직 규격 (combat.md 5-2 잡몹 공통 — 참고용, 실제 적용은 CB-4/CB-7)")
@export var stagger_normal_sec: float = 0.15
@export var stagger_strong_sec: float = 0.25
@export var superarmor_after_hits: int = 3
@export var superarmor_duration_sec: float = 1.5


## 타일 단위 값을 픽셀 단위로 환산 (px/s, px 등)
func tiles_to_px(tiles: float) -> float:
	return tiles * tile_size_px
