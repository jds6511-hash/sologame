## 레벨업 스탯 자동 성장 반영 노드 (M3 B-2) — m3-leveling-spec.md 5장·3-2장.
##
## B-1 PlayerProgression의 leveled_up 시그널을 구독해, 레벨업 순간 (현재 레벨, 직업)으로
## 스탯을 재계산(StatGrowthCalculator)하고 공유 CombatantStats에 반영한다. 그 CombatantStats는
## player.tscn에서 AttackResolver(공격력/민첩)·PlayerStats(최대 HP/MP·방어력)와 같은 인스턴스를
## 가리키므로, 재계산 결과가 데미지·방어·HP/MP 공식에 그대로 퍼진다(spec 7-5).
##
## Player 씬의 자식 노드("PlayerStatGrowth")로 배치하며, 형제 PlayerProgression·PlayerStats를
## 노드 경로로 참조한다(다른 컴포넌트와 동일 배치 패턴).
##
## Lv1 초기 스탯은 이 노드가 건드리지 않는다 — 기존 warrior_lv1_combatant_stats.tres가 Lv1 B급
## 착용 스냅샷을 담고 있어 그대로 두고(spec 7-5 "초기 스냅샷/폴백"), Lv2부터 재계산이 값을
## 넘겨받는다. HP/MP는 장비 기여가 없어 Lv1 스냅샷과 순수 함수 값이 정확히 일치하므로,
## 첫 레벨업의 증가분 계산도 어긋나지 않는다.
##
## 그 스냅샷 .tres는 `resource_local_to_scene = true`로 두어 씬 인스턴스마다 사본이 만들어진다 —
## 재계산이 파일 백업 리소스(=Godot 리소스 캐시)를 오염시켜 이후 생성되는 플레이어가 스냅샷
## 대신 재계산값을 보게 되는 문제를 원천 차단한 것이다(상세는 combatant_stats.gd 머리말).
## 사본은 씬 안의 세 참조로 그대로 리맵되므로 공유 구조는 유지된다.
class_name PlayerStatGrowth
extends Node

## 직업별 성장 배분(spec 7-3). 전직(B-5)이 이 값을 교체하면 다음 재계산부터 소급 반영된다.
@export var job: JobGrowthData
## 성장 공식 상수(spec 5장) — 직업 무관 공통.
@export var formula: StatGrowthFormula
## 반영 대상. AttackResolver·PlayerStats와 동일 CombatantStats 인스턴스를 할당해야 전투에
## 반영된다(player.tscn에서 같은 리소스 공유).
@export var combat_stats: CombatantStats

@onready var _progression: PlayerProgression = get_node_or_null("../PlayerProgression")
@onready var _stats_component: PlayerStatsComponent = get_node_or_null("../PlayerStats")


func _ready() -> void:
	if _progression:
		_progression.leveled_up.connect(_on_leveled_up)


## 레벨업 1회분 처리. 재계산 후 늘어난 최대 HP/MP만큼 현재값을 가산해 "레벨업 = 약간 회복"
## 체감을 준다(spec 3-2 규약, 전체 회복 아님). 다중 레벨업은 레벨마다 이 함수가 호출되어
## 각 단계 증가분이 순차 가산된다.
func _on_leveled_up(new_level: int) -> void:
	if combat_stats == null:
		return
	var old_max_hp := combat_stats.max_hp
	var old_max_mp := combat_stats.max_mp
	recompute_stats(new_level)
	if _stats_component:
		_stats_component.grow_max_stats(
			combat_stats.max_hp - old_max_hp, combat_stats.max_mp - old_max_mp
		)


## (레벨, 직업)으로 스탯만 재계산한다(현재 HP/MP는 건드리지 않음). 세이브 로드·전직 완료 등
## 레벨에 맞춰 스탯을 세팅해야 할 때 호출한다(레벨업 회복 연출과 분리).
func recompute_stats(level: int) -> void:
	if combat_stats == null or job == null or formula == null:
		return
	StatGrowthCalculator.apply(combat_stats, level, job, formula)
