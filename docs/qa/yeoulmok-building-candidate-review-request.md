# 여울목 건물 원본·게임 화면 비교 통합 검토

- 날짜: 2026-09-28
- 담당: Codex
- 기준: `6acff2f`
- 검토 대상: `5eaea5f` (14파일). 후속 인계 커밋은 이 해시 기록만 포함한다.
- 의존: [원본/실측/제작 계약](../art/concepts/yeoulmok/README.md), [기존 시제품](yeoulmok-art-pilot-review-request.md)
- 변경 이력: 2026-09-28 생성 후보2종·검사 로더·크기별 낮밤 비교 묶음 작성.
- 판정 범위: **자산 제작 방식과 격리된 비교 도구**. 완성 미술/제품 반영 승인 요청이 아니다.

## 산출물

목표 전경과 건물 원본V1/V2를 저장소에 보관했다. `yeoulmok_candidate_assets.gd`는 원본 크기·고유RGB·반투명 픽셀·투명 분리 간격을 측정하고 두 건물을 AtlasTexture로 표시한다. 원본을 리사이즈해 저장하거나 수정하지 않는다. 기존 probe에 `--candidate`를 추가했다. 두 건물에는 집 기준 공통 배율을 사용한다.

후보 이미지는 현행 팔레트/알파/정수 픽셀 기준을 만족하지 않는다. **미리보기 성공을 자산 품질 통과로 표시하지 않는다.** 기존 물리 검사는 도형 시제품에 적용되며 후보 교체 후 그림-충돌 정합성까지 검증한 것으로 해석하지 않는다. 그래서 후보와 `--interactive` 동시 사용은 월드 생성 전에 exit2로 거부한다.

## 재현과 검증

```powershell
godot --path godot --resolution 1920x1080 --log-file ../docs/qa/yeoulmok-candidate-v2.log --script ../docs/qa/tools/yeoulmok_art_pilot_probe.gd -- --candidate
# 거부 경로: 위 명령 끝에 --interactive 추가 → exit2
python -m gdtoolkit.formatter --check godot/scripts/tools/yeoulmok_candidate_assets.gd docs/qa/tools/yeoulmok_art_pilot_probe.gd
python -m gdtoolkit.linter godot/scripts/tools/yeoulmok_candidate_assets.gd docs/qa/tools/yeoulmok_art_pilot_probe.gd
```

- Godot 프로세스 대기 후 확인: 정상 exit0/`YEOULMOK_ART_CANDIDATE_PREVIEW_PASS`, 대화형 혼용 exit2.
- GD2파일 형식/린트 통과. 파일 읽기·투명 영역 분리·렌더4장 성공.
- 자동 출력은 ignored screenshots, 아래 evidence는 선별 복사본이다. 추적 PNG를 probe가 직접 갱신하지 않는다.
- 제품 씬/아이템/저장/전투 코드 변경 없음. 전체 GUT는 재실행하지 않았다.
- 실측값과 품질 반려 사유는 원본 README에 기록했다. 두 생성 시도는 정확한 엔진용 규격을 얻는 데 실패했으며 미화하지 않는다.

| 집 기준 폭(게임 좌표) | 낮 | 밤 |
|---|---|---|
| 48px | [화면](evidence/yeoulmok-candidate/candidate-v2-48-day.png) | [화면](evidence/yeoulmok-candidate/candidate-v2-48-night.png) |
| 72px | [화면](evidence/yeoulmok-candidate/candidate-v2-72-day.png) | [화면](evidence/yeoulmok-candidate/candidate-v2-72-night.png) |

48/72 낮과72 밤을 직접 열어 비교했다. 카메라zoom4·현재 캐릭터/HUD·제품 지형에 대한 정지 렌더다. 야간색은 직접 적용했으며 실제 야간 플레이가 아니다. 큰 작업장 그림은 기존 벽과 겹치고 HUD 안내가 지붕을 가린다. 현재 부지와의 부정합을 보여주는 자료이며 길찾기 통과 화면이 아니다.

## Claude에게 확인할 것

1. 신규 로더가 원본과 제품 리소스를 변경하지 않고 임시 Sprite2D로만 표시하는가?
2. 색 수/알파/분리 측정의 의미와 한계가 정확한가? alpha>0 bbox를 최종 접지점으로 과장한 곳은 없는가?
3. 기존 물리 검사와 후보 미술/충돌 적합성 판정을 분리했고 대화형 혼용을 막았는가?
4. 집/작업장을 공통 배율로 비교하는 정책과 후속 앵커/부지 재검증 계약에 빠진 위험은 없는가?

원본 형상·미술 취향은 디렉터 판정이며 Claude에게 대신 승인하도록 요청하지 않는다. G3/G4/G5·동적 교전·최종 미술은 미판정이다. 다음 제품 적용은 규격에 맞는 원본 재작화 및 부지 검증 뒤 진행한다.
