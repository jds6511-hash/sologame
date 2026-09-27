# Claude 검토 요청 — M5 단위 3 자동 검증

- 기준: `f11430e`. 구현 해시는 커밋 후 이 문서에 기록한다.
- [결과와 제한](m5-quest-persistence-report.md). 게임 코드 변경 없음. 단위 3 전체/G5 완료 심사가 아니라 **검증 스크립트의 타당성과 보고서 주장**에 대한 읽기 전용 검토다.

## 집중 항목

1. 실제 SaveSession 저장/월드 교체/codec 복원을 거치는지, 상태 1/2·2/2·completed와 전체 payload 비교가 독립 프로세스에서 이뤄지는지.
2. EXP 75/400, 골드·포션 및 재보고 불변 단언이 유효한지. KILL 이벤트 fixture를 실제 플레이로 과장하지 않았는지.
3. V1 레벨/장비 복원·의뢰 시작과 슬롯 5 저장 이후 슬롯 1~4 SHA-256 보호가 검증되는지.
4. 완료 플래그/오류 수집 누락, 실행 중 스크립트 오류가 PASS로 위장할 가능성. 종료 경고와 입력 도구 한계 기록의 정확성.

## 재현

Windows GUI Godot 실행 파일은 `Start-Process -Wait`로 종료를 기다린다. 각 단계는 별도 프로세스로 실행하고 exit code와 stderr의 SCRIPT ERROR를 함께 검사한다.

```powershell
godot --headless --path godot -s res://test/quests/first_quest_process_probe.gd -- cleanup
godot --headless --path godot -s res://test/quests/first_quest_process_probe.gd -- seed
godot --headless --path godot -s res://test/quests/first_quest_process_probe.gd -- active
godot --headless --path godot -s res://test/quests/first_quest_process_probe.gd -- ready
godot --headless --path godot -s res://test/quests/first_quest_process_probe.gd -- completed
godot --headless --path godot -s res://test/quests/first_quest_process_probe.gd -- legacy
godot --headless --path godot -s res://test/quests/first_quest_process_probe.gd -- cleanup
gdformat --check godot/test/quests/first_quest_process_probe.gd docs/qa/tools/m5_manual_play.gd
gdlint godot/test/quests/first_quest_process_probe.gd docs/qa/tools/m5_manual_play.gd
```

예상: 7단계 PASS, 신규 2파일 형식/린트 통과. seed 종료 경고 4/2, active 6/2는 잔존한다. 직접 플레이는 입력 도구의 physical_keycode 불일치로 미완료다. 리뷰가 통과해도 G4/G5 승인을 대신하지 않는다.
