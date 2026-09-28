# 여울목 배치·도보·대화 통합 검토

- 최종 수정: 2026-09-29 / 담당: Codex
- 기준: `795e276` / 대상: 후속 인계에 구현 해시 기록
- 변경 이력: 재질 묶음 리뷰 통과 후 배치 보완과 실제 이동·대화 자동 회귀를 함께 검토한다. [과거 요청](yeoulmok-environment-kit-review-history.md)은 이력으로 분리했다.
- 근거: [변경 파일·검증 상세](yeoulmok-walk-report.md), [키트 계약](../art/concepts/yeoulmok/native-kit/README.md)

## 이번 범위

안내판·상자의 NPC 상부 예약 영역 침범을 해소하고, 원본/키트 양쪽의 실제 이동→NPC 선택→대화→닫기→귀환 자동 경로를 추가했다. 사람 직접 조작이나 지역 이동·저장 검증을 주장하지 않는다. 제품 아트 배선·게임플레이 변경은 없다.

변경 파일:

- `godot/scripts/tools/yeoulmok_native_kit.gd`: 안내판·상자 좌표 및 검사 진단용 소품 종류 메타.
- `docs/qa/tools/yeoulmok_art_pilot_probe.gd`: NPC 상부 예약 영역과 옛 배치 음성 대조.
- `docs/qa/tools/yeoulmok_walk_probe.gd`: 원본/키트 실제 이동·대화 입력·닫기·재개, 이동 차단 음성 실행.
- `docs/art/concepts/yeoulmok/native-kit/README.md`: 배치 계약과 검증 범위.
- `docs/qa/yeoulmok-walk-report.md`: 절차·실패 이력·재현·한계.
- 이 요청서·검토 이력·`docs/PROJECT_STATUS.md`·`docs/HANDOFF.md`: 통과 기록과 인계.

## 판정할 질문

1. NPC 상부 사각형을 실제 글꼴/HUD의 전체 범위로 과장하지 않았는가? 옛 안내판/상자 음성 대조와 새 소품 간 검사로 이번 배치를 충분히 확인하는가?
2. 도보 probe가 좌표를 지정하거나 안전 조건을 우회하지 않고 실제 이동/충돌/근접·레이캐스트/대화 입력/pause 경로를 거치는가? 이동 차단 시 실패가 확실한가?
3. 원본/키트 경로 비교의 의미가 마을 안 자동 왕복으로 제한되는가? OS 물리 입력·노베라 왕복·저장 복원·교전·사람 체감·G3~G5 미판정이 유지되는가?

재현 명령과 실행 결과는 보고서에 있다. Python9/9, GD3, 정지 렌더3모드, 원본/키트 도보2경로 PASS. 차단 음성 실행은 예상 exit1. 전체 GUT·배칭 측정·혼용 거부는 이번에 재실행하지 않았다. 출력은 ignored screenshots 아래에만 생성한다. 다른 작업자의 추적 PNG9개는 제외한다.
