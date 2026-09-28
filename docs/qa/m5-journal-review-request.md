# M5 의뢰 저널 — 기능 묶음 통합 검토

> 독립 검토 `bf50f49` 통과 수신. 재승인 요청은 종료했다. 겹침/렌더 출력/필터 문구 보완과 숨김 UI 최적화 이월은 [다음 큰 구현 묶음](m5-chapter-one-review-request.md)에 함께 기록한다.

- 최종 수정일: 2026-09-28
- 담당: Codex (구현·통합)
- 기준 커밋: `b084cef`
- 구현 커밋: `bf50f49` (22파일, 기능·검증·문서·화면 증거)
- 계약: [M5 저널](../design/systems/m5-journal.md), [S09](../art/ux/ux-foundation.md)

## 플레이어에게 바뀐 것

J 저널의 한 줄 임시 표시를 실제 의뢰 화면으로 교체했다. 수락한 의뢰 목록에서 진행 중/보고 가능/완료를 구분하고 제목·목표·위치를 검색한다. 상세에는 전체 목표의 완료/현재/대기 상태와 위치·보상·보고 안내가 나온다. 완료 이력을 읽거나 현재 의뢰 보기로 돌아갈 수 있다. HUD에는 J 안내를 추가했다.

메인1 고정 추적은 유지한다. 완료 이력을 선택해도 HUD가 과거 의뢰로 바뀌지 않는다. 미수락·잠긴 의뢰를 목록에서 미리 공개하지 않으며 수락/보고/보상 지급은 NPC 대화에서만 한다. 필터·검색·열람 선택은 일시 UI 상태로, 새 캐릭터 바인딩 시 초기화한다. 저장은 기존 V3 Journal만 사용하고 스키마/마이그레이션/보상/전투 수치는 변경하지 않았다.

## MQ04 보완 리뷰 처리

- 문구: 굴 어귀/오솔길 끝 대신 **북쪽 오솔길의 푸른 조사 표식**으로 제안·목표·위치 문구를 맞췄다. 안정 ID는 유지했다.
- 반경: 인지64px와 교전 후 사격80px를 구분한다. 최초 인지 분리만 보장하며 이미 교전 중이거나 배회한 적의 사격권 전체 분리는 보장하지 않는다. 이 숫자 지적 때문에 전투 AI나 배치를 다시 바꾸지 않았다.
- 과거 PNG9개: 다른 작업자의 수정 상태와 추적을 유지한다. ignore가 기존 추적 파일을 막는다고 주장하지 않는다. 이번 커밋은 명시 경로만 포함한다.

## 검증 기록

| 검사 | 이번 실행 결과 |
|---|---|
| 미구현 계약 테스트 | 최초6/6 실패: 임시 탭에 의뢰 목록 API 없음 |
| 최종 전체 GUT | **1053/1053 · 116 scripts · 9057 asserts(관측)**, exit0 |
| 새 저널 검사 | 7건: 비노출·필터/검색·복수 목표·완료 이력·메인 추적·재바인딩·pause/읽기 전용 경계 |
| 형식/린트 | 변경 GD9개 `gdformat --check` unchanged / `gdlint` 성공 |
| MQ04 별도 프로세스 | cleanup→seed→active→reach→ready→completed→completed→cleanup **8/8 PASS**, exit0·SCRIPT ERROR0 |
| 렌더 입력 | **M5_JOURNAL_RENDER_PASS**, exit0: J 열기·검색 중 J 문자 입력·빈 결과·현재 의뢰 버튼·완료 행 버튼·Esc/J 닫기 |

프로세스 probe에 실제 저널 탭 목록/목표/상태 비교와 `(152,536)`로 옮긴 위치의 재실행 복원 검사를 추가했다. 기존 V2→V3·다른 슬롯 해시·보상 정확히 한 번 검사는 유지했다. 이동은 코드로 배치한 것이며 사람의 키보드 이동·도보 동선을 검증한 것은 아니다.

최초 전체 검사에서는 프레임 분할 스폰이 끝나기 전에 월드 fixture가 해제되는 엔진 오류를 관측했다. 해당 월드 테스트와 신규 저널 테스트에 스폰 완료 대기를 넣고 전체를 재실행했다. 렌더 도구도 초기화 전 `IntegratedMenu` 클래스 직접 참조로 Autoload 컴파일 오류가 났으며, 실행 이후 인스턴스의 enum 참조로 수정했다. 실패한 실행을 제품 통과 근거로 쓰지 않는다.

별도 프로세스의 종료 리소스 경고는 남아 있다. 위 PASS를 경고0으로 해석하지 않는다. 이 변경은 게임의 전체 G4/G5 승인이나 100시간 완주 판정이 아니다.

최종 전체 GUT은 SCRIPT ERROR·종료 leaked/RID·스폰 재개 오류0건이다. 파일 저장 실패 주입 테스트의 `Could not create directory` 로그는 발생했다. probe 관측은 seed4/2, active·ready·completed6/2, reach·cleanup0이며 고정 합격 기준이 아니다. 렌더 최종 실행은 SCRIPT ERROR0이다.

재현 명령(저장소 루트, Godot4.7.1):

```powershell
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
godot --path godot --rendering-method gl_compatibility -s ../docs/qa/tools/m5_journal_render_probe.gd
foreach ($phase in @('cleanup','seed','active','reach','ready','completed','completed','cleanup')) {
    godot --headless --path godot -s test/quests/fourth_quest_process_probe.gd -- $phase
    if ($LASTEXITCODE -ne 0) { throw "probe failed: $phase" }
}
```

probe는 `user://m5_fourth_process` 전용 경로를 사용한다. 재현 시 exit뿐 아니라 stderr의 SCRIPT ERROR도 확인한다. 실제 사용자 저장 경로를 수정하지 않는다.

## 화면 증거

- [진행 중 상세](evidence/m5-journal/active.png)
- [검색 결과 없음](evidence/m5-journal/search-empty.png)
- [완료 이력](evidence/m5-journal/history.png)

렌더는 합성 선행 진행/좌표와 엔진 입력을 사용한다. 실제 도보·사냥·NPC 관통 플레이를 대신하지 않는다.

## 변경 파일·검토 포인트

1. `quest_journal_view.gd`: 수락 상태만 순수 표시로 투영. 첫 미완료 이후 목표는 대기, 반환 데이터로 진행/Resource를 바꿀 수 없는지.
2. `quest_journal_tab.gd`, `integrated_menu.gd/.tscn`: 목록/상세/필터/검색, 바인딩 해제와 재연결, pause 소유권. J를 검색에 입력할 때 닫히지 않는지.
3. `quest_tracker.gd`, 시작 월드 스크립트: 현재 캐릭터 Journal 한 개 공유, HUD 메인 추적 유지. 목록 열람이 보상을 호출하지 않는지.
4. `mq_01_04.tres`: 현재 지형에 맞춘 텍스트만 변경. EXP1040/골드300/stable ID 유지.
5. 신규 저널 GUT, MQ04 월드 fixture, 프로세스 probe, 렌더 도구: 합성 입력/실제 UI/파일 복원을 구분한 검증.
6. 저널 계약·UX·로드맵·진행/인계·MQ04 대응: 범위와 이월 동기화.

새 기능 전체를 이 문서 하나로 검토한다. 이미 통과한 MQ04 보완을 별도로 반복 검토할 필요는 없다.

## 변경 이력

- 2026-09-28: 기능 구현·프로세스/렌더 검증·MQ04 후속 지적을 하나의 검토 묶음으로 작성.
