# M4 단위 2 — 캐릭터 검증·복원

- 날짜: 2026-09-21
- 범위: 저장 콘텐츠 목록, 본문 검증, 새 플레이어 복원, 파일 검증기 연결. 슬롯 UI·자동 저장·전체 G4는 미완료.
- Claude 검토 대상 커밋: `5595fe7` (기준 `8b773e9`).

## 변경 파일과 목적

| 파일 | 역할 |
|---|---|
| scripts/save/save_content_manifest.gd | 명시적 아이템·스킬 리소스 목록 |
| scripts/save/save_content_registry.gd | 고정 ID·문자열 장비 슬롯과 실행 리소스 변환 |
| scripts/save/save_schema.gd | 자료형·범위·직업/스킬·포인트·장비·계정·미완 거래 검증 |
| scripts/save/character_save_codec.gd | 계정 생성, 캐릭터 스냅샷, 새 플레이어에 보상 없는 복원 |
| scripts/save/save_file_store.gd | pending_transfer는 백업 폴백/덮어쓰기 없이 거부 |
| scripts/progression/player_job_transition.gd | 보상 없는 직업·로드아웃 복원 API |
| scripts/progression/player_skill_points.gd | 강화·실제 지출 장부 직접 복원 API |
| scripts/world/game_clock.gd | 날짜·경과 시각 복원 후 낮/밤 재계산 |
| test/save/test_character_save_codec.gd | 실제 player.tscn을 사용한 11개 테스트 |

위 경로는 godot/ 기준이다. 계약·실행 계획·PROJECT_STATUS·HANDOFF도 현 상태로 갱신한다.

## 검증 결과

- 최초 codec 미구현 상태에서 테스트 로드 실패를 확인한 뒤 구현했다.
- codec 11/11 포함 **전체 GUT 929/929, 3148 assertions**, 101 scripts.
- 변경 GDScript 11개 형식·린트 통과.
- 모험가·전사·궁수·검투사 복원, 레벨업 시그널 미발신, 강화/장비/반지 2칸 유지, 다른 계정 거부, 비정상 데이터의 대상 무변경, 밤 시각 복원, JSON 반복 라운드트립, 재저장 시간 갱신 검사.
- 실제 파일 검증기를 연결해 미완 거래가 정상 백업으로 우회하거나 새 저장으로 사라지지 않는지 검사.
- 전체 테스트 종료 시 객체 4개/리소스 2개 잔존 경고는 이전 기준선과 같은 수로 재현됐다. 테스트 성공과 별개이며 원인 해소를 주장하지 않는다. 저장 실패 주입 테스트의 의도적 디렉터리 오류는 GUT 기대 오류로 처리한다.

```powershell
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
```

## 후속 통합 및 검토 항목

- 현재 데이터 API만 연결했고 실제 월드 저장 메뉴는 없다. 단위 3에서 안전 상태·튜토리얼/플레이 시간·활성 슬롯·월드 교체·별도 프로세스 복원을 검증한다.
- 포인트 지급을 건너뛴 디버그 직업 직행은 정식 캐릭터 예산과 달라 거부한다.
- 테스트 준비 중 Lv40까지 모험가로 올린 뒤 뒤늦게 전직하면 현재 HP가 재계산된 최대 HP보다 클 수 있음을 관찰했다. 정상 Lv10 전직 경로는 통과한다. codec은 최대 HP 초과를 거부하며 값을 몰래 낮추지 않는다. 실제 메뉴 연결 전에 이 전직 상태 정규화 정책과 회귀 검사를 처리해야 한다.
- Claude 검토 범위: 저장 키 안정성, 값/자료형 검증, 스킬 예산, 미완 거래 차단, 계정 격리, 보상 없는 복원. 실제 콘텐츠 미구현 영역을 완료로 판단하지 않는다.
