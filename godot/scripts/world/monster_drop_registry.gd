## 몬스터 → 드랍 테이블 매핑 레지스트리 (C-10).
##
## M2에는 종이 3종뿐이라 월드 루트 스크립트가 `is WolfMonster` 식의 클래스 분기로 드랍
## 테이블을 골랐다. M3 신규 7종은 **한 스크립트가 여러 종을 담당**하므로(ForestSpiderMonster =
## 숲거미·그림자 숲거미 / OutlawMonster = 무법자·노상강도·밀렵꾼 / ImpMonster = 임프·포효
## 임프장) 클래스 분기로는 아종을 구분할 수 없다. 구분 키는 `stats.display_name`이며,
## 각 `MonsterStatsData.display_name`과 `DropTableData.monster_display_name`이 10종 전부
## 1:1로 일치하는 것을 데이터에서 확인했다(test/world/test_m3_enemy_scene_wiring.gd가 회귀 보증).
##
## 드랍(DropSystem)·처치 경험치(PlayerProgression) 둘 다 같은 DropTableData를 쓰므로
## (레벨·등급이 그 리소스에 있다) 월드 씬은 이 레지스트리 한 곳에서 표를 받아 두 시스템에
## 함께 등록한다.
class_name MonsterDropRegistry
extends RefCounted

## 종 표시명 → 드랍 테이블. 신규 종을 추가할 때 이 표에만 한 줄 넣으면 드랍·EXP가 함께 붙는다.
const TABLES := {
	"뿔토끼": preload("res://data/drops/rabbit_drop_table.tres"),
	"들개 마수": preload("res://data/drops/wolf_drop_table.tres"),
	"균열 점액": preload("res://data/drops/rift_slime_drop_table.tres"),
	"숲거미": preload("res://data/drops/forest_spider_drop_table.tres"),
	"그림자 숲거미": preload("res://data/drops/shadow_forest_spider_drop_table.tres"),
	"무법자": preload("res://data/drops/outlaw_drop_table.tres"),
	"노상강도": preload("res://data/drops/highwayman_drop_table.tres"),
	"밀렵꾼": preload("res://data/drops/poacher_drop_table.tres"),
	"임프": preload("res://data/drops/imp_drop_table.tres"),
	"포효 임프장": preload("res://data/drops/imp_lord_drop_table.tres"),
}


## 몬스터 인스턴스에 해당하는 드랍 테이블. 표에 없는 대상(더미·테스트 노드 등)은 null.
static func table_for(monster: Node) -> DropTableData:
	if monster == null:
		return null
	var monster_stats: Variant = monster.get("stats")
	if monster_stats == null:
		return null
	var display_name: Variant = monster_stats.get("display_name")
	if not (display_name is String) or not TABLES.has(display_name):
		return null
	return TABLES[display_name]
