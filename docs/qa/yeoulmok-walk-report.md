# 여울목 배치·도보·대화 통합 검증

- 최종 수정: 2026-09-29 / 담당: Codex
- 기준: `795e276` / 구현 해시: 인계 커밋에 기록
- 의존: [키트 규격](../art/concepts/yeoulmok/native-kit/README.md), [통합 검토](yeoulmok-environment-kit-review-request.md)
- 변경 이력: `bfab533` 리뷰 통과를 반영하고 NPC 상부 배치 보호와 실제 이동·대화 자동 검증을 연결했다.

## 변경

안내판을 (286,432)에서 (286,396)으로 이동했다. 불투명 범위는 x276–298/y374–396으로 관문지기 상부와 분리된다. NPC 발 기준 x±20/y−48..0을 **장식 배치용 예약 영역**으로 검사한다. 실제 글꼴의 글자 폭이나 HUD 전체를 측정한 범위는 아니다.

새 검사를 기존 배치에 실행했더니 안내판 외에 두 번째 상자도 실패했다(exit1, false2). 상자 둘을 (243,450)/(258,450)에서 (236,450)/(251,450)으로 옮겼다. 두 번째 상자의 보이는 오른쪽 끝은 x258로 관문 예약 영역 x260과 분리된다. 옛 안내판과 두 번째 상자의 침범을 각각 음성 대조로 유지한다. 기존 소품끼리·작물·동선·발 위치 검사는 유지한다.

`yeoulmok_walk_probe.gd`는 별도 월드를 실제 갱신하며 아래 경로를 검증한다. `--baseline`은 제품 그림, 기본은 키트 설치 상태다. 기존 렌더 probe의 정지·좌표 지정 캡처와 다른 도구다.

1. 시작점 (152,504)에서 접수원 선택 → 대화 입력 → 일시정지 → 닫기 입력 → 재개.
2. 이동 입력으로 (200,504) → (200,456) → (248,456), 관문지기 선택과 대화.
3. 역순으로 시작점 귀환, 접수원 재선택·대화 및 생존 확인.

좌표·속도 직접 대입, 의뢰 상태 편집, 시간 가속, 적 정지는 없다. 이동은 `Input.action_press/release`, 대화와 닫기는 `Input.parse_input_event(InputEventAction)`를 사용한다. 근접/레이캐스트/선택과 제품 대화·pause 중재가 실제 호출된다. 이것은 **OS 물리 키 전달이나 사람의 직접 조작이 아니다**. 노베라 지역 이동·저장/재실행·의뢰 수락/완료·공격/회피는 실행하지 않았다. 저장 경로 메타는 `user://yeoulmok_walk_probe`로 격리하며 실행 중 저장을 요청하지 않는다.

## 실행 결과

| 검증 | 결과 |
|---|---|
| 키트 Python | 9/9, DeprecationWarning 오류 처리 통과 |
| 변경 GD 3개 | gdformat check / gdlint 통과 |
| 렌더 기본/후보/키트 | 모두 exit0, 각 PASS, SCRIPT ERROR0, false0 |
| 옛 안내판·상자 배치 | 두 음성 대조 true |
| 실제 이동 원본/키트 | 각각 exit0, `YEOULMOK_WALK_PASS`, SCRIPT ERROR0 |
| 이동 차단 음성 실행 | exit1, 첫 구간 타임아웃, `YEOULMOK_WALK_FAIL`, SCRIPT ERROR0 |

원본과 키트의 도착 좌표 6개가 로그에서 동일했다: (198.5934,504), (199.215,456.785), (247.5666,456.785), (200.9732,456.785), (200.9732,503.3784), (152.6216,503.3784). 목표 오차 허용은 1.5px다. 특정 경로의 이번 실행 관측값이며 모든 프레임/환경의 결정성 보장은 아니다.

`--blocked`는 QA 전용으로 플레이어 처리를 끄고 90 physics-frame 안에 첫 구간을 도달하지 못하면 실패한다. 정상 경로는 구간당 최대600프레임, 전체60초 제한이다. 초기 개발 시 전역 PlayerController 타입의 조기 컴파일과 캡처 경로 생성 오류가 발생했으며, 전자를 엔진 기반 CharacterBody2D 타입으로 바꾸고 후자는 절대 경로로 변환했다. 이 실패는 게임 결함으로 계산하지 않는다.

그림/매니페스트/생성기·제품 씬/데이터·게임플레이 코드는 이번에 변경하지 않았다. 전체 GUT·배칭 성능 측정·혼용 거부 경로는 이번에 재실행하지 않았다. 배칭 절대 드로콜은 이전 리뷰처럼 ±1 변동 가능하며 성능 향상 주장을 추가하지 않는다.

## 재현

저장소 루트에서 실행. Windows에서는 프로세스 종료와 로그를 함께 확인한다.

```powershell
python -W error::DeprecationWarning docs/qa/tools/test_yeoulmok_native_kit.py
godot --path godot --script ../docs/qa/tools/yeoulmok_art_pilot_probe.gd -- --native-kit
godot --path godot --script ../docs/qa/tools/yeoulmok_walk_probe.gd
godot --path godot --script ../docs/qa/tools/yeoulmok_walk_probe.gd -- --baseline
godot --path godot --script ../docs/qa/tools/yeoulmok_walk_probe.gd -- --blocked
```

캡처는 ignored `docs/qa/screenshots/yeoulmok-walk/{native,baseline}/`에 저장한다. `gate-prompt.png`를 직접 열어 안내판 분리를 확인했다. 기존 NPC 이름표와 F 프롬프트 겹침, 캐릭터/지면의 스타일 차이는 남아 있다. NPC 예약 영역 검사 통과가 UI 자체 가독성 통과는 아니다.

실제 사람이 이동할 때의 소품 통과 체감·동적 교전 가독성·미감·G3/G4/G5·제품 채택은 미판정이다. 원본과 키트의 같은 도보 경로 통과를 지역 왕복이나 저장 복원 통과로 해석하지 않는다.
