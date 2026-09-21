# M4 파일 저장 계층 검증 — 2026-09-21

## 범위

Claude 설계 리뷰 후 작업 단위 1만 검사했다. 실제 캐릭터 복원·슬롯 화면·자동 저장·전체 G4는 이 보고서의 PASS 범위가 아니다. 게임플레이 파일은 변경하지 않았다.

**검토 대상 커밋: `8461823`**. 선행 아트 문서 정정은 별도 커밋 `e10f7ed`다. 이번 작업 기록 갱신은 구현 커밋 이후 별도 문서 커밋으로 남긴다.

## 최초 검증 결과 (`8461823`)

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

## 구현 리뷰 후 보완 — 2026-09-21

**보완 검토 대상: `6789f15`** (`218e719` 이후 변경). 다음 codec 구현과 분리한 파일 계층 수정 커밋이다.

### 2차 리뷰 후 추가 보완

구현 검토 대상은 `50df7e2`다. 후속 기록 커밋에서 GUT 공개 테스트 수에 대한 린트 예외 주석을 파일 첫 줄로 옮겨 린트 통과를 확인했다.

Claude가 `6789f15`의 GUT 18/18·87 assertions 및 중단 복구를 독립 재현했다. 추가 지적의 테스트 3건을 먼저 작성해 실패를 확인한 뒤 수정했다. 현재 **GUT 21/21·98 assertions**, 변경 파일 형식·린트 통과.

- `too_large` 주 파일·백업도 원본 보존 후에만 교체한다. 버전 99와 8 MiB 초과 내용의 두 파일을 준비하고, 반복 저장 후에도 각 보존본 SHA-256이 원본과 같은지 확인했다.
- 보존을 텍스트 변환에서 파일 복사로 변경했다. UTF-8이 아닌 바이트·NUL·CRLF를 포함한 원본도 바이트 단위로 동일함을 검사했다. 기존 보존 실패 주입 테스트도 복사 실패로 옮겨 덮어쓰기 중단을 계속 검증한다.
- 미지원 주 파일은 사전 거부되므로 보존 루프의 `unsupported_version`은 백업에만 해당한다는 주석을 추가했다.
- 로드 결과에 source/main_code/backup_code를 추가했다. 주 파일 스키마 오류와 백업 버전 오류가 동시에 남는지 확인했다. 실제 메뉴 문구 구현은 후속 단위다.
- 이번 검증 범위는 파일 계층이며 전체 게임 회귀·codec·G4 완료를 주장하지 않는다.

- **GUT 18/18, 87 assertions**, 변경 GDScript 3개 형식·린트 통과. 새 테스트를 먼저 실행해 5건 실패를 확인한 뒤 수정했다.
- 1번: 미지원 주 파일 보호는 유지한다. 미지원 백업은 해시 이름 보존본을 확보한 뒤 슬롯 재사용을 허용한다. 반복 저장 후에도 원문 유지 확인. 단순히 백업 버전 검사만 제거하자는 제안은 이후 백업 회전에 원문이 사라지므로 보완했다.
- 2번: 주 파일 삭제 후 정상 백업 복구 GUT 추가. `interrupt_mid`는 대상 제거 후 실제 프로세스를 종료하고 `verify_mid`가 다음 프로세스에서 주 파일 부재·recovered·직전 값을 확인한다. 기존 중단 검사와 함께 PASS. 이는 최악 상태 주입이며 Windows rename 내부의 실제 중단이나 원자성 측정은 아니다.
- 3번: 현재 검증에서 거부된 두 세대 모두 별도 보존한다. 정상 백업은 거부된 데이터로 교체하지 않는다. 보존 쓰기 실패 시 주 파일 불변 확인.
- 4번: payload와 봉투 크기를 각각 검사한다. payload는 한도 내지만 봉투가 초과하는 입력에서 임시 파일 생성 없이 `too_large` 반환 확인.
- 낮은 중요도: 검증기 String 반환 계약과 오류 처리, 잘못된 kind 거부 테스트 추가. 임시 파일은 슬롯에서 제외하는 정책을 명시하고 쓰기의 슬롯 필수 인자는 유지했다.
- 파일 계층 밖 게임플레이는 변경하지 않았으며 이번 검증은 저장 테스트에 한정한다. 전체 게임 회귀·G4 완료로 확대 해석하지 않는다.

추가 프로세스 재현 순서:

```powershell
godot --headless --path godot -s res://test/save/save_store_process_probe.gd -- seed
godot --headless --path godot -s res://test/save/save_store_process_probe.gd -- interrupt_mid
godot --headless --path godot -s res://test/save/save_store_process_probe.gd -- verify_mid
godot --headless --path godot -s res://test/save/save_store_process_probe.gd -- cleanup
```
