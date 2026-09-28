# M5 여울목 장 마무리 — 통합 구현 검토 요청

- 날짜: 2026-09-28
- 담당: Codex 구현·통합 / Claude 독립 검토
- 기준: `91a9999` (직전 저널 구현 `bf50f49`)
- 구현 커밋: `a1217d4` — 44파일,887줄 추가/107줄 삭제. 다른 작업자의 추적 PNG9개·설정·기존 미추적 로그는 제외했다.
- 설계: [진행 구간 계약](../design/systems/m5-chapter-one-transition.md), [저장 계약](../design/systems/save-load.md)

## 한 번에 검토할 진행 구간

MQ04 보고 → 접수원에게 MQ05 명시 수락 → 여울목 관문지기 도달·배웅 → 보고 버튼으로 EXP1800/골드560/공훈100 수령 → 별도 노베라 입구 월드 → 여울목 귀환 → 저장·재실행 복원.

기존 저널을 확장하고 보상을 새 지역·공훈·저장에 연결했다. 입구는 기존 타일·NPC 임시 외형을 재사용하는 통행 구역이며 도시 전체나2장 의뢰를 완료했다고 주장하지 않는다. 노베라 기존 BGM을 연결하고 여울목 전용 튜토리얼을 입구에서 재시작하지 않는다. 지역 이동에 추가 보상은 없다.

## 직전 리뷰 처리

| 지적 | 처리 |
|---|---|
| 숨겨진 저널 재생성 | 서브 확장 시 최적화로 이월. 현재5건이며 표시 모델의 즉시 질의 계약을 변경하지 않음 |
| 렌더가 추적 PNG 덮어씀 | 저널과 신규 probe 모두 ignored `docs/qa/screenshots/`에 출력. 기존 추적9개는 수정/추적 해제/커밋에서 제외 |
| 배경 HUD 겹침 | 메뉴 배경 alpha1, 상위 SaveMenu 배지는 메뉴 열림 동안 숨김.1920×1080 렌더 확인 |
| active 필터 명칭 | active/ready 포함 의미에 맞춰 ‘미완료’로 변경 |

## 저장·실패 경계

- 계정V1 유지. 캐릭터V4 출력·V1~V4 읽기. V1/V2 Legacy 검증 후 C1 EXP 비율 변환, V3 C1 EXP 불변. V4 재검증 전 적용 금지.
- V1~V3는 기존 맵·공훈0·MQ05 부재 계약을 유지한다. V4는 완료 의뢰 합계와 공훈을 대조하고 MQ05 미완료의 노베라 저장을 거부한다. story_flags/territory 예약은 유지한다.
- 기존 CandidateCodec3 하위 클래스는 역사 V3 변환을 계속 사용한다. 현재 파일 테스트만 기대 버전을4로 갱신하고 구V1/V2/V3 fixture·구REQ 상수는 유지했다.
- 이동은 캐릭터 파일을 쓰지 않는다. 첫 저장 전 출발만 계정 연결을 확보하기 위해 계정 파일을 생성한다. 캐릭터ID/슬롯/시간/진행/구버전 자동 저장 보류를 새 세션으로 넘긴다.
- 보상 보고는1회이며 이동 실패가 이미 지급한 보상을 취소/재지급하지 않는다. 재대화로 이동 재시도 가능. 관문40px·사망/보스/최근 전투/행동을 검사한다. 수동·자동 저장의160px 적 반경은 그대로이며 이동에는 이 고정 반경을 적용하지 않는다.
- 월드 교체는 기존 실패 시 기존 월드·pause 복원 경로를 사용한다. 새 지역 부팅 실패를 별도 주입하지는 않았다.

## 변경 파일과 목적

| 파일 (godot/ 기준, 별도 표기 제외) | 목적 |
|---|---|
| `data/quests/mq_01_05.tres` | 수락/배웅·보상 정의 |
| `scripts/npc/npc_registry.gd` | 관문지기2종 안정ID·이름 |
| `scripts/quests/quest_data.gd`, `quest_catalog.gd` | 수락 NPC/공훈 필드·검증·MQ05 등록 |
| `scripts/quests/quest_journal.gd`, `quest_journal_view.gd`, `quest_presentation.gd` | 공훈 합계·보고 NPC·배웅 후 왕복 안내 |
| `scripts/ui/quest_dialog.gd`, `quest_tracker.gd` | 보고→이동·실패 재시도·지역별 안내 |
| `scripts/ui/integrated_menu.gd`, `quest_journal_tab.gd` | 불투명 배경·필터 문구 |
| `scripts/world/region_registry.gd`, `novera_gate_layout.gd`, `eastern_frontier_starting_area.gd`, `scenes/world/novera_gate.tscn` | 별도 지역·도착점·관문 배선·기존 스포너 시작 전 마커 제거 |
| `data/audio/bgm_tracks.json` | 기존 노베라 곡 연결 |
| `scripts/save/character_save_codec.gd`, `character_save_migrations.gd`, `save_schema.gd`, `save_file_store.gd`, `save_progression_rules.gd`, `save_session.gd` | V4 호환·지역 부팅·세션 이동·파일 보호 |
| `test/quests/test_chapter_departure.gd`, `chapter_departure_process_probe.gd` | 새 계약6건·왕복/재실행/구버전 보류/미저장 출발 |
| `test/quests/test_third_quest.gd`, `fourth_quest_process_probe.gd` | 구 카탈로그 fixture 격리·현재 버전 기대값 |
| `test/save/test_c1_product_rollout.gd`, `test_c1_save_integration.gd`, `test_c1_save_migration.gd`, `test_m5_compatibility.gd`, `test_save_file_store.gd`, `test_save_progression_rules.gd`, `test_save_session.gd`, `c1_session_process_probe.gd` | 현행V4/미래V5 분리, 역사V3 후보 경로 유지 |
| `docs/qa/tools/m5_journal_render_probe.gd` | 임시 출력 경로 |
| `docs/design/systems/m5-chapter-one-transition.md`, `save-load.md`; `docs/design/quests/early-leveling-route.md`, `quest-structure.md`; `docs/design/DEVELOPMENT_ROADMAP.md`, `docs/PROJECT_STATUS.md`, `docs/HANDOFF.md`; 직전/현재 검토 요청 | 설계·현행 상태·리뷰 경계 동기화 |

## 실행 결과

| 검사 | 결과 |
|---|---|
| 최초 신규 계약 | 미구현4/4 실패 후 구현으로4/4·27 asserts 통과. 이후 차단·멱등 검사2건 추가 |
| 첫 전체 회귀 |1057 중35실패. 대부분 현재 버전3 기대값/구 카탈로그 fixture였으며 이를35개 제품 결함으로 주장하지 않는다. CandidateCodec3 호환 분기도 보완 |
| 전체 GUT |1059/1059·117 scripts·9096 asserts(관측값)·exit0·SCRIPT ERROR0·종료 잔존 경고0 |
| GD 형식/린트 | 변경32파일 통과 |
| 신규 프로세스 | cleanup→unsaved→cleanup→legacy→cleanup→seed→depart→verify→return→cleanup,10/10 PASS·exit0·SCRIPT ERROR0 |
| MQ04 회귀 | cleanup→seed→active→reach→ready→completed→completed→cleanup,8/8 PASS·exit0·SCRIPT ERROR0 |
| C1 회귀 | cleanup→seed→hold→hold→save→verify→cleanup,7/7 PASS·exit0·SCRIPT ERROR0 |
| 렌더 | 신규 cleanup→seed→depart→return→cleanup 5/5 PASS. 보고·도착·귀환 PNG 생성, 저널3화면 및 J/검색/Esc 입력 PASS |

프로세스 seed는 선행4의뢰 완료 상태를 주입한다. 관문 접근 좌표를 직접 설정하고 NPC 거리/시야선 검사·대화 선택 API를 호출한다. 실제 도보로 MQ01부터 완주한 시험이 아니다. 별도 프로세스 verify는 목적지·위치·골드560·공훈100·재지급 거부를 확인한다. 다른 슬롯은SHA-256 불변, 귀환은 캐릭터ID/player/inventory/progress snapshot 일치를 확인한다. 신규 장비 장착·강화 조작을 한 시험은 아니며 기존4직업/8장비 자동 검증과 구분한다.

프로세스 종료 잔존 경고는 별도 제한이다. 이번 headless 관측은 unsaved ObjectDB10/resources4, seed4/2, verify8/4이며 legacy/depart/return에는 해당 로그가 없었다. 기존과 같은 종류지만 새 이동 경로의 수치까지 과거 원인으로 확정하지 않는다. GUT의 의도적 경로 생성 실패 로그와 SCRIPT ERROR를 구분한다. 실제 처치 체감·도보 동선·첫5의뢰 총 레벨업 시간·G4/G5는 미판정이다. 질주 힌트 저장도 이번에 추가하지 않았다.

## 재현

저장소 루트에서 `$godot`은 Godot4.7.1 콘솔 실행 파일이다. 로그는 명령마다 `$LASTEXITCODE`와 SCRIPT ERROR를 함께 검사한다.

```powershell
& $godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
foreach ($phase in @('cleanup','unsaved','cleanup','legacy','cleanup','seed','depart','verify','return','cleanup')) {
  & $godot --headless --path godot -s res://test/quests/chapter_departure_process_probe.gd -- $phase
}
# 렌더: 위 probe를 headless 없이 seed/depart/return 순서로 실행하고 phase 뒤 render 추가.
& $godot --path godot --resolution 1920x1080 -s ../docs/qa/tools/m5_journal_render_probe.gd
```

## Claude 확인 요청

1. V1~V3 원본 의미가 새 맵/공훈으로 확장되지 않는가. V3→V4가 C1 EXP를 다시 축소하지 않는가.
2. 수락자≠보고자, 보고1회·이동 재시도·왕복이 추가 보상을 만들지 않는가.
3. 첫 저장 전 이동과 이전 버전 이동에서 ID·자동 저장 보류가 유지되는가.
4. 목표 지역 씬/복원 실패·새 캐릭터/다른 슬롯·스포너 시작 순서에서 회귀가 없는가.
5. 검증 범위를 실제 조작/도시 전체/M5 완료로 과장한 부분이 없는가.
