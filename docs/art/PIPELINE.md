# 아트 임포트·프로젝트 기준 파이프라인

- **최종 수정일**: 2026-07-16
- **담당**: tech-artist
- **의존 문서**:
  - `docs\art\STYLE_GUIDE.md` (1-1장 픽셀 해상도 기준, 1-2장 스프라이트 규격)
  - `docs\design\M2_PLAN.md` (태스크 MP-2)
- **변경 이력**:
  - 2026-07-16: 최초 작성 — MP-2(x4 정수 스케일·픽셀 스냅 프로젝트 설정) 적용, `project.godot` 수정 근거 기록

---

## 1. 해상도·스케일 구조 (확정)

`STYLE_GUIDE.md` 1-1장에 따라 **뷰포트 자체를 320x180으로 낮추지 않는다.** 대신 다음 구조를 채택한다.

| 항목 | 값 | 비고 |
|---|---|---|
| 프로젝트 뷰포트(네이티브) | **1280x720** | `ux-foundation.md`의 HUD 좌표·글자 크기가 이 해상도 기준이므로 유지 |
| 월드 카메라 줌 | **Camera2D.zoom = Vector2(4, 4)** | 씬마다 카메라에 설정하는 값 (프로젝트 전역 설정 아님) |
| 월드 실효 가시 영역 | **320x180** | 1280/4 x 720/4 — 카메라 줌으로 달성, 뷰포트 해상도 변경이 아님 |
| UI 렌더링 | **CanvasLayer, 네이티브 1280x720** | Camera2D 줌의 영향을 받지 않음 (분리 계층) |

**판단 근거**: 태스크 지시에는 "내부 해상도 320x180 + stretch 방식"이라는 대안 표현이 있었으나, `STYLE_GUIDE.md` 1-1장 원문은 "게임 월드 내부 해상도 320x180"과 "UI 렌더링: 네이티브 1280x720(CanvasLayer, 줌 비적용)"을 명시적으로 구분한다. 뷰포트를 320x180으로 낮추고 `stretch mode=viewport`로 확대하면 UI Control 노드의 좌표계도 320x180 기준으로 바뀌어 `ux-foundation.md`가 확정한 HUD 좌표(1280x720 기준)와 어긋난다. 따라서 뷰포트는 1280x720을 유지하고, 월드만 Camera2D.zoom=4로 축소해 보여주는 방식을 표준으로 채택했다.

### 1-1. 검증 씬

`godot\scenes\pixel_scale_test.tscn` (`godot\scripts\pixel_scale_test.gd`)에서 위 구조를 실측 확인할 수 있다. 헤드리스 실행 결과:

```
[MP-2 검증] 뷰포트(네이티브 UI 기준) 크기: (1280.0, 720.0)
[MP-2 검증] Camera2D.zoom: (4.0, 4.0)
[MP-2 검증] 월드 실효 가시 영역: (320.0, 180.0)
```

이후 몬스터/맵/HUD 씬 작업 시 이 씬을 Camera2D 표준 설정 참조용으로 사용한다 — **월드를 그리는 모든 씬은 Camera2D를 두고 zoom=Vector2(4,4)를 지정해야 하며, 프로젝트 전역 설정으로는 강제되지 않으므로 씬 작성자가 직접 챙겨야 한다.**

---

## 2. project.godot 설정 (확정)

`godot\project.godot`에 다음 항목을 반영했다.

| 섹션 | 키 | 값 | 목적 |
|---|---|---|---|
| `[display]` | `window/size/viewport_width` / `viewport_height` | 1280 / 720 | 네이티브 UI 해상도 유지 (변경 없음) |
| `[display]` | `window/stretch/mode` | `canvas_items` | 창 크기 변경 시 2D 캔버스 전체(월드+UI)를 함께 스케일 |
| `[display]` | `window/stretch/aspect` | `keep` | 종횡비 유지, 레터박스 허용 (이미지 왜곡 금지) |
| `[display]` | `window/stretch/scale_mode` | `integer` | 창을 키워도 **정수 배율로만** 확대 — 비정수 스케일에 의한 픽셀 뭉개짐 방지 |
| `[rendering]` | `textures/canvas_textures/default_texture_filter` | `0` (Nearest) | 모든 2D 텍스처 기본 필터를 Nearest로 고정 (STYLE_GUIDE 1-1) |
| `[rendering]` | `2d/snap/snap_2d_transforms_to_pixel` | `true` | 2D 노드 변환을 픽셀 격자에 스냅 (STYLE_GUIDE 1-1) |
| `[rendering]` | `2d/snap/snap_2d_vertices_to_pixel` | `true` | 정점 단위 스냅까지 적용 — 스프라이트 경계 흔들림 방지 |

## 3. 이후 작업자를 위한 체크리스트

- 새 월드 씬(맵·전투장 등)을 만들 때 **Camera2D를 반드시 배치하고 `zoom = Vector2(4, 4)`로 설정**한다 (`current = true` 포함).
- HUD/메뉴 등 UI는 반드시 **CanvasLayer** 하위에 배치한다 — Camera2D 자식으로 두면 줌이 적용되어 ux-foundation의 좌표가 어긋난다.
- 개별 텍스처를 import할 때 프로젝트 기본값(Nearest)을 그대로 두면 된다. 회전이 필수인 투사체 등 예외는 vfx-artist 판단 하에 개별 텍스처 임포트 설정에서만 조정한다 (STYLE_GUIDE 1-1 예외 규정).
- 런타임에 스프라이트를 비정수 배율로 스케일하지 않는다 (STYLE_GUIDE 1-1).
