# 여울목 환경 시제품 통합 검토 — 재질·경계·생활 공간

- 최종 수정: 2026-09-29 / 담당: Codex(구현·통합)
- 기준: `de34df5` / 검토 커밋: 인계 시 기록
- 변경 이력: 배칭 통과 리뷰 수신 후 재질·경계·생활 소품·검증까지 한 묶음으로 제작했다. 현재 요청만 이 파일에 두고 [과거 검토 기록](yeoulmok-environment-kit-review-history.md)을 분리했다.
- 의존: [환경 방향](../art/environment-style-direction.md), [제작 규격](../art/concepts/yeoulmok/native-kit/README.md)

## 이번 묶음

한 맵을 평가할 수 있도록 여울목 시제품의 물·여울·광장 재질과 경계 표시, 생활 소품을 함께 연결했다. 제품 씬·TileMap 데이터·충돌·NPC·퀘스트·저장 규격은 변경하지 않았다. 모든 변경은 기존 격리 시제품 실행에만 적용된다. 캐릭터 최종 리디자인과 다른 지역은 범위 밖이다.

| 구성 | 변경 |
|---|---|
| 물·여울·광장 | water/sand/paving 각2종. 66/9/55셀, 총130셀에 정수픽셀 표시. 물의 확정3색 배합은 유지하고 무늬를2종으로 나누며 여울은 따뜻한 모래색으로 구분한다. |
| 맵 끝 | 가장자리 충돌 바위에만 방향별 암반4종 배치. 164방향 면이며 모서리 중복 방향을 포함하므로164개 독립 바위가 아니다. 내부 조약돌과 구분하고 노베라 출구는 비운다. |
| 생활 | 우물(114,452), 건조대(115,493), 안내판(286,432) 추가. 기존7개+신규3개=10소품. 모두 비충돌 장식이고 새 상호작용 기능은 없다. |
| 규격 | EDG32·이진 알파·16px타일 유지. 시트160×192, 자산 manifest v5(게임 저장 버전 아님), 타일36/소품8종/건물2종. |
| 보존 | 기존 풀·흙1,463셀/원본 소품228, 경계78/56·코너4/0, 건물 앵커·충돌·작물·보호 지점 유지. 농지·방벽·균열 등 원래 재질은 남는다. |

광장55셀의 새 판석이 기존 도형 Floor의 흙/작은 판석 표시를 덮는 것은 이번 의도된 변화다. 다른 칸/작물까지 덮는 것은 허용하지 않는다. 물은 정지 재질이며 물결 애니메이션은 없다. 밤 화면은 대표 색상 모듈레이션으로 실제 낮밤 플레이 증거가 아니다.

## 변경 파일

- `godot/assets/tools/generate_yeoulmok_native_kit.py`, native-kit `environment.png`/`manifest.json`: 재질6·경계4·생활 소품3을 프로젝트 코드로 직접 작화. 외부 그림 복제·image_gen 호출 없음.
- `godot/scripts/tools/yeoulmok_native_kit.gd`: 재질/경계 표시와3소품 배치. 배칭 순서 유지.
- `docs/qa/tools/test_yeoulmok_native_kit.py`: 재질 불투명/지면 대비/물 확정3색 배합/변형 평균, 경계 픽셀 범위 검사.
- `docs/qa/tools/yeoulmok_art_pilot_probe.gd`: 재질·경계 기대 집합, 출구 보존, 생활 소품 간 가림 검사. 기존 전수/음성 대조/물리 경로 검사 유지.
- README·환경 방향·출처 문서·진행 문서2개·이 요청/과거 기록·선별 증거4장: 현행 범위/제한 동기화. 다른 작업자 스크린샷9개는 미포함.

## 실행 결과

- Python **9/9** (`-W error::DeprecationWarning`), GD3 형식/린트 통과. 새 규격 검사 최초 실행은 시트 크기/소품 수/새 재질 부재3건 실패, 재생성 후 통과.
- 원본 재생성 PNG/JSON SHA-256 동일. EDG32·알파0/255·기존 건물 영역/문턱/원본 충돌 계약 통과.
- native+surface-profile, 기본, candidate 각각 exit0/PASS. 기존 혼용2경로/profile 오용2경로 전부 exit2. native false0/SCRIPT ERROR0.
- 재질130셀 전수 대응, 암반164면 전수 대응. 물/여울 물리 규칙·4동선·소품/작물/프롬프트 보호 지점 검사 통과. 새 소품을 실제 사람이 지나간 체감은 미검증.
- 3위치 교대/묶음 순서 화면 바이트 동일. 최종 드로콜181→73/192→64/145→63. 직전 실행 동부는144→62로 전체 화면 절대값에1콜 편차가 있었으며 감소분82콜은 같았다. 절대값이 모든 실행에서 결정적이라고 주장하지 않는다. 프레임 간격은 여전히 VSync 영향이 있으므로 성능 향상 근거로 쓰지 않는다.
- 전체 GUT·직접 이동/교전은 이번에 실행하지 않았다. 제품 실행 경로와 저장 파일을 바꾸지 않는 아트 시제품 변경이다.

최신 리뷰의 CPU/GPU 뷰포트 시간 API 제안은 타당한 후속 측정 방법으로 기록했다. 이번에는 FPS/렌더 비용 개선을 주장하지 않으므로 측정 도구를 다시 확장하지 않았다. 비용 판단을 할 때 CPU/GPU 시간과 양방향 실행 순서를 사용한다.

## 화면과 판정할 질문

[마을 낮](evidence/yeoulmok-environment-package/pilot-day.png) · [마을 밤](evidence/yeoulmok-environment-package/pilot-night.png) · [물가](evidence/yeoulmok-environment-package/shore-day.png) · [동부 경계](evidence/yeoulmok-environment-package/region-560-320.png)

화면을 열어 확인했다. 캡처 간 적 수/위치는 동일하지 않으며, 성능 비교만 같은 정지 월드에서 수행했다. 전체 미술 완성도나 동적 전투 가독성 승인으로 해석하지 않는다.

1. 재질 적용이 목표130셀로 한정되고 여울/물의 충돌과 출구를 보존하는가?
2. 경계 암반이 내부/출구로 새지 않으며 새 소품이 기존 통행·보호 지점·작물·다른 소품을 가리지 않는가?
3. 원본 제작 규격과 모드 격리, 전수 검사/그림/문서의 범위가 일치하는가?

디렉터 판단은 별도다: 물/판석 분위기, 생활 공간 밀도, 외곽 암반이 통행 불가로 읽히는지. 캐릭터·HUD·농지/방벽의 남은 스타일 차이도 현 화면에 존재한다. 직접 이동·동적 교전·G3/G4/G5·제품 채택은 미판정이다.

## 재현

```powershell
python -W error::DeprecationWarning docs/qa/tools/test_yeoulmok_native_kit.py
godot --path godot --log-file ../docs/qa/environment-local.log --script ../docs/qa/tools/yeoulmok_art_pilot_probe.gd -- --native-kit --surface-profile
```

probe 캡처는 ignored screenshots 경로에만 기록한다. evidence는 이번에 고른4장만 수동 복사했다. 로컬 커밋과 원격 반영은 별개이며, 푸시는 기존 자동 승인 검토 거절 미해소로 미실행이다.
