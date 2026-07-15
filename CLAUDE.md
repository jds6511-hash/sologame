# 2D RPG 프로젝트 (sologame)

Godot 4.x로 만드는 한국어 싱글플레이 2D 판타지 RPG. 개인 프로젝트(배포 없음).

## 절대 규칙
- 모든 산출물(문서, 게임 텍스트, 커밋 메시지)은 **한국어**로 작성한다.
- **스포일러 금지**: 스토리 반전 관련 내용은 `docs\design\spoilers\`에만 기록한다.
  사용자(디렉터) 보고에는 "반전 요소 작업 완료" 수준으로만 언급하고 내용은 절대 쓰지 않는다.
- 싱글플레이/PC 전용. 멀티플레이, 서버, PvP, 수익 모델 관련 작업 금지.

## 환경
- Godot 실행 파일: `godot` (별칭: `C:\Users\UserK\AppData\Local\Microsoft\WinGet\Links\godot.exe`, 버전 **4.7.1.stable** 고정)
- GDScript 도구: gdformat / gdlint (gdtoolkit 4.5.0)
  - 경로: `C:\Users\UserK\AppData\Local\Packages\PythonSoftwareFoundation.Python.3.12_qbz5n2kfra8p0\LocalCache\local-packages\Python312\Scripts\` (사용자 PATH에 등록됨 — 새 셸에서는 `gdformat`/`gdlint`로 실행 가능)
- Godot 프로젝트 루트: `godot\`

## git 규칙
- 작업 단위마다 커밋, 마일스톤 완료 시 `origin master`로 푸시 (원격: github.com/jds6511-hash/sologame)
- gdformat 등 일괄 포맷팅 전에는 반드시 먼저 커밋
- 커밋 메시지는 한국어, `feat:`/`fix:`/`docs:`/`chore:` 접두사 사용

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

## 마일스톤 게이트
- 각 마일스톤(M1, M2, …) 완료 시 디렉터(사용자) 승인 필수. M2(수직 슬라이스)는 디렉터가 직접 플레이하여 재미/난이도 승인.
