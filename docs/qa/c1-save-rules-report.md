# C1 저장 호환 단위 A — 규칙·검증기 구현 보고서

- 날짜/담당: 2026-09-27 / Codex 구현·통합. 기준 `4b02332`.
- 구현 커밋: `15fc0a3` (코드·테스트·문서 9개). 후속 커밋은 검토 대상 해시 기록이다.
- 의존: [계약](../design/systems/c1-save-migration.md), [설계 검토 요청](c1-save-migration-review-request.md).
- 변경 이력: 설계 리뷰 3건 반영 후 단위 A 구현·검증. 실제 런타임 곡선, codec 출력 V2, store 지원 V1/V2, 세션·변환기는 변경하지 않았다.

## 리뷰 대조와 결정

1. 의뢰 `== 2`는 V3 지원 확대 때 검증 누락을 만든다. 현재 제품은 버전 단계에서 V3를 거부하므로 현행 파일 우회가 이미 발생한다는 뜻은 아니다. 지원 여부 확인 후 `version >= 2`로 의뢰를 검사한다. 잘못된 ID·상태·counts·선행 조건을 V2/V3 모두 검사했다.
2. 규칙은 payload마다 새로 선택해 `player_error`와 `skills_error`의 인자로 넘긴다. 선택 규칙을 공유 인스턴스에 저장하지 않는다. 가변 필드도 매 호출 정확히 갱신하면 반드시 오염되는 것은 아니지만, 이번에는 그 갱신 의존 자체를 제거했다.
3. `test_save_file_store.gd`의 V2 payload 38곳을 재검색해 확인했다. 나머지 probe·함수명 변경 목록과 보존할 V1 fixture를 계약의 단위 C에 기록했다. 이번 단위에서 일괄 버전 치환은 하지 않았다.

## 구현 파일

| 파일 | 변경 |
| --- | --- |
| `godot/scripts/save/save_progression_rules.gd` | 저장 소유의 불변 구/C1 REQ 표(각99개), 만렙·전직 관문·포인트/강화 비용. 상태 없는 Legacy/Candidate 객체 |
| `godot/scripts/save/save_schema.gd` | 공통 검증 내부에서 버전별 규칙 선택·명시 전달, V2/V3 의뢰 검사. 실제 `character_error`는 V1/V2만, 별도 `candidate_character_error`는 후보 V3까지 검사 |
| `godot/test/save/test_save_progression_rules.gd` | 8개 테스트: 런타임 리소스 독립, 세대 교차, 의뢰 오류, 전 REQ 엔진 대조, 전 레벨 EXP 경계, 4직업 스킬/HP·MP, 계정·거래·콘텐츠 보호, JSON 버전 |
| `docs/design/systems/c1-save-migration.md` | 리뷰 보완·단위 A 경계·단위 C fixture 작업 목록 |
| `docs/qa/c1-save-migration-review-request.md` | 이전 설계 리뷰 종료 표시 |
| 본 보고서·`c1-save-rules-review-request.md` | 검증 근거·독립 리뷰 인계 |
| `docs/HANDOFF.md`·`docs/PROJECT_STATUS.md` | 현재 작업과 남은 B/C/D·게이트 기록 |

저장 스냅샷은 가변 `.tres`를 읽지 않는다. 후보도 저장을 변환하거나 이벤트를 발생시키지 않는다. int64 범위 검사·비율 변환 자체는 단위 B에 남는다. 후보 V3 허용이 실제 codec/store로 전파되지 않는 것을 기존 V3 거부 테스트와 신규 검사로 확인했다.

## 검증 기록

- 최초 3개 테스트 **0/3**: 런타임 곡선 변경에 따라 기존 검증이 `exp_overflow`, 후보 API 없음 2건. 미구현 실패와 기존 결합 재현을 구분한다.
- 구현 후 3/3, 확장 후 7/7·1,294 assertions.
- 첫 전체 실행 **990/1,008**: 새 버전 배열 포함 검사가 JSON의 float 버전(1.0/2.0)을 거부했다. 구현 중 도입한 회귀다. 별도 JSON 왕복 테스트를 추가해 **7/8, 5 assertions 실패**로 재현했다.
- 수정: 유한 정수 여부를 먼저 검사하고 허용 범위를 비교한 뒤 int로 변환. 큰 미지원 숫자도 int 변환 전에 거부한다.
- 최종 전체 GUT **Tests 1,009 / Passing 1,009 / Asserts 4,968 / Scripts 110**, exit 0. 신규 8개 포함. `SCRIPT ERROR` 없음. GUT 내부 orphan 표시·Deprecated 8 및 실패 경로 테스트의 디렉터리 생성 오류 출력은 존재하며 무경고 실행이라고 주장하지 않는다.
- 기존 `m5_migration_process_probe.gd`: cleanup → seed → upgrade → verify → cleanup **5단계 모두 M5_MIGRATION_PROCESS_PASS**, 각 exit 0, SCRIPT ERROR 없음.
- 변경 `.gd` 3개 `gdformat --check` / `gdlint` 통과. `git diff --check` 통과.

실행(설치된 Godot 4.7.1 콘솔 바이너리 사용):

```powershell
godot_console --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
godot_console --headless --path godot -s res://test/save/m5_migration_process_probe.gd -- <phase>
gdformat --check godot/scripts/save/save_schema.gd godot/scripts/save/save_progression_rules.gd godot/test/save/test_save_progression_rules.gd
gdlint godot/scripts/save/save_schema.gd godot/scripts/save/save_progression_rules.gd godot/test/save/test_save_progression_rules.gd
```

전99개 구REQ를 현행 엔진 곡선과, 후보REQ를 Godot의 C1 수식/roundi와 대조했다. 후보 합계61,860,102·Lv10 누적18,612 일치. 테스트가 런타임 리소스를 잠시 변경하는 경우 결과를 보관한 뒤 원복하고 단언한다. 새 후보 객체에 공유 가변 데이터는 없다.

## 미완료 경계

- **B**: 실제 EXP 비율 변환·입력 불변·멱등·V3 재검증 연계.
- **C**: 출력/허용 버전 및 원본 버전 기반 migration_pending 변경, 실제 혼합 세대 파일 복구·해시 보호 검증. 이번 세대 교차 검사는 동일 스키마 호출 검사이며 파일 복구 시험이 아니다.
- **D**: 승인된 C1 런타임과 V3 동시 전환. 새 보상 의뢰 ID/순서·보스95/98 밸런스 미확정.
- G4/G5 직접 플레이, M4 이월 항목 유지. 새 구현의 독립 검토는 Claude 담당이며 본 보고서는 구현자의 검사 결과다.
