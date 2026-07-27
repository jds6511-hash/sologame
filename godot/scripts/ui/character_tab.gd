## S07 통합 메뉴 — 캐릭터 탭 (읽기 전용 스탯 표시, UI-2 "실탭" 최소 구현).
##
## `docs\art\ux\ux-foundation.md` 3장 S07: "장비+스탯+칭호 장착+명성" — 장비/칭호/명성
## 표시는 해당 시스템(스탯 성장·칭호) 확정 전이라 8장 M2 이후 과제 2번으로 남아 있다.
## 이번 M2는 이미 존재하는 CombatantStats(scripts/combat/combatant_stats.gd, 읽기 전용
## 참조만 — 해당 스크립트는 수정하지 않는다)로 표시 가능한 기본 스탯만 "실탭"으로 구현한다.
class_name CharacterTab
extends Control

@onready var _level_job_label: Label = $VBox/LevelJobLabel
@onready var _stat_list_label: Label = $VBox/StatListLabel


func _ready() -> void:
	UiStyle.apply_body_font(_level_job_label)
	UiStyle.apply_body_font(_stat_list_label)
	_level_job_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT)
	_stat_list_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT)


## stats: 공유 CombatantStats(읽기 전용). level/job_name: 호출자가 PlayerProgression·직업에서
## 읽어 넘긴다(M3 B-4). crit_percent: 치명타%(0~100). 음수면 표시하지 않는다 — 치명타는
## CombatantStats에 저장되지 않고 DamageCalculator.calculate_crit_chance(민첩, formula)로
## 산출해야 하므로(spec 5-2), 그 값을 아는 호출자만 넘긴다. 표시는 round()(spec 8-1).
func bind_stats(
	stats: CombatantStats, level: int, job_name: String, crit_percent: float = -1.0
) -> void:
	_level_job_label.text = "Lv.%d %s" % [level, job_name]
	var text := (
		"공격력 %d\n방어력 %d\n민첩 %d\n최대 HP %d\n최대 MP %d"
		% [
			roundi(stats.attack_power),
			roundi(stats.defense),
			roundi(stats.agility),
			roundi(stats.max_hp),
			roundi(stats.max_mp),
		]
	)
	if crit_percent >= 0.0:
		text += "\n치명타 %d%%" % roundi(crit_percent)
	_stat_list_label.text = text
