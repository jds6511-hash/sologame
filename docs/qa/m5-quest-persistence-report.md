# M5 단위 3 — 의뢰 재실행 검증

- 날짜: 2026-09-27. 비교 기준 `f11430e`.
- 상태: **별도 프로세스 자동 검증 완료, 실제 플레이 미완료**. G4/G5 미승인 유지.
- 연결: [실행 계획](../superpowers/plans/2026-09-27-m5-first-quest.md), [단위 2 보고서](m5-first-quest-report.md), [검토 요청](m5-quest-persistence-review-request.md).

## 변경과 범위

| 파일 | 목적 |
| --- | --- |
| `godot/test/quests/first_quest_process_probe.gd` | active/ready/completed 및 V1 캐릭터를 별도 실행에서 복원·계속 진행·보상·슬롯 보호 검증 |
| `docs/qa/tools/m5_manual_play.gd` | 기존 M4 실제 입력 런처를 재사용하되 M5 전용 저장 폴더로 격리 |
| 이 보고서·검토 요청·기존 보고서 링크·현황·인수인계·로드맵·계약·계획 | 자동 검증 완료와 실제 플레이 미완료를 구분 |

게임플레이 코드 변경 없음. 기존 수정 스크린샷 3개 및 타 작업 파일은 포함하지 않는다.

## 별도 프로세스 결과

`user://m5_first_quest_probe`만 사용한다. 정적 월드에서 공개 Journal 이벤트 API로 목표를 만들고 실제 Controller 보상 및 SaveSession 저장/월드 복원을 사용한다. 최근 전투 타이머는 fixture에서 10초로 설정한다. 실제 이동·처치 입력이나 저장 안전 조건의 체감 검증이 아니다.

| 단계 | 확인 | 결과 |
| --- | --- | --- |
| cleanup | 전용 fixture 정리 | PASS |
| seed | 슬롯 1 active 1/2, 슬롯 2 ready 2/2, 슬롯 3 completed, 슬롯 4 Lv2·반지 장착 V1 fixture | PASS |
| active | 전체 payload 복원, counts 1/2, EXP 75, 추가 KILL→보고·골드 120·포션 2, 재보고 불변 | PASS |
| ready | 전체 payload 복원, counts 2/2, EXP 75, 보고 후 보상·재보고 불변 | PASS |
| completed | 전체 payload 복원, EXP 400, 재보고 거부 및 전체 상태 불변 | PASS |
| legacy | V1 Lv2·장비 복원, migration_pending, 실제 첫 보상/다음 의뢰 수락 후 장비 유지 | PASS |
| cleanup | 전용 fixture 정리 | PASS |

각 복원 단계는 새 OS 프로세스다. 복원 비교는 의뢰뿐 아니라 codec 전체 payload(레벨·EXP·골드·가방·장비·위치 등)를 비교한다. 각 단계에서 진행 캐릭터를 **슬롯 5에 저장한 후** 슬롯 1~4 원본 SHA-256이 모두 불변인지 확인한다. V1 원문도 포함된다. V1 fixture는 신버전에서 만든 검증된 캐릭터를 V1 봉투/빈 quests로 변환한 것이며 과거 사용자 저장 샘플은 아니다. 처치는 이벤트만 전달하므로 처치 EXP/드랍은 없고 75/400은 의뢰 EXP만의 총량이다.

최종 7단계 모두 `M5_FIRST_QUEST_PROCESS_PASS`, exit 0. SCRIPT ERROR 없음. seed 종료 4 ObjectDB/2 resources, active 종료 6/2 경고가 남았다. ready/completed/legacy/cleanup에서는 같은 경고가 없었다. 원인은 미확정이며 저장 유실로 판정하지 않는다.

형식·린트: 신규 GDScript 2개 통과. 게임 코드를 바꾸지 않은 이번 검증 단위에서는 전체 GUT/렌더 회귀를 재실행하지 않았다. 직전 전체 결과는 `406d4d0`의 992/992이며 이번 실측과 구분한다.

초기 실행기 오류: SceneTree 스크립트에서 씬 preload와 QuestController 타입 참조가 Autoload 초기화 전에 의존 스크립트를 읽어 컴파일 오류를 냈다. 런타임 load/Node 타입으로 수정했다. 초기에는 종료 PASS 문구만으로 실패를 놓칠 수 있어 최종 도달 플래그와 실행 명령의 SCRIPT ERROR 검사도 추가했다. 이 오류는 게임 코드 결함이 아니다.

로컬 로그(커밋 제외): `m5-quest-final-{cleanup,seed,active,ready,completed,legacy}.log`, 각각의 `-errors.log`. 처음/마지막 cleanup은 같은 로그 경로를 사용한다.

## 실제 창 시도와 제한

Computer Use의 `@oai/sky`로 실제 게임 창을 열고 화면 확인 후 F와 W를 전달했다. 접수원 근처 Lv1, HP 135/135, MP 72/72와 대화 안내가 보였으나 대화는 열리지 않았다.

```text
MANUAL_INPUT key=70 physical=4194313 device=16 move_up=false menu_skill=false
MANUAL_INPUT key=87 physical=4194313 device=16 move_up=false menu_skill=false
```

프로젝트의 interact와 move_up은 각각 physical_keycode 70/87이다. 도구 입력의 물리 코드가 둘 다 4194313으로 전달되어 액션이 성립하지 않았다. 입력 매핑 변경이나 이벤트/위치 주입으로 실제 플레이 통과를 대신하지 않았다. Alt+F4 후 프로세스 종료 확인, `m5-native-errors.log`는 비어 있었다. 저장 폴더는 `user://m5_manual_play_2026_09_27`이며 런처는 폴더 격리와 입력 관찰만 한다.

아직 검증하지 못한 항목:

- 이동→대화→명시적 수락→실제 처치→보고→저장→종료→재실행 관통.
- 이동 입력 이후 위치 복원(M4 이월), 실제 초반 소요 시간·포션 사용·사망 기록.
- 패 수령 후 재대화 흐름의 발견 가능성, 보상/레벨업 안내 체감, 저장 거부 빈도.

이 항목은 정상 물리 키를 전달할 수 있는 실제 조작 환경 또는 디렉터 플레이에서 채운다. 9개 의뢰/Lv10 및 G4/G5 통과를 주장하지 않는다.
