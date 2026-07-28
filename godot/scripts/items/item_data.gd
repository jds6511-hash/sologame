## 아이템 데이터 스키마 (Resource)
##
## economy-foundation.md 2장(등급 체계·ID 규칙)·growth.md 3장(장비 8슬롯)을 따르는
## 데이터 주도 아이템 정의. 실제 수치는 코드에 넣지 않고 godot/data/items/*.tres로 분리한다.
class_name ItemData
extends Resource

## 아이템 종류 — economy-foundation.md 2-3장 ID 규칙의 "종류" 코드에 대응
enum ItemType {
	WEAPON,  ## WPN
	ARMOR,  ## ARM
	ACCESSORY,  ## ACC
	POTION,  ## POT
	SPECIAL_WEAPON,  ## SPW
	MATERIAL,  ## MAT
}

## 아이템 등급 — economy-foundation.md 2-1장 (성능 배율 C 0.85 / B 1.00 / A 1.15 / S 1.32)
enum ItemGrade { C, B, A, S }

## 장비 슬롯 — growth.md 3장 8슬롯 구조 (반지는 슬롯 1종이 2자리를 차지)
enum EquipSlot {
	NONE,
	WEAPON,
	ARMOR_BODY,  ## 갑옷
	ARMOR_LEG,  ## 하의
	ARMOR_HEAD,  ## 모자
	ARMOR_FOOT,  ## 신발
	RING,  ## 반지 (2슬롯 보유, 장착 로직은 인벤토리 시스템 담당)
	NECKLACE,  ## 목걸이
}

## 주 옵션 스탯 종류 — growth.md 3장 슬롯별 주 옵션 대응
enum MainStatType {
	NONE,
	ATTACK_POWER,  ## 공격력 (무기)
	DEFENSE,  ## 방어력 (방어구)
	CRIT_CHANCE,  ## 치명타 확률 (반지 등)
	MAX_HP,  ## 최대 HP (목걸이 등)
	MAX_MP,  ## 최대 MP
	ATTACK_SPEED,  ## 공격 속도
}

## economy-foundation.md 2-3장 ID 규칙: {종류}-{계열/슬롯}-{티어Lv}-{등급}
@export var item_id: String = ""
@export var item_name: String = ""
@export var item_type: ItemType = ItemType.WEAPON
@export var grade: ItemGrade = ItemGrade.C
@export var level_limit: int = 1
@export var equip_slot: EquipSlot = EquipSlot.NONE

## 주 옵션 (무기=공격력, 방어구=방어력 등) — economy-foundation.md 3장 공식으로 산출한 값
@export var main_stat_type: MainStatType = MainStatType.NONE
@export var main_stat_value: float = 0.0

## 신발 전용 고정 옵션 — economy-foundation.md 3-4장 등급별 고정값 공식 (C+2/B+3/A+4/S+5, 레벨 무관)
@export var move_speed_bonus: float = 0.0

## 포션 전용 고정 회복량 — economy-foundation.md 5-1장 포션 4티어 표(POT-HP-1 100 / -2 320 /
## -3 550 / -4 730). "고정치 + 레벨 제한"이 저레벨의 상급 포션 과회복을 막는 장치이므로
## 회복량은 최대 HP 비율이 아니라 이 절댓값으로 적용한다. 0이면 값 미지정으로 보고
## PlayerRecoveryRules 기본값(최대 HP 30%)으로 회복한다.
@export var heal_amount: float = 0.0

## 골드 가격. 판매 미확정/비매품(표에 "—")인 경우 -1
@export var price: int = -1

## 획득처 설명 (economy-foundation.md 3-1장 표 "획득처" 열 그대로)
@export_multiline var acquisition: String = ""
