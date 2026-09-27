# MQ-01-04 조사 구현 — 통합 검토 요청

- 최종 수정일: 2026-09-28
- 담당: Codex (구현·통합)
- 기준: `e63dd13` (설계 `38bacfa`)
- 계약: [MQ04 설계·착수 결정](../design/systems/m5-fourth-quest.md)
- 범위: 정의·복수 목표 표시·상호작용 선택·보고·저장 재실행을 한 묶음으로 구현. M6/MQ05·G4/G5 완료 아님.

## 결과와 설계 리뷰 처리

MQ03 보고 후 접수원이 MQ04를 제안한다. 명시적으로 수락하고 기존 어귀에 접근하면 첫 목표가 끝나며, 표식에 F로 조사하면 보고 상태가 된다. 접수원 보고 시 **1040 EXP·300골드**를 한 번 지급한다. 기존01~03 보상은 불변이다.

| 설계 지적 | 처리 |
|---|---|
| 중간1 질주 힌트/저장 스키마 | (a) 선택. V3 유지, hint_dash_done 및 질주 힌트는 별도 저장 변경 단위. 온보딩 문서·코드 주석에 미완료 및 구 MQ04 수락/완료 저장의 소급 노출 정책 필요를 명시 |
| 낮음1 반경 겹침 | 마커35.78px, REACH32/INTERACT40px 유지. 어귀 같은 자리에서 명시적 F 조사 가능함을 의도한 설계로 기록 |
| 낮음2 이벤트/폴링 혼동 | WorldItem의 폴링 유지, 공통 메타로 후보 차단. 조사 완료 프레임/다음 프레임에는 소비 프레임 메타로 중복 줍기 억제 |
| 참고 테스트 메타/빈 source | test_world_item의 직접 메타 설정 갱신. MQ01 빈 source는 그대로 허용 |

## 구현 경계

- `QuestData`: 목표별 label/location 배열. 카탈로그 전체의 title/offer/표시 배열 공백·길이 검증. MQ01의 패·접수원 REACH/TALK만 위치 빈 값 허용. INTERACT 추가, 기존 첫 미완료 목표 순서·저장 Schema 불변.
- `QuestPresentation`: 첫 미완료 목표의 종류/이름/위치/수량을 함께 투영. 같은 projection을 대화/추적창이 사용한다. MQ04 완료 후 MQ05는 준비 중이라고 안내한다.
- `WorldInteraction`: 월드 로컬 단일 선택자. NPC→조사→줍기 순서, 같은 종류는 거리/ID 정렬. 우선 갱신(process_priority=-100), pause에도 후보/메타 정리. 대상 삭제/월드 종료에도 해제한다.
- `QuestNpc`: 후보·실행 메서드 유지, 자체 `_process`/F 이벤트 소비 제거. 실제 입력은 선택자에서만 소비한다. 기존 NPC 단독 public 메서드 테스트는 그대로이며, 새 실제 월드·렌더 테스트는 선택자를 경유한다.
- `RiftInvestigation`: 기존 마커 재사용, 명시적 stable ID/출처, 어귀32px·표식40px·레이어1 시야선. 생존/입력 잠금/경직/공격/스킬/대시/pause 차단. 새 월드 표식은 코드 도형·라벨의 기능용 표시이며 최종 아트가 아니다.
- HUD: 프롬프트 소유자 지정. 튜토리얼의 hide/show가 선택자 프롬프트를 지우지 못한다. 아이템은 `world_interaction_available` 및 `world_interaction_consumed_frame`으로 폴링을 억제한다. 두 메타는 저장하지 않는다.
- CharacterSave V3/AccountSave V1·V1/V2 Legacy→C1 변환·보상 트랜잭션·저장 안전 기준은 그대로다.

## 검증 — 이번 실행

| 검사 | 결과 |
|---|---|
| 최초 새 정의 검사 | 3건 모두 실패 확인 후 구현 |
| 첫 전체 회귀 | 1037 중 3건 실패. MQ03 뒤 준비 중 기대값과 과거2의뢰 카탈로그 fixture를 갱신. 예전 두 의뢰 fixture를 새 콘텐츠로 바꾸지 않고 MQ04도 제거해 역사 범위 유지 |
| 최초 월드 검사 | 5건 중 벽 fixture 1건 실패. 비활성 월드의 충돌체도 비활성화돼 있었으므로 기존 벽 테스트와 같이 ALWAYS로 설정 |
| 최종 전체 GUT | **1044/1044 · 115 scripts · 8990 assertions**, exit0, SCRIPT ERROR/종료 잔존 경고 없음. assertion 수는 관측값 |
| 새 MQ04 프로세스 | cleanup→seed→active→reach→ready→completed→completed→cleanup **8/8 PASS**, exit0·SCRIPT ERROR0 |
| 기존 의뢰 프로세스 | 기존 MQ01~03/V1 **11/11 PASS**, exit0·SCRIPT ERROR0 |
| C1 세션 프로세스 | 기존7단계 **7/7 PASS**, exit0·SCRIPT ERROR0 |
| 변경 GD 검사 | **17파일** gdformat --check/gdlint 통과 |
| 렌더·합성 F | **M5_FOURTH_RENDER_PASS**, 수락/조사/보고 버튼·화면 저장 성공. offer/site 이미지를 열어 표시 확인 |

MQ04 probe는 QA 폴더에서 **합성 3의뢰 완료 상태**를 V2로 포장하고 로드한다. 실제 사냥이나 과거 V2 전체 재현을 주장하지 않는다. 직접 Journal 이벤트로 active `[0,0]`·active `[1,0]`·ready·completed를 별도 실행 사이에 이어 저장하고, 동일 완료를 한 번 더 로드해 중복 보상을 거부한다. 다른 슬롯의 SHA-256을 비교한다. 새 probe는 QA를 위해 전투 정적 타이머를 설정하며, 실제 5초 대기·이동/조사 입력은 별도 월드/렌더 테스트 범위다.

새 probe의 seed/active/reach/ready/completed에서 기존 계열의 **종료 시 2 resources 잔존 경고**를 관측했다. SCRIPT ERROR와 구분하며 해결했다고 주장하지 않는다. 전체 GUT와 렌더 출력에는 이 경고가 없었다.

파일 보호 테스트는 과거3의뢰 카탈로그의 백업 복구/원문 보존, 미수락 MQ04 공백 offer 콘텐츠 오류 시 읽기/쓰기 차단·파일 수/해시 불변을 검증한다. 기존 C1/V1 프로세스 검사도 유지했다. 구 빌드로의 다운그레이드 복원을 지원한다는 의미가 아니다.

## 재현

```powershell
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
# 각 단계는 별도 프로세스로 실행
godot --headless --path godot -s res://test/quests/fourth_quest_process_probe.gd -- cleanup
# seed, active, reach, ready, completed, completed, cleanup 순서
godot --path godot --rendering-method gl_compatibility -s ../docs/qa/tools/m5_fourth_render_probe.gd
```

렌더는 선행 진행·좌표를 직접 설정하고 엔진에 physical_keycode를 합성 주입한다. 외부 키 입력 도구의 문제를 해결하거나 인간 플레이/G4/G5를 대신한 것이 아니다. 증거: [수락](screenshots/m5-fourth/offer.png), [표식](screenshots/m5-fourth/site.png), [조사 후](screenshots/m5-fourth/ready.png), [보고](screenshots/m5-fourth/report.png). 기존 작업자의 스크린샷9개를 덮어쓰지 않았다.

로컬 로그: `m5-fourth-red.log`, `m5-fourth-full.log`, `m5-fourth-world.log`, `m5-fourth-final.log`, `m5-fourth-process.log`, `m5-fourth-c1.log`, `m5-fourth-previous.log`, `m5-fourth-render.log`. 로그는 커밋 제외.

## 변경 파일 묶음

- 콘텐츠: `godot/data/quests/mq_01_01~04.tres`.
- 의뢰: `quest_data.gd`, `quest_catalog.gd`, `quest_presentation.gd`, 신규 `world_interaction.gd`, `rift_investigation.gd`.
- 월드/UI: `quest_npc.gd`, `world_item.gd`, `hud.gd`, `tutorial_controller.gd`, `eastern_frontier_starting_area.gd`.
- 검증: `test_fourth_quest.gd`, `test_fourth_quest_world.gd`, `fourth_quest_process_probe.gd`, `test_third_quest.gd`, `test_world_item.gd`, `test_m5_compatibility.gd`, `m5_fourth_render_probe.gd`, 증거 PNG4개.
- 문서: MQ04 계약/설계 리뷰/이 구현 리뷰, 온보딩, 로드맵·진행·인계.

## 독립 검토 질문

1. 후보/소비 프레임 메타로 이벤트와 아이템 폴링 경합이 닫혔는가? pause/삭제/월드 교체 시 소유권 누수가 있는가?
2. 목표별 문구 검증과 MQ01 예외가 콘텐츠 전체 차단/기존 저장 안전성을 유지하는가?
3. 순서·상태 복원·중복 보고 거부가 실제 월드/Controller와 별도 프로세스에서 충분히 구분 검증됐는가?
4. 질주 힌트 이월/V3 유지와 반경 접힘이 설계 리뷰의 착수 조건을 정확히 해소했는가?

미판정: 실제 장거리 이동·슬라임 회피·안전한 조사 동선·완주 시간·직접 저장 복원·G4/G5. 이번 보상 합계가 100시간 콘텐츠 지급/페이스 검증을 뜻하지 않는다. 질주 힌트는 완료하지 않았다.

## 변경 이력

| 날짜 | 변경 |
|---|---|
| 2026-09-28 | MQ04 정의·입력·표시·보상·영속성 구현 및 검증을 하나의 리뷰로 작성 |
