# 여울목 정수 픽셀 제작 키트

- 최종 수정: 2026-09-28 / 제작: Codex
- 의존: [제작선](../../../art-pipeline-candidates.md), [환경 파일럿](../../../environment-style-direction.md)
- 변경 이력: 2026-09-28 건물 2종·분리 소품 5종·명시 앵커/벽 범위와 격리 배치 추가.
- 상태: **기술 검증용 원본 자산. 미술 승인·제품 편입 전.**

## 제작 경로

`godot/assets/tools/generate_yeoulmok_native_kit.py`가 정수 좌표로 직접 작화한 프로젝트 원본이다. 공용 EDG32만 사용한다. 외부 그림을 복제하지 않았고, 앞선 image_gen V1/V2를 축소·양자화·가공한 결과도 아니다. 이번 제작에는 image_gen·Higgsfield·PixelLab을 호출하지 않았다. CC0 외부 소싱 항목으로 취급하지 않는다.

`environment.png`는 160×96 RGBA 시트, `manifest.json`은 스프라이트별 영역·앵커·부지 정보다. 64×64 셀의 수선 집/작업장과 32×32 셀의 물통·상자·장작·바구니·작업대가 있다. 셀 크기는 그림의 실체 크기와 다르다. 소품은 건물에서 독립적으로 배치할 수 있다.

## 엔진 계약

- 원본 1px = 월드 1px, 카메라 zoom4 유지. 매니페스트 좌표는 각 잘린 셀의 좌상단 기준이다.
- 건물 anchor/threshold `(32,60)`, wall_bottom `60`. 이미지 bbox 추정 대신 작화 시 지정한 문턱과 벽 바닥을 쓴다. 문턱 아래 3px 계단은 충돌 밖이다. 문은 현재 장식이며 실내 진입 기능이 없다.
- 집 origin `(72,424)`, footprint `(12,36,40,24)` → 월드 `(52,400,40,24)`.
- 작업장 origin `(248,424)`, footprint `(12,40,40,20)` → 월드 `(228,404,40,20)`.
- 지붕은 벽보다 돌출하며 충돌을 추가하지 않는다. 건물 노드 z0/발밑 y-sort가 가림을 처리한다. `roof_overhang`은 도형 지붕의 외접 범위이며 픽셀별 마스크가 아니다.
- 소품 5종은 7개 인스턴스로 배치하고 발밑 y-sort에 참여한다. 전부 장식이며 별도 충돌·획득·상호작용은 없다. 소품을 지나갈 수 있는지의 체감은 직접 플레이에서 확인한다.
- 제품 씬·타일·저장 형식은 그대로다. 시제품에서 불러오기·새 캐릭터·지역 이동 시 제품 월드가 다시 생성되어 키트가 사라진다. `user://yeoulmok_art_pilot` 저장 격리는 기존 실행기를 따른다.

## 재현

```powershell
python godot/assets/tools/generate_yeoulmok_native_kit.py
python docs/qa/tools/test_yeoulmok_native_kit.py
godot --path godot --resolution 1920x1080 --script ../docs/qa/tools/yeoulmok_art_pilot_probe.gd -- --native-kit
# 직접 조작용, 동일한 검사를 끝내고 창을 유지한다.
godot --path godot --resolution 1920x1080 --script ../docs/qa/tools/yeoulmok_art_pilot_probe.gd -- --native-kit --interactive
```

자동 출력은 ignored `docs/qa/screenshots/yeoulmok-art/native-kit/`에만 저장한다. 선별 증거만 별도로 보관한다. 기존 생성 후보는 `--candidate`로 별도 실행하고 두 옵션을 섞으면 월드 생성 전에 거부한다.

## 판정 범위

팔레트·이진 알파·정수 배율·문턱 앵커·벽 충돌 계약을 충족하는 제작 예시다. 앞선 풍부한 콘셉트와 동등한 미술 완성도라는 뜻은 아니다. 캐릭터와의 비례, 작업장/집의 구별, 아늑함과 생활 밀도는 디렉터 판단 대상으로 남긴다. 지면·물가·울타리·초목 타일은 이 PNG에 포함하지 않았고 기존 도형 파일럿을 유지한다. 공격 예고·투사체·드롭의 동적 가독성과 G3/G4/G5도 미판정이다.
