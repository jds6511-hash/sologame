# 토끼 추격 완화 및 C1 리뷰 보완 — 통합 검토 요청

- 최종 수정일: 2026-09-28
- 담당: Codex (구현·통합)
- 기준 커밋: `c8f5173` (직전 제품 구현 `d424a6d`, 인계 `b9e0b60`)
- 검토 대상 커밋: `3668bd4` (구현·테스트·진행 문서 15개)
- 근거: [디렉터 플레이 피드백](c1-director-play-feedback.md), [몬스터 정본](../design/systems/m2-monster-spec.md)

## 문제와 변경

디렉터는 이동·전투·퀘스트를 플레이한 뒤 토끼가 계속 도망가 잡기 어렵다고 보고했다. 기존 도주 종료 조건은 1.5초 경과와 인지 범위 이탈을 동시에 요구했다. 토끼는 4타일/초이고 플레이어는 공격 중 걷기 속도의 45%가 되어 추격만 길어질 수 있었다.

토끼는 이제 도주 타이머가 끝나면 거리와 무관하게 0.8초 휴식한다. 타이머 만료 판정은 박치기보다 먼저다. 휴식 중 접근해도 재도주·박치기를 시작하지 않는다. 휴식 종료 후 인지 범위 안이면 도주, 밖이면 배회한다. 도주 도중 잡혔을 때의 박치기 예고·판정·후딜은 유지한다. 경직 시 기존 넉백 처리는 그대로이며 행동 타이머는 정지한다. HP·피해량·이동 속도·퀘스트 보상·처치 수는 변경하지 않았다.

C1 독립 리뷰의 낮음 3건도 함께 처리했다.

1. codec의 `candidate` 불리언 분기 제거. 제품/호환 별칭 모두 동일 내부 구현을 직접 호출한다. 별칭을 공개 함수로 우회시키면 하위 테스트 클래스에서 재귀가 발생하므로 그렇게 하지 않는다.
2. C1 두 전직/보간 시작 필드가 10으로 일치해야 하는 배포 계약 주석 추가.
3. `growth.md`, `m3-leveling-spec.md`, `save-load.md`, `m3-balance-phase-d.md`의 변경 이력·날짜 갱신. D 전환 배너를 09-28로 정정.

리뷰의 참고 사항인 공유 Resource 임시 변이 테스트는 이번에 변경하지 않았다. 단순 복제로 바꾸면 실제 registry가 읽는 리소스와 분리되어 원래 독립성 검사의 의미가 약해질 수 있다. 후속 테스트 격리 정리 대상이며 낮음 3건의 처리와 구분한다.

## 검증

- 수정 전 토끼 검사: 13건 중 3건 실패. 지속 추격 시 정지 없음·접근 시 박치기·거리 확보 후 이동 속도 잔존을 새 단언으로 확인했다.
- 수정 후 토끼 검사: 13/13, assertions 20.
- 첫 전체 실행: 1034건 중 1건 실패. codec 호환 별칭의 재귀를 이번 리팩터가 만들었음을 호출 스택으로 확인하고 수정했다.
- 최종 전체 GUT: **1034/1034**, scripts 113, assertions **8914**(이번 관측값), exit 0. 최종 로그에서 SCRIPT ERROR·종료 잔존 경고 없음.
- C1 제품 process probe: cleanup → seed → hold → hold → save → verify → cleanup, **7/7 PASS**, 전부 exit 0·SCRIPT ERROR 없음. 기존 probe 종료 잔존 경고는 별도이며 해결 주장 없음.
- 변경 GDScript 5개 `gdformat --check` / `gdlint` 통과.
- 로그: `rabbit-rest-red.log`, `rabbit-rest-green.log`, `rabbit-c1-full.log`(실패 이력), `rabbit-c1-final.log`, `rabbit-c1-process.log` (로컬 QA 출력, 커밋 제외).

```powershell
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gtest=res://test/ai/test_rabbit_monster.gd -gexit
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
# 각 단계는 별도 프로세스
godot --headless --path godot -s res://test/save/c1_session_process_probe.gd -- cleanup
# 이어서 seed, hold, hold, save, verify, cleanup
```

## 변경 파일

- 행동/데이터: `godot/scripts/ai/rabbit_monster.gd`, `monster_stats_data.gd`, `godot/data/monsters/rabbit_stats.tres`.
- 회귀: `godot/test/ai/test_rabbit_monster.gd`.
- C1 보완: `godot/scripts/save/character_save_codec.gd`, `godot/scripts/progression/level_curve.gd` 및 위 설계 문서 4개.
- 설계/진행: `m2-monster-spec.md`, `docs/PROJECT_STATUS.md`, `docs/HANDOFF.md`, 이 검토 요청서와 피드백 기록.
- 타 작업자의 기존 스크린샷 9개 및 비관련 미추적 파일은 제외.

## 검토 요청과 남은 범위

1. 휴식 중 즉시 재도주/박치기로 공격 기회를 없애는 경로가 남았는가?
2. 기존 박치기·경직·사망 처리와 충돌하는가?
3. codec 별칭 정리가 원본 검증→변환→재검증 및 하위 테스트 클래스 호환을 유지하는가?

실제 처치 시간·근접/궁수 체감·0.8초의 적정성은 수정 후 직접 플레이로 아직 확인하지 않았다. 디렉터의 이전 플레이 보고를 수정 후 통과로 재사용하지 않는다. 의뢰 완료/보상·이동 후 저장 복원·G4/G5는 여전히 별도 판정 대상이다. 자동 검사만으로 100시간 완주나 C1 보스 체감을 보증하지 않는다.

## 변경 이력

| 날짜 | 변경 |
|---|---|
| 2026-09-28 | 구현 커밋 `3668bd4` 확정 및 검토 범위 연결 |
| 2026-09-28 | 토끼 행동 및 C1 리뷰 보완을 하나의 구현·검증 단위로 작성 |
