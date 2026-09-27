# M5 단위 2 — 첫 의뢰 실행 연결

- 날짜: 2026-09-27. 기준 커밋: `0e7e261`.
- 상태: 구현·자동 검증 완료, Claude 독립 코드 리뷰 대기. 단위 3의 별도 프로세스 의뢰 상태별 복원·직접 플레이/G5는 미완료다.
- 구현 커밋: **`5df3099`**, 비교 범위 `0e7e261..5df3099`. [검토 요청](m5-first-quest-review-request.md), [실행 계획](../superpowers/plans/2026-09-27-m5-first-quest.md), [계약](../design/systems/npc-dialog-quest.md).

## 실제 연결된 흐름

새 캐릭터 또는 빈 V1 진행을 복원한 캐릭터는 MQ-01-01을 자동 수락한다. 기존 접수원 마커에 배치된 NPC의 40px 안으로 접근하면 REACH만 기록하고, F로 대화가 열린 뒤 TALK를 기록한다. Esc는 ready 상태를 남기며 보상을 주지 않는다. `모험가 패 받기`를 명시적으로 선택하면 75 EXP·20골드와 완료 상태를 함께 반영한다.

다시 대화해 토끼몰이를 수락한 뒤 동쪽 서식지 뿔토끼를 2마리 잡으면 ready가 된다. 수락 전 처치, 다른 몬스터/출처, 중복 사망 token은 집계하지 않는다. 최초 스폰과 재스폰 모두 같은 경로로 등록한다. `보고하고 보상 받기` 선택에서 325 EXP·100골드·POT-HP-1 2개를 지급하고 완료한다. 가방 만석은 무지급·ready 유지, 기존 포션 스택은 합산 가능하다. 재보고는 거부한다.

우측 추적 문구와 J 저널 요약이 상태를 표시한다. 대화 중 월드·자동 저장 시간은 멈추며, 저장/통합 메뉴와 상호 배제한다. 전직 선택창도 기존 pause가 있으면 열지 않는다. 보상 알림 후 레벨업 연출을 재생한다.

## 변경 파일과 책임

| 파일 (godot/ 기준, 별도 표기 제외) | 변경 |
|---|---|
| scripts/quests/quest_journal.gd | 캐릭터별 수락·순서·중복 처치·ready/completed·복제 export/검증 restore |
| scripts/quests/quest_controller.gd | 보상 전체 사전 검사, 수치 상한, 동기 지급과 재진입 잠금 |
| scripts/quests/quest_catalog.gd, scripts/save/save_schema.gd | 공유 SaveContentRegistry 주입, NPC 등록 목록 검증; 자체 아이템 인덱스 제거 |
| scripts/npc/npc_registry.gd, quest_npc.gd, scenes/npc/quest_receptionist.tscn | 실제 NPC 등록/생성, 거리·벽·행동 가능 여부 검사, F 상호작용 |
| scripts/ui/quest_dialog.gd, quest_tracker.gd | 명시적 수락/보고 UI, 추적 문구·저널 요약·보상 안내 |
| scripts/ui/ui_pause_arbiter.gd | 월드 소유 pause, 소유자 종료/오반납/중복 반납/전환 시 반납 |
| scripts/ui/integrated_menu.gd, scripts/save/save_menu.gd | 중재 경유, 다른 메뉴 process_mode 비활성화 우회 제거 |
| scripts/ui/job_selection_screen.gd | 대화 등 외부 pause 중 전직창 열기 차단 |
| scripts/ui/hud.gd | 일시정지 중 발생한 레벨업 연출을 보상 알림 뒤로 지연 |
| scripts/ui/tutorial_controller.gd, scripts/items/world_item.gd | NPC 대화 대상이 있을 때 F 줍기/공격 프롬프트 경합 방지 |
| scripts/items/inventory_component.gd | 부작용 없는 가방 수용 가능 검사 |
| scripts/save/character_save_codec.gd | 플레이어의 캐릭터 Journal 캡처/복원. 대상 검사를 모두 통과한 뒤에만 변경 |
| scripts/save/save_session.gd, save_safety.gd | 보상 중 저장·캐릭터 전환 차단, 월드 교체 실패 시 메뉴 pause 소유권 복원 |
| scripts/world/eastern_frontier_starting_area.gd | Journal 복원→신호 연결→start→온보딩. 소급 몬스터 등록 제거. NPC/UI는 런타임 배치 |
| scripts/world/monster_spawner.gd, m3_new_enemy_field.gd | 명시적·멱등 start, 비동기 생성 중 종료 방어, 토끼 콘텐츠/서식지 ID 전달 |
| test/quests/test_first_quest_flow.gd, test_quest_world_flow.gd, test_quest_state_schema.gd | 의뢰·보상·저장·상호작용·공유 정의·아이템 레지스트리·NPC ID 회귀 검증 |
| test/ui/test_ui_pause_arbiter.gd, test_hud.gd | pause 조합/소유자 종료·이전 월드 늦은 반납·알림 순서 |
| test/ui/test_integrated_menu.gd, test_integrated_menu_death_block.gd | 독립 메뉴 하네스의 월드 소유 중재 노드 정리 |
| test/save/test_save_session.gd, m5_migration_process_probe.gd | V1 fixture는 빈 quests 유지, 실패한 교체 후 메뉴 닫기로 정상 재개 검사 |
| test/world/test_monster_respawn.gd, test_m3_enemy_placement.gd | 직접 생성 하네스에서 명시적 start, start 전 0마리/중복 호출 검사 |
| docs/qa/tools/m5_quest_render_probe.gd | F/Esc/F6 입력 및 대화/추적 화면 렌더 증거 |
| docs/qa/tools/runtime_playtest_2026_09_11.gd | 저장 폴더 격리, 기존 줍기 테스트를 접수원 범위 밖으로 이동; 기존 40개 단언 유지 |

신규 GDScript의 Godot `.uid`도 포함한다. 기존 미추적 UID·로그·다른 작업자 설정·아트 파일은 포함하지 않는다.

## 검증 결과

- 전체 GUT: **989/989 · 3564 assertions · 107 scripts**, exit 0. 기존 deliberate I/O 실패 테스트의 오류 출력 1건 외에 전체 GUT 종료 잔존 경고 없음.
- 변경 GDScript **35개**: `gdformat --check`·`gdlint` 통과. `git diff --check` 통과.
- 기존 렌더 월드 입력 회귀 **40/40**, exit 0. 이동·전투·줍기·포션·전직·AI·미니맵 포함. 입력 주입과 피해 API를 사용하는 자동 검사다.
- 신규 렌더 `M5_QUEST_RENDER_PASS`, exit 0, 오류 로그 없음. F 대화, 대화 중 F6 차단, Esc 무보상/재개, 명시적 패 보상 확인.
- V1→V2 probe cleanup/seed/upgrade/verify/cleanup **5단계 PASS**. 기존 4직업 저장 probe cleanup/seed/verify/cleanup **4단계 PASS**.
- 최초 의뢰 테스트는 5개 실패 후 12/12 통과. 월드/pause 연결은 신규 2개 실패를 먼저 확인했다. 통합 중 Godot 자식 준비 시점의 형제 노드 추가와 `get_meta` 기본 null 동작을 수정했다.
- 추가 경계 테스트로 보상 신호 중 새 캐릭터 전환과 거부된 codec 복원의 Journal 변경을 재현·수정했다. 벽 테스트 1건은 비활성 월드 하네스가 충돌체까지 꺼 놓은 문제여서 테스트 충돌체만 ALWAYS로 바꿨다.
- 최종 코드 대조에서 스킬/대시 중 대화 진입 누락을 신규 테스트로 재현한 뒤 차단했다. 일반 공격뿐 아니라 진행 중인 스킬/대시도 행동 불가 조건에 포함한다.
- 기존 40항목의 첫 실행은 7건 실패했다. 새 NPC가 시작점의 F를 우선 받아 대화가 열린 것이 원인이었다. 줍기 위치를 64px 옆으로 옮기고 기존 단언은 유지해 40/40을 확인했다.
- 렌더 런처 초기 실패는 Autoload 참조 시점, 입력 사이 프레임 미대기, Windows `res://..` 디렉터리 생성 문제였다. 런처 수정 후 통과했다. 게임 물리 키 매핑은 바꾸지 않았다.

회귀 검증은 원본 파일을 편집해 통과시키는 방식이 아니다. 잘못된 V1 fixture의 퀘스트 진행만 `{}`로 유지하며 원본 보존·마이그레이션 pending 단언은 그대로다.

## 화면 증거

- [패 수령 대화](screenshots/m5-01-pass-dialog.png)
- [토끼몰이 제안](screenshots/m5-02-rabbit-offer.png)
- [수락 후 추적](screenshots/m5-03-quest-tracker.png)

기존 전사 LPC 스프라이트를 접수원의 **임시 외형**으로 재사용했다. 최종 NPC/캐릭터 디자인 완료나 신규 아트 제작으로 주장하지 않는다. 시작 지역 `.tscn`의 마커/지형은 변경하지 않고 NPC 씬을 해당 마커에서 생성한다.

## 남은 범위

단위 3에서 active 1/2·ready·completed 각각의 별도 프로세스 저장/복원, 완료 후 재보고 무지급, 직접 이동→NPC→사냥→보고→재실행을 검증한다. 이번 단위의 같은 프로세스 새 월드 복원과 기존 V1/4직업 probe를 그 검증의 대체로 주장하지 않는다.

신규 네이티브 사람 조작 QA와 디렉터 G4/G5 승인은 없다. M4 직접 이동 후 위치 복원도 그대로 남는다. V1 probe의 seed 종료 4 objects/2 resources·upgrade/verify 6/2, 기존 4직업 seed 16/4 경고는 기존 제한이며 이번에 해결하지 않았다. 전체 GUT/렌더 PASS와 분리한다.
# 후속 검증

단위 2 독립 검토 통과 및 줍기 안내 보완은 [리뷰 대응](m5-first-quest-review-response.md), 단위 3 별도 프로세스 결과와 실제 창 입력 제한은 [재실행 보고서](m5-quest-persistence-report.md)를 따른다. 위 본문은 단위 2 당시 기록이다.
