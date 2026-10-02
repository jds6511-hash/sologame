# 3장 방어전 구현 계획

> **2026-10-02 순서 변경:** 디렉터가 [구조 통합](content-integration-plan.md)을 먼저 지시했다. 이 계획은 승인 설계의 이력으로 보류한다. 아래 V8·별도 후보 사슬은 구현하지 않았으며 통합 후 제품 형식 V6/콘텐츠 개정 방식으로 갱신한다. 제품3장 파일은 아직 만들지 않았다.

- 2026-10-02 / Codex. 근거: 승인된 [통합 설계](m7-chapter-three-defense.md), `04bc4e0` 독립 검토 통과.
- 실행: subagent-driven-development. 현재 작업 폴더의 승인된 개발 경로를 유지하고 명시 소유 파일만 편집한다. 다른 작업자 PNG9개 제외. 기본 V5/사용자 저장 미접근.
- 변경 이력: 설계 통과 후 낮음2건과 누적EXP 보고를 구현 검증에 포함.

## 구조와 작업

- [ ] 콘텐츠: `scripts/chapter_three/defense_{catalog,regions,layout,world,navigation}.gd`, `data/quests/m7_defense` 8건. V7을 동결하고 복제/상속 확장. 03-04 목격 장면, 하사 파생 UI, 후보 지도/문구를 연결한다. 담당 콘텐츠 에이전트.
- [ ] 저장: `defense_save_candidate.gd`, `defense_environment.gd`, `test/save/test_defense_save_candidate.gd`. 원본 V1~V7 검증→V8 이관→재검증, 현장/공훈 잠금, reserved 필드와 디렉터 저장 격리. 담당 저장 에이전트.
- [ ] 전투: `defense_spawner.gd`, `defense_rally.gd`, GUT. 살아 있는 동일 source를 제외해 max(0,목표−counts−살아 있음) 생성. ready/completed와 중복 시작 방지, source 분리, 죽은/삭제 예정 개체 제외. 담당 주 작업자.
- [ ] 통합: 후보 실행기/로컬 exe, API 중간/완료 저장·복원, 렌더, 정상 입력 고정3회, 누적EXP 목표 차이. 전체 GUT·형식·린트·저장 루트 검사. 제품 상태 주입 fixture와 정상 입력을 구분한다.
- [ ] 최종 내부 검토 후 제품 묶음 요청서·현황·인계·실행 안내와 명시 파일 로컬 커밋. 원격 반영은 별도 기록.

## 공통 인터페이스

환경 `defense_environment.gd.instantiate_world(region)` / `SessionDefense`. 지역 `yeoulmok_defense`, 경로 `user://m7_defense_candidate_*`. 기존 Closure 월드 형태를 확장하고 새 Catalog/Regions 사용. 전투 관리자는 월드 자식 `DefenseSpawner`, `start(world)` 연결 후 `resume() -> bool`로 현재 active KILL 목표를 시작한다. 재개 노드는 `defense_rally`(npc_id), 플레이어/컨트롤러/관리자로 setup한다. 전투 source는 wave_1/wave_2/elite 각각 `yeoulmok_defense_` 접두사. 전투 target은 `forest_wolf` (두 무리), `rift_slime` (정예), 별도 stats로Lv12/13 설정. 최종 데이터는 기존 정의 키와 대조한다.

검증은 먼저 계약 실패를 재현하고 구현 후 같은 검사로 확인한다. 코드 고정 후 3회 배치 결과를 전부 남기며 도구 안정화만을 별도 리뷰로 쪼개지 않는다. 직접 플레이/기본 채택 승인으로 확대하지 않는다.
