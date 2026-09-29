# 좌우 전용 원화 연결 계약 검토

- 날짜: 2026-09-29 / 담당: Codex
- 기준: `2da4494` / 구현: `b7e150c` (10파일, 로컬 완료·원격 미푸시).
- **범위: 제작 도구→SpriteFrames→런타임 선택·공격 시계의 연결 준비. 전사 손 교체 해결/원화 완성/미술 승인 아님.** 제품 PNG·배포 SpriteFrames는 변경하지 않았다.

## 수신 리뷰 처리

`a740968` 저장 피드백은 독립 검토 지적0건 통과했다. `travel()`만 누적 시간을 전달하고 load/new는 기본 carry를 사용함을 코드로 대조하여 [이전 검토서](save-feedback-review-request.md)의 ‘월드 교체’를 ‘지역 이동’으로 정정했다. 저장 제품 코드는 이번에 변경하지 않았다.

## 실제로 추가된 계약

- 기존3방향 시트는 종전처럼 왼쪽에서 side를 뒤집는다. 현재 배포 원화는 이 경로이며 손 교체가 남는다.
- 모든 `*_side`에 대응하는 `*_left`가 있고 프레임 수·속도·loop가 일치할 때만 왼쪽 전용 세트를 사용한다. 일부 상태만 지원하면 **전 상태**를 기존 경로로 돌려 이동/공격의 혼용을 막는다. 좌우 전용 세트에서도 기존 판정 시계로8프레임 공격을 재생한다.
- 제작 파일은 기존 PNG 이름 뒤에 `_left`를 붙인 한 행이다. 예: `player_warrior_v2_walk_left.png`=168×36, `player_warrior_v2_attack_sweep_left.png`=512×64. 전사는9상태 전체가 필요하다. 다른 방향/기존 시트는 변경하지 않는다.
- 생성기는 좌측 파일이 하나라도 있으면 모든 상태의 존재·크기를 검사한다. 모든 직업을 사전 검증한 뒤 `.tres`를 기록하므로 뒤 직업이 잘못됐다고 앞 직업만 갱신되지 않는다. 파일 쓰기 중 OS 장애에 대한 원자성은 보장하지 않는다.
- 이 검사는 리소스 연결 계약이다. 투명 빈 그림·잘못된 손·무기 위치·팔레트/미감은 별도 작화 검수 대상이다. 합성 테스트용 측면 복사본을 제품 원화로 넣지 않았다.

## 원본 조사와 남은 원화

`warrior_left_source_audit.py`로 LPC 원본의 대기/이동/1타/2타 각3프레임, 좌우24개 합성을 비교했다. 원본 왼쪽 행을 읽을 수 있다는 것은 확인했으나, 이것만으로 현행 대검·손 앵커·8프레임 공격 전반의 오른손 일관성을 보장할 수 없다. 기존 몸 전체 flip을 끄거나 원본 행만 바꿔 ‘해결’했다고 표시하지 않는다.

필요한 다음 산출물은 오른손의 가까운 쪽/먼 쪽 가림을 명시한 왼쪽9상태 원화다. 대기↔이동↔공격↔복귀와 피격/회피/사망까지 같은 손을 유지해야 한다. 실제 원화가 공급되면 이 계약으로 연결하고 픽셀 접점·동적 재생을 확인한다. 이번 작업을 최종 리디자인으로 확대하지 않는다.

## 변경 파일

| 파일 | 변경 |
|---|---|
| `godot/assets/tools/gen_player_spriteframes.py` | 선택적 왼쪽 한 행 입력, 전체 입력 사전 검증, 기존 출력 불변 |
| `godot/scripts/player/player_visual_module.gd` | 완전한 좌측 세트만 선택, 기존 폴백 유지 |
| `godot/assets/tools/test_player_left_sheets.py` | 완전성·크기·배포 리소스 동일·후속 직업 오류 시 앞 리소스 보존5검사 |
| `godot/test/player/test_player_left_animation.gd` | 왼쪽 이동/공격 시계, 불완전·길이/속도/loop 불일치 폴백, 오른쪽/정면5검사 |
| `docs/qa/tools/warrior_left_source_audit.py` | 제품 파일을 수정하지 않는 원본24프레임 비교, ignored screenshots 출력 |
| 아트 가이드·진행 문서·이 검토서 | 미해결 원화와 연결 준비의 구분, 저장 리뷰 통과 반영 |

## 검증과 질문

- 신규 런타임4검사 최초2실패→구현 후4통과, 속도/loop 검사 추가. 공격 방향 fixture를 Facing=PI로 정정했다. 반복 fixture 생성 시 같은 이름 애니메이션 중복 오류도 fixture를 정정하여 제거했다.
- Python5/5. 최초 API 미구현4오류 확인 후 구현. 추가 음성 테스트에서 Windows cp949 콘솔의 기존 em-dash 출력 오류가 드러나 오류 문구를 하이픈으로 정정했다.
- 생성기를 실제 재실행했으며 `godot/assets/sprites/player/` diff0. 제품 PNG와 기존 전사/궁수 `.tres` 불변.
- GD2개 gdformat/gdlint 통과. 최종 전체 GUT **1,074/1,074 · 120 scripts · 9,186 asserts**, exit0, SCRIPT ERROR/종료 잔존 경고 없음. 의도적 저장 I/O 음성 테스트의 ERROR 1건은 기존 ExpectedError다.

```powershell
python godot/assets/tools/test_player_left_sheets.py
python docs/qa/tools/warrior_left_source_audit.py
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
```

검토 질문:

1. 불완전한 좌측 세트가 이동/공격 사이 혼용되지 않으며 기존 직업 리소스에는 동작 변화가 없는가?
2. 좌측 전용 공격도 기존 판정 시계와 프레임 동기화를 유지하는가?
3. 생성 입력 실패 시 기존 리소스를 미리 덮어쓰지 않는가? 준비 작업을 원화 완성/손 교체 해결로 과장하지 않았는가?

현재 손 교체, 실제 새 원화, G3~G5, 미감·환경 제품 채택은 미해결/미판정이다.
