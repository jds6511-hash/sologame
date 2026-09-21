# M4 단위 3 — 슬롯 화면·자동 저장·월드 연결

- 날짜: 2026-09-21
- 기준 커밋: `56d30b1`. Claude 검토 대상 구현 커밋: **`bc06619`**.
- 담당: Codex 구현·통합, Claude 독립 검토 대기.
- 범위: 시작 지역에 저장 기능 연결. 게임플레이 수치·직업·아트·project.godot은 변경하지 않았다. G4 디렉터 승인은 미완료다.

## 변경 파일

godot/ 기준:

| 파일 | 목적 |
|---|---|
| scripts/save/save_session.gd | 계정/활성 슬롯, 플레이 시간, 튜토리얼 누적, 수동/자동 저장, 새 월드 검증 후 교체 |
| scripts/save/save_safety.gd | 전투·이동·사망·쿨다운·근처 적의 저장 차단 기준 |
| scripts/save/save_menu.gd | F6·10슬롯·덮어쓰기/진행 폐기 확인·한국어 결과·일시정지 소유권 |
| scripts/world/eastern_frontier_starting_area.gd | HUD/튜토리얼 바인딩 전 복원, 바인딩 후 저장 메뉴 생성 |
| scripts/world/game_clock.gd | 스포너 준비 전 신호 없는 시각 설정, 실패 시 원래 시각 복구 |
| test/save/test_save_session.gd | 세션/실패 보존 11개 테스트 |
| test/save/save_session_process_probe.gd | 별도 프로세스 4직업 라운드트립·메뉴 렌더·테스트 파일 정리 |

문서는 save-load 계약, 실행 계획, PROJECT_STATUS, HANDOFF, 본 보고서를 갱신했다. 기존 무관한 로그·스크린샷·로컬 설정은 커밋 대상에서 제외한다.

## 검증 결과

- 구현 전 세션 스크립트 부재로 테스트 로드 실패를 확인했다. 최초 프로세스 probe의 선행 preload는 autoload 미초기화로 실패했으며 지연 load로 수정했다. 완료 지점에 도달하지 못하면 PASS를 출력하지 않도록 방어했다.
- 최종 **전체 GUT 944/944, 3226 assertions, 102 scripts**. 저장 묶음 **47/47, 257 assertions**. 이 중 새 세션 테스트는 11개다.
- 변경 GDScript **7파일** gdformat --check·gdlint 통과, git diff --check 통과.
- 별도 실행 `cleanup → seed → verify → cleanup`: 각 프로세스 `M4_SESSION_PROCESS_PASS`. 모험가·전사·궁수·검투사를 각각 진행시켜 4슬롯에 저장한 뒤 다른 프로세스에서 전체 캐릭터 스냅샷을 비교했다. 8장비 칸(동일 반지 2칸 포함), 강화/지출, EXP, 골드, 소수 HP/MP, 위치, 밤 시각, 튜토리얼, 플레이 시간이 비교 대상이다.
- 신규 테스트: 안전 상태 제한, 활성 슬롯 없는 자동 저장 금지, 위험 상태에서 지연 후 저장, 손상/다른 캐릭터 슬롯의 자동 덮어쓰기 방지, 메뉴 확인·정지, 로드 실패 무변경, 새 캐릭터 계정 유지, 캐릭터 쓰기 실패 시 기존 활성 슬롯 유지, 계정 유실 시 재생성 금지, 새 월드 복원 실패 시 기존 시각·정지 상태 복구, 계정 오류 출처 유지.
- 기존 실제 월드 입력 도구: headless **33/33**, 렌더/캡처 포함 **40/40**. 입력 주입 기반 자동 검사이며 사람이 플레이한 판정을 대신하지 않는다.
- 저장 메뉴 별도 렌더: F6 입력으로 열림, 한글 직업명·안내·확인창 및 취소 버튼 표시 확인. 재생성 경로: `docs/qa/screenshots/m4-save-menu.png`, `m4-save-confirm.png`(로컬 QA 산출물).

### 경고·제한

- 최종 전체 GUT과 렌더 입력 검사에는 종료 잔존 경고가 없었다. 파일 계층의 디렉터리 생성 실패 메시지는 기존 실패 주입 테스트의 기대 오류다.
- **headless seed** 종료에서 객체 16개/리소스 4개 잔존 경고가 남았다. headless 기존 입력 검사에는 객체 4개/리소스 2개가 남았다. 프로세스 복원 비교 성공과 별개이며 원인 해소를 주장하지 않는다. verify·메뉴 preview는 해당 경고 없이 종료했다.
- 계정→캐릭터 순서의 두 파일 기록은 원자적 거래가 아니다. 캐릭터 저장 실패 전 계정의 튜토리얼 완료만 기록될 수 있다. 활성 슬롯은 캐릭터 저장 성공 후에만 바꾼다.
- 장비 효과 비배선은 유지한다. 저장되는 장비 소유·장착과 전투 스탯 효과 연결은 별개이며 M6 전환 계약을 따른다.

## 재현 명령

저장소 루트 PowerShell에서 실행한다. 프로세스 probe는 `user://m4_session_process_probe`만 사용하며 실제 `user://saves`와 분리된다.

```powershell
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
godot --headless --path godot -s res://test/save/save_session_process_probe.gd -- seed
godot --headless --path godot -s res://test/save/save_session_process_probe.gd -- verify
godot --path godot --rendering-method gl_compatibility -s res://test/save/save_session_process_probe.gd -- preview
godot --headless --path godot -s res://test/save/save_session_process_probe.gd -- cleanup
godot --path godot --rendering-method gl_compatibility -s ../docs/qa/tools/runtime_playtest_2026_09_11.gd
```

## 다음 확인

1. Claude: 슬롯/계정 경계, 자동 저장 보호, 새 월드 교체 실패, 메뉴 정지 소유권, 시각/스포너 초기화 순서 검토.
2. 디렉터: 안전한 곳에서 F6 저장 → 게임 종료/재실행 → F6 같은 슬롯 불러오기. 레벨/장비/강화/위치 확인.
3. 다른 슬롯에 새 캐릭터를 저장하고 기존 슬롯이 그대로인지 확인. 메뉴를 닫은 안전 상태에서 3분 자동 저장 표시 확인.
4. 리뷰 수정과 직접 플레이 판정 후 G4를 판단한다. 이번 단위만으로 M4 전체 승인 또는 M5 착수를 기록하지 않는다.

## 후속 — 보스전 저장 잠금

- 사용자 요청에 따라 기존 PlayerStats의 보스 조우 상태를 `save_safety.gd`에 연결했다. `save_menu.gd`에는 보스전 저장 거부 안내를 추가했다. 세션 타이머·저장 스키마·보스 AI는 변경하지 않았다.
- `test_save_session.gd`에서 보스전 수동 저장 거부/슬롯 미생성, 3분 만료 후 요청 유지, 장시간 대기에도 저장 금지, 조우 종료 후 최근 전투 조건이 남으면 대기, 안전해진 다음 갱신에 저장 및 수동 저장 재허용을 검사했다.
- 수정 전 새 테스트 실패(12개 중 1개 실패)를 확인했다. 수정 후 **전체 GUT 945/945·3236 assertions·102 scripts**, 변경 GDScript 3개 형식/린트 및 diff check 통과. 파일 계층의 의도적 디렉터리 실패 외 새 스크립트 오류·종료 잔존 경고 없음.
- 계약/PROJECT_STATUS/HANDOFF/실행 계획을 갱신했다. 실제 보스 조우 콘텐츠는 아직 없으므로 입장·처치·이탈·전멸 트리거의 실전 연결 완료를 주장하지 않는다. 향후 start/end API 연결은 저장 계약 9장에 명시했다. G4 승인 상태는 변하지 않는다.
