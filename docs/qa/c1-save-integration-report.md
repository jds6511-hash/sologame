# C1 저장 호환 — 파일·세션·재실행 통합 보고서

- 2026-09-27 / Codex 구현·통합. 기준 `f24facf`.
- 구현·검증 커밋 **`decf2d5`** (15파일). 후속 인계는 보고서/요청서에 이 해시만 기록한다.
- 2026-09-27 독립 리뷰: C 통과. 리뷰어1,028/1,028·112 scripts·8,794 assertions는 작성자8,801과 별도 관측이다. 낮음 지적은 원본 버전을 호출 전에 Variant로 보관하고 검증 후 int 변환하도록 보완했다. 입력을 변경하는 codec 주입 시9/10 실패(2 assertions)→전체1,029/1,029·112 scripts·8,804 assertions 통과, GD2개 형식/린트 통과. 변경 파일은 `save_session.gd`, `test_c1_save_integration.gd`. 별도 보완 리뷰 대신 [D 전환·보상 설계](../design/systems/c1-product-rollout.md)와 묶었다.
- 의존: [계약](../design/systems/c1-save-migration.md), [B 보고서](c1-save-conversion-report.md).
- 변경 이력: B 통과를 반영하고 C의 파일 계층·세션·월드 교체·재실행을 한 검토 묶음으로 구현했다. 후보 환경 검증이며 기본 제품 전환은 아니다.

## 범위와 구조

실제 파일 교체/백업 및 세션 저장/로드 알고리즘을 복제하지 않았다. 다음 생성·버전 조회 지점만 분리하고, 테스트 하위 클래스에서 C1/V3를 함께 사용한다. 제품 스크립트는 테스트 파일을 참조하지 않는다.

| 변경 파일 | 목적 |
| --- | --- |
| `scripts/save/save_file_store.gd` | 현재/지원 버전 조회 메서드. 기본2/[1,2] 유지; 봉투 작성·읽기·본문 검사가 같은 조회를 사용 |
| `scripts/save/character_save_codec.gd` | `character_version()`으로 capture 출력과 세션 비교의 기준 공유. 기본2 |
| `scripts/save/save_session.gd` | `loaded_source_version < codec.character_version()` 보류 판정, store/다음 월드 생성 분리. 수동 성공 분기 외에는 보류 해제 안 함 |
| `scripts/world/eastern_frontier_starting_area.gd` | 세션 생성 메서드 분리. 기본 세션은 기존과 동일 |
| `test/save/c1_candidate_environment.gd` | 후보 schema/codec/store/session/world/curve를 함께 구성. `user://c1_candidate_` 폴더와 후보 곡선이 아니면 세션 setup 거부. 구 배포 Resource 수정 없음 |
| `test/save/test_c1_save_integration.gd` | 실제 파일/월드/세션 통합9개 검사 |
| `test/save/c1_session_process_probe.gd` | 종료·재실행 포함7단계 및 fixture 부재 음성 시험 |

위 경로는 `godot/` 기준이다. 문서는 B 보고서·B 요청서 종료 표기, `c1-save-migration.md`/`save-load.md` 경계 갱신, 본 보고서/통합 요청서, `HANDOFF.md`/`PROJECT_STATUS.md`를 변경했다.

원본 버전은 원본 검증이 성공한 뒤 변환본을 대입하기 전에 보관한다. 잘못된 버전의 int 변환을 피하며, 이번 부팅의 출처 값은 수동 저장 뒤에도 남긴다. `migration_pending`만 성공 시 해제한다.

기본 제품은 여전히 V2이고 C1/새 보상을 적용하지 않는다. 따라서 기존 V2 쓰기 fixture38곳과 probe/함수명은 의도적으로 유지했다. 후보 V3 파일은 별도 테스트 경로에서 검사한다. 실제 기본 출력 전환 때의 fixture 분류 작업이 완료됐다는 뜻은 아니다.

## 검증 결과

- 최초 후보 파일·월드 연결2개 **0/2**(4 assertions 실패) → 연결 후 **2/2**. 미구현 확인이다.
- 확장 중 테스트의 Dictionary 타입 추론 오류2건으로 GUT가 아무것도 실행하지 않고 exit0을 반환했다. 명시 타입으로 수정하고 **SCRIPT ERROR 검사**를 함께 사용했다. 이를 통과 실행으로 기록하지 않았다.
- 통합9개를 포함한 최종 전체 **GUT1,028/1,028 / Scripts112 / Asserts8,801**, exit0. assertions는 관측값이다. SCRIPT ERROR 없음. GUT의 기존 Deprecated8·내부 orphan 표기 및 의도적 IO 실패 오류 출력은 남는다.
- 변경 GD7개 `gdformat --check`/`gdlint` 통과. `git diff --check` 통과.

통합 검증 내용:

1. 후보 출력3/지원1·2·3과 기본 제품 V3 거부. C1 REQ20=39,355 동시 적용.
2. V1/V2 원본 부팅→메모리 V3, EXP20,000, 원본 버전 기록.180초 및 추가1,000초 호출에도 파일 해시 불변.
3. 대시 중 수동 거부·임시 파일 경로 장애로 쓰기 실패 시 보류/주 파일 유지. 성공 시 원본 `.bak` 보존 및 보류 해제. 이후179+1초 자동 저장 갱신 확인.
4. 주V2/백업V1, 주V3/백업V2의 정상 읽기 및 주 파일 스키마 오류→구 백업 복구. 같은 검증기 인스턴스에서 세대를 교차 검사하며 두 파일 해시 불변.
5. JSON 손상 주+V2 백업 복구·읽기 불변·수동 V3 저장 후 정상 백업 유지.
6. 미래 V4 주 파일 덮어쓰기 거부, 미래 백업의 `.bak.preserved.<sha256>` 보존. 콘텐츠 오류는 백업 폴백/보존 생성 없이 차단.
7. 메뉴 취소 후 보류 유지. 슬롯2 수동 저장이 슬롯1 원본을 유지. 실제 `load_slot` 월드 교체 뒤에도 후보 codec/곡선과 EXP를 유지.

### 별도 프로세스

`c1_session_process_probe.gd`: **cleanup→seed→hold→hold→save→verify→cleanup**, 매 단계 별도 Godot 프로세스.7단계 모두 `C1_SESSION_PROCESS_PASS`, exit0, SCRIPT ERROR0.

- seed는 구 V2와 최초 SHA-256을 생성한다.
- hold는 C1 월드로 부팅하고181초를 호출하되 자동 저장 보류를 확인하고 종료한다. 두 번째 hold가 원본 V2 재부팅/해시 보존을 다시 확인한다.
- save는 위치를 `(160,504)→(168,504)`로 변경하고 골드99로 수동 저장. 구 원본 백업 해시 확인.
- verify는 새 프로세스에서 V3·보류 해제·EXP20,000·C1곡선·위치·골드·백업 해시·구 제품의 V3 거부 확인.
- cleanup 뒤 seed 없이 verify는 **exit1, `["seed fixture missing"]`, SCRIPT ERROR0**. 음성 시험 통과.
- 최초 probe는 preload 시 오토로드 이름이 준비되지 않아 컴파일 오류가 났다. 지연 실행 안에서 환경을 load하도록 수정했다. 초기 실행의 PASS 문자열은 SCRIPT ERROR가 있어 폐기했고 이후7단계를 다시 실행했다.
- 후보 hold/save/verify 종료 시 **객체4·리소스2 잔존 경고** 관측. 원인 미확정이며 무경고 실행이라 하지 않는다. 해시/재실행 검증은 통과했다.

기존 `m5_migration_process_probe.gd`의 cleanup→seed→upgrade→verify→cleanup도 **5단계 PASS·exit0·SCRIPT ERROR0**. 기본 제품의 V1→V2 경로 회귀 확인이다.

실행은 Godot4.7.1 콘솔 `--headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit`; probe는 `-s res://test/save/c1_session_process_probe.gd -- <phase>`. 종료 코드뿐 아니라 PASS 표식·SCRIPT ERROR 부재를 함께 검사한다.

## 남은 경계

- 후보 통합은 실제 기본 제품의 V3 배포/C1 적용 승인이 아니다. 기본 곡선과 새 의뢰 보상은 미변경이다.
- 후보 probe는 코드로 시간을 진행시키고 좌표를 옮긴다. 사람의 물리 입력·실제180초 대기·G4/G5 직접 플레이를 입증하지 않는다.
- 계정→캐릭터 비원자성, 헤드리스 종료 잔존 경고, 기존 장비 스탯 미배선 유지.
- 독립 리뷰 대상은 이 통합 묶음 한 건이다. 이후에도 작은 커밋은 유지하되 연결된 구현·검증을 묶어서 전달한다.
