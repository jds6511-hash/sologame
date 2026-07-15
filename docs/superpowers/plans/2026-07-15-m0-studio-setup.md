# M0 스튜디오 구축 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Godot 4.x 기반 2D RPG 개발을 위한 가상 스튜디오(에이전트 18명 + 도구 + 폴더 구조) 구축 및 동작 검증

**Architecture:** 프로젝트 루트에 Claude Code 서브에이전트 정의(`.claude\agents\*.md`) 18개를 두고, 문서 폴더(`docs\`)를 인수인계 매체로 사용. Godot 프로젝트는 `godot\` 하위에 격리.

**Tech Stack:** Godot 4.x (winget), Python(gdtoolkit 4.x, Pillow, numpy), GUT(테스트 프레임워크), git + GitHub

## Global Constraints

- 모든 산출 문서·게임 텍스트는 한국어
- 싱글플레이 전용, PC(Windows) 전용
- 원격 저장소: `https://github.com/jds6511-hash/sologame.git` (master)
- gdtoolkit은 반드시 4.x (`pip install "gdtoolkit==4.*"`)
- 스포일러(반전) 내용은 `docs\design\spoilers\`에만 기록, 사용자 보고에 내용 언급 금지
- 작업 단위마다 커밋

---

### Task 1: Godot 4.x 설치 및 CLI 검증

**Files:** 없음 (시스템 설치)

**Interfaces:**
- Produces: `godot` 실행 파일 경로 → Task 3의 CLAUDE.md에 기록

- [ ] **Step 1: winget으로 Godot 설치**

```powershell
winget install --id=GodotEngine.GodotEngine -e --accept-source-agreements --accept-package-agreements
```
Expected: "Successfully installed"

- [ ] **Step 2: 실행 파일 경로 확인**

```powershell
Get-Command godot -ErrorAction SilentlyContinue; if (-not $?) { Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "Godot*.exe" | Select-Object -First 5 FullName }
```
Expected: `Godot_v4.x.x-stable_win64.exe` 경로 확보 (버전 숫자 기록)

- [ ] **Step 3: CLI 구동 검증**

```powershell
& "<확보한 경로>" --version
```
Expected: `4.x.x.stable...` 출력

### Task 2: Python 도구 설치

**Files:** 없음 (시스템 설치)

**Interfaces:**
- Produces: `gdformat`, `gdlint` 명령, Python `PIL`/`numpy` 모듈

- [ ] **Step 1: Python 존재 확인**

```powershell
python --version
```
Expected: `Python 3.x`. 없으면 `winget install Python.Python.3.12` 후 재확인

- [ ] **Step 2: 패키지 설치**

```powershell
pip install "gdtoolkit==4.*" Pillow numpy
```
Expected: Successfully installed

- [ ] **Step 3: 검증**

```powershell
gdformat --version; gdlint --version; python -c "import PIL, numpy; print('ok')"
```
Expected: gdtoolkit 4.x 버전 출력 + `ok`

### Task 3: 폴더 구조, .gitignore, CLAUDE.md

**Files:**
- Create: `.gitignore`, `CLAUDE.md`, `docs\qa\.gitkeep`, `docs\art\.gitkeep`, `docs\design\spoilers\.gitkeep`, `.claude\agents\` (Task 5에서 채움)

**Interfaces:**
- Consumes: Task 1의 Godot 경로/버전
- Produces: 모든 에이전트가 참조할 CLAUDE.md 규칙

- [ ] **Step 1: 폴더 생성**

```powershell
New-Item -ItemType Directory -Force .claude\agents, docs\design\spoilers, docs\art, docs\qa, godot | Out-Null
```

- [ ] **Step 2: .gitignore 작성**

```gitignore
# Godot
godot/.godot/
*.import
# Python
__pycache__/
# 임시
*.tmp
```

- [ ] **Step 3: CLAUDE.md 작성** — 아래 내용 (Godot 경로/버전은 Task 1 결과로 치환)

```markdown
# 2D RPG 프로젝트 (sologame)

Godot 4.x로 만드는 한국어 싱글플레이 2D 판타지 RPG. 개인 프로젝트(배포 없음).

## 절대 규칙
- 모든 산출물(문서, 게임 텍스트, 커밋 메시지)은 **한국어**로 작성한다.
- **스포일러 금지**: 스토리 반전 관련 내용은 `docs\design\spoilers\`에만 기록한다.
  사용자(디렉터) 보고에는 "반전 요소 작업 완료" 수준으로만 언급하고 내용은 절대 쓰지 않는다.
- 싱글플레이/PC 전용. 멀티플레이, 서버, PvP, 수익 모델 관련 작업 금지.

## 환경
- Godot 실행 파일: `<GODOT_PATH>` (버전 <GODOT_VERSION> 고정)
- GDScript 도구: gdformat / gdlint (gdtoolkit 4.x)
- Godot 프로젝트 루트: `godot\`

## git 규칙
- 작업 단위마다 커밋, 마일스톤 완료 시 `origin master`로 푸시
- gdformat 등 일괄 포맷팅 전에는 반드시 먼저 커밋
- 커밋 메시지는 한국어, `feat:`/`fix:`/`docs:` 접두사 사용

## 문서 규칙 (에이전트 인수인계)
- 기획 문서 머리말: 제목, 최종 수정일, 담당 에이전트, 의존 문서 링크, 변경 이력(changelog)
- 문서를 수정하면 반드시 변경 이력에 한 줄 추가
- 개발 에이전트는 구현 시작 전 참조 기획서의 변경 이력을 확인한다
- 산출물 위치: 기획 `docs\design\`, 아트 `docs\art\`, QA `docs\qa\`, 진행 관리 `docs\PROJECT_STATUS.md`
- QA 리포트는 휘발성: 지적 사항이 모두 반영되면 리포트 파일을 삭제한다

## GDScript 컨벤션
- 파일/폴더: snake_case (`player_controller.gd`), 씬은 `godot\scenes\`, 스크립트는 `godot\scripts\`, 에셋은 `godot\assets\`
- 클래스명 PascalCase, 함수/변수 snake_case, 상수 UPPER_SNAKE_CASE, 시그널은 과거형 동사
- 커밋 전 `gdformat`으로 포맷, `gdlint`로 린트 통과
```

- [ ] **Step 4: 커밋**

```powershell
git add -A; git commit -m "chore: 폴더 구조, .gitignore, CLAUDE.md 생성"
```

### Task 4: Godot 프로젝트 초기화 + GUT 설치

**Files:**
- Create: `godot\project.godot`, `godot\icon.svg`, `godot\addons\gut\` (다운로드)

**Interfaces:**
- Consumes: Task 1의 Godot 경로
- Produces: 헤드리스 구동 가능한 Godot 프로젝트 + GUT 테스트 프레임워크

- [ ] **Step 1: project.godot 작성**

```ini
; godot\project.godot
config_version=5

[application]
config/name="sologame"
config/features=PackedStringArray("4.5")
run/main_scene=""

[display]
window/size/viewport_width=1280
window/size/viewport_height=720

[rendering]
renderer/rendering_method="gl_compatibility"
```
(`config/features`의 버전은 Task 1에서 확인된 실제 버전으로 기입)

- [ ] **Step 2: 헤드리스 구동 검증**

```powershell
& "<GODOT_PATH>" --headless --path godot --quit
```
Expected: 에러 없이 종료 (import 로그만 출력)

- [ ] **Step 3: GUT 설치** (Godot 4용 GUT 9.x)

```powershell
git clone --depth 1 https://github.com/bitwes/Gut.git "$env:TEMP\gut-clone"
Copy-Item -Recurse "$env:TEMP\gut-clone\addons\gut" godot\addons\gut
Remove-Item -Recurse -Force "$env:TEMP\gut-clone"
```
Expected: `godot\addons\gut\plugin.cfg` 존재

- [ ] **Step 4: 커밋**

```powershell
git add -A; git commit -m "chore: Godot 프로젝트 초기화 및 GUT 설치"
```

### Task 5: 에이전트 18명 정의 파일 생성

**Files:**
- Create: `.claude\agents\<이름>.md` × 18

**Interfaces:**
- Consumes: CLAUDE.md 규칙 (에이전트는 자동으로 프로젝트 CLAUDE.md를 읽음)
- Produces: Agent 툴에서 `subagent_type: "<이름>"`으로 호출 가능한 에이전트 18개

- [ ] **Step 1: 공통 템플릿 확정** — 모든 파일은 아래 구조를 따른다

```markdown
---
name: <이름>
description: <메인 Claude가 언제 이 에이전트를 호출해야 하는지 한 문장 (한국어)>
---

당신은 한국어 싱글플레이 2D 판타지 RPG(Godot 4.x)를 만드는 가상 게임 스튜디오의 **<직함>**입니다.

## 담당
<담당 목록>

## 작업 방식
<에이전트별 작업 규칙>

## 공통 규칙
- 모든 산출물은 한국어로 작성한다.
- 작업 시작 전 `docs\design\GAME_CONCEPT.md`와 담당 영역의 기존 문서를 읽고, 문서 머리말의 변경 이력을 확인한다.
- 산출 문서에는 머리말(제목/최종 수정일/담당/의존 문서/변경 이력)을 반드시 포함한다.
- 다른 팀원의 산출물 위치: 기획 `docs\design\`, 아트 `docs\art\`, QA `docs\qa\`, 진행 현황 `docs\PROJECT_STATUS.md`
- 확신이 없는 결정(게임의 방향을 바꾸는 것)은 임의로 정하지 말고 결과 보고에 "디렉터 결정 필요" 항목으로 명시한다.
```

- [ ] **Step 2: 18개 파일 생성** — 각 에이전트의 직함/담당/작업 규칙:

| name | 직함 | 담당 | 에이전트별 작업 규칙 (요지) |
|---|---|---|---|
| narrative-designer | 내러티브 디자이너 | 세계관, 메인 스토리, 캐릭터, 대사, 반전 요소 | 산출물 `docs\design\` (세계관/스토리 문서). **반전 관련 내용은 `docs\design\spoilers\`에만 기록하고 일반 문서·보고에는 절대 쓰지 않는다.** quest-designer와 스토리 연계 협의 필요 사항은 문서에 명시 |
| systems-designer | 시스템 디자이너 | 전투/스탯/성장/직업/펫/칭호/도감/시간 시스템 설계, 전투 밸런스 수치 최종 책임 | 산출물 `docs\design\systems\`. 수치는 근거(공식, 곡선)와 함께 표로 제시. economy-designer의 경제 전제와 충돌하지 않는지 명시적으로 교차 확인 |
| level-designer | 레벨 디자이너 | 맵 구조, 지역 간 동선, 몬스터/오브젝트 배치 | 산출물 `docs\design\levels\`. 맵은 ASCII 다이어그램 + 표로 표현. systems-designer의 전투 밸런스(적정 레벨)를 참조해 배치 |
| quest-designer | 퀘스트 디자이너 | 메인/서브퀘스트 시나리오, 보상 설계 | 산출물 `docs\design\quests\`. 퀘스트는 ID, 발주 NPC, 조건, 단계, 보상(경험치/골드/명성/아이템) 표 형식. 반전 관련 퀘스트는 spoilers\에 |
| economy-designer | 이코노미 디자이너 | 골드/아이템 경제, 드랍률, 상점 가격, 영지 수입 밸런싱 | 산출물 `docs\design\economy\`. 아이템은 S/A/B/C 등급·레벨 제한 체계 준수. 인플레이션 방지 관점에서 골드 유입/소비처 균형 검토 |
| gameplay-dev | 게임플레이 프로그래머 | 플레이어 조작, 전투 코어, 이동/충돌 (GDScript) | 코드는 `godot\scripts\`, 씬은 `godot\scenes\`. 구현 전 해당 기획서 필독. 커밋 전 gdformat/gdlint 통과. 씬 구조 변경은 결과 보고에 명시 |
| systems-dev | 시스템 프로그래머 | 인벤토리, 세이브/로드, 대화, 퀘스트 로직, 도감, 게임 내 시간 (GDScript) | 데이터는 Resource(.tres) 또는 JSON으로 분리해 기획 수치를 코드에 하드코딩하지 않는다. 커밋 전 gdformat/gdlint 통과 |
| ui-dev | UI 프로그래머 | HUD, 메뉴, 인벤토리/도감 화면 (GDScript, Control 노드) | ux-designer의 레이아웃 문서 필독 후 구현. 해상도 1280x720 기준. 커밋 전 gdformat/gdlint 통과 |
| ai-dev | AI 프로그래머 | 몬스터/NPC/보스 행동 패턴 (GDScript 상태머신) | systems-designer의 전투 기획 필독. 행동 패턴은 상태 다이어그램을 주석/문서로 남긴다. 커밋 전 gdformat/gdlint 통과 |
| art-director | 아트 디렉터 | 아트 스타일 가이드, 팔레트, 비주얼 일관성 검수 | 산출물 `docs\art\STYLE_GUIDE.md` 등. 픽셀 해상도 기준(타일 크기 등)과 공통 팔레트(hex 코드)를 확정해 다른 아트 에이전트가 따르게 한다 |
| pixel-artist | 픽셀 아티스트 | 타일/UI 아이콘/파티클 텍스처를 Python Pillow 스크립트로 절차 생성, 캐릭터/몬스터 스프라이트는 CC0 에셋 소싱 | 생성 스크립트는 `godot\assets\tools\`에 보존(재생성 가능하게), 결과물은 `godot\assets\`. CC0 소싱 시 출처·라이선스를 `docs\art\ASSET_SOURCES.md`에 기록. art-director의 팔레트 준수 |
| ux-designer | UX 디자이너 | UI 레이아웃, 화면 흐름, 조작감 설계 | 산출물 `docs\art\ux\`. 화면은 ASCII 와이어프레임으로 표현. 키보드(+마우스) 조작 전제. ui-dev가 그대로 구현할 수 있는 수준으로 구체화 |
| vfx-artist | VFX 아티스트 | 스킬/폭발/타격 이펙트 (GPUParticles2D), 개별 이펙트용 셰이더 | 이펙트 씬은 `godot\scenes\vfx\`. 공용 셰이더 시스템 변경이 필요하면 직접 수정하지 말고 tech-artist 작업 요청으로 문서화 |
| tech-artist | 테크니컬 아티스트 | 공용 셰이더·후처리, 그래픽 최적화, 아트 임포트 파이프라인 | 공용 셰이더는 `godot\shaders\`. 성능 기준: 1280x720에서 60fps. 최적화 변경은 전후 측정치를 결과에 포함 |
| audio-designer | 오디오 디자이너 | SFX를 numpy 파형 합성으로 생성(.wav), BGM은 CC0 칩튠 소싱 | 생성 스크립트는 `godot\assets\tools\`, 음원은 `godot\assets\audio\`. CC0 소싱 출처는 `docs\art\ASSET_SOURCES.md`에 기록 |
| code-reviewer | 코드 리뷰어 | GDScript 코드 리뷰, 버그 탐지, 기획 대비 구현 검증 | 리뷰 시 gdlint 실행 + 해당 기획서와 대조. 결과는 `docs\qa\review-<주제>.md`. 심각도(치명/중요/사소) 구분. 코드를 직접 고치지 않고 지적만 한다 |
| alpha-tester | 알파 테스터 | Godot CLI로 게임 실행, GUT 테스트 작성·실행, 로그/스크린샷 분석, 플레이 리포트 | Godot 경로는 CLAUDE.md 참조. 리포트는 `docs\qa\playtest-<날짜>.md` — 재현 절차 포함. **리포트는 휘발성: 반영 완료 확인되면 삭제된다.** 재미/난이도 판단은 하지 않는다(디렉터 몫) — 사실(동작/오류)만 보고 |
| producer | 프로듀서 | `docs\PROJECT_STATUS.md` 백로그/진행 관리, 기획 문서 취합, **기획서 간 정합성 검증** | 정합성 검증: 기획 문서들을 교차로 읽고 모순(수치 전제 불일치, 용어 충돌, 중복 정의)을 발견하면 PROJECT_STATUS.md의 "정합성 이슈" 섹션에 기록하고 결과 보고에 플래그. 마일스톤 완료 조건에 "디렉터 승인" 포함 |

- [ ] **Step 3: 파일 개수 검증**

```powershell
(Get-ChildItem .claude\agents\*.md).Count
```
Expected: `18`

- [ ] **Step 4: 커밋**

```powershell
git add -A; git commit -m "feat: 게임 스튜디오 에이전트 18명 정의"
```

### Task 6: 동작 검증 (E2E) 및 푸시

**Files:**
- Create (에이전트가 생성): `docs\PROJECT_STATUS.md`, `docs\design\worldview-seed.md`(테스트용)

**Interfaces:**
- Consumes: Task 5의 에이전트 18명

- [ ] **Step 1: producer 호출 테스트** — Agent 툴로 `producer` 호출: "docs\PROJECT_STATUS.md 초안을 작성하라. 현재 상태: M0 구축 완료 직전, 다음 마일스톤 M1(기획 기반). 스펙(docs\superpowers\specs\2026-07-15-agent-team-design.md)의 마일스톤 절 참조."
Expected: 머리말 규칙을 갖춘 한국어 PROJECT_STATUS.md 생성

- [ ] **Step 2: 인수인계 E2E 테스트** — ① `narrative-designer` 호출: "세계관 한 단락 시드 문서를 docs\design\worldview-seed.md로 작성 (본 기획 아님, 인수인계 테스트용)". ② `systems-dev` 호출: "docs\design\worldview-seed.md를 읽고 그 내용을 3줄로 요약해 반환하라 (파일 생성 금지)."
Expected: ②의 요약이 ①의 내용과 일치 → 문서 인수인계 작동 확인. 확인 후 worldview-seed.md 삭제

- [ ] **Step 3: M0 완료 조건 전체 점검** — 스펙의 검증 기준 6개 항목 체크리스트 확인

- [ ] **Step 4: 커밋 + 푸시**

```powershell
git add -A; git commit -m "feat: M0 스튜디오 구축 완료 - 동작 검증 통과"; git push origin master
```
Expected: 푸시 성공

---

## Self-Review 결과

- 스펙 커버리지: 검증 기준 6개 항목 모두 Task 1~6에 대응됨. Dialogue Manager는 스펙상 "대화 기능 착수 시점 설치"이므로 M0 제외 (의도된 것)
- 플레이스홀더: `<GODOT_PATH>` 등은 Task 1 실행 결과로 치환되는 런타임 값으로, 치환 지침 명시됨
- 정합성: 에이전트 name 18개가 스펙 팀 구성 표와 일치
