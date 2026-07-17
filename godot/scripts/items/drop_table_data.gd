## 몬스터별 드랍 테이블 데이터 (Resource) — IT-2.
##
## m2-monster-spec.md 4장(뿔토끼·들개 마수·균열 점액 드랍 테이블)을 필드화한다. 드랍률
## 자체(확률 수치)는 등급 공통 정책이라 DropRateConfig에 있고, 이 리소스는 "이 몬스터가
## 어떤 재료/포션을 드랍하는가"와 "몬스터 레벨(골드·장비 티어 산출용)"만 담는다.
class_name DropTableData
extends Resource

## 몬스터 분류 — economy-foundation.md 2-5장 "일반/정예/보스" 표의 열에 대응.
## M2 3종은 전부 NORMAL(잡몹)이다.
enum MonsterTier { NORMAL, ELITE, BOSS }

@export var monster_display_name: String = ""  ## 디버그/문서 대조용 (MonsterStatsData.display_name과 동일)
@export var monster_level: int = 1  ## 골드 공식 g(L)·장비 드랍 티어 산출에 쓰는 L
@export var tier: MonsterTier = MonsterTier.NORMAL

@export var material_item_id: String = ""  ## MAT-* (economy-foundation.md 2-5장 "재료·잡템")
@export var potion_item_id: String = ""  ## POT-* (해당 지역 티어 포션)

## 균열 점액 코어 파괴 예외 (m2-monster-spec.md 3-3장) — 사망 직전 피격 등급이 "강"이면
## material_item_id 드랍이 확률과 무관하게 100% 확정된다. 다른 두 몬스터는 false.
@export var core_break_guarantees_material: bool = false
