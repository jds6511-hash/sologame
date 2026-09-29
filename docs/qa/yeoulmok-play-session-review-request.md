# 여울목 연속 플레이 세션 통합 검토

- 최종 수정: 2026-09-29 / 담당: Codex
- 기준: `77e963e` / 구현 해시: 인계에서 기록
- 변경 이력: `d660631` 독립 검토 지적0건 통과 후, 긴 이름 보완을 포함하여 시제품 실행·월드 교체·지역 왕복·저장/프로세스 복원까지 연결했다.
- 의존: [키트 규격](../art/concepts/yeoulmok/native-kit/README.md), [이전 NPC 검토](npc-reading-review-request.md), [저장 계약](../design/systems/save-load.md)

## 사용자가 얻는 동작

이전에는 F6 불러오기·새 캐릭터·지역 이동 시 시제품 아트가 사라졌다. 이제 **격리 실행기로 시작한 세션**에서는 여울목 월드가 만들어질 때 키트를 다시 설치한다. 노베라는 기존 제품 아트를 유지하고 여울목으로 돌아오면 키트가 돌아온다. 동일 월드 중복 설치와 다른 저장 경로에 대한 적용을 막는다.

```powershell
godot --path godot --script ../docs/qa/tools/yeoulmok_pilot_play.gd
```

위 실행기는 `user://yeoulmok_art_pilot`을 사용한다. 실제 사용자 입력으로 이동·전투·의뢰·F6 메뉴를 사용할 수 있으며 fixture/시간 가속/자동 조작을 넣지 않는다. 기존 `yeoulmok_art_pilot_probe.gd -- --native-kit --interactive`에도 같은 수명 관리자를 연결했다. 제품 기본 실행에는 관리자를 등록하지 않으며 환경 키트 제품 채택은 아니다.

## 설계·파일

| 파일 | 변경과 이유 |
|---|---|
| `godot/scripts/tools/yeoulmok_pilot_session.gd` | 루트 `child_entered_tree`→월드 ready를 관찰한다. 여울목 scene 경로와 격리 save_directory가 모두 일치할 때만 설치. root에 남아 월드 교체 뒤에도 작동한다. |
| `docs/qa/tools/yeoulmok_pilot_play.gd` | 비교 캡처를 기다리지 않고 사람 플레이로 진입하는 별도 실행기. |
| `docs/qa/tools/yeoulmok_art_pilot_probe.gd` | 기존 대화형 실행에도 관리자 연결. 후보/비대화형 경로는 그대로. |
| `docs/qa/tools/yeoulmok_journey_probe.gd` | 실제 도보·MQ05 보고·노베라 저장·다음 프로세스 로드·귀환·이동 저장·재실행·새 캐릭터·다른 슬롯 불변을 묶어 검증. |
| `godot/scenes/npc/quest_receptionist.tscn` | Label grow_horizontal=BOTH. 긴 이름이 한쪽으로 밀리지 않게 함. |
| `godot/test/ui/test_npc_name_layout.gd` | 접수원/두 관문 NPC/긴 가상 이름의 중앙 정렬과 프롬프트 기준 검사. |
| 키트 README·기존 시제품 보고서·이 요청·진행 문서 | 사라짐 제한을 현행 동작으로 갱신, 검증 범위/실패 이력/인계 기록. |

세이브 포맷·SaveSession·전투·보상 제품 코드는 수정하지 않았다. 신규 저장 필드도 없다. 관리자가 참조하는 격리 경로는 기존 SaveSession이 새 월드에 전달하는 메타를 사용한다. 다른 저장 경로 가드는 합성 Node2D로, 실제 월드 교체는 제품 SaveSession으로 각각 검증했다.

## 여행 검증 계약

QA 폴더는 사람 플레이 폴더와 다른 `user://yeoulmok_journey_probe`다. `cleanup`은 이 고정 폴더의 파일만 비재귀 삭제한다. 실행 순서:

```powershell
godot --path godot --script ../docs/qa/tools/yeoulmok_journey_probe.gd -- cleanup
godot --path godot --script ../docs/qa/tools/yeoulmok_journey_probe.gd -- depart
godot --path godot --script ../docs/qa/tools/yeoulmok_journey_probe.gd -- return
godot --path godot --script ../docs/qa/tools/yeoulmok_journey_probe.gd -- reload
godot --path godot --script ../docs/qa/tools/yeoulmok_journey_probe.gd -- cleanup
```

- depart: 실제 입력으로 남쪽 (152,520) 이동. **MQ01~04 완료만 fixture로 주입**, MQ05는 journal.accept 호출. 슬롯2 저장/해시 보관 → 관문까지 실제 도보 → 상호작용 액션으로 대화 → 대화의 choose(report) 호출 → 제품 보상/노베라 이동 → 슬롯1 저장.
- return: 별도 프로세스에서 슬롯1 노베라 복원 → 제품의 초기 정적5초를 실제 시간으로 대기 → 노베라 NPC 대화/choose(travel) → 제품 지역 귀환 → 키트 재설치 → 도보로 남쪽 이동 후 슬롯1 저장, 위치 기대값 보관.
- reload: 다시 별도 프로세스에서 이동 위치 복원(오차<0.001px), 공훈100/골드560 확인 → 새 캐릭터 → 키트 유지·기존 슬롯1 해시 불변. 모든 정상 단계에서 슬롯2 해시 불변과 격리 루트 유지 확인.
- 좌표/속도 대입·적 정지·안전 타이머 편집·시간 가속은 없다. 저장은 실제 save_slot을 최대20회/1초 간격으로 재시도한다. 근처 적 때문에 시간 초과할 수 있고 이를 성공으로 무시하지 않는다.
- 이동/대화 열기/닫기는 기존 자동 도보 도구의 액션 입력을 사용한다. 보고/여행 버튼은 choose를 직접 호출한다. UI 클릭/OS 물리 입력·선행4의뢰 실제 수행을 검증한 것이 아니다.

## 재현 결과

| 검사 | 결과 |
|---|---|
| 전체 GUT | **1063/1063**,119 scripts,9118 asserts,exit0. Deprecated8은 기존 출력에 남음 |
| 최종 여행 cleanup/depart/return/reload | **4/4 YEOULMOK_JOURNEY_PASS**, exit0, false0/SCRIPT ERROR0 |
| 이동 위치 | (152.4334,519.0394)에 걸어서 저장한 후 다음 프로세스에서 일치 |
| fixture 부재 음성 | cleanup→reload, exit1·이전 저장 로드 false·단계 완료 false·JOURNEY_FAIL, SCRIPT ERROR0 |
| 실행기 | `--quit-after 180` 실행, exit0·YEOULMOK_PLAY_READY. 초기 구동 검사이며 사람 조작 아님 |
| 기존 키트 렌더 | native PASS, false0/SCRIPT ERROR0 |
| Python 픽셀 | 9/9, 폐기 경고 오류 처리 |
| 변경 GD5 | gdformat check/gdlint 통과 |

GUT 최종은 제품 이름표 변경과 긴 이름 테스트를 포함한다. 후보/기본 도형 렌더·성능 profiler는 이번에 재실행하지 않았다. 기존 도형 대화형도 수명 관리자에 연결했지만 왕복 검증은 native 키트 모드에 한정한다. 재현 출력은 ignored screenshots와 로컬 로그이며 기존 타 작업자의 추적 PNG9개는 건드리지 않았다.

### 실패를 통해 확인한 범위

1. 이전 저장 probe에서 쓰던 (152,536)을 도보 목표로 사용했더니 y≈527.998에서 벽에 막혀 타임아웃 실패했다. 제품 충돌을 바꾸지 않고 실제 접근 가능한 (152,520)으로 새 검증 목표를 바꿨다. 이전 좌표 지정 시험을 실제 도보 통과 근거로 사용하지 않는다.
2. 로드 직후 바로 귀환을 시도하면 제품의 정적5초 조건으로 이동이 거부됐다. 조건을 수정하지 않고 자연 대기 후 진행했다. depart 저장에서도 recent_combat 재시도가 관측됐다.
3. 초기 긴 이름 시험에서 제품이 하지 않는 reset_size()를 호출하여 짧은 이름부터 중심이 틀어졌다. 이를 제품 결함으로 세지 않고 text 변경 후 자동 레이아웃을 기다리는 실제 경로로 바로잡았다. 단독12단언과 최종 전체 GUT 통과.

## 독립 검토 질문

1. 관리자 설치가 여울목+정확한 격리 경로에 한정되고, 월드 ready 순서·중복·다른 지역·기본 제품 실행을 침범하지 않는가?
2. 실제 월드 교체와 저장 프로세스 검증이 이전 단순 좌표 지정/정지 검증과 구분되는가? 테스트 fixture와 직접 호출 범위를 정직하게 제한했는가?
3. 신규 실행기와 기존 대화형 실행 연결이 저장 폴더를 유지하고, 새 캐릭터/왕복/재로드로 아트나 보상을 중복 설치·지급하지 않는가?

## 남은 범위

이번으로 **자동 검증의 지역 왕복·이동 후 저장 위치 복원**은 확인했다. 사람의 OS 물리 입력, 전투/드롭 동적 가독성, 미감·소품 통과 체감, 실제 전 의뢰 완주, G3/G4/G5와 환경 제품 채택은 미판정이다. M6는 별도 설계 보관 상태이며 이번 기능에 섞지 않았다. 작은 NPC 후속만 다시 전달하지 않고 실행기부터 프로세스 복원까지 이 묶음 하나를 검토한다.
