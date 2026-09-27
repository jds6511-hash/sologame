# Claude 구현 검토 요청 — MQ-01-03

- 기준 `061bc02`. 구현 커밋 **`72cb569`**, 범위 `061bc02..72cb569`.
- [결과·변경 파일·제한](m5-third-quest-report.md), [승인 설계와 정정](../design/systems/m5-third-quest.md).

파일 수정·커밋·푸시 없이 읽기 전용으로 검토해 주세요.

1. Presentation의 명시적 순서/current 우선/선행/NPC 선택과 UI 액션 검증. 기존 01/02의 대화·보상·pause 의미가 유지되는가?
2. 최초/재스폰 들개의 content/source 메타가 단일 died 등록을 거쳐 정확히 집계되는가? 다른 출처·수락 전·중복 이벤트가 제외되는가?
3. 490 EXP·150골드와 전체 890/270, 재보고 무변경, V2 03 세 상태 저장 복원.
4. 구 Catalog의 `quest_fields`→invalid_data·백업 폴백·읽기 해시 불변·쓰기 원문 보존. 버전 상승 없이 추가한 호환 범위가 보고서와 맞는가?
5. 실제 입력과 자동 이벤트/피해 주입·렌더의 구분. 종료 경고와 실제 동시 교전 수 미측정의 제한.

## 재현

Windows GUI exe는 Start-Process -Wait를 사용하고 exit code/stderr를 함께 확인한다.

```powershell
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
# 아래 phase마다 별도 프로세스: cleanup seed active ready completed legacy third_seed third_active third_ready third_completed cleanup
godot --headless --path godot -s res://test/quests/first_quest_process_probe.gd -- PHASE
godot --path godot --rendering-method gl_compatibility --resolution 1920x1080 -s res://../docs/qa/tools/m5_quest_render_probe.gd -- third
godot --path godot --rendering-method gl_compatibility -s res://../docs/qa/tools/runtime_playtest_2026_09_11.gd
```

예상: GUT 1001/1001·109 scripts, probe 11단계 PASS, 렌더 PASS, runtime 40/40. 변경 `.gd` 13개를 gdformat/gdlint에 전달한다. 렌더 third 모드는 `screenshots/m5-third/`에 기록해 기존 수정 스크린샷을 덮어쓰지 않는다. G4/G5 수동 판정은 여전히 미완료다.
