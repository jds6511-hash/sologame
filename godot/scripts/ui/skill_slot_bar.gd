## HUD F요소 — 스킬 슬롯 바 (스킬 7 + 구분선 + 퀵슬롯 2, ux-foundation 5장 F행).
##
## 커밋 2103c94(CB-2)의 PlayerController 스킬 슬롯 키(slot1~4/slot_q/slot_e/ultimate)와
## `get_skill_cooldown_remaining()`, PlayerStatsComponent(M2 Phase3)의 MP·포션 쿨다운
## 조회 API를 그대로 폴링한다 — 두 스크립트 모두 이미 완성되어 있어 수정하지 않는다.
class_name SkillSlotBar
extends HBoxContainer

const ICON_PATHS := {
	"slot1": "res://assets/icons/skills/skill_strike.png",
	"slot2": "res://assets/icons/skills/skill_sprint.png",
	"slot3": "res://assets/icons/skills/skill_first_aid.png",
	"slot4": "res://assets/icons/skills/skill_cleave.png",
	"slot_q": "res://assets/icons/skills/skill_charge.png",
	"slot_e": "res://assets/icons/skills/skill_battle_shout.png",
	"ultimate": "res://assets/icons/skills/skill_ultimate_ground_smash.png",
}

const KEY_LABELS := {
	"slot1": "1",
	"slot2": "2",
	"slot3": "3",
	"slot4": "4",
	"slot_q": "Q",
	"slot_e": "E",
	"ultimate": "R",
}

var _player: PlayerController = null
var _stats: PlayerStatsComponent = null
var _skill_data: Dictionary = {}  ## key(String) -> WarriorSkillData
var _slots: Dictionary = {}  ## key(String) -> SkillSlot

@onready var _quickslot_5: SkillSlot = $Slot5
@onready var _quickslot_6: SkillSlot = $Slot6


func _ready() -> void:
	_slots = {
		"slot1": $Slot1,
		"slot2": $Slot2,
		"slot3": $Slot3,
		"slot4": $Slot4,
		"slot_q": $SlotQ,
		"slot_e": $SlotE,
		"ultimate": $SlotUltimate,
	}
	for key in _slots.keys():
		var icon: Texture2D = load(ICON_PATHS[key])
		_slots[key].configure(icon, KEY_LABELS[key], key == "ultimate")
	## 포션 퀵슬롯(5)은 아이템 아이콘이 아직 없다(IT-1 스타터 9종에 포션 미포함,
	## economy-foundation.md 3-1장 vs 5장 별도 — 결과 보고 참조). 6번은 완전 빈 자리.
	_quickslot_5.configure(null, "5")
	_quickslot_6.configure(null, "6")


## player: 스킬 쿨다운 조회용(PlayerController). stats: MP 확인·포션 쿨다운 조회용
## (PlayerStatsComponent). 둘 다 player.tscn 인스턴스에서 그대로 참조를 넘기면 된다
## (부착 방법은 UI-1 결과 보고 참조 — 씬 배선은 후속 통합 작업).
func bind_player(player: PlayerController, stats: PlayerStatsComponent) -> void:
	_player = player
	_stats = stats
	_skill_data = {
		"slot1": player.skill_slot_1,
		"slot2": player.skill_slot_2,
		"slot3": player.skill_slot_3,
		"slot4": player.skill_slot_4,
		"slot_q": player.skill_slot_q,
		"slot_e": player.skill_slot_e,
		"ultimate": player.skill_ultimate,
	}


func _process(_delta: float) -> void:
	if _player == null:
		return
	for key in _slots.keys():
		var skill: WarriorSkillData = _skill_data.get(key)
		if skill == null:
			continue
		var remaining: float = _player.get_skill_cooldown_remaining(key)
		_slots[key].set_cooldown(remaining, skill.cooldown_sec)
		if _stats and _stats.stats:
			var mp_cost: float = _stats.stats.max_mp * skill.mp_cost_percent
			_slots[key].set_mp_insufficient(not _stats.has_mp(mp_cost))
	if _stats and _stats.recovery_rules:
		_quickslot_5.set_cooldown(
			_stats.get_potion_cooldown_remaining_sec(), _stats.recovery_rules.potion_cooldown_sec
		)
