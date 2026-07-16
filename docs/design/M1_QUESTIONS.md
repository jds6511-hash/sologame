# M1 기획 질문 목록

- **최종 수정일**: 2026-07-16
- **담당**: producer
- **의존 문서**: 각 항목별 근거 문서(본문에 개별 병기)
- 작성일: 2026-07-15
- 출처: 외부 검토 의견에서 추출. M1(기획 기반) 단계에서 각 담당 에이전트가 안을 만들어 디렉터 승인을 받는다.
- 확정된 전제: 싱글플레이 전용, PC(Windows), 배포 없음 — 멀티/PvP/서버/경매장/수익 모델 질문은 제외했다.
- **변경 이력**:
  - 2026-07-15: 최초 작성
  - 2026-07-16: **M1 클로징 — 이슈 C-16 처리(producer)**. 전 항목을 실제 답변 여부로 재검증해 체크박스를 갱신하고, 답변된 항목마다 근거 문서를 병기했다. 미답변 2건(캐릭터 커스터마이징 여부, 튜토리얼/온보딩)은 체크하지 않고 문서 내 표기 + PROJECT_STATUS 결과 보고로 별도 취합했다.
  - 2026-07-16: **M1 최종 승인(G-2) 반영** — 8절 "캐릭터 커스터마이징 여부"가 `GAME_CONCEPT.md` G-2 승인 기록(미도입 확정)으로 해소되어 체크. "튜토리얼/온보딩"은 여전히 미답변이나 M2에서 정식 설계 태스크로 배정됨을 병기(`M2_PLAN.md` 참조)

## 0. 최우선 결정 (다른 모든 시스템의 전제)

- [x] **전투 방식**: 실시간 액션 vs 턴제 — 담당: systems-designer가 양쪽 안 제시, 디렉터 결정 → `systems\combat-options.md` 9장 결정 기록 (A안 실시간 액션 확정)

## 1. 세계관 — narrative-designer

- [x] 3종족(인간/엘프/드워프) 간 관계 — 대립 구도, 계급과 종족의 연동 여부 → `worldview.md` 4.2~4.3
- [x] 세계관 톤(밝은 판타지 vs 다크 판타지), 시대적 배경 → `worldview.md` 2.1~2.2 (밝음6:어둠4 확정)
- [x] 마법 체계가 로어 차원에서 존재하는지 (원리/제약) → `worldview.md` 7.1~7.3
- [x] 왕국이 하나인지 여러 개인지, 국가 간 정치/전쟁 요소 → `worldview.md` 3.1(단일 왕국 확정)·3.3(내부 정치 구도)
- [x] 스토리 반전 설계 (spoilers\에만 기록) → `spoilers\twist.md` (내용은 스포일러 격리 — 본 문서·보고에 기재하지 않음)

## 2. 직업 시스템 — systems-designer

- [x] 최대 레벨과 전직 단계별 레벨 구간 (예: 모험가 1~10, 1차 11~40, …) → `systems\jobs.md` 전제 표기 + 2장 (만렙 100·전직 Lv10/40/80 확정)
- [x] 직업 10개 목록과 히든 직업 2개의 해금 조건 → `systems\jobs.md` 2장(목록)·4장(히든 해금 조건)
- [x] 전직 초기화(되돌리기) 가능 여부 → `systems\jobs.md` 7장 (재서임 정책 확정)
- [x] 직업별 무기/장비 제한 → `systems\jobs.md` 5-1
- [x] 역할군(탱커/딜러/힐러) 구분 여부 — 싱글플레이이므로 동료 NPC/펫 편성과 연동해 검토 → `systems\jobs.md` 1장 (역할군 분포·순수 서포터 미도입) + `systems\combat.md` 5-4 (회복은 공통 규칙으로 보장, 전 직업 솔로 클리어)

## 3. 퀘스트 — quest-designer

- [x] 퀘스트 유형 다양성 (토벌/채집/호위/탐사/제작 등) → `quests\quest-structure.md` 2-1(목표 프리미티브 9종)·2-2(유형 분류·비중)
- [x] 반복 퀘스트(일일/주간) 존재 여부 → `quests\quest-structure.md` 4장 (게임 내 시간 기준 반복 퀘스트 정책)
- [x] 선택지 분기 — 플레이어 선택이 결말/반전에 영향을 주는지 (narrative-designer와 협의) → `quests\quest-structure.md` 2-3(CHOICE 프리미티브)·5-1(엘프 서사 라인 화해/방관 사례). **잔여**: 종족 라인 CHOICE가 결말에 주는 영향의 정확한 범위는 narrative-designer와 공동 설계 예정(`worldview.md` 9장 5번, 비차단·미결)

## 4. 명성·영지 — systems-designer + economy-designer

- [x] "계급 사회"(세계관)와 "명성"(수치) 시스템의 관계 정의 — 같은 것인지 별개인지 → `worldview.md` 5.3(명성 = 공훈부 수치) + `systems\reputation-territory.md` 1-1(정의와 원칙)
- [x] 도시 하사 이후의 엔드콘텐츠 (영지 확장 등) → `systems\reputation-territory.md` 5-4(왕국의 기둥 특권, 만렙 후) + `systems\collection.md` 6장(만렙 후 50시간 배분)
- [x] 영지 관리 콘텐츠 구체화 (건설/세금/치안/몬스터 침공 방어 등) → `systems\reputation-territory.md` 3장 (3-1 설계 원칙 ~ 3-5 특산품 주문)
- [x] 명성 하락 요소 (범죄, 퀘스트 실패 등) → `systems\reputation-territory.md` 1-4 (미도입 확정)

## 5. 아이템 — economy-designer

- [x] 강화/제작 시스템 존재 여부 → `economy\economy-foundation.md` 11장 (결정 기록 — 완전 제외 확정)
- [x] 내구도 시스템 → `economy\economy-foundation.md` 11장 (완전 제외 확정)
- [x] 세트 아이템 개념 → `economy\economy-foundation.md` 11장 (완전 제외 확정)

## 6. 수집 콘텐츠 — systems-designer

- [x] 펫 획득 방식(포획/부화/구매)과 전투 참여 여부 → `systems\collection.md` 2-1(획득 방식 혼합안)·2-2(역할과 전투 기여)
- [x] 칭호 100개 — 스탯 효과 vs 순수 장식 → `systems\collection.md` 3-1(총량 구조) + `systems\growth.md` 7장(칭호 스탯 예산)
- [x] 도감 완성 보상(업적) 존재 여부 → `systems\collection.md` 4-4 (완성 보상 업적 구조)

## 7. 시간·이벤트 — systems-designer

- [x] 낮/밤이 NPC 스케줄, 몬스터 출현, 상점 운영에 영향을 주는지 → `systems\reputation-territory.md` 4장 (게임 내 시간 규칙) + `systems\combat.md` 2-3 (주야간 전투 규칙)
- [x] 게임 내 1년 길이, 계절 시스템 존재 여부 → `systems\reputation-territory.md` 4장 (게임 내 시간 규칙 확정)
- [x] 왕국 이벤트 종류 목록 (플레이 중에만 진행되는 싱글 콘텐츠로 확정됨) → `systems\reputation-territory.md` 5-2 (이벤트 유형 목록 10종)

## 8. 기본 기능 — ux-designer + systems-dev

- [x] UI/UX 목록: 인벤토리, 맵/미니맵, 퀘스트 저널 → `art\ux\ux-foundation.md` 3장 (화면 목록 전체 16종)
- [x] 캐릭터 커스터마이징 여부 → **미도입 확정** (`GAME_CONCEPT.md` 변경 이력 2026-07-16 — 고정 외형, 외형 변화는 장비 교체로 표현. G-2 승인과 함께 해소)
- [ ] 튜토리얼/온보딩 → **미답변** (world-structure·quest-structure에 "튜토리얼 겸용" 배치 언급만 있고 온보딩 설계 자체는 없음). M2에서 첫 10분 경험으로 설계 착수 — `M2_PLAN.md` 2-4절 UI-3 태스크(ux-designer+quest-designer) 배정, 체크는 설계 완료 시
- [x] 옵션 (사운드, 접근성 등) → `art\ux\ux-foundation.md` 6장 (접근성 체크리스트 M1 확정분) + `art\audio-direction.md`

## 9. 콘텐츠 배분 — producer

- [x] 200시간 목표의 대략적 배분 (메인퀘스트 vs 서브퀘스트 vs 파밍/수집 비중) → **250시간으로 상향 확정** 후 `PROJECT_STATUS.md` 6장(종합) + `quests\quest-structure.md` 9장 + `systems\growth.md` 5-3 + `systems\collection.md` 6장
