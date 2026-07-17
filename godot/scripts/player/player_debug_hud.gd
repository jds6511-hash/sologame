extends CanvasLayer
## CB-1/CB-2 디버그 씬 HUD — 걷기/콤보/대시/스킬/HP·MP 상태를 텍스트로 눈으로 확인하기
## 위한 임시 표시. 정식 HUD(UI-1)와 무관한 디버그 전용 오버레이.

@export var player_path: NodePath
@onready var _player: PlayerController = get_node(player_path)
@onready var _label: Label = $Label


func _process(_delta: float) -> void:
	var stats_text := ""
	var stats_node: Node = _player.get_node_or_null("PlayerStats")
	if stats_node:
		stats_text = (
			"HP %d/%d · MP %d/%d\n"
			% [
				int(stats_node.current_hp),
				int(stats_node.stats.max_hp),
				int(stats_node.current_mp),
				int(stats_node.stats.max_mp),
			]
		)
	_label.text = (
		"[CB-1/CB-2 디버그] WASD 이동 · 좌클릭 공격 · 우클릭 홀드 차지 강타 · Space 회피\n"
		+ "1234·Q·E 스킬 · R 궁극기 · 5 포션\n"
		+ stats_text
		+ "상태: %s\n" % _player.get_debug_state_text()
		+ "회피 충전: %d / %d\n" % [_player.dash_charges, _player.movement_data.dash_charge_max]
		+ "무적 프레임: %s" % ("예" if _player.is_dash_invincible else "아니오")
	)
