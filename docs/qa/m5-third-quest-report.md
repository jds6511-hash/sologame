# M5 후속 MQ-01-03 구현·검증

- 날짜: 2026-09-27. 비교 기준 `061bc02`. 구현 해시는 후속 문서 커밋에 기록한다.
- 상태: 세 번째 의뢰 구현·자동 검증 완료, Claude 구현 검토 대기. **직접 플레이/G4/G5 미완료**.
- [설계](../design/systems/m5-third-quest.md), [실행 계획](../superpowers/plans/2026-09-27-m5-third-quest.md), [검토 요청](m5-third-quest-review-request.md).

## 동작

토끼몰이 보고 후 접수원에게 `무리들의 그림자`를 명시적으로 수락한다. 시작 지역 들개 마수 2마리를 처치하면 보고 대기가 되고, 접수원에게 보고해 **490 EXP·150골드**를 한 번 받는다. 기존 첫 두 의뢰와 합계 890 EXP·270골드이며 실제 처치 EXP/드랍은 별도다. 03 완료 뒤 균열 조사 의뢰는 준비 중으로 표시한다.

수락/보고 버튼은 `action + quest_id`를 전달하고 현재 화면 선택·재계산 선택과 일치할 때만 실행한다. 잘못된 NPC, 표시되지 않은 ID/액션, 닫힌 창의 호출은 진행을 바꾸지 않는다. 기존 Controller 보상 검증과 Journal 선행/중복 방지는 유지했다. 01의 패 수령·Esc 무보상·성공 후 닫기·pause 소유권은 바꾸지 않았다.

QuestPresentation은 명시적 순서에서 active/ready를 우선하고 그다음 선행 완료인 미수락 의뢰를 선택하는 순수 표시 함수다. 01 active 상태에서 02 제안이 먼저 보이던 엣지를 제거한다. 제목·제안·목표 설명은 Resource, 보상 문구는 실제 수치와 아이템 이름에서 읽는다. 대화창과 추적기가 같은 선택기를 사용한다. 현재 KILL 표시 수량은 첫 목표를 사용하고, 01 복합 목표는 패 발급 안내로 표현한다. 미구현 다중 토벌/조사 표시까지 일반화했다고 주장하지 않는다.

들개는 `_spawn_monster`에서 `feral_dog`/출처를 add_child와 발신 전에 받는다. 시작 지역은 `yeoulmok_dog_habitat`, 다른 월드는 기본 빈 출처다. 기존 died 단일 등록·최초/재스폰 공통 경로를 그대로 쓴다. 스폰 수·AI·공격 수치 변경 없음.

## 설계 리뷰 반영

Claude `bfb4f85` 리뷰는 착수 가능. 기존 2개 Catalog로 의뢰 3개를 읽으면 `unknown_quest`보다 앞에서 **quest_fields**가 반환됨을 정정했다. 파일 계층의 invalid_data·정상 백업 폴백·읽기 원본 불변·이후 쓰기 시 `.preserved.<sha256>` 보존을 회귀 테스트로 확인했다. 읽기 자체가 preserved 파일을 만든다고 기술하지 않는다. 진단 순서 재정렬은 구 빌드 동작 검증과 분리해 보류했다. V2 형식/버전은 유지한다.

## 변경 파일

| 그룹 | 파일·목적 |
| --- | --- |
| 정의 | `godot/data/quests/mq_01_01.tres`, `mq_01_02.tres` 표시 문구; 신규 `mq_01_03.tres` |
| 카탈로그/표시 | `scripts/quests/quest_data.gd`, `quest_catalog.gd`, 신규 `quest_presentation.gd` |
| UI | `scripts/ui/quest_dialog.gd`, `quest_tracker.gd`: 공통 선택·ID 액션. 렌더에서 뒤 추적 문구가 비쳐 대화 패널만 불투명 처리 |
| 월드 | `scripts/world/monster_spawner.gd`, `eastern_frontier_starting_area.gd`: 들개 메타와 시작 지역 출처 |
| GUT | 신규 `test/quests/test_third_quest.gd`, 기존 `test_first_quest_flow.gd`, `test_quest_world_flow.gd`, `test/save/test_m5_compatibility.gd` |
| 실행 probe | `test/quests/first_quest_process_probe.gd`: 기존 7단계 유지+03 생성/3상태 복원; `docs/qa/tools/m5_quest_render_probe.gd`: 새 choose API와 third 모드 |
| 문서/증거 | 설계 정정·실행 계획·이 보고서·구현 검토 요청·현황/인수인계/로드맵, `screenshots/m5-third/`의 6장 |

scripts/data/test의 경로는 `godot/` 기준이다. 기존 수정 스크린샷 3개, 다른 작업자의 파일, QA 로그는 커밋하지 않는다.

## 검증 결과와 한계

- 최종 전체 GUT **1001/1001, 3671 assertions, 109 scripts**. assertion 수는 난수 들개 수(2~4마리)의 개별 확인 횟수에 따라 달라질 수 있다. `m5-third-release-corrected.log`의 실측값이다.
- 변경 GDScript **13개** `gdformat --check`/`gdlint` 통과.
- 별도 프로세스 **11단계 PASS**, exit 0, SCRIPT ERROR 없음: `cleanup → seed → active → ready → completed → legacy → third_seed → third_active → third_ready → third_completed → cleanup`.
- 03 active 1/2·ready 2/2·completed 전체 payload 복원, 이어서 보고·890 EXP/270골드·재보고 전체 불변 확인. 기존 7단계와 슬롯 1~4 보호도 유지한다. third_seed는 슬롯 6~8에 기록한다.
- 신규/기존 대화 렌더 **M5_QUEST_RENDER_PASS**. F 대화·F6 차단·Esc 무보상·01/02 및 03 버튼 배선 확인. 제안/진행/보고 화면 6장 중 새 제안·보고의 문구/가독성을 직접 확인했다.
- 기존 월드 런타임 **40/40**, exit 0. 사람의 실시간 플레이가 아닌 자동 입력·일부 피해 API 검증이다.
- 전체 GUT의 기존 의도적 저장 I/O 실패 로그 외 SCRIPT ERROR/종료 잔존 경고 없음. 최종 렌더/runtime stderr는 비어 있었다. 별도 프로세스의 seed 4/2 및 여러 복원 단계 6/2 종료 경고는 관측됐으며 비결정적이라는 기존 제한을 유지한다. 종료 경고 원인을 해결했다고 주장하지 않는다.

실패부터 확인: 신규 데이터/표시 테스트 4건 중 3건 실패 후 구현. 다음 월드 테스트에서 새 UI/들개 메타 2건 실패 후 연결. 전체 실행 중 기존 오버플로 단언을 새 테스트 안으로 잘못 옮긴 fixture 편집 실수 1건을 발견해 원래 함수로 되돌리고 재실행했다. 이 마지막 실패는 제품 결함으로 분류하지 않는다.

최종 반복 검증에서 새 재스폰 테스트가 1틱에 두 마커가 생성된다고 잘못 가정한 것도 발견했다. 기존 스포너의 1틱 1마커 예산을 확인하고 두 틱 뒤 최소 2마리를 검사하도록 테스트를 고쳤다. 난수 팩 크기가 2일 때만 우연히 통과하던 테스트였으며 제품의 스폰 예산을 바꾸지 않았다.

로컬 로그: `m5-third-red*`, `m5-third-world-red*`, `m5-third-release*`, `m5-third-process-*`, `m5-third-final-render*`, `m5-third-final-runtime*` (커밋 제외).

## 남은 실제 플레이

기존 01/02의 직접 관통 플레이, 이동 후 위치 복원, 프롬프트 우선순위, 패 수령 후 재대화, 저장 거부 빈도는 그대로 남는다. 03의 **2마리 처치까지 실제 최대 동시 교전 수**도 사람 플레이에서 기록한다. 자동 world 테스트는 몬스터 피해 API를 사용하며 조작 부담/공정성을 측정하지 않는다. MQ-01-04/05, Lv6~10, 전체 M5·M6 완료를 주장하지 않는다.
