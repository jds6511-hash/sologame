# 여울목 한 화면 아트 시제품 검토

## 2026-09-28 독립 리뷰 보완 결과

`2a061e7`/인계 `2311b7c`는 시제품으로 통과했다. 다음은 해당 리뷰의 후속 보완이며 아래 최초 검증 기록과 구분한다.

- 건물을 각각 별도 Node2D로 분리했다. 컨테이너는 y-sort 활성·z0, 각 건물은 z0·발밑 원점y424, 바닥/낮은 소품은 z−1이다. 그림은 건물 원점 기준(-24,-48)에서 시작한다. 같은 z의 플레이어와 건물이 발 위치에 따라 정렬된다. 건물 collision footprint는 그대로다. 이는 가림 방식 보완이며 현재 도형의 미술 품질 승인이 아니다.
- probe 출력은 ignored `screenshots/yeoulmok-art/`로 옮겼다. 재실행 전후 기존 evidence PNG4개의 SHA-256이 동일함을 확인했다. 아래 추가 증거4장만 눈으로 확인한 뒤 `evidence/yeoulmok-art-layering/`에 의도적으로 복사했다. 실행기가 증거 경로에 직접 쓰지 않는다.
- 경로 검사는 제품 `Player/CollisionShape2D`의 캡슐(반지름6/높이18)과 로컬 변환(0,−9)을 그대로 사용한다. 동문·관문지기·귀환점·MQ04 동문 우회/여울의4경로를 검사한다. 정지시킨 적/NPC와의 동적 충돌까지 검증한 것은 아니다.
- **리뷰 표현 정정**: 북쪽 성벽에는 출구가 없다. MQ04는 동문 밖에서 북상한 뒤 여울로 접근한다. 첫 QA 경유점(300,272)은 실제 캡슐 상단이 수면에 닿아 실패했고, 경유점을(300,280)→(152,280)으로 바꿨다. 제품 타일·통로를 바꾼 것이 아니다.
- 대화형 모드에서 지역 이동뿐 아니라 F6 불러오기·새 캐릭터도 제품 씬으로 교체되어 시제품 아트가 사라진다. 세 경우 모두 별도 저장 폴더 격리는 유지한다.

최종 재실행: 종료0 / `YEOULMOK_ART_PILOT_PASS`, GD2개 형식/린트 통과. 기존 타일/시작점·성벽/건물 충돌·4경로·정렬 구조 단언 통과. 실제 플레이어를 각 건물의 북쪽y398/남쪽y448에 배치한4장을 직접 열어 앞뒤 가림을 확인했다. 좌표 주입 정지 렌더이며 사람이 걸어서 확인한 기록은 아니다. 미술 완성도·동적 교전·G3/G4/G5는 미판정 유지. 제품 미배선 시제품만 변경했으므로 전체 GUT는 재실행하지 않았다.

| 건물 | 북쪽: 지붕이 캐릭터의 겹친 부분을 가림 | 남쪽: 캐릭터가 건물 앞 |
|---|---|---|
| 수선 집 | [증거](evidence/yeoulmok-art-layering/house-398.png) | [증거](evidence/yeoulmok-art-layering/house-448.png) |
| 작업장 | [증거](evidence/yeoulmok-art-layering/workshop-398.png) | [증거](evidence/yeoulmok-art-layering/workshop-448.png) |

이 보완은 기존 리뷰 대응 기록으로 다음 통합 아트 검토에 포함한다. 별도의 작은 재승인을 요구하지 않는다. 기존 시제품은 배치/가림 확인용이며, 생성한 완성 목표 콘셉트와 같은 품질로 완성됐다고 주장하지 않는다.

## 최초 시제품 기록 (2a061e7)

- 날짜: 2026-09-28
- 담당: Codex
- 기준: `2bd4fb2`
- 구현 커밋: `2a061e7` (10파일). 이후 인계 커밋은 이 해시 기록만 포함한다.
- 의존: [환경 계획](../art/environment-style-direction.md), [지역별 기준](../art/regional-environment-art-bible.md)
- 변경 이력: 2026-09-28 실제 월드 낮/밤 비교용 시제품·물리 검증 추가.
- 상태: **별도 실행 가능한 첫 배치 시제품. 제품 아트 교체/아트 게이트 통과 아님.**

## 구현 범위

`godot/scripts/tools/yeoulmok_art_pilot.gd`는 원본 픽셀 도형으로 수선 집·작업장2종, 장작·물통·상자·작업대·바구니, 재배 구역·울타리·관목을 그린다. 기존 생성기/타일 에셋/제품 씬은 수정하지 않는다. 카메라 배율4·HUD·캐릭터는 그대로다. 기존 아트 도구를 구입하거나 외부 이미지/작품 자산을 사용하지 않았다.

`docs/qa/tools/yeoulmok_art_pilot_probe.gd`는 실제 여울목 씬을 별도 저장 폴더 `user://yeoulmok_art_pilot`로 실행하고 아트 노드를 추가한다. 마커·원본 타일 데이터는 불변이다. 건물 관통을 막기 위해 **시제품 인스턴스에만** 충돌2개를 추가한다. 따라서 기존 충돌을 그대로 유지하는 것과 전체 충돌이 전혀 늘지 않는 것은 구분한다. 접수원 접근/광장/동문 경로는 새 footprint 밖이다.

범위는 부락 한 화면이다. 물가 키트·아르셀 보드·HUD 축소·전 지역 교체·캐릭터 리디자인은 이번 산출물에 없다. 색/도형은 재현 가능하지만 아직 독립 PNG 타일/소품 시트로 확정하지 않았다. 현재 건물 문은 상호작용 기능이 없다.

## 재현

저장소 루트에서 Godot4.7.1 실행:

```powershell
godot --path godot --resolution 1920x1080 --log-file ../docs/qa/yeoulmok-art-engine.log --script ../docs/qa/tools/yeoulmok_art_pilot_probe.gd
# 비교 캡처 뒤 직접 조작하려면 마지막에 다음 사용자 인자를 붙인다.
# -- --interactive
python -m gdtoolkit.formatter --check godot/scripts/tools/yeoulmok_art_pilot.gd docs/qa/tools/yeoulmok_art_pilot_probe.gd
python -m gdtoolkit.linter godot/scripts/tools/yeoulmok_art_pilot.gd docs/qa/tools/yeoulmok_art_pilot_probe.gd
```

Windows GUI 실행 파일은 셸 반환과 프로세스 종료가 다를 수 있다. 이번 검증은 `Start-Process -PassThru -Wait`로 실제 종료 코드를 확인했다. 대화형 실행에서 지역 이동하면 원래 제품 씬으로 이동하므로 시제품 비교는 여울목에 한정한다.

## 직접 확인한 결과

- Godot 종료0, `YEOULMOK_ART_PILOT_PASS`.
- 원본 타일/충돌 데이터 및 플레이어 시작점 불변.
- 건물2개의 접수원40px 접근·광장/동문 영역 비침범.
- 실제 물리 공간에서 기존 성벽과 건물 내부 충돌 존재.
- 반경8px 원을4px 간격으로 질의하여 `(152,504)→(200,504)→(200,448)→(300,448)` 경로의 지형 충돌 없음. 이는 조작 입력/전투/모든 경로 검증을 대신하지 않는다.
- 새 GD2파일 형식/린트 검사. 제품 연결이 없는 도구 시제품이므로 전체 GUT는 재실행하지 않았다.
- 실패 이력: 처음 물리 검사에서 건물2개가 감지되지 않았다. 월드 정지용 PROCESS_MODE_DISABLED를 상속했기 때문이며, 검사 대상 Ground/ArtPilot을 ALWAYS로 유지하고 기존 성벽 양성 대조도 추가한 뒤 통과했다.
- 첫 판석 배치가 반복 사각 패턴을 만들어 드문 작은 판석으로 수정했다. 낮/밤 이미지 모두 직접 열어 확인했다.

## 화면과 미판정

| 기존 | 시제품 |
|---|---|
| [낮](evidence/yeoulmok-art/before-day.png) | [낮](evidence/yeoulmok-art/pilot-day.png) |
| [밤](evidence/yeoulmok-art/before-night.png) | [밤](evidence/yeoulmok-art/pilot-night.png) |

캡처는 카메라를 부락에 맞추고 월드를 정지시킨 합성 QA다. 밤은 CanvasModulate 대표색을 직접 적용했으며 야간 AI/밤 진입 이벤트 검증이 아니다. 스포너의 지연 콜백 때문에 캡처 간 적 수는 같다고 보장하지 않는다. 실제 플레이와 공격 예고/투사체/드롭의 동적 가독성, 미술적 완성도, G3/G4/G5는 미판정이다. 아직 단순 도형의 느낌과 기존 큰 HUD가 남아 있어 완성품 수준이라고 주장하지 않는다.

## Claude 검토 항목 — 이 묶음 하나

1. 제품 씬/원본 자산을 바꾸지 않고 별도 저장 폴더로 격리했는가?
2. 추가 건물 footprint와 길/접근 검사에 빠진 충돌·가림 위험이 있는가?
3. 정지 렌더/밤 색조/물리 질의를 실제 플레이 검증으로 과장하지 않았는가?
4. 직접 조작 모드의 제품 저장·지역 이동 경계가 문서와 일치하는가?

후속은 이 시제품의 실제 조작/동적 가독성을 확인하고 원본 픽셀 자산으로 정리하는 단계다. 이 묶음이 승인되기 전에 제품 기본 씬에 자동으로 배선하지 않는다.
