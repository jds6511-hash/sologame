# 상점·가방·장비 분리 및 공통 글꼴 검토

- 날짜: 2026-09-30 / 담당: Codex / 기준: `afcb001` / 대상: **`f21899e`** (`e376818` 포함, 로컬 완료·원격 미푸시)
- 변경 이력: 디렉터가 동시 배치와 거친 글씨를 반려해 [분리 설계](../design/systems/shop-inventory-typography.md)로 대체하고 인터넷에서 공식 무료 글꼴을 찾아 적용했다.

## 제품 변경

- **상점(F)**: 구매/판매 전용. 판매는 가방 소지품만, 착용품 제외. 상품 분류/검색·수량·총액·확인/취소와 장비 읽기 전용 비교를 제공하며 장착 버튼은 없다.
- **가방(B)**: 보유품·수량·장착·보관품 회수. 거래 버튼 없음. ‘장비 보기’로 별도 화면 전환.
- **장비**: 캐릭터 주변8슬롯·실제 능력치. 슬롯 선택 시 해당 부위 가방 후보만 표시하고 독립 반지 칸까지 교체한다. 해제는 가방으로, ‘가방으로’는 화면 복귀. 화면 전환은 pending·검색·이전 메시지를 초기화하며 pause를 유지한다. 모든 쓰기는 기존 EconomyRuntime.act를 통한다.
- **폰트**: Pretendard v1.3.9 Regular/SemiBold 공식 TTF와 SIL OFL 원문·출처·SHA-256을 [폰트 README](../../godot/assets/fonts/README.md)에 동봉했다. UI/HUD·대화 기본 폰트와 NPC 이름에 적용. 작은 픽셀 글자 확대 대신 MSDF와 선형 필터로 윤곽을 유지한다. 스프라이트 최근접 필터는 유지한다. 두 신규 `.import`를 명시 추적해 MSDF 설정을 보존한다.
- 디렉터의 게임 전반 폰트 적용을 위해 `project.godot`은 **gui/theme/custom_font 한 키만** 의도적으로 변경했다. 입력·창·렌더 설정 유실 없음(diff 대조). 과거 일괄 스테이징 금지를 일반적으로 해제한 것은 아니다. 저장 형식·가격·전투 판정 변경 없음.

## 검증

전체 GUT **1109/1109**,128 scripts, 관측13,509 asserts, exit0. SCRIPT ERROR0, 기존 저장 I/O ExpectedError1. 새 검사는 화면별 액션 분리, 수량 거래, 착용품 판매 제외, 반지2 교체 시 반지1 불변과 가방 회수, 폰트/MSDF 설정을 포함한다. 첫 실행의 검색 초기화 API 오류는 수정 후 전체 재검증했다.

경제 cleanup→seed→reload→cleanup **4/4 PASS** (`screenshots/m6/20260930-175207`). 최종 렌더 seed PASS, 상점·가방·장비·NPC 이름 PNG를 직접 확인했다. `M6 상점 테스트.exe --smoke` exit0. GD5개 포맷/린트·diff check 통과. 캡처는 ignored `screenshots/m6-{shop,bag,equipment,npc-names}.png`.

이번 UI/폰트 변경에 전투3회 배치는 재실행하지 않았다. 직전1/3과 **M6 채택 미통과는 유지**한다. OS 입력·미감 승인이 아닌 자동 기능/정지 렌더 증거다. [공통 한계·게이트 기록](g3-g5-functional-evidence.md).

재현: `godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit`; `powershell -ExecutionPolicy Bypass -File docs/qa/tools/run_m6_candidate.ps1`; 렌더 `godot --path godot --script ../docs/qa/tools/m6_candidate_probe.gd -- seed`.

## 검토 질문

1. 상점의 구매/판매와 가방/장비의 장착/해제가 화면·확정 동작까지 분리되고 상태 유실·pause 회귀가 없는가?
2. 슬롯 후보와 반지2 교체·수량·확인 취소가 기존 모델 계약을 지키는가?
3. 공식 폰트 출처/라이선스·MSDF 재현 설정·전역 폰트 변경 범위와 검증 한정이 정확한가?
