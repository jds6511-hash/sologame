# 콘텐츠 목록 통합·2장 기본 합류 구현 계획

- 2026-10-02 / Codex. 디렉터 요청1~5를 한 제품 묶음으로 구현한다. 3장 설계는 승인 유지·구현 순서는 이 작업 뒤다.
- 저장 **제품 형식 V6 + content_revision=1**을 새 계약으로 사용한다. 과거 QA 후보 V6/V7은 호환 대상이 아니다. 사용자 V1~V5는 동결된 V5 변환기로 원본 검증 후 이관한다.
- 실행: subagent-driven-development로 콘텐츠/월드, 저장, 검증을 분담하고 주 작업자는 실행기·문서·전체 통합을 담당한다. 현재 작업 폴더의 명시 파일만 수정하며 다른 작업자의 PNG는 제외한다.
- 변경 이력: 3장 구현보다 구조 정리를 우선하도록 범위 교체.

## 인터페이스·소유권

콘텐츠 개정은 기존 ID의 의미를 보존하는 **추가만** 허용한다. 기존 의뢰의 목표 수·선행·보상 변경이나 지역·ID 삭제는 개정 번호만 올려 처리하지 않고 명시적 저장 변환 또는 형식 버전 변경으로 처리한다. 변경 이력(2026-10-02): `f2348d6` 검토 참고 2 반영. 현재 생성기 정합성 검사가 과거 ID 동결을 자동으로 보장하는 것은 아니다.

- [x] 콘텐츠/월드: `scripts/content/game_content.gd`(CURRENT_REVISION=1, SCENES/NAMES/BOUNDS/EDGES, 의뢰·NPC·표식 목록), `game_catalog.gd`, `game_navigation.gd`; `scripts/world/product_world.gd`, `game_product.gd`, `scenes/world/product_world.tscn`. 기본 World는 기존 BaseWorld를 직접 상속하고 후보 환경/set_script 월드 교체를 사용하지 않는다. factory `instantiate_world(region)`는 저장경로 메타 `user://saves`를 설정한다. `product_world._create_save_session`는 `scripts/save/product_save.gd`의 Session.new().
- [x] 저장: `scripts/save/product_save.gd`의 Schema/Codec/Store/Session과 별도 conversion. Content/Catalog를 주입하고 format6/content1을 기록한다. 미래 content는 unsupported_content로 백업우회 금지. 후보V6는revision누락으로거부,후보V7은version거부. 세션은 실제saves와 명시 QA경로만 허용한다. 기존 m6_product_test/process/combat 및 product_verify/product_real_copy/product_chapter_preview를 허용한다. 전투/거래/이동 보호와 Journal 선택 carry 유지.
- [x] 검증: `verify_all.ps1`, 기본 제품 API 중간/완료 복원, 실제V4/V5 복사본 이관. 기존 동결 API/이관·실패 가드 실행기를 통합 호출. 사용자 원본은 해시/복사 읽기만,게임실행중변화는검증실패로기록·원복금지. 테스트파일/fixture와 정상플레이증거구분.
- [x] 실행기: `게임 실행.exe` 하나, 기본/2장 준비/3장 준비 진입선택. 준비상태는QA경로고정,3장콘텐츠는아직없음을명시. 기존별도exe는obsolete표기,현재켜진프로세스미종료.
- [x] 문서: DECISIONS 날짜/결정/반영커밋, PROJECT_STATUS 현재표, 이전이력 docs/history, HANDOFF 다음작업/주의만. 리뷰원문은 Claude파일을보존해명시커밋. 1막종료체감표준비.
- [ ] 독립 검토 1회: 전체 검증·내부 검토·로컬 커밋을 완료하고 통합 검토서를 준비했다. Claude 판정은 대기한다. 제품코드변경전체GUT,API이관,실패가드,원본해시검사. -Combat은옵션/채택조건아님.


검증 완료(2026-10-02): verify_all 107/107, GUT 1,162/1,162, 실제 원본 6개 해시 불변. [검증 기록](../../qa/content-integration-evidence.md). 생성기·장 예산 검사는 후속 3장부터 적용하며 이번 범위에 추가하지 않았다.

## 5장부터의 콘텐츠 개정별 ID 경계 (2026-10-03)

제품 형식은 영지·여행을 추가한V7을 유지한다. 장 표의 content_revision(기존3/4장은 각각2/3)로 생성기가 QUEST_REVISIONS·REGION_REVISIONS를 만든다. 저장에 적힌 개정보다 뒤에 생긴 의뢰·현재 지역·방문 도시를 넣으면 unsupported_content로 거부한다. 미지 ID는 기존 카탈로그/지역/여행 검사로 거부한다. 한 장을 추가할 때마다 V7 검증기 사본을 만들지 않는다.

V7의 이전 개정 파일은 준비 단계에서 원본 값을 그대로 보존하고, 제품 snapshot을 새로 저장할 때 현재 개정을 기록한다. 기존 필드 구조 검증·의뢰 선행·지역 잠금·공훈 합계는 현재 통합 목록을 쓰며, 기존 ID의 의미/보상 변경은 별도의 호환 검토 사항이다. V1~제품V6의 동결 원본 검증 경로는 유지한다.

변경 이력: 2026-10-03 5장 통합에 개정별 ID 도입 경계를 추가. 저장 형식을 장마다 올리거나 후보 사슬을 재도입하지 않는다.