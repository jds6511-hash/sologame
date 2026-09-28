# 여울목 장 통합 리뷰 대응

- 날짜: 2026-09-28
- 담당: Codex
- 검토 대상: `a1217d4`, 인계 `aa3c580` — Claude 통과
- 변경 이력: 2026-09-28 테스트 판별력·V2 이동·구버전 안내·지역 경계 회귀 보완

통과한 구현의 재승인을 요구하지 않는다. 다음 전달물은 [M6 경제·장비 통합 설계](m6-economy-equipment-review-request.md)다.

| 리뷰 항목 | 코드 대조와 처리 |
|---|---|
| V3 EXP0 검사 | Lv20/EXP20,000으로 변경. 제안한 두 줄 외에 스킬 포인트19도 지정해야 저장 스키마가 유효함. 원본 불변·변환 결과 전체 player 동일 검사 유지 |
| V2 이동 미검증 | `legacy2` 추가. V2 Lv20/EXP50,000→V4 EXP20,000→MQ05 보상 후21,800→이동·저장·재로드. 원본 해시/자동 저장 보류/ID 검사 유지 |
| 공훈 파생값 제약 | 저장 계약에 V4의 비의뢰 공훈 미지원·추가 시 후속 버전/공급 장부 필요를 명시 |
| 이동 뒤 수동 저장 안내 누락 | carry 적용 후 메시지 판정. 수정 전 legacy2가 `migration notice after travel`만 실패함을 확인하고 수정 후 통과 |
| 목적지 문자열 | QuestDialog에서 Regions.START/NEXT 사용 |
| 맵 크기 중복 | 두 런타임 TileMap의 실제 시작/끝 경계와 Regions.contains 대조 검사 추가. 크기 상수는 유지하며 생성기/레이아웃 변경 때 회귀에서 드러나게 함 |

검증: 전체 GUT **1060/1060·117 scripts·9102 asserts**(이번 관측)·exit0·SCRIPT ERROR0·종료 잔존 로그0. 변경GD4파일 형식/린트 통과. 출발 probe `cleanup→unsaved→cleanup→legacy→cleanup→legacy2→cleanup→seed→depart→verify→return→cleanup` **12/12 PASS**, 각exit0·SCRIPT ERROR0. legacy2 종료 ObjectDB10/resources4 경고는 별도 제한이며 저장 실패로 해석하지 않는다. 이번에는 MQ04/C1 별도 probe·렌더를 재실행하지 않았다(직전 구현에서 검증됨).

변경 코드: `save_session.gd` 안내 순서, `quest_dialog.gd` 상수 참조, `test_chapter_departure.gd` 경계/EXP 검사, `chapter_departure_process_probe.gd` V2 경로. 직접 도보/처치 체감·장비 조작·새 지역 부팅 실패 주입·G4/G5는 미판정 유지. V1 출발은 별도 프로세스로 추가하지 않았으며 V2/V3 이동과 구V1 변환 단위 검사를 구분한다.
