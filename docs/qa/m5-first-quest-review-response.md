# M5 단위 2 독립 검토 대응

- 날짜: 2026-09-27. Claude 검토 대상 `0e7e261..5df3099`, 보완 기준 `a3aba60`.
- 판정: **단위 2 구현 통과**. 단위 3 실제 플레이 및 G4/G5 승인을 뜻하지 않는다.
- 연결: [기존 요청](m5-first-quest-review-request.md), [구현 보고서](m5-first-quest-report.md), [실행 계획](../superpowers/plans/2026-09-27-m5-first-quest.md).

## 지적 대조와 처리

| 항목 | 처리 | 근거/남은 일 |
| --- | --- | --- |
| NPC 우선 시 줍기 안내 잔존 (중간) | 수정 | WorldItem의 입력·안내가 `_pickup_available()`을 공유한다. 진입 시와 매 갱신에 적용하며 NPC 우선 종료 시 재진입 없이 안내를 복원한다. |
| 처치 토큰 무제한 누적 (낮음) | 최적화 보류 | 활성 KILL 목표가 없다고 토큰 기록을 생략하면 수락 전 사망 token이 수락 후 재전달될 때 집계된다. 기존 `test_no_retroactive_kills_wrong_source_or_duplicate_token`이 이 경우를 금지한다. 세션 장기 누적 비용은 미측정이며, 이벤트 수명·중복 방지 계약을 함께 정리할 후속 과제로 남긴다. |
| 패 수령 후 재대화 필요 (낮음) | 단위 3 체감 확인 | 명시적 다음 의뢰 수락은 가능하다. 실제 플레이에서 재대화 발견 가능성·보상/레벨업 안내 충돌을 확인한 뒤 연속 제안 여부를 판단한다. 이번에는 흐름을 바꾸지 않았다. |

Claude가 재현한 기존 989/989·3564 assertions·107 scripts, 마이그레이션 5단계, 렌더 PASS 및 40/40은 **리뷰어 결과**다. 아래는 이번 보완에서 직접 실행한 결과다.

## 변경 파일과 검증

- `godot/scripts/items/world_item.gd`: 줍기 가능 판정과 안내 상태 통일.
- `godot/test/items/test_world_item.gd`: 실제 아이템 씬으로 NPC 우선 진입/입력 차단, 겹친 상태에서 우선 전환/해제 및 정상 줍기, 범위 이탈 후 숨김 유지 3건.
- 이 문서 및 현황·인수인계·로드맵·계약·실행 계획: 단위 2 통과와 비차단 후속 항목을 기록한다.
- 기존 스크린샷 3개는 작업 시작 전부터 수정돼 있었으므로 이번 변경에 포함하지 않는다.

실행:

```powershell
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gtest=res://test/items/test_world_item.gd -gexit
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
gdformat --check godot/scripts/items/world_item.gd godot/test/items/test_world_item.gd
gdlint godot/scripts/items/world_item.gd godot/test/items/test_world_item.gd
```

- 수정 전: 3건 중 2건 실패, 안내 표시 단언 3개 실패. 첫 시도의 입력 프레임 공유로 생긴 중복 줍기 fixture 오류는 `after_each`에서 프레임을 분리한 후 제거하고 재실행했다.
- 수정 후 전체 GUT: **992/992, 3574 assertions, 108 scripts**. 형식·린트 2파일 통과.
- 기존 저장 실패 주입 테스트의 의도된 디렉터리 생성 오류 외 종료 잔존 경고 없음. 이번에는 렌더/마이그레이션 probe를 재실행하지 않았다.
- 로컬 로그: `m5-prompt-red.log`, `m5-prompt-full.log` 및 대응 `-errors.log` (커밋 제외).

## 리뷰어 전달 및 다음 작업

이번 보완 검토는 WorldItem과 새 테스트 두 파일로 한정한다. NPC 우선 중 안내/입력이 모두 막히는지, 우선 해제 시 재진입 없이 복원되는지 확인하면 된다. 전체 단위 2 재검토를 요구하지 않는다.

다음은 단위 3의 의뢰 active/ready/completed 별도 프로세스 복원과 실제 이동→대화→수락→처치→보고→저장→재실행 검증이다. M4 이동 위치 복원·종료 경고 원인·G4, M5/G5 및 저장 거부 빈도 관찰은 계속 미완료다.
