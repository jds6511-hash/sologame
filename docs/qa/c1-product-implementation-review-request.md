# Claude 통합 구현 검토 — C1 런타임·V3 저장 제품 전환(D)

- 2026-09-27~28 / Codex 구현·통합. 기준 `af4df6f`, **구현·검증 커밋 `d424a6d`**. 후속 인계 커밋은 해시 고정만 하며 별도 검토 단위가 아니다.
- 디렉터가 권고안대로 구현 승인했다. **C1·공급 정책 채택, 기본 V3 전환, 보스 기준 우선95 유지**. 이는 G4/G5 플레이 통과나 100h 완주 확인이 아니다.
- [전환 계약](../design/systems/c1-product-rollout.md) · [저장 계약](../design/systems/c1-save-migration.md). 작은 보완별 인계 없이 이 묶음 전체를 검토한다.

## 구현 결과

1. `LevelCurveData`에 Legacy/C1 프로필을 추가하고 배포 `.tres`만 C1 선택. 기본 생성은 Legacy 유지. L<10 0.45·L10 1·L11~19 기하 보간·L≥20 0.4이며, 저장용 고정 배열에 런타임이 의존하지 않는다. Lv10 누적18,612 / Lv100 누적61,860,102.
2. 기본 Store가 V1/V2/V3 읽기·V3 쓰기, Codec가 V3 capture와 기본 `prepare_loaded` 변환을 수행한다. Schema는 원본 버전별 규칙으로 검사한다. 후보 API는 호환 경로로 남겼으나 검증/산술 구현은 제품과 공유한다.
3. 원본 검증→복사·정수 비율 변환→V3 재검증. V3 재입력 멱등, 레벨/직업/의뢰/장비/스킬 지출/계정 데이터 보존. 세션의 원본 버전 선보관·구 버전 로드 후 자동 저장 보류·첫 수동 성공 후 재개는 유지한다.
4. 추가 경계: `restore_into`에 구 버전 입력을 직접 주면 변환 없이 구EXP가 적용될 수 있었다. 실패 테스트로 재현한 뒤 **원본 스키마 검사 후 버전3만 적용**, 구 버전은 `migration_required`로 거부한다. 준비된 V3 복원은 정상 동작한다.
5. 기존 필요EXP154,381,573 단언은 `legacy_level_curve.tres`로 보존. V1/V2 입력 fixture는 유지하고 현재 쓰기 기대값만 V3로 갱신했다. 새 제품 곡선 전99값 및 버전 배선 테스트를 추가했다.
6. 두 Python 계산기는 공통 C1/Legacy 수식과 half-away 반올림 사용. 테스트는 현재 C1/역사 Legacy를 분리하고 실제 Godot 출력과 전99값·기본 몬스터EXP100값·반올림 경계를 대조한다.
7. 미래 S7/S11/S12 의뢰는 제작 계약 유지. 현재 MQ-01-01~03의 정의·목표·보상 변경과 소급 지급은 없다. 역사 Phase D 판정과 현재 산술 검증을 구분하고 관련 문서 상태를 동기화했다.

## 검증 및 한계

- 최초 제품 테스트2개 모두 실패를 확인한 뒤 전환. 첫 전체1,031개 중31개 실패는 이전 V2 출력/구 곡선 비교 기대값 등이며 모두 제품 결함이라고 주장하지 않는다. 구 fixture를 분리한 뒤 전체 통과.
- 직접 복원 우회: 제품 테스트3개 중1개 실패(4 assertions) 재현→가드 후 통과.
- 최종 GUT **1,032/1,032 · 113 scripts · 8,907 assertions(관측값)**. 기존 파일 생성 실패 주입의 ERROR 로그는 있으나 SCRIPT ERROR와 종료 잔존 경고는 구분한다.
- 변경 `.gd`19개 `gdformat --check` / `gdlint` 통과. `git diff --check` 통과.
- `c1_session_process_probe`: cleanup→seed→hold→hold→save→verify→cleanup **7단계 PASS/exit0/SCRIPT ERROR0**. 이번에는 후보 오버라이드가 아닌 기본 제품 World/Codec/Store다. V2 EXP50,000→V3 EXP20,000, 자동 보류, 원본 SHA-256, 수동 성공 백업, 별도 프로세스 재실행을 검사한다.
- 기존 `m5_migration_process_probe` **5단계**, `save_session_process_probe` **4단계**, `first_quest_process_probe` **11단계** 모두 PASS/exit0/SCRIPT ERROR0. 4직업 복원과 기존 의뢰 상태·재보고 보상 무중복을 유지한다.
- Godot `c1_curve_export.gd` 신규 출력 후 `C1_ENGINE_JSON`을 지정해 Python **6 tests OK, skip0**. 환경 변수 미지정 실행은 엔진 대조1개가 skip이므로 그것을 엔진 통과로 인용하면 안 된다.
- `verify_100_hour_exp_margin.ps1`의 산술/여유 모델 PASS 유지. 미검증 출력의 engine rounding은 구REQ 대조 완료와 혼동하지 않도록 **quest reward rounding**으로 한정했다. 실제 의뢰 보상 배분·지급 시점·플레이타임은 여전히 미검증이다.
- 종료 잔존 경고는 기존과 같이 별도 프로세스에서 관측: C1 hold/save/verify 4객체/2리소스, M4 seed 12/4, 의뢰 seed류4/2·복원류6/2 등. 고정 보장 수치나 해소 판정이 아니다. 정상 종료코드·PASS만으로 경고가 없다고 주장하지 않는다.
- 이동 후 위치는 직접 좌표 +8px, 시간은 `advance(181)`로 검증했다. 실제 이동 입력·3분 실시간 대기·디렉터 플레이를 대체하지 않는다. G4/G5 이월 유지.
- LegacyStore 검사는 이전 **파일 버전 거부 계약**만 재현한다. 구 실행 파일 전체를 실행한 다운그레이드 QA가 아니다.

## 재현 명령

```powershell
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
godot --headless --path godot -s res://test/save/c1_curve_export.gd -- C:/Users/UserK/Desktop/game/docs/qa/c1-engine-curves.json
$env:C1_ENGINE_JSON='C:/Users/UserK/Desktop/game/docs/qa/c1-engine-curves.json'
python docs/qa/tools/test_m3_exp_calculators.py
powershell -NoProfile -ExecutionPolicy Bypass -File docs/qa/tools/verify_100_hour_exp_margin.ps1
```

각 process probe는 위 단계 순서대로 별도 `godot --headless --path godot -s res://test/...gd -- <phase>` 프로세스를 실행한다. Windows 실측은 GUI shim 대신 Godot4.7.1 console exe를 사용했다. QA 폴더만 사용했고 실제 사용자 저장을 읽거나 변경하지 않았다.

## 독립 검토 요청

1. 제품 런타임·Schema·Codec·Store가 함께 전환됐으며 구 원본을 C1 규칙으로 먼저 검사하는 경로가 없는가?
2. 전99레벨 변환·직업/의뢰 상태·변환 후 재검증이 이제 제품 호출 경로에서 검증되는가? 직접 복원 가드가 우회/부분 적용을 막는가?
3. 현재 출력 기대값 갱신이 역사 V1/V2 입력과 Legacy99값 검증을 훼손하지 않았는가?
4. 혼합 세대 복구·자동 보류·수동 실패·다른 슬롯·재실행이 기본 제품 배선으로 닫혔는가?
5. 실제 엔진 대조와 문서 산술, 미래 콘텐츠 정책과 실제 지급 구현, 자동 QA와 직접 플레이의 경계가 정확한가?

## 확정 커밋·변경 파일

`d424a6d`의 변경40파일은 아래와 같다. 게임플레이/저장 전환, 테스트/계산기, 현행 문서 동기화만 포함하며 기존 스크린샷9개와 비관련 미추적 파일은 제외했다.

- `docs/design/100-hour-exp-margin.md`
- `docs/design/100-hour-progression-budget.md`
- `docs/design/100-hour-scope-audit.md`
- `docs/design/M3_PLAN.md`
- `docs/design/systems/c1-product-rollout.md`
- `docs/design/systems/c1-save-migration.md`
- `docs/design/systems/growth.md`
- `docs/design/systems/m3-balance-phase-d.md`
- `docs/design/systems/m3-leveling-spec.md`
- `docs/design/systems/save-load.md`
- `docs/HANDOFF.md`
- `docs/PROJECT_STATUS.md`
- `docs/qa/c1-product-implementation-review-request.md`
- `docs/qa/c1-product-rollout-review-request.md`
- `docs/qa/tools/m3_exp_math.py`
- `docs/qa/tools/m3_phase_d_balance_calc.py`
- `docs/qa/tools/m3_respawn_pace_calc.py`
- `docs/qa/tools/test_m3_exp_calculators.py`
- `docs/qa/tools/verify_100_hour_exp_margin.ps1`
- `godot/data/progression/level_curve.tres`
- `godot/scripts/progression/level_curve.gd`
- `godot/scripts/save/character_save_codec.gd`
- `godot/scripts/save/character_save_migrations.gd`
- `godot/scripts/save/save_file_store.gd`
- `godot/scripts/save/save_progression_rules.gd`
- `godot/scripts/save/save_schema.gd`
- `godot/test/progression/test_level_curve.gd`
- `godot/test/save/c1_candidate_environment.gd`
- `godot/test/save/c1_curve_export.gd`
- `godot/test/save/c1_session_process_probe.gd`
- `godot/test/save/legacy_level_curve.tres`
- `godot/test/save/m5_migration_process_probe.gd`
- `godot/test/save/save_store_process_probe.gd`
- `godot/test/save/test_c1_product_rollout.gd`
- `godot/test/save/test_c1_save_integration.gd`
- `godot/test/save/test_c1_save_migration.gd`
- `godot/test/save/test_m5_compatibility.gd`
- `godot/test/save/test_save_file_store.gd`
- `godot/test/save/test_save_progression_rules.gd`
- `godot/test/save/test_save_session.gd`
