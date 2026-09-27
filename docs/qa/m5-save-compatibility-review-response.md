# M5 단위 1 리뷰 대응·보완 검토 요청

- 기준: `9c81c7c` (구현 `d5878fd`, 최초 비교 기준 `64d7f61`).
- Claude 판정: **단위 1 통과**. 아래는 통과 후 보완이며 설계 재승인 요청이 아니다.
- 보완 구현 커밋: **`08af954`**. 검토 범위: `9c81c7c..08af954`.
- 범위: 정적 의뢰 콘텐츠 검증·저장 오류 분류·단위 2 이월 명확화. NPC/대화/보상 실행은 아직 미구현이다.

## 지적별 처리

| 지적 | 처리·근거 |
|---|---|
| 중간 1: 수락한 의뢰만 정의 검사 | 카탈로그 생성 시 모든 정의를 검사하고 의뢰 ID별 오류를 `push_error`로 알린다. 저장 경로에서도 전체 카탈로그를 확인하고 `quest_content_error`로 차단한다. 오류를 손상 저장으로 오인해 백업 복구·보존본 이동·덮어쓰기를 하지 않는다. 디버그 assert에만 의존하지 않는다. |
| 중간 2: 보상 미검증 | EXP·골드·아이템 수량 음수와 ID/수량 불일치를 거부한다. 아이템 존재 여부는 기존 저장 레지스트리와 같은 `SaveContentManifest.ITEMS`를 사용한다. NPC ID 대조는 단위 2 NPC 등록 시 수행한다. |
| 낮음 1: 자동 수락 귀속 | 계약 §6에 단위 1은 `{}` 유지, 단위 2 Journal이 MQ-01-01 자동 수락을 수행한다고 명시했다. |
| 낮음 2: 공유 Resource | 카탈로그에 읽기 전용 계약을 표시하고 계획에 두 Journal의 진행·보고·복원 전후 정의/다른 캐릭터 상태 불변성 검증을 추가했다. 테스트의 잘못된 정의 주입도 `duplicate(true)`로 격리한다. 실제 Journal 검증은 단위 2 이월이다. |
| 낮음 3: codec 버전 0 | 숫자 형식 검사와 지원 버전 검사를 분리했다. 0·-1·3·JSON 정수형 float 0.0 모두 `unsupported_version`. 비정수·비숫자는 기존 형식 오류로 남는다. |

## 변경 파일

- `godot/scripts/quests/quest_data.gd`: 보상 수치/ID·수량 정합성.
- `godot/scripts/quests/quest_catalog.gd`: 모든 정의 및 등록 아이템 검사, 생성 시 진단.
- `godot/scripts/save/save_schema.gd`: 콘텐츠 오류 차단 및 버전 분류.
- `godot/scripts/save/save_validation_codes.gd`: `quest_content_error` 차단 코드.
- `godot/scripts/save/save_file_store.gd`: 읽기·백업·쓰기·보존 경로가 공유 `BLOCKED` 목록 사용. 기존 미완 거래/미지원 거래 기록 차단을 유지한다.
- `godot/scripts/save/save_menu.gd`: 콘텐츠 오류 한국어 안내.
- `godot/test/quests/test_quest_state_schema.gd`, `godot/test/save/test_m5_compatibility.gd`: 신규 회귀 테스트 4개.
- `docs/design/systems/npc-dialog-quest.md`, `docs/superpowers/plans/2026-09-27-m5-first-quest.md`: 콘텐츠 오류 계약과 단위 2 책임 명시.
- `docs/qa/m5-save-compatibility-report.md`, `m5-save-compatibility-review-request.md`, 본 대응 문서: 원 리뷰 통과와 후속 제출 구분.
- `docs/PROJECT_STATUS.md`, `docs/HANDOFF.md`, `docs/design/DEVELOPMENT_ROADMAP.md`: 현행 판정과 다음 작업 갱신.

## 검증

- 최초 실행: 72개 중 4개 실패. 그중 3개는 미구현 동작의 단언 실패, 1개는 테스트 fixture의 typed Array 대입 오류였다. fixture를 `assign()`으로 고친 후 최종 전체 실행으로 검증했다. 4개 모두 제품 결함을 재현했다고 주장하지 않는다.
- 전체 GUT: **970/970, 3417 assertions, 104 scripts**, exit 0.
- 변경 GDScript **8개** `gdformat --check` / `gdlint` 통과. `git diff --check` 통과.
- `m5_migration_process_probe.gd`: cleanup → seed → upgrade → verify → cleanup 모두 `M5_MIGRATION_PROCESS_PASS`, exit 0.
- 미수락 MQ-01-02의 목표 수량 0 / 미등록 보상 ID 각각에 대해 로드·쓰기 차단, 백업 미조회, 주 파일/백업 SHA-256 및 파일 수 2개 유지 확인.
- 전체 GUT 종료 잔존 경고 없음. 의도적 디렉터리 생성 실패 테스트 1건의 오류 출력은 예상 동작이다. 프로세스 종료 경고는 아래 제한과 구분한다.

재현: 기존 [단위 1 요청](m5-save-compatibility-review-request.md)의 전체 GUT 및 5단계 probe 명령을 그대로 실행한다. 변경 `.gd` 목록은 `git diff --name-only 9c81c7c 08af954 -- '*.gd'`로 얻는다.

## Claude에게 전달할 요청

> `9c81c7c..08af954`를 읽기 전용으로 검토해 주세요. 전체 카탈로그 검사가 미수락 의뢰를 포함하는지, 콘텐츠 오류가 invalid_data로 변환되거나 백업·보존·교체로 우회되지 않는지, 기존 거래 차단 조건이 유지되는지 확인해 주세요. 신규 보상 검사와 codec 버전 분류도 재현해 주세요. 단위 1 통과 판정은 이미 수신했으며 이번에는 보완 변경만 검토 대상입니다.

## 다음 작업과 제한

다음은 **단위 2 NPC·대화·Journal·명시적 보고/보상·스폰 시작 순서·UI pause 중재**다. 공유 정의 불변성 및 NPC ID 검증을 포함한다. 콘텐츠 오류 시 새 캐릭터 저장도 차단하는 정책이며, 게임 데이터 수정 전까지 잘못된 콘텐츠로 새 저장을 생산하지 않는다.

실제 창 플레이는 이번에 수행하지 않았다. M4 직접 이동 후 위치 복원·G4 승인, M5 수직 슬라이스/G5 판정은 미완료다. 이번 probe에서 seed 종료 4 objects/2 resources, verify 종료 6/2 경고를 관측했고 upgrade 오류 로그는 비어 있었다. 기존 headless 종료 잔존 경고를 해결한 커밋은 아니다.
