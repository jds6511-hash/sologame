## 몬스터(잡몹) 피격 경직·넉백 규칙 데이터 (Resource).
##
## combat.md 5-2장 "몬스터 피격 경직" 표의 잡몹 행 + 5-2-1장(2026-07-17 신설) 체급별
## 넉백 거리 표를 그대로 필드화했다. 정예/보스의 그로기 게이지 규칙은 M2 범위(잡몹 3종)에
## 해당하지 않아 별도 리소스로 미룬다(후속 태스크에서 신설).
##
## 체급별 프리셋(godot/data/combat/):
##   - mob_stagger_rules.tres        → 표준 체급 (들개 마수, 저항 계수 x1.0)
##   - mob_stagger_rules_light.tres  → 경량 체급 (뿔토끼, 저항 계수 x1.5 — 더 크게 밀림)
##   - mob_stagger_rules_heavy.tres  → 중량 체급 (균열 점액, 저항 계수 x0.5 — 덜 밀림)
## 경직 시간(초)은 체급과 무관하게 공통이며(5-2장 잡몹 행), 넉백 거리(타일)만 체급별로
## 다르다 — 5-2-1장 "종별 배정은 m2-monster-spec.md 3장·6장 참조".
class_name MobStaggerRules
extends Resource

@export_group("경직 시간 (5-2장 — 체급 무관 공통)")
@export var light_stagger_sec: float = 0.15  ## 일반 타격
@export var heavy_stagger_sec: float = 0.25  ## 강타·치명타
@export var stagger_chain_limit: int = 3  ## 연속 경직 허용 횟수
@export var superarmor_sec: float = 1.5  ## 연속 경직 한도 도달 후 부여되는 슈퍼아머 시간

@export_group("넉백 거리 (5-2-1장 — 체급별 상이, 기본값=표준 체급)")
@export var light_knockback_tiles: float = 0.2  ## 일반 타격
@export var heavy_knockback_tiles: float = 0.45  ## 강타·치명타
