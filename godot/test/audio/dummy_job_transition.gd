## 전직 팡파레 테스트용 대역 — PlayerJobTransition의 job_changed 시그널만 흉내낸다.
## 실제 PlayerJobTransition은 형제 노드(PlayerStatGrowth 등)와 부모 PlayerController가 있어야
## 동작하고 scripts/progression은 다른 담당 도메인이라, 시그널 계약만 별도 테스트로 확인한다
## (test_real_job_transition_exposes_job_changed_signal).
extends Node

signal job_changed(job_id: StringName)
