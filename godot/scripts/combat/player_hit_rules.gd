## 플레이어 피격 규칙 데이터 (Resource).
##
## combat.md 5-1장 "플레이어 피격" 표의 확정 수치를 그대로 필드화했다.
## 강공격/보스 공격(넉다운) 행은 M2에 보스가 없어 실전 트리거가 없지만, 문서에 수치가
## 있으므로 필드는 채워 두고 CB-6/보스 콘텐츠가 생기면 그대로 재사용한다.
## 넉다운 행의 "기상 시 방향 입력으로 구르기" 상호작용은 M2 범위 밖(보스 부재)이라
## 구현하지 않았다 — 넉다운 자체(경직·무적 타이머)만 재현한다.
class_name PlayerHitRules
extends Resource

@export_group("일반 피격")
@export var light_stun_sec: float = 0.25
@export var light_invincibility_sec: float = 0.6
@export var light_knockback_tiles: float = 0.5  ## 넉백 소(0.5타일)

@export_group("강공격/보스 공격 피격 (넉다운) — M2 범위 밖, 향후 재사용")
@export var heavy_knockdown_sec: float = 0.8
@export var heavy_invincibility_sec: float = 0.5
