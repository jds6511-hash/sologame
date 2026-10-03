# 9장 도시 방어·군후 구현 계획

2026-10-03 / Codex. 실행: subagent-driven-development/dispatching-parallel-agents. 정본 [통과 설계](../design/systems/chapter-nine-defense.md), [리뷰](../qa/reviews/1a06b22.md). 기존 승인 작업공간 master에서 명시 파일만 커밋한다. 다른 작업자PNG/로그는 보존한다.

목표:9장5메인/13서브·4지역·대피·군후·저장 복원·실행기를 한 묶음으로 완성한다. 기술:Godot/GDScript·JSON/Python 생성기·GUT/PowerShell. 제품V7/개정8, 영지rev2. 실제 saves는 읽기/QA복사만 한다.

## 작업과 인터페이스

- [x] 콘텐츠: `chapter_nine.json`, 생성기와 생성물, `test_chapter_nine_content.py`. 예산/가중189/메인5서브13 검사부터 작성·실패 확인 후 구현. 지역/목표/source/몹Lv/관문/현장보고를 통과 설계대로 등록. `Content.ENCOUNTERS`는 회의 후 확정하고 런타임은 지역/퀘스트/source를 읽는다. 생성물 검사/Python 실행. 담당 content.
- [x] 보스: `ai/warlord_monster.gd`, `scenes/monsters/warlord.tscn`, `test/combat/test_warlord_monster.gd`. MonsterBase 상속, `summon_requested` 신호, phase/예고/회복/취소/타격1회/그로기. 실패 테스트→최소 구현→단독 GUT. 몬스터 stats/drop 데이터는 content 담당. 담당 boss.
- [x] 전장: `content/encounter_controller.gd`, `encounter_install.gd`, `encounter_rally.gd`, 필요 표시 부품, `test/world/test_encounter_controller.gd`. `install(world)`가 `EncounterController` 노드를 만들고 `active`/`suspend()` 제공. 대피 구역 F·8초·피격/이탈·무보상, 군후/척후 생성·저널 사건·사망/월드 해제. 완료 source는 생성하지 않음. 실패 테스트→구현→단독 GUT. 3장 spawner는 옮기지 않아 기존상한3 유지. 담당 encounter.
- [x] 통합: root는 `product_world.gd` 설치, 저장안전 active 거부/이동 중단, 시작9장 준비, `game_catalog.gd` 완료안내, 기존 `product_territory_probe.gd` 중간/보스후/완료 복원, `verify_all.ps1`, 성장 계산/장비별 TTK/형상 검사. API fixture와 실제 전투 입력 단언을 분리. 실패/통과 기록.
- [ ] 검토/완료: 각 담당 결과를 다른 담당이 읽고 API/상태/신호 계약 대조. 전체GUT+verify_all, 생성물/형식린트, 렌더 캡처, 실제 saves 해시. 실행기 갱신. 원문리뷰/상태/증거/한쪽 체감/통합요청/커밋/푸시.

## 집중 회귀

저장 직전 보스죽음/플레이어죽음 동일프레임, 구역 시작 연타와 삭제대기, 소환병무보상, 무기/직업교체 후 보스실제피해, 기존3장상한3, 구개정 새ID거부를 각각 소유 테스트에 포함한다. 테스트 전역 watcher에 해제 객체를 남기지 않는다. Godot QA는 root 허가 순서대로 직렬 실행한다. 중간 이상 리뷰는 우선 처리한다.

## 실행 기록

- 착수:8장 `485037c`,9장 설계 `1a06b22` 모두 통과 확인. 리뷰 원문 수정 금지.8장 참고의 번영 귀속은 실제 코드와 다시 대조한다.
