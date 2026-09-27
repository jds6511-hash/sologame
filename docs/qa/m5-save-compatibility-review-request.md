# Claude 코드 리뷰 요청 — M5 단위 1

- 검토 대상: **`d5878fd`**, 비교 기준: **`64d7f61`**.
- 상태: Claude **단위 1 통과** 회신 수신. 이 문서는 원 요청 이력이며 후속 제출은 [리뷰 대응·보완 검토 요청](m5-save-compatibility-review-response.md)을 사용한다.
- [검증 보고서](m5-save-compatibility-report.md), [계약](../design/systems/npc-dialog-quest.md), [실행 계획](../superpowers/plans/2026-09-27-m5-first-quest.md).

## 전달 요청

> `64d7f61..d5878fd`의 M5 단위 1을 독립 검토해 주세요. 파일 수정·커밋·브랜치 변경·푸시 없이 코드와 테스트를 대조하고 결과를 재현해 주세요. V1/V2 검증·원본 보존, migration_pending 해제 조건, 퀘스트 상태 검증이 승인된 계약을 만족하는지 확인해 주세요. 지적은 중요도·코드 위치·실패 시나리오·보완 제안으로 작성하고 마지막에 단위 1 판정을 주세요. NPC/대화/보상 실행은 단위 2이며 이번 구현 범위가 아닙니다.

## 집중 검토

1. `save_file_store.gd`: 읽기 허용 V1/V2와 쓰기 V2 분리, JSON 숫자 타입, 봉투/본문 교차 검사. 불일치 `invalid_data`의 원본 보존과 미래 버전 거부. 미완 거래·백업 보호 회귀 여부.
2. `save_schema.gd`·`character_save_codec.gd`·`character_save_migrations.gd`: V1의 빈 예약 필드 제약 유지, 계정 연결 포함 원본 검사 → 복제 변환 → V2 재검증. 마이그레이션 함수는 검증된 입력용이고 공개 로드 진입점은 `prepare_loaded`라는 경계.
3. `save_session.gd`·`save_menu.gd`: V1 로드 시 파일을 쓰지 않고 자동 저장 보류, 수동 실패/취소는 유지, 성공 후만 해제/타이머 초기화. 다른 슬롯·새 캐릭터로 상태 누출 없음. recovered 보호와 안내 유지.
4. `quests/quest_data.gd`·`quest_catalog.gd`·`quest_state_schema.gd` 및 의뢰 2개: 카탈로그가 정의의 단일 출처인지, 상태/counts/선행/목표 순서의 잘못된 조합이 거부되는지. 공유 Resource를 진행 상태로 변경하지 않는지.
5. 기존 파일 계층 fixture에 버전 필드를 추가한 변경이 실패/보존 테스트를 약화하지 않았는지. UI/프로세스 검증과 단순 Dictionary 검증의 범위를 구분했는지.

## 재현 명령

저장소 루트 PowerShell에서 프로세스 종료를 기다리며 실행합니다. Windows GUI Godot 실행 파일은 `Start-Process -Wait` 또는 콘솔 실행 파일을 사용해야 결과 수집 전에 돌아오는 문제를 피할 수 있습니다.

```powershell
git diff --check 64d7f61 d5878fd
git diff --stat 64d7f61 d5878fd
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
godot --headless --path godot -s res://test/save/m5_migration_process_probe.gd -- cleanup
godot --headless --path godot -s res://test/save/m5_migration_process_probe.gd -- seed
godot --headless --path godot -s res://test/save/m5_migration_process_probe.gd -- upgrade
godot --headless --path godot -s res://test/save/m5_migration_process_probe.gd -- verify
godot --headless --path godot -s res://test/save/m5_migration_process_probe.gd -- cleanup
```

예상: 전체 **966/966·3389 assertions·104 scripts**. 신규 probe 각 단계 `M5_MIGRATION_PROCESS_PASS`, exit 0. 기존 `save_session_process_probe.gd` cleanup/seed/verify/cleanup도 재현 가능하며 4직업 복원 PASS다.

GDScript 15개 목록은 `git diff --name-only 64d7f61 d5878fd -- '*.gd'`로 얻어 `gdformat --check`와 `gdlint`에 전달한다. 계획/보고서의 향후 NPC 파일은 아직 존재하지 않으므로 검사 목록에 넣지 않는다.

## 알려진 제한

- 전체 GUT의 의도적 디렉터리 I/O 실패 1건은 테스트에서 예상한 오류다. 전체 GUT 종료 잔존 경고는 없다.
- 신규 headless probe seed 종료 4 objects/2 resources, upgrade·verify 종료 6/2 경고는 남아 있다. 기존 4직업 seed의 16/4도 유지된다. 저장 검증 PASS와 경고 해소를 구분한다.
- 신규 Native UI 플레이는 하지 않았다. M4 직접 이동 후 위치 복원/G4 판정도 이월 상태다.
- Journal 자동 수락/실제 퀘스트 보상은 아직 연결하지 않았으며 NPC 없는 카탈로그 구현을 수직 슬라이스 완료로 주장하지 않는다.

회신 후 Codex가 지적을 코드와 대조해 보완하고 후속 커밋을 전달한다. 이번에는 설계 재승인 대신 **실제 구현의 단위 1 통과 여부**를 요청한다.
