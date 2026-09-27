# Claude 독립 코드 리뷰 요청 — M5 단위 2

- 비교 기준: **`0e7e261`**. 구현 커밋은 후속 인계 커밋에서 기록한다.
- [검증 보고서](m5-first-quest-report.md), [승인된 계약](../design/systems/npc-dialog-quest.md), [실행 계획](../superpowers/plans/2026-09-27-m5-first-quest.md).
- 단위 1 재검토는 종료했다. 이번에는 실제 NPC→의뢰→보상 실행 연결과 단위 1 이월 인덱스 통합을 검토한다.

## 전달 문구

> 기준 커밋부터 단위 2 구현 커밋까지 읽기 전용으로 독립 검토해 주세요. 파일 수정·커밋·브랜치 변경·푸시 없이 테스트를 재현하고, 지적은 중요도·코드 위치·실패 시나리오·제안으로 작성해 주세요. 단위 2 구현 판정과 단위 3 직접 플레이/G5 판정을 구분해 주세요.

## 집중 확인

1. **Journal/정의 경계:** 수락 전 처치·중복 token·잘못된 출처·선행 미완료 거부. REACH와 TALK 시점 구분. JSON 복원 counts 정수화, 공유 QuestData 및 다른 캐릭터 상태 불변. 실제 NPC 목록·공유 아이템 레지스트리 사용.
2. **보상 원자성:** 만석·수치 상한 실패 시 전부 무변경, 기존 포션 묶음 합산, 75+325 EXP·20+100골드·포션 2개. 아이템 먼저 처리하고 동기 구간 재진입을 차단하는지. `gold_changed` 등 콜백의 재보고·저장·월드 전환 우회 여부.
3. **저장:** codec이 대상 검사 전에 Journal을 바꾸지 않는지. 월드 복원 완료 전에 처치 신호를 받지 않는지. V1 원본 보호/수동 전환 pending이 유지되는지.
4. **스폰:** `_ready()`는 준비만, `start()`는 명시적·멱등. 초기/재스폰 각각 드랍·EXP·퀘스트 1회 연결. 소급 등록 함수 제거, 야간 소멸은 처치 제외, 프레임 분산 중 종료 방어와 M3 필드 회귀.
5. **일시정지:** 세 UI 순서 조합 6개, 외부 pause, 소유자 종료/오반납, 실패한 월드 교체의 메뉴 표시+토큰 복원, 이전 월드의 늦은 release. 전직창의 추가 외부 pause 거부도 확인.
6. **실행 UX:** 40px/벽/죽음/공격 중 대화 차단, F의 NPC 우선 처리, Esc 무보상, 명시적 수락·보고, 추적/저널 표시. 기존 40항목 줍기 fixture 이동이 단언을 약화하지 않았는지.

## 재현

Windows GUI Godot 실행 파일은 `Start-Process -Wait`로 종료를 기다린다. 프로젝트 루트 기준:

```powershell
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
godot --headless --path godot -s res://test/save/m5_migration_process_probe.gd -- cleanup
godot --headless --path godot -s res://test/save/m5_migration_process_probe.gd -- seed
godot --headless --path godot -s res://test/save/m5_migration_process_probe.gd -- upgrade
godot --headless --path godot -s res://test/save/m5_migration_process_probe.gd -- verify
godot --headless --path godot -s res://test/save/m5_migration_process_probe.gd -- cleanup
godot --path godot --rendering-method gl_compatibility --resolution 1920x1080 -s res://../docs/qa/tools/m5_quest_render_probe.gd
godot --path godot --rendering-method gl_compatibility -s res://../docs/qa/tools/runtime_playtest_2026_09_11.gd
```

예상: GUT **989/989·3564 assertions·107 scripts**, V1 probe 5단계 PASS, 신규 렌더 PASS, 기존 렌더 **40/40**. GDScript는 비교 범위의 `*.gd` 35개를 `gdformat --check`/`gdlint`에 전달한다. 알려진 종료 경고와 단위 3 미검증은 보고서 마지막 절에 명시했다.
