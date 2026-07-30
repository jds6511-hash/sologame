## BGM 전투 전환 테스트용 몬스터 대역 — MonsterBase의 교전 시그널 3종과 stats(정예 여부)만
## 흉내낸다. 스탯 자원은 실제 MonsterStatsData를 쓰므로 is_elite 계약이 바뀌면 이 테스트가
## 함께 깨진다(scripts/ai는 다른 담당 도메인이라 진짜 몬스터 씬을 띄우지 않는다).
extends Node

signal took_damage(amount: float, remaining_hp: float)
signal attack_landed(target: Node)
signal died

var stats := MonsterStatsData.new()
