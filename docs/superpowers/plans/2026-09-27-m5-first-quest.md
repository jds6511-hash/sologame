# M5 첫 의뢰 실행 계획

> 실행 담당: Codex가 `superpowers:executing-plans`로 직접 구현한다. Claude는 독립 검토만 담당한다. 각 단위의 변경 파일·검증·커밋 해시는 QA 보고서에 남긴다.

**Goal:** 여울목 NPC → 첫 패 발급 → 토끼 2마리 의뢰 → 보고 보상 → 재실행 복원을 연결한다.

**Architecture:** Resource 기반 정의와 캐릭터별 Journal을 분리하고 월드 Controller가 대화·처치·보상을 연결한다. 기존 SaveSession의 파일/월드 소유 경계를 유지한다.

**Tech Stack:** Godot 4.x / GDScript / GUT / 기존 gdformat·gdlint.

**Spec:** [M5 구현 계약](../../design/systems/npc-dialog-quest.md). 이 계획은 구현 전 설계 단위이며 체크되지 않은 항목은 미실행이다.

## 공통 제약

- 기준 `dcbda4d`. 타 작업자 변경을 포함하지 않는다. M4 G4 미승인은 별도로 유지한다.
- 새 Autoload·의존 패키지·전투 밸런스·최종 아트 변경 없음.
- MQ-01-01: 75 EXP/20골드/모험가 패, MQ-01-02: 325 EXP/100골드/POT-HP-1 ×2.
- 준비 작업의 커밋 분리는 허용하지만 NPC 없는 퀘스트 엔진만으로 플레이 구현 완료를 선언하지 않는다.

## 검토 집중 항목

| 실패 조건 | 담당 단위와 검증 |
|---|---|
| V1 읽기가 원본을 다시 쓰거나 미래 버전을 덮어씀 | 1: 원본 해시·미지원 버전 보존 |
| 가방 만석인데 EXP만 지급됨 | 2: ready/EXP/골드/가방 전부 무변경 |
| 보상 신호에서 재진입해 중복 지급됨 | 2: 신호 콜백에서 report 재호출·save 요청 |
| 월드 교체 직후 죽음 이벤트가 복원보다 먼저 적용됨 | 2·3: 복원 중 이벤트 차단·전후 payload 비교 |
| ESC/다른 메뉴가 일시정지 소유권을 빼앗음 | 2·3: 입력과 pause 조합 테스트 및 실제 창 |

## 단위 1 — V1 호환 저장 확장

파일: `godot/scripts/save/save_file_store.gd`, `save_schema.gd`, `character_save_codec.gd`; 신규 `godot/scripts/save/character_save_migrations.gd`, `godot/scripts/quests/quest_state_schema.gd`; 테스트 `godot/test/save/test_save_file_store.gd`, 신규 `test_character_save_migrations.gd`, `godot/test/quests/test_quest_state_schema.gd`.

인터페이스: `CharacterSaveMigrations.upgrade(data: Dictionary) -> Dictionary`는 `{ok, code, data}` 반환, 실패 시 입력 불변. `QuestStateSchema.validate(quests: Variant) -> String`은 성공 시 빈 문자열. 파일 계층은 마이그레이션을 수행하지 않는다. 입력 버전별 스키마 검사 후 codec에서 변환하며 출력 payload/봉투는 V2다.

- [ ] V1 빈 quests 변환, 입력 불변, V1의 잘못된 기존 필드 거부, V2 중복 변환 불변, 미래 버전 거부 테스트를 먼저 작성한다.
- [ ] QuestState의 unknown ID/잘못된 상태/음수·소수·초과 counts/선행 미완료를 실패로 고정한다. `{}`는 유효하다.
- [ ] 실패 실행을 기록한 뒤 읽기 V1/V2·쓰기 V2와 마이그레이션을 구현한다. 검증 전에는 원본 파일을 쓰지 않는다.
- [ ] 저장 계층 테스트에서 정상 V1 백업 회전·새 버전 보호를 다시 확인한다. 기존 V1만 유효하다고 전제한 테스트는 실제 보호 계약을 유지하도록 갱신한다.
- [ ] GUT 저장 테스트 및 형식/린트 통과 후 `docs/qa/m5-save-compatibility-report.md`에 파일·결과를 기록하고 이 단위만 커밋한다.

검증 명령(저장소 루트):

```powershell
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test/save -ginclude_subdirs -gexit
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test/quests -ginclude_subdirs -gexit
```

## 단위 2 — NPC부터 보상까지 첫 수직 슬라이스

신규 파일: `godot/scripts/quests/quest_data.gd`, `quest_journal.gd`, `quest_controller.gd`; `godot/scripts/npc/quest_npc.gd`; `godot/scripts/ui/quest_dialog.gd`, `quest_tracker.gd`; `godot/data/quests/mq_01_01.tres`, `mq_01_02.tres`; `godot/scenes/npc/quest_receptionist.tscn`; `godot/test/quests/test_first_quest_flow.gd`.

변경: `godot/scripts/world/eastern_frontier_starting_area.gd`, 대응 `.tscn`, `world/monster_spawner.gd`, `ui/tutorial_controller.gd`, `save/character_save_codec.gd`, `save/save_session.gd`, `save/save_safety.gd`. 보상 사전 검사 API가 필요하면 `items/inventory_component.gd`에 부작용 없는 검사를 추가한다.

인터페이스: Journal `accept(quest_id: String) -> String`, `record_event(kind: String, target_id: String, source_id: String, token: int) -> void`, `export_state() -> Dictionary`, `restore_state(data: Dictionary) -> String`. 성공 문자열은 빈 값. Controller `report(quest_id: String, npc_id: String) -> String`이 지급·완료를 함께 소유하고 `is_reward_busy() -> bool`을 저장 경계에 제공한다. NPC는 Controller만 호출하며 저장 파일에 접근하지 않는다.

- [ ] 01 자동 수락/접근/대화 완료 → 02 제안/거절/수락 경로를 테스트로 작성한다. 수락 전 죽음·다른 서식지·중복 token은 진행되지 않아야 한다.
- [ ] 기존 마커에 NPC를 배치하고 F 대상 탐색·기존 프롬프트·대화·추적 문구를 연결한다. 기존 에셋의 임시 외형임을 명시한다.
- [ ] 스폰 출처와 명시적인 몬스터 콘텐츠 ID를 이벤트로 전달한다. 등록은 1회, 낮 소멸/씬 해제는 KILL 제외다.
- [ ] 2회 처치 후 ready를 표시하고 보고 버튼만 보상을 준다. 만석 실패, 기존 포션 스택 성공, 신호 재진입, completed 재보고를 테스트한다.
- [ ] Journal을 codec 캡처/복원에 연결하고 슬롯 교체 전후 객체 공유가 없는지 검증한다. restore 완료 전에 이벤트를 받지 않는다.
- [ ] 대화 pause·닫기·F6 차단·통합 메뉴 상호 배제를 검증한다. 보상 중 저장 요청은 명시적으로 거부한다.
- [ ] 전체 GUT 및 변경 파일 형식/린트, 렌더 월드 회귀를 실행한다. `docs/qa/m5-first-quest-report.md`에 기록 후 커밋한다.

## 단위 3 — 재실행·실제 플레이 검증

신규 `godot/test/quests/first_quest_process_probe.gd`는 `user://m5_first_quest_probe`만 사용한다. `docs/qa/m5-first-quest-report.md`와 현황/인수인계를 갱신한다.

- [ ] active 1/2·ready 2/2·completed 상태를 각각 저장하고 새 프로세스에서 상태·레벨/EXP·골드·포션을 비교한다. completed 재보고 시 변화가 없어야 한다.
- [ ] V1 기존 캐릭터를 로드하고 레벨/장비를 유지한 채 NPC 의뢰를 시작한다. 다른 슬롯의 상태와 원본 해시가 변하지 않는지 확인한다.
- [ ] 실제 창에서 이동→NPC→수락→처치→보고→저장→종료→재실행한다. 입력 도구가 물리 키를 전달하지 못하면 자동 이벤트 주입으로 실제 조작 통과를 대신하지 않는다.
- [ ] 이동한 위치 복원 확인을 M4 미완료 항목에도 연결한다. 기존 종료 경고 6/2의 재현 여부는 별도 기록한다.
- [ ] 디버그 레벨업 없이 첫 두 의뢰 전후 레벨·시간·포션·사망을 기록한다. 9개 의뢰/Lv10 검증은 아직 주장하지 않는다.
- [ ] Claude에게 구현 커밋·보고서·재현 명령을 전달할 자료를 준비한다. 최종 문서와 커밋·푸시는 Codex가 담당한다.

## 이번 설계 단위 검증

기존 NPC 마커, interact 입력, 스포너/사망 신호, 가방 실패 조건, 저장 예약 필드 제약을 코드로 대조했다. 이 계획의 구현/테스트는 아직 실행하지 않았다. 다음 실제 구현 단위는 1이며, 2·3까지 이어져야 첫 수직 슬라이스 완료다.
