# 콘텐츠 목록 통합·2장 기본 합류 구현 계획

- 2026-10-02 / Codex. 디렉터 요청1~5를 한 제품 묶음으로 구현한다. 3장 설계는 승인 유지·구현 순서는 이 작업 뒤다.
- 저장 **제품 형식 V6 + content_revision=1**을 새 계약으로 사용한다. 과거 QA 후보 V6/V7은 호환 대상이 아니다. 사용자 V1~V5는 동결된 V5 변환기로 원본 검증 후 이관한다.
- 실행: subagent-driven-development로 콘텐츠/월드, 저장, 검증을 분담하고 주 작업자는 실행기·문서·전체 통합을 담당한다. 현재 작업 폴더의 명시 파일만 수정하며 다른 작업자의 PNG는 제외한다.
- 변경 이력: 3장 구현보다 구조 정리를 우선하도록 범위 교체.

## 인터페이스·소유권

- [x] 콘텐츠/월드: `scripts/content/game_content.gd`(CURRENT_REVISION=1, SCENES/NAMES/BOUNDS/EDGES, 의뢰·NPC·표식 목록), `game_catalog.gd`, `game_navigation.gd`; `scripts/world/product_world.gd`, `game_product.gd`, `scenes/world/product_world.tscn`. 기본 World는 기존 BaseWorld를 직접 상속하고 후보 환경/set_script 월드 교체를 사용하지 않는다. factory `instantiate_world(region)`는 저장경로 메타 `user://saves`를 설정한다. `product_world._create_save_session`는 `scripts/save/product_save.gd`의 Session.new().
- [x] 저장: `scripts/save/product_save.gd`의 Schema/Codec/Store/Session과 별도 conversion. Content/Catalog를 주입하고 format6/content1을 기록한다. 미래 content는 unsupported_content로 백업우회 금지. 후보V6는revision누락으로거부,후보V7은version거부. 세션은 실제saves와 명시 QA경로만 허용한다. 기존 m6_product_test/process/combat 및 product_verify/product_real_copy/product_chapter_preview를 허용한다. 전투/거래/이동 보호와 Journal 선택 carry 유지.
- [x] 검증: `verify_all.ps1`, 기본 제품 API 중간/완료 복원, 실제V4/V5 복사본 이관. 기존 동결 API/이관·실패 가드 실행기를 통합 호출. 사용자 원본은 해시/복사 읽기만,게임실행중변화는검증실패로기록·원복금지. 테스트파일/fixture와 정상플레이증거구분.
- [x] 실행기: `게임 실행.exe` 하나, 기본/2장 준비/3장 준비 진입선택. 준비상태는QA경로고정,3장콘텐츠는아직없음을명시. 기존별도exe는obsolete표기,현재켜진프로세스미종료.
- [x] 문서: DECISIONS 날짜/결정/반영커밋, PROJECT_STATUS 현재표, 이전이력 docs/history, HANDOFF 다음작업/주의만. 리뷰원문은 Claude파일을보존해명시커밋. 1막종료체감표준비.
- [ ] 독립 검토 1회: 전체 검증·내부 검토·로컬 커밋을 완료하고 통합 검토서를 준비했다. Claude 판정은 대기한다. 제품코드변경전체GUT,API이관,실패가드,원본해시검사. -Combat은옵션/채택조건아님.


검증 완료(2026-10-02): verify_all 107/107, GUT 1,162/1,162, 실제 원본 6개 해시 불변. [검증 기록](../../qa/content-integration-evidence.md). 생성기·장 예산 검사는 후속 3장부터 적용하며 이번 범위에 추가하지 않았다.
