# C1 저장 호환 단위 B — 순수 변환 보고서

- 2026-09-27 / Codex 구현·통합. 기준 `c5adb9c` (단위 A 리뷰 보완 포함).
- 의존: [계약](../design/systems/c1-save-migration.md), [A 보고서](c1-save-rules-report.md).
- 변경 이력: 후보 원본 검증→정수 비율 변환→후보 재검증 구현. 제품 곡선·출력 V2·파일 계층·세션 미변경.

## A 리뷰 처리

`c5adb9c`에서 누락 전직 관문을 `unknown_job`으로 거부하고 레지스트리/고정 규칙 키 집합 일치 테스트를 추가했다. 실패8/9→통과9/9·1,302 assertions. A의 전체 assertions4,967/4,968은 각각 실행 관측값으로 기록했다. 변동 원인은 이번에 별도로 추적하지 않았다. 본 단위의 전체 회귀에 A 보완도 포함했다.

## 변경 파일과 동작

| 파일 | 변경 이유/동작 |
| --- | --- |
| `godot/scripts/save/character_save_migrations.gd` | `upgrade_candidate`와 정수 비율 산술. 원본 세대 REQ로 EXP 범위를 확인하고 곱셈 전에 int64 범위 검사. 깊은 복사본의 버전/EXP만 변경 |
| `godot/scripts/save/character_save_codec.gd` | `prepare_candidate_loaded` 후보 진입점. 공통 내부 경로가 선택한 검증기를 원본과 결과에 모두 적용. 실제 `prepare_loaded`는 기존 V2 유지 |
| `godot/test/save/test_c1_save_migration.gd` | 순수 변환9개 검사. 부등식으로 floor 조건 확인, 변환 후 실패 주입, 오버플로 경계, 입력/중첩 복사 격리 |
| `docs/design/systems/c1-save-migration.md`, `save-load.md` | 실제 B 후보 구현과 C/D 미적용 경계 및 예시 산술 정정 |
| 본 보고서·`c1-save-conversion-review-request.md` | 검증 기록과 새 구현 검토 요청 |
| `docs/HANDOFF.md`·`docs/PROJECT_STATUS.md` | A 종료/B 검토 대기·C/D 및 G4/G5 이월 |

`upgrade_candidate`는 산술에 필요한 입력만 방어하며 전체 계정/의뢰 검증기는 아니다. 호출 계약은 codec의 원본 전체 검증 이후다. 실패는 빈 data를 반환하고 파일·플레이어·보상에 접근하지 않는다. V1은 기존 V1→V2 복사를 거친 뒤 V3로 올린다. V3 재입력은 같은 값의 독립 복사본을 반환한다. Lv100은 EXP0만 허용한다.

### 예시 계산 정정

이전 설계 리뷰의 `floor(50,000 × 39,355 / 98,387) = 19,999`는 틀렸다. 실제 몫은 **20,000**, 나머지는 **10,000**이다. 처음 테스트에 리뷰의19,999를 넣어 실행했을 때 이 단언만 실패했고, PowerShell 독립 계산과 정수 곱셈 항등식으로 기대값을 정정했다. 구현을 잘못된 기대값에 맞추지 않았다.

## 검증

- 후보 API 부재를 먼저 실행해 **0/2** 실패 확인. 이는 미구현 확인이며 기존 제품 결함2건을 뜻하지 않는다.
- 구현 후 예시 기대값1건 실패 → 위 산술 정정 → 확장 **9/9·3,739 assertions**, 별도 GUT 프로세스에서 실행.
- 전 레벨1~99 × 원본 V1/V2 × EXP0/1/REQ−1: 결과 범위, `converted×old_req ≤ old_exp×new_req < (converted+1)×old_req`, 원본 불변 및 버전/EXP 외 전체 필드 동일 확인.1~10 EXP 정확 보존,100 EXP0/1 허용/거부.
- Lv20/EXP50,000 변환20,000과 같은 payload의 V3 위장 거부를 분리. JSON 숫자 처리, V3 재입력 멱등 및 중첩 컨테이너 독립 확인.
- 4직업 × 의뢰 active/ready/completed:8장비 칸·가방·골드·HP/MP·스킬 강화/실지출·위치/시각 전체 payload 보존 확인. V1의 의뢰 예약, 다른 계정·미완 거래·미등록 의뢰·미지원 버전·잘못된 EXP 거부.
- 변환 후 검증기가 `vitals`를 반환하도록 주입해 빈 실패 결과와 원본 불변 확인. 변환본 재검증 생략 회귀를 잡는 검사다.
- 산술 helper:2^53 경계를 넘는 값에서 정수 결과 보존, int64 곱셈 허용/초과 경계 및0/음수 REQ 거부. helper 사설 호출은 산술 경계 시험에 한정한다.
- 최종 전체 **GUT Tests1,019 / Passing1,019 / Scripts111 / Asserts8,707**, exit0. assertions는 해당 실행 관측값이다. `SCRIPT ERROR` 및 종료 ObjectDB/resources 잔존 경고 없음. GUT 내부 orphan 표기·Deprecated8 및 실패 경로의 오류 출력까지 없다고 주장하지 않는다.
- 기존 마이그레이션 probe **cleanup→seed→upgrade→verify→cleanup 5단계 M5_MIGRATION_PROCESS_PASS**, 각 exit0, SCRIPT ERROR 없음. 기존 V1→V2 제품 흐름 확인이며 V3 파일 복구 시험이 아니다.
- A 보완 포함 변경 GD5개 `gdformat --check`/`gdlint` 통과. `git diff --check` 통과.

실행 명령: 설치된 Godot4.7.1 콘솔에서 `--headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit`. 단위 테스트는 `-gtest=res://test/save/test_c1_save_migration.gd`. 기존 probe는 `-s res://test/save/m5_migration_process_probe.gd -- <phase>`.

## 남은 범위

실제 경로의 `capture`/store 출력2, 읽기1/2, `prepare_loaded`/`restore_into`의 V3 거부를 유지한다. 후보 호출은 테스트에서만 사용한다. 새 V3 저장 파일 생성, 혼합 세대 주/백업 복구, 세션 migration_pending 일반화 및 원본 해시 보호는 **단위 C**다. C1 런타임 전환은 **단위 D**이며 곡선/보상 적용 승인을 대신하지 않는다. 실제 의뢰 지급 순서·보스95/98·G4/G5 직접 플레이도 미확정이다.
