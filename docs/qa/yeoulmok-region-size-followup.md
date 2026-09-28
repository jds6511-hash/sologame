# 지역별 크기와 여울목 후보 측정 후속 기록

- 최종 수정: 2026-09-28 / 담당: Codex
- 기준: `6795f8a`, 수신 리뷰: `5eaea5f` 통과(낮음 2건).
- 구현·검증 커밋: `90c6ab0` (10파일). 로컬 커밋 완료, 원격 푸시는 이전 자동 승인 검토 거절이 해소되지 않아 미실행.
- 변경 이력: 2026-09-28 지역별 크기 계약·런타임 경계 분리·후보 몸체 측정과 회귀 검증을 묶음 처리.

## 반영 내용

| 파일 | 변경 이유 |
|---|---|
| `docs/design/levels/world-structure.md` | 마을·도시·사냥터별 규모/형태 차등, 면적·동선·저장 좌표 검증 계약 명시 |
| `docs/art/regional-environment-art-bible.md` | 지역 제작 카드에 규모와 형태 추가, 공통 크기 복제 금지 |
| `godot/scripts/world/region_registry.gd` | 모든 맵에 단일 사각형을 적용하던 코드를 map_id별 BOUNDS로 분리 |
| `godot/test/quests/test_chapter_departure.gd` | 경계 목록과 실제 두 TileMap 일치·미등록 맵 거부 확인 |
| `godot/scripts/tools/yeoulmok_candidate_assets.gd` | V2 기본값, 몸체 분리·공통 배율·바닥 앵커 보정 |
| `godot/test/quests/test_candidate_body_regions.gd` | 후광/외부 스펙과 1개·3개 몸체의 오분리 거부 검증 |
| `docs/art/concepts/yeoulmok/README.md` | 새 측정 규칙과 실제 몸체 치수, 기존 반려 유지 기록 |
| `docs/HANDOFF.md`, `docs/PROJECT_STATUS.md` | 수신 통과와 이번 처리·후속 제작 경계 인계 |

현재 두 맵은 768×576px 그대로다. 실제 크기가 다른 신규 맵을 만들었다는 뜻이 아니다. 저장 형식·기존 좌표·이동 경로도 그대로다. 새로운 맵은 BOUNDS 등록과 실제 타일 경계 대조가 필요하다.

## 실행 검증

- 전체 GUT: **1062/1062**, 118 scripts, 9111 asserts, exit 0. 난수 관련 assert 수는 관측값이다.
- 변경 GD 4개: gdformat 4 unchanged / gdlint 성공.
- 실제 렌더 probe `--candidate`: exit 0, `YEOULMOK_ART_CANDIDATE_PREVIEW_PASS`, 낮/밤×48/72 캡처 성공. 48px 낮 화면을 직접 열어 확인했다.
- V2 SHA-256: `2d96916e934b4ef748d6032098ba0fedab15539774320bed7c8366b7b9b7c618`, 이전 원본과 동일.
- 자동 검증은 직접 조작, 최종 미감, 후보 그림-충돌 정합성, G3/G4/G5 통과를 뜻하지 않는다. 대화형 거부 분기는 변경하지 않았고 이번에는 재실행하지 않았다.

재현:

```powershell
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
godot --path godot --resolution 1920x1080 --script ../docs/qa/tools/yeoulmok_art_pilot_probe.gd -- --candidate
```

## 다음 제작 경계

이번 낮음 보완만을 별도 Claude 재승인 대기로 만들지 않는다. 다음 통합 아트 검토는 실제 규격 원본·문턱/벽 바닥 앵커·건물 부지·가림·동선까지 함께 준비됐을 때다. 현재 후보를 자동 편입하거나 작업장만 임의 축소해 비례를 맞추지 않는다. 지역 규모의 차등 원칙은 확정됐지만, 노베라 전체 도시 크기나 새 부지는 아직 정해지지 않았다.
