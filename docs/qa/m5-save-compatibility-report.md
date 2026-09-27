# M5 단위 1 — 저장 호환성·퀘스트 상태 검증

- 기준 커밋: `64d7f61`. 구현 커밋: **`d5878fd`**. [Claude 코드 리뷰 요청](m5-save-compatibility-review-request.md).
- 범위: 캐릭터 V2 쓰기/V1·V2 읽기, 순수 메모리 변환과 양쪽 스키마 검사, 이전 버전 자동 저장 보류, 공유 퀘스트 카탈로그와 상태 검증.
- 상태: `d5878fd` Claude **단위 1 통과**. 후속 지적·검증·보완 커밋은 [리뷰 대응](m5-save-compatibility-review-response.md)에 기록한다. 아래 수치는 원 구현 검증 이력이다. NPC·대화·보상 실행 및 G5 플레이 통과는 아직 아니다.

## 동작과 판단

V1 슬롯을 열면 원본은 그대로 두고 메모리의 캐릭터를 V2로 변환한다. `migration_pending` 동안 자동 저장은 쓰기를 하지 않는다. 수동 저장 성공 후에만 보류를 해제하고 180초 타이머를 새로 시작한다. UI 배지·슬롯 목록·메시지에 수동 저장 필요를 표시한다. 계정은 V1을 유지하며 recovered 자동 저장 보호도 유지했다.

봉투/payload 버전을 읽기·쓰기 모두 교차 검사한다. 지원 버전 불일치는 `invalid_data`로 보존하고 미래 버전은 덮어쓰기 거부한다. 정상 V1 주 파일을 V2로 수동 저장하면 정상 V1 원문이 백업으로 남는다. JSON 파싱 뒤 버전이 float가 되는 경계를 정수성 검사 후 정규화했다.

QuestData Resource 2개와 QuestCatalog가 ID/선행/목표/수량/보상의 정본이다. 검증기는 같은 정의를 받아 상태·counts·목표 순서·선행 완료를 검사한다. MQ-01-01 완료는 패 소유를 뜻하며, 실제 자동 수락·대화·지급은 단위 2에서 연결한다. 이 단위의 V1 변환은 빈 quests를 보존하고 보상을 지급하지 않는다.

실행 판단: Claude는 독립 리뷰 담당이므로 구현은 Codex가 기존 공유 작업공간에서 수행했다. 착수 시 tracked 변경은 없었고, 기존 untracked 로그·타 작업자 설정/에셋은 커밋에서 제외했다. 마이그레이션 함수는 검증된 입력을 복제하는 순수 함수이며 계정 연결까지 포함한 진입점은 `codec.prepare_loaded(data, account)`다.

## 변경 파일

| 파일(아래 경로는 godot/ 기준) | 변경 이유 |
|---|---|
| scripts/quests/quest_data.gd, quest_catalog.gd, quest_state_schema.gd | Resource 정의·공유 카탈로그·캐릭터별 상태 검증 |
| data/quests/mq_01_01.tres, mq_01_02.tres | 확정된 두 의뢰 목표/보상 데이터 |
| scripts/save/character_save_migrations.gd | 입력을 변경하지 않는 V1→V2 변환 |
| scripts/save/character_save_codec.gd, save_schema.gd | 버전별 검증·변환 후 재검증·V2 캡처 |
| scripts/save/save_file_store.gd | 지원 버전과 쓰기 버전 분리·봉투/본문 검사 |
| scripts/save/save_session.gd, save_menu.gd | 세션 자동 저장 보류·실패/성공 경계·UI 안내 |
| test/save/test_m5_compatibility.gd, test/quests/test_quest_state_schema.gd | 변환·원본/백업·버전·상태 경계 테스트 |
| test/save/test_save_session.gd | V1 보류·수동 실패/성공·다른 슬롯·새 부팅 검증 |
| test/save/test_save_file_store.gd, save_store_process_probe.gd | 기존 파일 계층 fixture에 필수 본문 버전 추가. 기존 보호 테스트 유지 |
| test/save/m5_migration_process_probe.gd | 별도 프로세스로 V1 읽기→수동 변환→V2 재실행 검증 |

새 스크립트의 생성된 `.uid`도 함께 추적한다. 저장 계약·실행 계획·진행 현황·인수인계·리뷰 인계 문서는 구현 상태와 검증 범위를 동기화한다.

## 검증 결과

- 구현 전 신규 호환성 테스트 **4/4 실패** 확인: V2 캡처, V2 퀘스트 상태 허용, 읽기/쓰기 버전 불일치.
- 저장/퀘스트 집중 검증 **68/68·395 assertions** 통과. 이후 배지 단언을 추가한 전체 검증은 아래 수치다.
- **전체 GUT 966/966·3389 assertions·104 scripts** 통과. 기존 의도적 I/O 실패 테스트의 디렉터리 오류 1건 외 스크립트 오류/종료 잔존 경고 없음.
- 변경 GDScript **15개 gdformat/gdlint 통과**.
- 신규 probe cleanup → seed → upgrade → verify → cleanup 모두 `M5_MIGRATION_PROCESS_PASS`, exit 0.
- 기존 4직업 세션 probe cleanup → seed → verify → cleanup 모두 `M4_SESSION_PROCESS_PASS`, exit 0. 장비 8칸·강화·스킬 지출·위치·시각 비교 유지.
- 문서 상대 링크·git diff 공백 검사 수행. 실제 네이티브 UI 조작은 이번 단위에서 수행하지 않았다.

실패/수정 이력: 최초 JSON 재로드에서 정수 배열 membership과 float 버전 값이 맞지 않아 실패했다. 정수성 확인 후 int로 비교해 해소했다. 신규 SceneTree probe의 최초 preload는 Autoload 준비 전 컴파일 오류를 냈으며 기존 probe처럼 deferred 실행 시 load하도록 수정했다. 해당 실패 실행은 중단 후 다시 실행했고 위 PASS는 수정 후 결과다.

## 재현

저장소 루트에서 실행한다. 프로세스별로 종료를 기다린 뒤 다음 명령을 실행한다. 테스트는 실제 `user://saves`를 사용하지 않는다.

```powershell
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
godot --headless --path godot -s res://test/save/m5_migration_process_probe.gd -- cleanup
godot --headless --path godot -s res://test/save/m5_migration_process_probe.gd -- seed
godot --headless --path godot -s res://test/save/m5_migration_process_probe.gd -- upgrade
godot --headless --path godot -s res://test/save/m5_migration_process_probe.gd -- verify
godot --headless --path godot -s res://test/save/m5_migration_process_probe.gd -- cleanup
```

## 제한과 다음 단위

- 신규 headless probe 종료 잔존 경고: seed **4 objects/2 resources**, upgrade·verify **6/2**. 데이터 검증은 통과했지만 종료 경고가 없어졌다고 주장하지 않는다.
- M4의 계정→캐릭터 비원자성, 장비 전투 스탯 비배선, 직접 이동 후 위치 복원/G4 판정은 그대로 이월한다.
- 캐릭터 V2 파일은 구 M4 빌드가 미지원 버전으로 거부한다. V1 원문 백업 보존과 명시적 수동 전환으로 제어한다.
- 단위 2에서 Journal·NPC·대화·보상·스포너 start·pause 중재를 연결한다. 단위 1 카탈로그만으로 플레이 흐름이 완성된 것은 아니다.
