# 3장 방어전·향사 구현 계획

- 2026-10-02 / Codex. 승인 설계 [3장](m7-chapter-three-defense.md), 검토 [04bc4e0](../../qa/reviews/04bc4e0.md), [디렉터 결정](../../DECISIONS.md).
- subagent-driven-development로 콘텐츠 생성/검사, 방어 런타임, 월드/UI를 분담하고 주 작업자가 저장·통합 검증을 맡는다. 기존 작업 폴더에서 명시 소유 파일만 수정한다.
- 목표: 급보→대피→두 방어 무리→정예와 그림자 목격→심사→향사와 복구권, 기준 서브3건을 제품에 연결한다. 4장·영지 경영·추가 서브·새 아트는 제외한다.
- 변경 이력: 구조 통합 완료 후 폐기된 V8 후보 계획을 제품 V6/콘텐츠 개정2와 생성 방식으로 갱신.

## 구조·작업

- [ ] 콘텐츠 생성: 장별 JSON 표에서 의뢰8건, 표식, NPC, 방어 스폰 정의를 생성한다. 기존 통합 목록에 개정2로 합친다. 이후 장 추가는 같은 생성 경로를 사용한다. Python 검사로 현행 보고 EXP/골드/공훈 합계, 선행 사슬, source/표식 존재와 생성 결정성을 확인한다.
- [ ] 방어 런타임: 현재 Journal 목표만 명시적 F 재개로 시작한다. 생성 수=max(0,목표수-count-동일source생존수), 동시최대3, 다음 무리는 재개 입력 필요. 기존 MonsterSpawner 자식으로 등록해 저장 안전·처치/드롭/EXP 경로를 유지한다. 사망·부분완료·재진입·연타·다른source 테스트를 먼저 추가한다.
- [ ] 공통 월드/UI: 새 지역은 통합 layout 데이터로 만들고 별도 월드/카탈로그/세션을 추가하지 않는다. 현장 왕복, 조사와 그림자 목격, 심사와 하사 파생 표시를 기존 UI에 연결한다. 3장 시작 버튼은 기존 준비 상태를 사용한다.
- [ ] 저장: 제품 형식6 유지, content_revision2. 개정1 로드 시 새 의뢰는 미수락, 현재개정으로 캡처. 현장 잠금/공훈/예약필드 검증, 미래개정 거부를 확장한다. 실제 저장은 전후 해시·QA복사본만 사용한다.
- [ ] 검증: 전체GUT, generator --check와 음성 검사, API중간/완료/재방문/메인만하사 복원, 렌더, verify_all 통합. 전투 조작은 선택 증거이며 채택 관문으로 만들지 않는다. 실제EXP 부족과Lv도달을 산출해 보고한다.
- [ ] 독립 검토 파일 확인→원문/중간이상 우선반영→통합 요청서1회. 다음 승인 작업을 진행하되 1막 종료 체감 판단 전 2막은 시작하지 않는다.

## 파일 경계·인터페이스

콘텐츠 담당: data/content/*.json, data/quests/chapter_three/*.tres, scripts/content/game_content.gd 및 생성 산출물, tools/generate_chapter_content.py, docs/qa/tools/test_chapter_content.py. 방어 정의는 Content.DEFENSE_WAVES[source] Dictionary (quest_id,index,region,points,scene,content_id,stats)와 Content.RALLIES[id] (region,position,title), Content.SITE_NOTICES[id] 공개문구로 제공한다.

런타임 담당: scripts/content/defense_spawner.gd, defense_rally.gd, test/world/test_defense_spawner.gd. Spawner.start(world), resume()->bool. Rally.setup(player,controller,dialog,hud) 기본NPC계약+configure(manager), npc_id=defense_rally. 정본은 저널이며 별도 저장 필드를 만들지 않는다.

월드/UI 담당: product_world.gd, game_layout.gd, game_catalog.gd, game_navigation.gd, game_site.gd, character_tab.gd와 해당 테스트. 루트 담당과 공유 파일 편집을 조정한다. 주 작업자는 product_conversion.gd/save.gd, 검증 실행기·API·문서.

임시 좌표: 여울목 현장 관문(200,392), 귀환(152,440); 현장 출구(128,544), 도착(192,544); 책임자(288,512), 재개(416,480). 현장 1024×640. 표식·스폰은 안전 집결지에서 북쪽으로 배치하며 모든 실제 좌표는 물리검사로 확정한다.