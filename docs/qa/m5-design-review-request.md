# Claude 독립 검토 요청 — M5 첫 의뢰 설계

- 작성일: 2026-09-27
- 상태: **리뷰 요청 준비 완료 / 검토 결과 미수신**. 이 문서 작성은 리뷰 수행·통과를 뜻하지 않는다.
- 검토 대상 커밋: **`955f9c5`**
- 비교 기준: **`dcbda4d`**
- 역할: Claude는 읽기·코드 대조·판정, Codex는 수정·통합·진행 문서·커밋·푸시.
- 요청 범위: **구현 전 설계와 실행 계획 검토**. 게임 코드 변경이나 M5 실행 결과 검토가 아니다.

## 그대로 전달할 요청

> `dcbda4d..955f9c5`의 M5 설계와 실행 계획을 독립 검토해 주세요. 파일 수정·커밋·브랜치 변경·푸시는 하지 말고, 아래 문서와 기존 Godot 코드의 실제 경계를 대조해 주세요. 특히 저장 V1→V2 호환, 목표 상태 전이, 보상 일관성, 월드 복원 순서, 대화 일시정지 소유권을 확인해 주세요. 설계의 빈틈은 구현된 결함과 구분하고, 문제마다 문서 절/코드 위치·실패 시나리오·필요한 보완을 적어 주세요. 마지막에는 “단위 1 구현 착수 가능 여부”를 판정해 주세요. M4/G4나 전체 M5/G5 합격 판정은 요청하지 않습니다.

## 읽을 문서

1. [M5 NPC·대화·첫 의뢰 계약](../design/systems/npc-dialog-quest.md) — 주 검토 대상, §1~7.
2. [M5 실행 계획](../superpowers/plans/2026-09-27-m5-first-quest.md) — 단위별 파일·인터페이스·검증 범위.
3. [저장 계약](../design/systems/save-load.md) — 기존 버전/백업/복구/자동 저장 보호를 깨지 않는지 확인.
4. [퀘스트 구조](../design/quests/quest-structure.md) §0·3-2, [초반 의뢰 성장](../design/quests/early-leveling-route.md), [플레이 경험](../design/PLAY_EXPERIENCE_PROPOSAL.md) §4~5 — 선행 의뢰·NPC 발주·확정 보상 근거.
5. [M4 실제 창 QA](m4-native-play-report.md) — 미확인 범위와 기존 관찰. 이 리뷰에서 M4 전체를 다시 검토할 필요는 없음.

## 이번 설계의 의도

- MQ-01-01: 접수원 접근·대화 → 75 EXP·20골드·모험가 패 소유.
- MQ-01-02: NPC 제안·명시적 수락 → 서식지 뿔토끼 2마리 → 보고 → 325 EXP·100골드·POT-HP-1 ×2.
- 정의 Resource와 캐릭터별 진행 상태 분리. NPC 없는 임시 카운터로 완료하지 않음.
- 구현 순서: V1 호환 저장 확장 → NPC부터 보상까지 연결 → 프로세스/실제 창 검증.
- M5 진행 지시는 받았으나 M4의 직접 이동 후 위치 복원·종료 경고·G4 판정은 별도 유지.

## 우선 검토 쟁점

| 우선 | 검토 질문 | 기존 코드 근거 |
|---|---|---|
| 높음 | 봉투와 payload 버전을 2로 올리되 V1을 읽는 흐름에서 검증기·마이그레이션·백업 순서가 성립하는가? 봉투/payload 버전 불일치와 미래 버전은 어떻게 거부하는가? | `godot/scripts/save/save_file_store.gd`, `save_schema.gd`, `character_save_codec.gd` |
| 높음 | “첫 명시적 저장에서 V2 기록”과 V1 로드 후 활성화되는 자동 저장은 양립하는가? 마이그레이션 직후 자동 저장 정책을 더 명시해야 하는가? | 계약 §6, `godot/scripts/save/save_session.gd`의 `advance/load_slot/save_slot` |
| 높음 | TALK/REACH/KILL 목표와 `active → ready → completed`의 관계가 충분히 정의됐는가? 수락 대화·보고 대화를 목표 counts에 포함하면 보고 가능 조건이 순환하지 않는가? | 계약 §3~5, `quest-structure.md` §3-2 |
| 높음 | 검증→보상→completed를 동기 실행한다는 것만으로 신호 재진입까지 막을 수 있는가? 가방 만석·상한 초과·지급 실패 때 일부 보상이 남지 않는가? | `godot/scripts/items/inventory_component.gd`, `godot/scripts/progression/player_progression.gd`, 계약 §5 |
| 높음 | 단위 1의 QuestState 검증기가 단위 2에 생길 QuestData에 의존하지 않고 ID·목표 길이·선행 조건을 검증할 수 있는가? 중복 상수 또는 작업 순서 보완이 필요한가? | 실행 계획 단위 1·2 |
| 높음 | Journal 복원이 초기 스폰·사망 이벤트보다 먼저 끝나고, 실패 시 기존 월드·슬롯 상태가 유지되는가? | `godot/scripts/save/save_session.gd`, `godot/scripts/world/eastern_frontier_starting_area.gd`, `monster_spawner.gd` |
| 중간 | V1 이관 때 01 의뢰를 시작하되 기존 진행·튜토리얼을 유지하는 정책이 맞는가? completed에서 모험가 패 소유를 도출하는 표현이 서사 아이템 계약과 충돌하지 않는가? | 계약 §1·6, 기존 codec/튜토리얼 |
| 중간 | 스폰 출처로 서식지를 판정하는 선택이 “서식지 한정” 의도와 맞는가? 사망 중복·낮 소멸·월드 교체를 오집계하지 않는가? | `godot/scripts/world/monster_spawner.gd`, `godot/scripts/ai/monster_base.gd` |
| 중간 | F/ESC·통합 메뉴·F6가 대화와 겹칠 때 pause/입력 잠금이 잔류하지 않는가? 보상 신호·레벨업 알림 지연과 기존 UI 구조가 맞는가? | `godot/scripts/ui/integrated_menu.gd`, `interaction_prompt.gd`, `tutorial_controller.gd`, `godot/scripts/save/save_menu.gd` |

위 항목은 **리뷰 질문**이며 이미 입증한 결함 목록이 아니다. 발견하면 구현 전에 닫아야 할 항목과 후속 단위에서 검증할 항목을 구분해 주세요.

## 확인 명령과 검증 현황

저장소 루트 PowerShell 기준. 최신 HEAD가 움직여도 검토 대상은 아래 고정 커밋이다. 공유 작업 폴더를 checkout/reset하지 않고 `git show`로 읽을 수 있다.

```powershell
git show --stat 955f9c5
git diff --check dcbda4d 955f9c5
git diff --name-only dcbda4d 955f9c5
git diff dcbda4d 955f9c5 -- docs/design/systems/npc-dialog-quest.md docs/superpowers/plans/2026-09-27-m5-first-quest.md
git diff --name-only dcbda4d 955f9c5 -- godot/
git show 955f9c5:godot/scripts/save/save_session.gd
```

- 대상 커밋은 문서 5개 변경이며 `godot/` 변경은 없다.
- 작성 시 코드 연결점 대조, 문서 링크 검사, diff 공백 검사를 수행했다.
- M5 GUT·형식/린트·프로세스 probe·실제 플레이는 **아직 실행하지 않았다**. 실행 계획의 명령은 향후 구현 검증용이다.
- M4의 기존 통과 수치를 M5 통과 근거로 사용하지 않는다.

## 회신 형식과 완료 조건

1. 검토한 커밋·파일 및 직접 실행한 명령을 명시한다.
2. 지적마다 **중요도 / 위치 / 구체적인 실패 시나리오 / 제안 / 구현 전 필수 여부**를 적는다. 발견이 없으면 없다고 기록한다.
3. 마지막에 **단위 1 착수 가능 / 보완 후 가능 / 설계 재검토 필요** 중 하나와 이유를 적는다. 단위 2·3에만 영향을 주는 지적은 따로 표시한다.
4. Codex는 회신을 코드와 대조해 채택·정정·보류 근거와 후속 커밋을 기록한다. 리뷰어가 파일 수정·커밋·푸시를 대신하지 않는다.

이 문서와 링크된 설계/계획이 이번 리뷰 인계물이다. 아직 존재하지 않는 구현 보고서나 테스트 파일을 제출 완료로 취급하지 않는다.
