# PROJECT_STATUS — 프로젝트 진행 현황

- **최종 수정일**: 2026-07-15
- **담당**: producer
- **의존 문서**:
  - `docs\design\GAME_CONCEPT.md` (초기 기획안)
  - `docs\design\M1_QUESTIONS.md` (M1 기획 질문 목록)
  - `docs\superpowers\specs\2026-07-15-agent-team-design.md` (스튜디오 설계 스펙, 마일스톤 정의)
  - `docs\superpowers\plans\2026-07-15-m0-studio-setup.md` (M0 구현 계획)
- **변경 이력**:
  - 2026-07-15: 최초 작성 (M0 완료 직전 시점 초안)

---

## 1. 현재 마일스톤과 상태

### M0 — 스튜디오 구축: **완료 직전 (동작 검증 중)**

| 완료 조건 (스펙 기준) | 상태 |
|---|---|
| Godot 실행 파일 CLI 구동 | 완료 — Godot **4.7.1** 설치·버전 고정 |
| `.claude\agents\`에 에이전트 18명 정의 | 완료 |
| 폴더 구조 + CLAUDE.md 생성 | 완료 |
| 도구 설치 (gdtoolkit 4.x, Pillow, numpy, GUT) | 완료 |
| git 원격 저장소 연결·푸시 | 진행 중 (검증 완료 후 최종 푸시) |
| 에이전트 호출 테스트 (producer의 본 문서 작성 포함) | 진행 중 |
| 문서 인수인계 E2E 테스트 (기획→개발 참조) | 진행 중 |
| **디렉터 승인** | **대기** — 모든 마일스톤 완료 조건에는 디렉터 승인이 포함된다 |

### 다음 마일스톤: M1 — 기획 기반

GDD(세계관, 직업/전투/경제 시스템 상세 설계)와 아트 스타일 가이드를 작성하는 단계.
`docs\design\M1_QUESTIONS.md`의 질문들에 대해 담당 기획 에이전트가 안을 만들고 디렉터 승인을 받는다.

---

## 2. 백로그 (우선순위별)

### P0 — 최우선 (다른 모든 시스템의 전제)

| # | 항목 | 담당 | 비고 |
|---|---|---|---|
| 1 | **전투 방식 결정 (실시간 액션 vs 턴제)** | systems-designer | 양쪽 안을 제시하고 **디렉터가 결정**. 직업/밸런스/레벨/AI 등 모든 후속 기획의 전제이므로 M1에서 가장 먼저 처리 |

### P1 — 핵심 시스템 기획 (전투 방식 확정 후 착수)

| # | 항목 | 담당 | 비고 |
|---|---|---|---|
| 2 | 세계관 상세 (종족 관계, 톤, 마법 체계, 왕국 구조) | narrative-designer | M1_QUESTIONS §1 |
| 3 | 스토리 반전 설계 | narrative-designer | `spoilers\`에만 기록, 보고에 내용 언급 금지 |
| 4 | 직업 시스템 (레벨 구간, 직업 10개 목록, 히든 2개 해금, 전직 트리) | systems-designer | M1_QUESTIONS §2 |
| 5 | 명성·계급·영지 시스템 정의 | systems-designer + economy-designer | M1_QUESTIONS §4. "계급 사회"와 "명성" 수치의 관계 정의 포함 (아래 정합성 이슈 참조) |
| 6 | 아이템·경제 기획 (강화/제작, 내구도, 세트 여부) | economy-designer | M1_QUESTIONS §5 |
| 7 | 아트 스타일 가이드 (해상도 기준, 팔레트) | art-director | M1 산출물 |

### P2 — 부속 시스템·콘텐츠 기획

| # | 항목 | 담당 | 비고 |
|---|---|---|---|
| 8 | 퀘스트 유형·분기 설계 | quest-designer | M1_QUESTIONS §3, 분기는 narrative-designer와 협의 |
| 9 | 수집 콘텐츠 (펫, 칭호 100개, 도감 보상) | systems-designer | M1_QUESTIONS §6 |
| 10 | 시간·이벤트 (낮/밤 영향, 계절, 왕국 이벤트 목록) | systems-designer | M1_QUESTIONS §7 |
| 11 | 기본 기능 UX (인벤토리/맵/저널, 커스터마이징, 튜토리얼, 옵션) | ux-designer + systems-dev | M1_QUESTIONS §8 |
| 12 | 200시간 콘텐츠 배분안 | producer | M1_QUESTIONS §9 |

---

## 3. 완료 항목

- Godot 4.7.1 설치 및 CLI 구동 확인, 버전 고정
- 개발 도구 설치: gdtoolkit 4.x (gdformat/gdlint), Pillow, numpy, GUT
- 폴더 구조 생성 (`docs\design\spoilers\`, `docs\art\`, `docs\qa\`, `godot\` 등) 및 CLAUDE.md 작성
- 에이전트 18명 정의 (`.claude\agents\*.md`) — 기획 5, 개발 4, 디자인 5, 사운드 1, QA 2, 관리 1
- 기획 입력 문서 확보: `GAME_CONCEPT.md`(초기 기획안), `M1_QUESTIONS.md`(M1 질문 목록)

---

## 4. 정합성 이슈

현재 기획 문서는 `GAME_CONCEPT.md`와 `M1_QUESTIONS.md` 2건뿐이며, 교차 검토 결과 **모순은 발견되지 않았다.** 단, M1에서 어긋나기 쉬운 감시 항목을 미리 기록한다.

| # | 유형 | 내용 | 상태 |
|---|---|---|---|
| W-1 | 용어 충돌 예방 | "계급 사회"(세계관 용어)와 "명성"(수치 시스템)의 관계가 미정의. 같은 개념인지 별개인지 M1에서 확정하지 않으면 narrative/systems 문서 간 용어 충돌이 발생할 수 있음 | 감시 중 — 백로그 #5에서 해소 예정 |
| W-2 | 전제 의존성 | 전투 방식(백로그 #1)이 미결인 상태에서 직업/밸런스/펫 전투 참여 등 후속 기획을 진행하면 전면 재작업 위험 | 감시 중 — P0 완료 전 P1 착수 금지 권고 |

---

## 5. 디렉터 결정 대기

| # | 항목 | 필요 시점 |
|---|---|---|
| 1 | **M0 완료 승인** — 동작 검증 결과 확인 후 M1 진입 승인 | 즉시 (검증 완료 시) |
| 2 | **전투 방식 결정 (실시간 액션 vs 턴제)** — systems-designer가 양쪽 안 제시 예정 | M1 최우선 |
