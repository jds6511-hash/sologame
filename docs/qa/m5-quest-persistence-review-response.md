# M5 단위 3 자동 검증 — Claude 리뷰 대응

- 날짜: 2026-09-27. 검토 대상 `f11430e..3022586`, 이번 보완 기준 `2e51152`.
- 보완 커밋: **`c3e25e9`**, 범위 `2e51152..c3e25e9`.
- 판정: **검증 스크립트 타당, 보고서 주장 정확**. 실제 관통 플레이·G4/G5는 여전히 미완료.
- [보고서](m5-quest-persistence-report.md) / [기존 요청](m5-quest-persistence-review-request.md).

## 코드 대조와 처리

1. **종료 처리(낮음)**: 완료 플래그를 오디오 정리 전에 검사한다. BgmManager는 `get_node_or_null`과 `has_method`로 확인하고 부재 시 명시적 오류를 남긴 뒤 종료한다. 단순히 검사 순서만 바꾸는 것으로 프로세스 종료를 보장할 수 없으므로 널 가드도 추가했다. reset 내부 임의 오류를 모두 처리했다고 주장하지 않으며 실행 시 stderr 검사도 유지한다.
2. **fixture 진단(낮음)**: expected 파일과 hashes 파일을 월드 생성·저장 전에 확인한다. 부재 시 파일명과 `run seed first`, JSON이 객체가 아니거나 비어 있으면 별도 오류를 기록한다. 잘못된 Dictionary 대입으로 중단되는 경로를 제거했다.
3. **사설 타이머 접근(낮음)**: 보류. 영속성 probe의 명시적인 fixture 설정이며 실제 저장 안전성/전투 체감 검증이 아니다. 이 테스트만을 위해 제품 API를 추가하지 않는다. 필드 변경 시 완료 플래그와 SCRIPT ERROR 검사로 검증 실패가 드러난다. 향후 테스트 설정을 공통화할 때 함께 재검토한다.
4. **종료 경고 표기**: 비결정적으로 정정했다. 최초 실측 수치는 이력으로 남기되 고정 기준으로 사용하지 않는다. Claude는 active 연속 실행에서 경고 유무 차이를 확인했고, 이번 재실행에서는 ready/completed/legacy도 6/2였다. 원인은 확정하지 않는다.

## 변경 파일

- `godot/test/quests/first_quest_process_probe.gd`: 종료 가드와 fixture 진단.
- `m5-quest-persistence-report.md`, `m5-quest-persistence-review-request.md`, 이 대응 문서: 검토 판정·진단 보완·경고 정정.
- `docs/PROJECT_STATUS.md`, `docs/HANDOFF.md`, `docs/design/DEVELOPMENT_ROADMAP.md`: 자동 검증 리뷰 통과와 남은 직접 플레이 구분.
- 게임 코드와 기존 수정 스크린샷은 변경/커밋에 포함하지 않는다.

## 직접 재검증

- 수정 전 cleanup→active(seed 없음): exit 1, 출력은 `phase reached final checks`뿐이며 Dictionary 대입 SCRIPT ERROR 발생.
- 수정 후 동일 조건: exit 1, `fixture missing: expected_1.json (run seed first)`, `fixture missing: hashes.json (run seed first)` 및 완료 플래그 실패 출력. SCRIPT ERROR 없음.
- 정상 cleanup→seed→active→ready→completed→legacy→cleanup: **7단계 PASS, 각각 exit 0, SCRIPT ERROR 없음**.
- 변경 GDScript 1개 `gdformat --check` 및 `gdlint` 통과. 게임 코드 변경이 없어 전체 GUT/렌더는 이번에 재실행하지 않았다.
- 이번 정상 실행의 종료 경고: seed 4/2, active/ready/completed/legacy 6/2, cleanup 없음. 고정 기준이 아닌 관측값이다.
- 로컬 로그 `m5-review-before-*`, `m5-review-{seed,active,ready,completed,legacy,cleanup}*`는 커밋 제외. 정상/음성 실행은 출력과 exit code, stderr를 함께 확인했다.

오디오 오토로드 부재 가드는 코드 대조로 확인했으며 제거 주입 테스트는 하지 않았다. JSON 손상 분기는 방어 처리로 추가했고 이번 실행 검증은 fixture 부재와 정상 데이터에 한정한다.

## 다음 단계

자동 영속성 검증을 NPC 근접/레이캐스트·대화 선택·monster.died 배선의 종단 간 검증으로 확대 해석하지 않는다. 해당 배선의 자동 검증은 기존 단위 2 GUT/렌더 범위다.

남은 것은 정상 물리 키 환경에서 이동→대화→수락→실제 처치→보고→저장→종료→재실행이다. 이동 후 위치 복원, 아이템/NPC 프롬프트 우선순위, 패 수령 후 재대화, 저장 거부 빈도를 함께 기록한다. 이 플레이가 끝나기 전에는 단위 3 전체·G4/G5를 닫지 않는다.
