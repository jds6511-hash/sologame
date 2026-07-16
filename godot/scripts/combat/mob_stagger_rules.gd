## 몬스터(잡몹) 피격 경직 규칙 데이터 (Resource).
##
## combat.md 5-2장 "몬스터 피격 경직" 표의 잡몹 행을 그대로 필드화했다.
## 정예/보스의 그로기 게이지 규칙은 M2 범위(잡몹 3종)에 해당하지 않아 별도 리소스로
## 미룬다(후속 태스크에서 신설).
##
## 넉백 거리(타일)는 combat.md 5-2장에 수치가 없다("강타·치명타 0.25초 + 넉백"만 명시,
## 크기 미지정) — 임의로 만들어 넣지 않고, 넉백 거리는 호출자(공격 판정 쪽)가 직접
## 지정하도록 비워 둔다. 최종 수치는 기획 확인 필요.
class_name MobStaggerRules
extends Resource

@export var light_stagger_sec: float = 0.15  ## 일반 타격
@export var heavy_stagger_sec: float = 0.25  ## 강타·치명타
@export var stagger_chain_limit: int = 3  ## 연속 경직 허용 횟수
@export var superarmor_sec: float = 1.5  ## 연속 경직 한도 도달 후 부여되는 슈퍼아머 시간
