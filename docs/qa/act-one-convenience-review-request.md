# 1막 후 이동·사거리·줍기 통합 검토

- 2026-10-03 / Codex. 기준 **`4d9136e`**, 대상 **`15397a7`**. [설계·계획](../design/systems/act-one-convenience.md), [실행 증거·실패 기록](act-one-convenience-evidence.md).
- 디렉터의1막 체감 통과는 유지한다. 재완주나 새 아트 승인을 요청하는 묶음이 아니다.

## 변경·재현

- 제품: Shift 평상시1.5배 달리기와 ESC 누르기/토글 설정(세션 유지), 기본/일반 스킬/조준 화살10/10.5/12타일, 발32px·시야·같은 월드의 F 다중 줍기. 캐릭터 저장 형식·콘텐츠 개정은 그대로다.
- QA: 실제 캡슐 overlap·스킬 시작 배율·벽/만석/우선권 회귀와 기존 설정 GUI 검사 확장. 기존 직업 메뉴 probe는 적 없는 초기 fixture로 분리했다. 실패한 첫 전체 배치는 숨기지 않았다.
- 최종 `verify_all` **114/114**, 전체 GUT **1191/1191**, 실제 저장6개 해시 불변. GUI `PLAY_FEEDBACK_PASS`, 실행기 smoke exit0. `-Combat` 미실행. Ogg 종료 경고는 기존 예외 범위이며 해소 주장 없음.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/qa/tools/verify_all.ps1
godot --path godot -s ../docs/qa/tools/play_feedback_probe.gd
```

## 질문

1. 달리기 토글·일시정지·사망·지역 교체와 공격/조준/스킬/회피 속도 및 저장 안전 조건이 충돌하지 않는가?
2. 다중 줍기가 실제 캡슐 기준 범위·벽·NPC 우선권·가방 용량·중복 지급 방지를 유지하는가?
3. 사거리와 문서 수치, 적 없는 메뉴 fixture, 최초 실패/최종 통과를 정확히 구분했는가? 원거리 피격 추격은 기존 미구현으로 남겼다.

결과는 `docs/qa/reviews/15397a7.md`에 원문으로 작성한다. 이전 검토 `62d3573` 참고의 월드 교체 주석은 `8475525`에 반영했다. 낮음만을 위한 별도 재검토는 요청하지 않는다.
