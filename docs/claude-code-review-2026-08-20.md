# Claude Code 전달용 개발 리뷰 — 2026-08-20

> 목적: 현재 게임 프로젝트의 중간 검수 결과를 바탕으로, Claude Code가 다음 작업의 우선순위·검증 기준·주의사항을 빠르게 파악할 수 있도록 정리한 리뷰 문서.
>
> 기준 문서: `interim-review-2026-08-20.md`
>
> 주의: **"원본 검수 사실"과 "리뷰어 판단/제안"을 분리**한다. 원본에 없는 사실을 코드에 존재하는 것으로 가정하지 말 것. 실제 구현 착수 전 반드시 저장소에서 재검증할 것.

---

## 0. Executive Summary

현재 프로젝트는 **전투·성장·전직·적·사망 흐름까지 연결된 전투 프로토타입**으로서는 상당히 성숙하다.

원본 검수 기준:

- GUT 테스트 **856/856 통과**
- 어서션 **2,809개**
- gdlint **0건**
- 구현 스크립트 **106개 / 12,759줄**
- 테스트 스크립트 **93개 / 11,469줄**
- 테스트/구현 코드 비율 **0.90**
- 전투, 성장, 1차 전직, 적 10종, 드랍, 주야간, 재스폰, 사망/부활, HUD까지 end-to-end 동작
- 반면 **Save/Load, Quest, NPC, Dialog, Shop은 구현 0줄**

따라서 현재 상태를 한 문장으로 정의하면:

> **"전투의 재미를 검증할 수 있는 프로토타입은 완성되어 있으나, 장기 진행과 세계 상호작용을 갖춘 RPG 제품은 아직 아니다."**

다음 핵심 의사결정은 **M3 게이트 플레이 세션**이다.  
M3 게이트를 통과한 이후에는 기능을 무작정 늘리기보다, **영속성 → 목적/퀘스트 → 세계 상호작용** 순서로 RPG의 메타 루프를 세우는 것이 적절하다.

---

# 1. Source-grounded Status

이 절은 원본 검수 리포트에 명시된 사실만 요약한다.

## 1.1 현재 작동하는 핵심 시스템

### 전투
- 이동
- 기본 공격 콤보
- 회피
- 스킬 사용
- 공격 중 이동 계수 0.45
- 몬스터 반격 및 양방향 데미지
- 그로기/스태거
- HitFeedback 약/중/강 3단계
- 카메라 피드백 연동

### 성장/직업
- EXP 및 레벨업
- 스탯 자동 성장
- 스킬 포인트 경제
- 모험가 → 1차 3직업 전직
- 직업 스킬 데이터 18종
- 분노 게이지 UI

### 적/아이템
- 적 데이터 10종
- 관련 씬 12개
- 드랍 테이블 10종
- 아이템 43종

### 월드/시스템
- 맵 2개
- 주야간 사이클
- 몬스터 재스폰
- 사망 연출 4단계
- 시작 지점 부활
- 골드 경미 손실
- HUD
- 통합 메뉴 6탭
- 온보딩 힌트 바

---

## 1.2 현재 없는 핵심 RPG 시스템

원본 검수에서 `scripts` 전체 검색 결과 구현 파일이 없다고 명시된 항목:

- Save
- Quest
- Dialog
- NPC
- Shop
- Pet
- Title
- Codex
- Territory

특히 아래 3개는 원래 M2 정의에 있었다가 범위 축소 이후 재배정되지 않은 상태로 기록되어 있다.

1. Save/Load
2. Quest
3. Village/NPC 계층

이는 단순한 "미구현 기능"이 아니라 **마일스톤 계획에서 빠진 의존성 리스크**로 봐야 한다.

---

## 1.3 품질 상태

원본 판정:

| 축 | 상태 |
|---|---|
| 회귀 방어 | 양호 |
| 코드 규약 | 양호 |
| 밸런스 근거 | 양호 |
| 통합 안정성 | 양호 |
| 아트 일관성 | 미흡 |
| 아트 완성도 | 최소 수준 / 의도된 상태 |

특이사항:

- 지형 타일 명도 폭이 **101**
- 목표 명도 폭은 **≤15**
- 2×2 체커 비율 **4.19%**
- 레퍼런스 대비 지면 대비가 과도해 시각 피로 리스크가 있음

---

# 2. Reviewer Assessment

이 절은 원본 사실을 바탕으로 한 **리뷰어 판단**이다. 저장소 검증 없이 구현 사실로 간주하지 말 것.

## 2.1 가장 잘된 점

### A. 구현 범위보다 "검증 가능한 코어"를 먼저 만든 점

현재 프로젝트는 전투/성장/전직/적/사망까지 연결되어 있어, 실제 플레이를 통해 재미를 평가할 수 있는 단계다.

대형 RPG에서 흔한 실패는 콘텐츠와 시스템을 동시에 대량 추가해놓고 나중에 "기본 전투가 재미없다"는 사실을 발견하는 것이다.

현재 프로젝트는 반대로:

> 기술 검증 → 전투 루프 → 플레이 게이트 → 메타 시스템

순서를 유지하고 있어 개발 리스크를 통제하기 좋은 구조다.

### B. 테스트 밀도가 높다

테스트 코드가 구현 코드의 약 90% 수준이라는 것은 개인 프로젝트치고 상당히 강한 회귀 방어 구조다.

이 비율 자체를 목표로 삼을 필요는 없지만, 이후 Save/Quest/Dialog 같은 대형 시스템을 추가할 때 **기존 테스트 문화가 깨지지 않는 것**이 중요하다.

### C. 문서가 결함을 숨기지 않는다

특히 다음 문제를 이미 명시한 점이 좋다.

- `player.tscn`의 Inventory 자식 부재
- 골드 패널티 경로가 유닛 테스트를 실제로 통과하지 않는 문제
- 문서 스테일 5건
- 아트 대비 결함
- Save/Quest/Village가 계획에서 실종된 문제

테스트 수치만 보고 "안정적"이라고 결론내리지 않고 **테스트가 닿지 않는 구멍까지 기록**하고 있다는 점은 유지해야 한다.

---

# 3. 가장 중요한 제품 리스크

## 3.1 Save/Load는 단순 기능이 아니라 전체 콘텐츠의 기반 인프라다

현재 RPG에는 성장, 아이템, 골드, 직업, 월드 상태가 있지만 저장이 없다.

따라서 Save/Load가 없으면:

- 레벨업 가치가 세션 종료 시 소멸
- 아이템 수집 가치가 소멸
- 퀘스트 진행을 추가해도 의미가 제한됨
- 월드 상태 변화 구현도 세션 한정
- 디버깅/회귀 재현 비용이 커짐

**M4의 최우선은 Save/Load가 맞다.**

단, 단순히 JSON 파일을 쓰는 수준에서 끝내지 말고 저장 경계를 먼저 정의할 것.

최소 저장 후보:

- Player level / EXP
- Stat / skill point state
- Job / learned skills
- Inventory / equipment
- Gold
- Current map / respawn position
- World flags
- Quest state (Quest 추가 시)
- Version/schema metadata

---

## 3.2 Quest와 NPC/Dialog는 완전히 분리하지 않는 것이 좋다

원본 계획에서는 Quest가 P1이고, NPC/Dialog/Shop 역시 P1이지만 M4 후반 또는 M5로 미룰 수 있다고 제안한다.

리뷰어 판단:

> **Quest 시스템은 최소 NPC/Dialog 수직 슬라이스와 함께 만드는 편이 낫다.**

이유:

Quest를 시스템만 따로 만들면 쉽게 아래와 같은 임시 구현이 생긴다.

- 디버그 키로 퀘스트 수락
- UI 버튼으로 퀘스트 시작
- 테스트용 글로벌 플래그 직접 변경

이후 NPC/Dialog를 붙이면서 다시 흐름을 뜯게 된다.

권장 최소 수직 슬라이스:

```text
NPC
 → 대화
 → Quest offer
 → 수락
 → 목표 진행
 → 완료 조건
 → NPC 보고
 → 보상
 → Save
```

Shop은 이 슬라이스에서 제외해도 된다.

---

## 3.3 Art Full Migration은 기능 마일스톤과 분리할수록 좋다

원본 계획의 아트 전환 범위:

- 프롭 밀도 변경
- 팔레트 32 → 128
- 명암 4 → 5~6단
- 부분 아웃라인
- 스프라이트 284개 영향 가능
- Camera2D.zoom 4 → 3

이는 단순 리스킨이 아니라 **화면 가독성·밀도·작업량을 동시에 바꾸는 대규모 변경**이다.

따라서 Save/Quest 구현과 같은 마일스톤에서 모두 병렬로 돌리면:

- 기능 버그인지 아트 변경 영향인지 구분이 어려워짐
- 플레이 게이트 비교 기준이 흔들림
- PR/커밋 단위가 커짐
- 회귀 원인 추적이 어려워짐

권장:

- M3 게이트 전: 지형 대비 결함만 최소 수정
- M3 게이트 후: Art Migration을 독립 workstream으로 운영
- 기능 시스템 커밋과 아트 대량 교체 커밋을 섞지 말 것

---

# 4. M3 Gate Review

## 4.1 게이트 전에 반드시 할 것

### 지형 대비 수정

원본에서 현재:

- 명도 폭: 101
- 목표: ≤15

이 문제는 단순 미관 이슈가 아니다.

플레이 테스트에서:

- 적 가독성
- 피격 이펙트 가독성
- 장시간 플레이 피로
- 전투 난이도 체감

을 오염시킬 수 있다.

따라서 **G3-1 재미/난이도 판정 전에 처리하는 것이 타당하다.**

---

## 4.2 G3에서는 자동 테스트로 판단할 수 없는 것을 봐야 한다

자동 테스트가 잡을 수 없는 핵심 질문:

1. 기본 공격 자체가 반복해도 기분 좋은가?
2. 회피 성공이 "운"이 아니라 "내 판단"으로 느껴지는가?
3. 몬스터 종류가 실제 플레이 방식의 변화를 요구하는가?
4. 스킬을 얻었을 때 행동 선택지가 바뀌는가?
5. 레벨업 이후 힘이 강해졌다는 체감이 있는가?
6. 사망 후 다시 시도하고 싶은가?
7. 20~30분 플레이 후 다음 행동이 자연스럽게 떠오르는가?

### 특히 중요한 항목

> **"다음에 무엇을 하고 싶은가?"**

현재는 전투 루프는 있으나 RPG 메타 루프가 없다.

따라서 플레이어가 다음 행동을 스스로 찾지 못한다면, 전투가 나빠서가 아니라 **목표 시스템 부재**일 수 있다.

G3 결과 기록 시:

- Combat issue
- Balance issue
- UX issue
- Missing meta-loop issue

를 구분할 것.

---

# 5. Recommended Milestone Restructure

원본 M4 제안은:

- P0 Save/Load
- P0 Art full migration
- P1 Quest
- P1 NPC/Dialog/Shop
- P2 Archer 2nd job
- P2 Enemy art

리뷰어는 아래처럼 더 잘게 나누는 것을 권장한다.

---

## M4-A — Persistence Foundation

### 목표

> "게임을 종료하고 다시 켜도 플레이 진행이 유지된다."

### 구현 범위

- Save schema
- Save slot 또는 최소 단일 저장 구조
- Load
- Autosave trigger 정의
- Save version metadata
- Player progression 저장
- Inventory/equipment 저장
- Gold 저장
- Job/skill state 저장
- 최소 world state 저장

### Acceptance Criteria

- 새 게임 → 플레이 → 저장 → 종료 → 재실행 → 동일 진행 상태 복원
- 잘못된/누락된 저장 파일에서 크래시하지 않음
- Save version mismatch 처리 정책 존재
- 주요 저장 대상에 자동 테스트 존재
- 기존 856 테스트 회귀 없음

### 구현 시 피해야 할 것

- UI까지 먼저 크게 만드는 것
- 모든 월드 객체를 무조건 직렬화하는 것
- 노드 경로를 그대로 저장 데이터 ID로 사용하는 것
- 버전 필드 없이 저장 포맷을 고정하는 것

---

## M4-B — Quest Vertical Slice

### 목표

> "NPC에게 임무를 받아 실제 전투 행동으로 완료하고 보상을 받은 뒤 그 상태가 저장된다."

### 최소 구현 범위

#### NPC
- NPC 1종
- Interaction entry point

#### Dialog
- 최소 텍스트 대화
- Quest offer / accepted / complete 상태 분기

#### Quest
- Quest definition
- Quest runtime state
- Objective 1종
- Completion
- Reward

#### Save integration
- Accepted
- Progress
- Completed
- Reward claimed

### 추천 첫 퀘스트

복잡한 분기 퀘스트 금지.

예:

```text
NPC A
 → 특정 몬스터 N마리 처치
 → NPC A에게 복귀
 → 골드/아이템 보상
```

핵심은 콘텐츠 품질이 아니라 **전체 계층 연결 검증**이다.

### Acceptance Criteria

- NPC 대화로만 정상 수락 가능
- 목표 카운트 자동 진행
- 저장 후 재실행해도 진행 상태 유지
- 완료 후 중복 보상 불가
- Quest 완료 상태에 따라 NPC 대화 변경
- 최소 실패/엣지 테스트 존재

---

## M4-C — Art Migration

### 목표

> "M3에서 검증한 플레이 감각을 해치지 않고 목표 아트 방향으로 전환한다."

### 작업 원칙

- 기능 변경과 커밋 분리
- 한 번에 284개 전량 교체하지 말 것
- 대표 샘플 세트를 먼저 검증
- 환경 / 캐릭터 / 몬스터 / FX 카테고리별 게이트 적용

### 첫 샘플 추천

- 대표 지형 1세트
- 플레이어 1직업
- 근접 몬스터 1종
- 원거리 몬스터 1종
- 전투 FX 일부

이 세트로 먼저:

- 가독성
- 명암
- 줌
- 충돌 박스 체감
- 공격 거리 체감
- 픽셀 밀도

를 검증한 뒤 확대 적용할 것.

---

# 6. Critical Technical Review Points for Claude Code

실제 저장소에서 다음을 우선 검증할 것.

## 6.1 Inventory dependency hole

원본 검수에 따르면:

- `player.tscn`에 Inventory 자식이 없음
- `_apply_gold_penalty`
- `inventory.lose_gold`

경로는 856개 유닛 테스트를 통과하지 않음
- 월드 씬 수동 검증에만 의존

### 요청

Claude Code는 해당 경로를 먼저 확인하고:

1. 실제 런타임 dependency injection 위치
2. 테스트 환경과 실제 씬의 차이
3. null 가능성
4. 골드 손실 실패 시 처리

를 점검할 것.

이 항목은 단순 버그 1건보다 중요하다.

> **"유닛 테스트에선 통과하지만 실제 scene composition에서 깨질 수 있는 패턴"이 다른 시스템에도 있는지 샘플링 검토할 것.**

---

## 6.2 Scene-level integration test gap

현재 테스트 수가 많더라도 scene wiring 문제는 별도다.

다음 패턴 검색 권장:

- `get_node(...)`
- `$Child`
- `%UniqueNode`
- exported NodePath
- runtime injected dependency
- autoload reference

위 참조가:

- 테스트 fixture에서는 존재
- 실제 scene에서는 누락

되는 사례가 있는지 확인할 것.

전량 리팩터링하지 말고 **고위험 경로 우선 샘플링**부터 할 것.

우선순위:

1. Death
2. Inventory
3. Job change
4. Skill usage
5. Respawn
6. Map transition

---

## 6.3 Save system 설계 시 stable ID 정책 필요

향후 Quest/NPC/World persistence 구현을 위해 노드 경로나 표시 이름에 의존하면 안 된다.

권장 데이터 식별자:

```text
player
item:<id>
quest:<id>
npc:<id>
world_flag:<id>
map:<id>
spawn:<id>
```

Save schema에서는 **stable content ID**만 사용하고 scene/node 경로는 런타임 매핑 계층에 둘 것.

---

# 7. Suggested Work Order

## 즉시

### 1. 지형 대비 축소
- 명도 폭 101 → ≤15
- G3 전 완료

### 2. M3 Gate
- G3-1 재미/난이도
- G3-2 원거리 전투
- G3-3 성장 곡선
- G3-4 캐릭터 아트

### 3. Gate 결과 분류
결과를 다음 카테고리로 나눌 것.

- Blocker
- Combat feel
- Balance
- UX/readability
- Missing meta-loop
- Polish

---

## G3 통과 시

### 4. M4-A Save/Load
기능 확장보다 먼저 진행.

### 5. M4-B Quest + NPC/Dialog vertical slice
Quest 시스템만 고립 구현하지 말 것.

### 6. Art migration sample gate
대표 샘플을 먼저 만들고 전량 교체 여부 판단.

---

# 8. Priority Table

| Priority | 항목 | 리뷰 판정 |
|---|---|---|
| P0 | 지형 대비 수정 | G3 판단 오염 방지 |
| P0 | M3 플레이 게이트 | 다음 전체 개발 방향 결정 |
| P0 | Save/Load | 모든 장기 콘텐츠의 기반 |
| P1 | Quest vertical slice | RPG 목적 계층 시작 |
| P1 | 최소 NPC/Dialog | Quest와 동시에 연결 |
| P1 | Scene wiring risk audit | 테스트 사각지대 확인 |
| P1 | Art migration sample | 전량 전환 전 비용/가독성 검증 |
| P2 | Shop | Quest/NPC 이후 |
| P2 | 궁수 2차 전직 | 기존 이월 |
| P2 | 적 추가 아트 | M4 검증 구간 |
| Later | Pet/Title/Codex/Territory | 메타 코어 확립 이후 |

---

# 9. Do Not Do Yet

Claude Code가 다음 작업을 선행하지 않도록 권장한다.

## 금지/보류 권장

- 새 몬스터 대량 추가
- 신규 클래스 대량 추가
- Pet 시스템 구현
- Title 시스템 구현
- Codex 시스템 구현
- Territory 시스템 구현
- 대규모 스토리 콘텐츠 입력
- 284개 아트 전량 일괄 교체
- Save 없이 Quest 콘텐츠 대량 제작

이유:

현재 병목은 콘텐츠 수가 아니라:

> **전투 재미 검증 + 영속성 + 목적 계층**

이다.

---

# 10. Definition of "Playable RPG"

다음 조건을 만족하면 현재 프로젝트를 "전투 프로토타입"에서 "플레이 가능한 RPG vertical slice"로 승격해도 좋다.

## Combat
- 기본 전투가 G3 통과

## Progression
- 레벨/직업/아이템 진행 존재

## Persistence
- 종료/재실행 후 상태 유지

## Purpose
- NPC로부터 Quest 수락 가능

## World interaction
- Quest 조건이 실제 월드 행동과 연결

## Reward
- 완료 보상이 캐릭터 진행에 반영

## Continuity
- Quest/Reward 상태까지 Save에 유지

즉:

```text
NPC
 → Quest
 → Combat
 → Reward
 → Growth
 → Save
 → Reload
 → Continue
```

이 한 줄이 실제로 end-to-end 동작하면 M4의 제품적 의미가 매우 커진다.

---

# 11. Claude Code 실행 요청 형식

아래 순서대로 진행하는 것을 권장한다.

## Step 1 — Repository Verification

이 문서의 사실을 그대로 믿고 구현하지 말고 실제 저장소에서 확인:

- 테스트 개수
- gdlint 상태
- Save/Quest/NPC/Dialog/Shop 부재 여부
- Inventory scene wiring
- M3 관련 문서 상태
- 현재 HEAD와 원본 검수 기준 커밋 차이

원본 검수 기준 커밋:

```text
c923f0b
```

현재 HEAD가 다르면 변경분을 먼저 요약할 것.

---

## Step 2 — Gate-blocking Fix Only

G3 전에 필요한 변경은 최소화:

- 지형 대비 수정
- 실제 플레이 차단 버그만 수정

다음은 G3 전에 섞지 말 것:

- Camera zoom 4 → 3
- 전체 아트 마이그레이션
- Quest
- Save
- 신규 전직

이유:

G3의 비교 기준을 흔들 수 있음.

---

## Step 3 — Produce Gate Checklist

G3 세션 직전 아래 체크리스트 생성:

- [ ] GUT all green
- [ ] gdlint clean
- [ ] 지형 명도 목표 확인
- [ ] 근접 전투 진입 가능
- [ ] 궁수 전투 진입 가능
- [ ] Lv1→10 성장 관찰 가능
- [ ] F11 전사 계통 2차 전직 경로 확인
- [ ] Page Up debug level jump 확인
- [ ] 사망/부활 흐름 확인
- [ ] 플레이 로그 기록 템플릿 준비

---

# 12. Final Review Verdict

## 기술 상태

**좋음**

이유:

- 자동 테스트가 강함
- lint 깨끗함
- 핵심 전투 루프 연결됨
- 데이터 중심 설계 흔적이 있음
- 결함과 리스크가 문서화되어 있음

## 제품 상태

**전투 프로토타입**

아직 RPG vertical slice라고 부르기 어려움.

가장 큰 이유:

- Save 없음
- Quest 없음
- NPC/Dialog 없음
- Shop 없음

## 다음 판단

**기능 추가보다 G3 플레이 검증이 우선**

그리고 G3 통과 후:

> **Persistence → Quest vertical slice → Art migration 확대**

순서를 추천한다.

---

# 13. Reviewer Decision Summary

Claude Code가 이 문서에서 가장 중요하게 받아들여야 할 내용은 다음 5가지다.

1. **G3 전에 프로젝트 범위를 키우지 말 것.**
2. **지형 대비 결함만 먼저 제거하고 플레이 게이트를 실행할 것.**
3. **G3 통과 후 첫 대형 시스템은 Save/Load로 할 것.**
4. **Quest는 최소 NPC/Dialog와 수직 슬라이스로 연결할 것.**
5. **아트 전면 전환은 기능 구현과 분리하고 대표 샘플부터 검증할 것.**

현재 프로젝트의 실패 위험은 "기능이 너무 적어서"가 아니다.

> **핵심 재미 검증 전에 RPG 기능과 콘텐츠 생산이 폭발하는 것**이 더 큰 위험이다.

따라서 다음 단계의 목표는 기능 수가 아니라:

> **검증 가능한 재미 + 유지되는 진행 + 목적이 있는 플레이**

로 두는 것을 권장한다.
