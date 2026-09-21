# M4 파일 저장 계층 검증 — 2026-09-21

## 범위

Claude 설계 리뷰 후 작업 단위 1만 검사했다. 실제 캐릭터 복원·슬롯 화면·자동 저장·전체 G4는 이 보고서의 PASS 범위가 아니다. 게임플레이 파일은 변경하지 않았다.

**검토 대상 커밋: `8461823`**. 선행 아트 문서 정정은 별도 커밋 `e10f7ed`다. 이번 작업 기록 갱신은 구현 커밋 이후 별도 문서 커밋으로 남긴다.

## 검증 결과

- Godot 4.7.1, GUT: `test/save/test_save_file_store.gd` **11/11**, **68 assertions**.
- 변경 GDScript 3개 `gdformat --check`, `gdlint` 통과.
- 계정과 10슬롯 독립, 슬롯/종류 제한, 체크섬 변조 거부, 정상 백업 복구, 스키마 검사 콜백의 거부/백업 복구, 버전 0/99 읽기·덮어쓰기 거부 확인.
- 임시 파일 쓰기 실패, 백업 쓰기 실패, 최종 rename 실패를 주입해 기존 정상 저장 보존 확인. 실제 디렉터리 생성 실패도 별도 검사했다. 물리적 디스크 고갈 자체를 재현한 것은 아니다.
- 10회 JSON 저장/로드에서 분수 시간·좌표 동일 확인. 실제 캐릭터 스탯 라운드트립은 후속 단위다.
- **별도 프로세스 강제 종료**: 최초 값 10 저장 → 값 99의 `.tmp` 기록·검증과 정상본 백업 완료 → 최종 rename 직전에 테스트 프로세스가 자신을 종료 → 새 프로세스가 값 10과 남은 `.tmp`/`.bak` 확인. 결과 `M4_PROCESS_PRESERVATION_PASS`. 저장 장치 전원 손실 내구성을 검증한 것은 아니다.

## 재현

저장소 루트에서:

```powershell
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gtest=res://test/save/test_save_file_store.gd -gexit
gdformat --check godot/scripts/save/save_file_store.gd godot/test/save/test_save_file_store.gd godot/test/save/save_store_process_probe.gd
gdlint godot/scripts/save/save_file_store.gd godot/test/save/test_save_file_store.gd godot/test/save/save_store_process_probe.gd
```

프로세스 검사는 아래 명령을 순서대로 실행한다. `interrupt`는 의도적 비정상 종료이며 그 자체를 PASS로 세지 않는다. `verify`의 출력과 종료 코드를 확인한다.

```powershell
godot --headless --path godot -s res://test/save/save_store_process_probe.gd -- seed
godot --headless --path godot -s res://test/save/save_store_process_probe.gd -- interrupt
godot --headless --path godot -s res://test/save/save_store_process_probe.gd -- verify
godot --headless --path godot -s res://test/save/save_store_process_probe.gd -- cleanup
```

두 검사는 `user://m4_test_*`와 `user://m4_process_probe`만 사용하며 실제 `user://saves`를 열지 않는다.

## Claude 재검토 범위

상세 기준은 [저장 계약](../design/systems/save-load.md), 작업 순서는 [실행 계획](../superpowers/plans/2026-09-21-m4-save-load.md)을 따른다. 이번 리뷰에서는 H1~H4의 정책과 파일 계층을 검토할 수 있다. 실제 값 범위·ID·스킬 예산 검증, 미완 거래 차단과 UI는 후속 구현 뒤 별도로 검토해야 한다.
