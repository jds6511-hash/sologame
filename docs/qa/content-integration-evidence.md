# 콘텐츠 통합 검증 기록

- 2026-10-02 / Codex. 기준 `d9c9d9c`. 제품 V6 / 콘텐츠 개정 1. [요청서](content-integration-review-request.md), [공통 범위](automated-evidence-boundaries.md).
- 변경 이력: 단일 검증·실제 저장 복사본·실행기 결과 기록. 후속 생성기/예산 검사는 이번 범위에서 제외.

## 최종 실행

`powershell -NoProfile -ExecutionPolicy Bypass -File docs/qa/tools/verify_all.ps1`

배치 `docs/qa/screenshots/verify-all/20261002-214353-438/result.json`: **status=pass, 107/107, exit0, actual_unchanged=true**. `-Combat`은 실행하지 않았다.

| 검사 | 결과 |
|---|---|
| 전체 GUT | 1,162/1,162, 135 scripts, 14,178 asserts |
| 구 세션·이관 | M4/M5/C1 16단계 |
| 의뢰 API | 최초/3번째·4번째·출발 31단계 |
| 파일 교체 중단 | 2경로 10단계, 정상 반환 금지와 후속 파일 복구 함께 확인 |
| M6/M7/V7 동결 API | 13단계 |
| 도보 여행·직업 메뉴 | 5+12단계 |
| 제품 이관·2장 중간/완료 복원 | 5+5단계 |
| 실제 V4 슬롯1·V5 슬롯3 복사본 | 이관/별도 프로세스 복원 4단계 |
| 실패 감지 가드 | 5단계, 선행 실패·사망 감지 확인 |

실제 `user://saves`의 **6개 파일** 해시가 전후 동일하다. 복사는 `user://product_real_copy`에서만 불러오기·직접 저장·구 파일 백업·재시작 비교를 수행했다. 원본을 쓰거나 복원하지 않았다. 이전 탐색 실행 세 번의 실패 로그도 보존되어 있으며 최종 결과에 합치지 않았다.

GUT의 의도적 저장 I/O ExpectedError 1건을 허용했다. **43단계에서 기존 Ogg 종료 잔존**을 기록했다. verbose의 누수 타입이 Ogg 4종뿐이고 정확한 `2/4 resources still in use at exit` 문구일 때만 비차단으로 분류한다. JSON의 warnings/leaked_types/known_ogg_shutdown에 근거가 남는다. 일반 ERROR·SCRIPT ERROR는 실패다. 잔존 경고 해소·오류 로그 0건을 주장하지 않는다.

## 추가 확인

- GDScript 26개 gdformat --check/gdlint, PowerShell 구문, git diff --check 통과.
- 시작 화면 및 2·3장 준비 상태: `product_start_preview.gd` 렌더 PASS. 캡처는 ignored `screenshots/product-start/`이며 직접 확인했다. 3장 콘텐츠가 없다는 안내를 표시한다.
- `게임 실행.exe` 재생성 및 `--smoke` 실행에서 PRODUCT_READY chapter=0, 엔진 오류 없음. 로그 `screenshots/launcher/game-20261002-212233-886.log`.
- 과거 후보 exe 4개는 ignored `screenshots/retired-launchers/`로 이동했다. 게임 폴더의 현재 exe는 하나다.
- 내부 정적 검토에서 추가 결함은 발견하지 못했다. Claude의 독립 검토를 대신하지 않는다.

기존 QA 도구의 낡은 버전 기대값·없는 폴더 정리·가드 실행 모드는 단일 실행 연결 과정에서 바로잡았다. 기본 검증에도 렌더/포인터를 쓰는 가드가 있다. 제품 2장 완주는 API 준비/이벤트 증거이며 새 도보·전투 표본이 아니다. 미감·체감은 3장 이후 1막 종료에 모은다.