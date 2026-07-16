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
class_name MonsterStatsData
extends Resource

@export var display_name: String = ""
@export var tile_size_px: float = 16.0  ## STYLE_GUIDE.md 1장 — 월드 타일 크기

@export_group("스탯 (m2-monster-spec.md 2장)")
@export var max_hp: float = 100.0
@export var attack_power: float = 10.0
@export var defense: float = 0.0  ## CB-3 데미지 공식이 참조하는 방어력 값(참고용 노출)

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

@export_group("원거리 공격(투사체) — 균열 점액 전용")
@export var projectile_range_tiles: float = 5.0
@export var projectile_speed_tiles: float = 3.5
@export var projectile_telegraph_sec: float = 0.7  ## 조준 예고 — spec 값 그대로
@export var projectile_cooldown_sec: float = 1.2

@export_group("자폭/코어 파괴 — 균열 점액 전용 (후속 태스크가 실제 판정 구현)")
@export var self_destruct_telegraph_sec: float = 0.3
@export var self_destruct_radius_tiles: float = 1.5
@export var self_destruct_duration_sec: float = 2.0
@export var self_destruct_dps_ratio: float = 0.5  ## 초당 피해 = 몬스터 공격력 x 이 비율

@export_group("경직 규격 (combat.md 5-2 잡몹 공통 — 참고용, 실제 적용은 CB-4/CB-7)")
@export var stagger_normal_sec: float = 0.15
@export var stagger_strong_sec: float = 0.25
@export var superarmor_after_hits: int = 3
@export var superarmor_duration_sec: float = 1.5


## 타일 단위 값을 픽셀 단위로 환산 (px/s, px 등)
func tiles_to_px(tiles: float) -> float:
	return tiles * tile_size_px
