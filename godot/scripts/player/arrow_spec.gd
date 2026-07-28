## 화살 투사체 1종 분량의 규격 데이터 (Resource, M3 C-5).
##
## m3-archer-skills.md 5·6장의 투사체 파라미터(속도·사거리·관통·폭)를 그대로 필드화했다.
## 기본 화살 / 조준 모드 정밀 화살 / 스킬 화살 / 궁극기 관통 화살이 모두 이 스키마 하나를
## 쓰고 .tres 값으로만 구분된다 — 밸런스 수치를 코드에서 분리하기 위한 데이터 주도 설계다
## (기획 수정 시 .tres만 고치면 반영된다).
##
## 이 규격을 소비하는 쪽:
##   - ArcherAttackStep.arrow (기본 공격 = 활 사격)
##   - ArcherSkillData.arrow / ArcherSkillData.aimed_arrow (스킬·조준 모드 사격)
##   - ArrowProjectile.configure() (실제 발사체 인스턴스)
class_name ArrowSpec
extends Resource

## 투사체 속도(타일/초). m3-archer-skills 6-2장 델타 ⑥ — 기본 16 / 조준·정밀 20 / 궁극기 24.
@export var speed_tiles_per_sec: float = 16.0
## 최대 사거리(타일). 명중이 없어도 이 거리를 지나면 소멸한다(6-2장 델타 ⑤).
@export var range_tiles: float = 5.0
## 관통 대상 수 — 0=비관통(첫 명중에 소멸), N>0=최대 N체 명중 후 소멸, -1=무제한 관통.
## m3-archer-skills 6-2장 델타 ④: 기본·속사·곡예 사격 0, 조준 모드 3, 관통 폭사 -1.
@export var pierce_count: int = 0
## 화살 히트박스 폭(타일) — 기본 0.6, 관통 폭사 1.0(4-4장).
@export var width_tiles: float = 0.6
## placeholder 화살 색(절차적 스프라이트). 정식 화살 스프라이트·궤적은 pixel-artist C-6 /
## vfx-artist C-7 영역이며(6-3장 "초기 구현은 절차적 placeholder 허용"), 그때 교체된다.
@export var visual_color: Color = Color(0.94, 0.88, 0.55)


## 투사체 속도(px/초) — 타일 크기를 곱한 실제 이동 속도.
func speed_px_per_sec(tile_size_px: float) -> float:
	return speed_tiles_per_sec * tile_size_px
