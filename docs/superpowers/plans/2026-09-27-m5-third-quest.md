# M5 MQ-01-03 구현 계획

기준 `061bc02`. [설계](../../design/systems/m5-third-quest.md)는 Claude `bfb4f85` 리뷰에서 착수 가능. Codex 직접 구현·통합, Claude 독립 검토. 기존 스크린샷 3개 제외. 새 승인을 기다리지 않고 승인된 범위에서 진행하라는 사용자 지시를 적용한다.

## 작업 단위

- [x] 1. 데이터/선택: `mq_01_03.tres`, 기존 01/02 표시 필드, QuestData/QuestCatalog 및 순수 `quest_presentation.gd`. 명시적 순서·active/ready 우선·선행/NPC 제한·표시 부작용 없음 테스트를 먼저 실패시킨다.
- [x] 2. 실행 연결: QuestDialog의 `choose(action, quest_id)`와 Tracker가 같은 선택기를 사용. 표시되지 않은 액션은 거부하고 기존 테스트/렌더 호출도 새 API로 옮긴다. MonsterSpawner에 들개 content/source 메타를 발신 전에 설정하고 시작 지역 출처만 배선. 토끼 경로·스폰 수/AI 불변.
- [x] 3. 회귀: 실제 died/재스폰 배선·보상 490/150·기존 의뢰 흐름·구 Catalog quest_fields→invalid_data 및 원문 보존·03 상태 복원. 기존 7단계 probe 유지하고 03은 별도 프로세스 단계로 추가한다.
- [x] 4. 전체 GUT, 변경 GD 형식/린트, 별도 프로세스, 렌더 확인. 보고서·Claude 구현 검토 요청·현황을 작성하고 정확한 파일만 커밋/푸시.

구현 `72cb569`: GUT 1001/1001·3671 assertions·109 scripts, GD 13파일 형식/린트, 프로세스 11단계, 렌더 PASS/runtime 40/40. [구현 검토 요청](../../qa/m5-third-quest-review-request.md). 실제 관통 플레이와 G4/G5는 미완료다.

공통 선택기는 대화/Tracker 표시만 소유한다. 보고 검증·지급은 기존 Controller, 상태는 Journal, 저장은 SaveSession에 남긴다. 표시는 Resource에 문구를 두고 수치 보상은 데이터에서 생성한다. 실제 입력/G4/G5는 미완료 유지.

검증 명령: `godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test/quests -gexit`, 전체는 `-gdir=res://test -ginclude_subdirs`. Windows GUI 실행 파일은 Start-Process -Wait로 종료와 stderr를 검사한다.
