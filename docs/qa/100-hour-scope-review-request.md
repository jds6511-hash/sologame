# Claude 검토 요청 — 100시간 전환의 문서·구현 영향

- 기준: `3359bf3` (제품 코드 `72cb569`). 이번 변경은 문서만이다.
- 검토 커밋: **`e007f07`**, 범위 `3359bf3..e007f07`. 문서7개, 게임 코드0개. 문서 diff 공백 검사와 새 문서 상대 링크29개 확인 완료. 후속 인계 커밋은 이 해시와 검증 결과만 기록한다.
- 대상: [100시간 영향 감사](../design/100-hour-scope-audit.md), [MQ03 리뷰 대응](m5-third-quest-review-response.md), 현황/인계/로드맵 연결.
- 요청: 파일 수정·커밋·푸시 없이 독립 검토. 아직100h 곡선·콘텐츠 축소를 구현하거나250h 정본을 대체하지 않았다.

## 검토 질문

1. 단일 캐릭터 메인+주요 선택100h라는 정의와 `40+30+5+7+3+15` 활동 배분에 중복/누락이 있는가? 120~150개 서브를 30h에 수용하는 가정, 전체 수집·다회차를 범위 밖에 둔 점을 분명히 했는가?
2. 기존480개 서브·명성/영지·왕국 전역과 현재 실제3개 의뢰·한 저장 대상 맵·예약 필드를 정확히 구별했는가? 이미 구현된 것을 없애거나 미구현을 완료로 간주한 곳은 없는가?
3. `save_schema.gd`의 현재곡선 EXP 검증 때문에 기존 정상 저장이 거부되는 분석이 맞는가? Lv20/EXP50,000 예시, 구 규칙 검증→변환→새 규칙 검증 순서에서 빠진 경계는 무엇인가? 기존 V1/V2 변환이 이미 해결하는 범위를 과소평가하지 않았는가?
4. 명성 공급 예시10,870과 최종관문×1.2=12,000 비교, 월간 이벤트15h의100h 영향이 타당한가? 전체 합계뿐 아니라 장별 관문·왕복·강제 대기를 검사하도록 충분히 요구했는가?
5. EXP·골드·전직·수집·계승과 문서 변경 목록/순서가 충분한가? 추가로 바꿔야 할 코드나 유지해야 할 계약을 파일·함수와 함께 지적해 달라.
6. MQ03 낮음3건의 처리 구분(2건 MQ04 이월, 패널 불투명 사유 기록)과 실제 플레이/G4/G5 미완료 유지가 적절한가?

## 대조 경로

```powershell
git diff --check 3359bf3 HEAD
git diff --stat 3359bf3 HEAD
git diff 3359bf3 HEAD -- godot
rg -n '250|480|127\.5|180h' docs/design
rg -n 'exp_overflow|reputation|territory|story_flags' godot/scripts/save/save_schema.gd
Get-Content godot/data/progression/level_curve.tres
Get-Content godot/scripts/progression/level_curve.gd
Get-Content godot/scripts/save/character_save_codec.gd
Get-Content godot/scripts/save/save_content_registry.gd
Get-Content godot/scripts/quests/quest_catalog.gd
```

`godot` 커밋 diff는0이어야 한다. 워킹트리에 원래 있던 재생성 스크린샷9개와 로그는 이번 변경에 포함하지 않는다. 이번 단위는 게임 테스트를 다시 실행하지 않았으며 이전 GUT1001/1001을 이번 검증 결과로 인용하지 않는다.

## 원하는 판정

- **예산 상세 설계 착수 가능 / 수정 필요**를 판정해 달라. 100h 완주 보장이나 새 곡선 배포 승인이 아니다.
- 차단 항목은 근거 경로·실패 사례·필요한 결정으로 나눠 달라.
- 통과 뒤에는 감사 §6의 정본 예산 단위를 진행한다. MQ04 기능 확장은 별도 구현 리뷰로 제출한다.
