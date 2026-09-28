# 여울목 원본 픽셀 키트·엔진 배치 통합 검토

- 날짜: 2026-09-28 / 담당: Codex
- 기준: `70ff973`. 변경 이력: 건물/분리 소품 원본·메타데이터·실제 월드 표시·회귀 검증을 한 묶음으로 추가.
- 기존 후보의 낮음 보완 재승인 요청이 아니다. **새 원본 자산 7종과 엔진 배치 계약**이 검토 대상이다.

## 무엇이 달라졌는가

고해상도 생성 후보는 현행 팔레트·알파·부지에 맞지 않아 제품 편입을 보류했다. 후속 작업으로 현행 직접 작화 제작선을 사용해 건물 2종과 소품 5종을 원래 픽셀 크기에서 만들고, 문턱·벽 바닥·충돌 범위를 명시한 매니페스트와 Godot 배치를 연결했다. 생성 후보 원본과 추적 증거는 덮어쓰지 않았다.

| 파일 | 변경 |
|---|---|
| `godot/assets/tools/generate_yeoulmok_native_kit.py` | 공용 EDG32·정수 좌표의 재현 가능한 원본 작화 |
| `docs/art/concepts/yeoulmok/native-kit/{environment.png,manifest.json,README.md}` | 실제 시트·앵커/영역/부지·제작/재현 계약 |
| `godot/scripts/tools/yeoulmok_native_kit.gd` | Sprite2D 원본 배율, 건물별 문턱 원점, 소품 7개 y-sort 배치 |
| `godot/scripts/tools/yeoulmok_art_pilot.gd` | Floor 이름과 기존 도형 소품 억제 분기; 기존 실행은 그대로 |
| `docs/qa/tools/yeoulmok_art_pilot_probe.gd` | `--native-kit`, 명시 부지/문턱 검사, 별도 캡처 폴더, 후보 혼용 거부 |
| `docs/qa/tools/test_yeoulmok_native_kit.py` | PNG 규격·전체 픽셀 팔레트/알파·앵커/원래 부지·시트 영역 검사 |
| `docs/art/ASSET_SOURCES.md`, `docs/HANDOFF.md`, `docs/PROJECT_STATUS.md` | 실제 제작 출처·현행 상태·전달 범위 연결 |

## 실행 결과

- 자산 생성 전 Python 검사: 파일 부재 2 errors. 제품 결함 재현이 아니라 미구현 산출물 확인이다.
- 생성 후 Python 검사: **2/2 PASS**. 픽셀 전체 EDG32/알파 0·255, 영역/문턱·원래 부지 일치.
- 연속 재생성: PNG와 JSON SHA-256 **동일**.
- 변경 GD 3개: gdformat unchanged / gdlint 성공.
- `--native-kit`: **YEOULMOK_NATIVE_KIT_PASS**, exit0. 기존 물리 4동선·벽/건물 충돌·타일 불변과 신규 계약 확인, 낮/밤·지붕 앞뒤 캡처.
- 기본 도형 실행: **YEOULMOK_ART_PILOT_PASS**, exit0.
- 기존 `--candidate`: **YEOULMOK_ART_CANDIDATE_PREVIEW_PASS**, exit0.
- `--candidate --native-kit`: 월드 생성 전 **exit2**.
- 낮·밤과 집 북쪽 가림 캡처를 직접 열어 확인했다. 플레이어를 좌표로 배치한 정지 렌더이며 직접 이동 플레이를 했다는 뜻이 아니다.
- 이번 변경은 제품 씬·게임플레이·저장 코드 미변경이다. 전체 GUT는 이번 묶음에서 재실행하지 않았다. 이전 지역 경계 커밋의 1062/1062를 이번 실행 결과로 재사용하지 않는다.

실행 명령은 [키트 README](../art/concepts/yeoulmok/native-kit/README.md)에 있다. 캡처는 ignored 경로에 쓰며, 아래 이미지만 선별 보관했다.

- [낮](evidence/yeoulmok-native-kit/pilot-day.png) / [밤](evidence/yeoulmok-native-kit/pilot-night.png)
- [집 뒤 가림](evidence/yeoulmok-native-kit/house-398.png) / [집 앞](evidence/yeoulmok-native-kit/house-448.png)

## 검토 질문

1. 매니페스트의 셀 좌표→문턱 원점→실제 벽 footprint 변환이 일관적인가? 지붕 돌출과 계단을 충돌 범위로 오인한 곳은 없는가?
2. 건물과 소품의 y-sort 경로가 유지되고, 도형/생성 후보 모드 회귀 또는 이중 표시가 없는가?
3. 정지 캡처·물리 질의·파일 검사를 실제 조작/미술 승인으로 과장한 부분은 없는가?

## 남은 범위

원본 픽셀 제작/배치 기술 검토와 미술 취향 판정은 별개다. 이 키트가 완성 목표의 밀도·미감을 달성했다고 판단하지 않는다. 지면/물가/울타리·초목 타일 제작, 직접 조작·소품 통과 체감·동적 전투 가독성, G3/G4/G5는 남아 있다. M6 제품 전환은 이번 아트 작업에 섞지 않았다.
