# NPC 이름표·상호작용 안내 통합 검토
> 2026-09-29 독립 검토 수신: `d660631` 통과, 지적0건. 긴 이름 grow 보완은 다음 [연속 플레이 통합 묶음](yeoulmok-play-session-review-request.md)에 포함했다. 이 요청서 재전달은 필요 없다.


- 최종 수정: 2026-09-29 / 담당: Codex
- 기준: `92e6e0b` / 구현: `d660631` (9파일, 로컬 완료·원격 미푸시)
- 변경 이력: `393d3f5` 독립 검토 지적0건 통과 후, 남은 NPC 안내 겹침을 제품 표시·시제품 배치·실제 도보 검증에 함께 반영했다.
- 의존: [이전 도보 검증](yeoulmok-walk-report.md), [키트 규격](../art/concepts/yeoulmok/native-kit/README.md)

## 문제와 변경

NPC 이름표와 `[F] 대화`가 같은 화면 위치를 차지했다. 제품 공통 NPC 씬의 이름표를 발 기준 y−48..−35로 올리고, NPC가 실제 Label 상단 중앙을 프롬프트 기준점으로 제공하도록 했다. WorldInteraction은 이 API가 있는 대상에만 사용한다. 조사 표식 등 나머지 대상은 기존 발−24 기준을 유지한다. InteractionPrompt의 기존 화면상 8px 간격도 유지한다.

기존 x±20 예약 영역과 별개로, 실제 Label Control 크기를 카메라 변환한 화면 사각형과 HUD 프롬프트 사각형을 비교한다. 글리프의 불투명 픽셀/외곽선까지 정밀 측정하는 검사는 아니다. 이름표 이동 후 접수원 Label 범위에 우물이 걸려, 시제품 우물만 (114,452)→(107,452)로 이동했다. 이름표·프롬프트와 생활 장식10개의 보이는 bbox를 각각 검사한다. 지붕·벽·다른 HUD 전체까지 가림 없음을 보장하지 않는다.

## 파일별 변경

| 파일 | 역할 |
|---|---|
| `godot/scenes/npc/quest_receptionist.tscn` | 공통 NPC 이름표 높이·영역 |
| `godot/scripts/npc/quest_npc.gd` | 이름표 기준 프롬프트 위치 API |
| `godot/scripts/quests/world_interaction.gd` | NPC 위치 API 사용, 기존 대상 fallback 유지 |
| `godot/scripts/tools/yeoulmok_native_kit.gd` | 시제품 우물 배치 |
| `docs/qa/tools/yeoulmok_walk_probe.gd` | 화면 표시 영역 분리, 소품 가림, 대화 완료 횟수 검사 |
| 키트 README·이 요청·PROJECT_STATUS·HANDOFF | 규칙/검증/통과 기록 및 인계 |

공통 NPC 씬은 접수원·여울목 관문지기·노베라 안내인이 사용한다. 실제 도보 캡처는 앞의 두 NPC만 검증했다. 저장 형식·전투·보상·지역 이동·환경 제품 채택은 바꾸지 않았다.

## 검증

- 제품 수정 전 이름표/프롬프트 겹침 false, exit1 재현. 최초 테스트 작성 때 HUD 노드 경로를 잘못 써 SCRIPT ERROR가 있었고 exit0가 나왔다. 그 실행은 재현 성공으로 세지 않는다. 이후 실제 소유자 `selection.hud`를 사용했고, 정상 경로에서 대화 검사3회가 끝까지 실행됐는지 검사한다. 로그 SCRIPT ERROR 검사도 별도로 유지한다.
- 제품 표시 수정 후 우물/접수원 Label 겹침 false를 추가 발견하고 배치 수정 후 통과.
- 전체 GUT **1062/1062**, Scripts118, Asserts9109, exit0. SCRIPT ERROR·종료 leak/RID 경고 없음. GUT Deprecated8은 출력에 남아 있다.
- 원본/키트 도보 각각 exit0 `YEOULMOK_WALK_PASS`. 접수원→관문→접수원, 근접/레이캐스트·이동·대화 입력·닫기·재개·표시 영역 검사 통과.
- 이동 차단 `--blocked`: 첫 구간 타임아웃, 예상 exit1 `YEOULMOK_WALK_FAIL`.
- 키트 정지 렌더 exit0 `YEOULMOK_NATIVE_KIT_PASS`, false0/SCRIPT ERROR0.
- Python9/9(폐기 경고 오류 처리), 변경 GD4개 gdformat/gdlint 통과.

```powershell
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
godot --path godot --script ../docs/qa/tools/yeoulmok_walk_probe.gd
godot --path godot --script ../docs/qa/tools/yeoulmok_walk_probe.gd -- --baseline
godot --path godot --script ../docs/qa/tools/yeoulmok_walk_probe.gd -- --blocked
godot --path godot --script ../docs/qa/tools/yeoulmok_art_pilot_probe.gd -- --native-kit
python -W error::DeprecationWarning docs/qa/tools/test_yeoulmok_native_kit.py
```

캡처는 ignored `screenshots/yeoulmok-walk/`에 출력한다. `native/gate-prompt.png`를 직접 열어 두 줄 분리를 확인했다. 기존 타 작업자 추적 PNG9개는 미포함. 후보/도형 렌더·배칭 성능·저장 프로세스 probe는 이번 재실행 범위 밖이다.

## 리뷰 질문

1. NPC 전용 기준점이 이름표 변경에 따라 움직이고, 비NPC 대상의 기존 안내 위치와 입력 선택 계약을 유지하는가?
2. Control 화면 사각형을 사용한 검사와 우물 이동이 실제 배치를 설명하는가? 검사 범위를 전체 HUD/글리프 가독성 보장으로 과장하지 않았는가?
3. 도보·대화 검사 완료 횟수와 로그 검사가 중간 스크립트 오류를 통과로 오인하지 않게 하는가?

OS 물리 키 전달·노베라 왕복·저장 복원·동적 교전·사람 체감·미술 승인·G3/G4/G5는 미판정 유지. 제품 NPC UI는 수정했지만 환경 키트의 제품 채택은 별개다.
