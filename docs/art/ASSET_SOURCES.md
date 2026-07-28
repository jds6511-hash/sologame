# 아트 에셋 소싱 출처 (CC0/무료 라이선스)

- **최종 수정일**: 2026-07-28
- **담당**: pixel-artist
- **의존 문서**:
  - `docs\art\STYLE_GUIDE.md` (2장 EDG32 팔레트, 3장 아웃라인/명암/프레임 규격, 7-3장 CC0 소싱 규칙, 1-2장·8장 — 2026-07-18 개정: G2-2 스타듀밸리 비율 정합 신규격)
  - `docs\art\m3-character-art-plan.md` (M3 3-A — 3장 CC0 후보 평가·라이선스 A/B/C 등급, 4-2장 실체 bbox 측정 규칙, 4-3장 7단계 파이프라인, 5·6장 전사·궁수 프레임 목록, 10장 파일명·시트 규약)
  - `docs\design\M2_PLAN.md` (2-5장 AR-1·AR-2 태스크)
  - `docs\design\systems\m2-monster-spec.md` (몬스터 3종 실루엣·기믹 힌트)
- **변경 이력**:
  - 2026-07-17: 최초 작성 — AR-1(전사 플레이어) 플레이스홀더 제작 결정, AR-2(몬스터 3종: 들개 마수·뿔토끼·균열 점액) CC0/CC-BY 소싱 및 EDG32 재색상화 완료 기록
  - 2026-07-17: ui-dev가 UI-1/UI-2(HUD·통합 메뉴) 구현 중 STYLE_GUIDE.md 1-3장 한글 폰트(갈무리 11/9) 소싱 기록 추가(9장) — M2_PLAN.md 지시("라이선스 SIL OFL 기록") 이행
  - 2026-07-17: (audio-designer) 8장 추가(기존 8장 디렉터 결정 필요는 9장으로 이동) — SD-1 전투 SFX 자체 생성 기록, SD-2 시작 지역 BGM CC0 후보 소싱 시도 결과와 임시 numpy 플레이스홀더 채택 사유 기록
  - 2026-07-18: 디렉터 지시(G2-2, STYLE_GUIDE 1-2장 개정)에 따라 전사 플레이어(32x32→16x32)·뿔토끼(32x32→16x16)·들개 마수(32x32→32x24) 3종 스프라이트를 신규격으로 재제작. 소싱 출처·라이선스는 변경 없음(2·3·4장에 축소 가공 내용만 추가 기록). 균열 점액은 재작업 대상 아님(캔버스 32x32 유지).
  - **2026-07-27 (pixel-artist): 디렉터 확정 스톤샤드식 안 1(STYLE_GUIDE 1-2·1-2-2·3-2-1장 개정, 커밋 42f55d7)로 4종 전 스프라이트를 신규격으로 재제작.** 전사 플레이어 16x32→**20x36**(~3.3등신, 명암 4단, 승인 샘플 디자인을 정식 3방향 애니메이션으로 확장), 뿔토끼 16x16→**20x20**(경량, 3단 절제 — 소형 프레임 명시 예외), 들개 마수 32x24→**36x28**(표준, 명암 4단, 64px 셀·최대연결성분 추출로 전신 유지), 균열 점액 32x32→**36x36**(중량, 명암 4단). 파일명·행 구성(하/측/상)·프레임 수·애니메이션 순서·소싱 원본·라이선스는 변경 없음. **점액 추가 보정**: 원본 Calciumtrice 슬라임 실체가 셀 안에서 소형(약 12x10)이라 신규 36 캔버스에서 중량 체급 목표(실체 약 30x29)에 못 미쳐 경량(토끼 18x18)보다 작아지는 체급 역전이 있었음 — NEAREST로 목표 폭 30까지 확대해 규격을 충족(재양자화 전 확대라 EDG32 유지). 공용 유틸 `sprite_source_common.recolor_ramp4`(휘도 5밴드=아웃라인+4단 램프) 신설. 3·4·5장 세부는 본 변경 이력으로 갈음.
  - **2026-07-28 (pixel-artist, M3 3-A): 10·11장 신설 — 플레이어 2직업 손그림 정식화 소스 확정.** `m3-character-art-plan.md` 4-2절이 최선행으로 지시한 **실체 bbox 측정**을 수행(도구 `measure_source_bbox.py` 신설)하고 그 결과로 소스를 재판정했다. ① **1순위 후보 Foozle(CC0)은 자동 다운로드에 성공했으나 픽셀 편입 부적합** — 실체 16x23으로 목표(15x33)보다 **높이가 11px 작고**, 근본 원인이 해상도가 아니라 **약 2두신 초변형 체형**(목표 ~3.3두신)이라 균등 축소·확대 어느 쪽으로도 규격에 도달하지 못한다(10-2절). ② **LPC 정적 레이어 합성을 채택**(실체 20x47, r=0.702 → 경로 4). M2 당시 "생성기가 JS 웹앱이라 자동화 불가"였던 실패(2장)를 리포지토리의 **정적 레이어 PNG 직접 합성**으로 해소했다(10-3·10-4절). ③ 라이선스 등급이 A(CC0)에서 **B(CC-BY-SA 3.0 선택)**로 내려가는 변경이라 9장에 디렉터 확인 항목 추가, `CREDITS.md` 동시 갱신. ④ 원본 재확보 절차를 11장에 자동화 기준으로 기록(Foozle itch.io 3단계 흐름 포함) — 계획서가 예상한 "디렉터 ZIP 수동 저장" 협조는 불필요했다.
  - 2026-07-26 (pixel-artist): 디렉터 확정 버그 수정 — 들개 마수 4시트(idle/walk/attack/death) **상반신(머리·앞다리) 누락** 재생성. 원인은 원본 측면 늑대 한 마리가 **64px 폭 셀**을 차지하는데 이전 스크립트가 소스 그리드 피치를 32px로 잘못 잡아 늑대를 반으로 갈라 뒷부분(엉덩이·꼬리·뒷다리)만 추출한 것. `gen_monster_wolf.py`를 64px 셀 크롭 + 최대 연결 성분(largest connected component) 추출 방식으로 재작성해 머리~꼬리 온전한 늑대가 셀에 들어가도록 수정(3장 갱신). 소싱 원본·라이선스·시트 크기·행 구성·프레임 수는 변경 없음. 뿔토끼·균열 점액은 동일 증상 점검 결과 정상(각각 head/blob 온전) — 재작업 없음.

> 본 문서는 `godot\assets\sprites\` 하위 캐릭터/몬스터 스프라이트 제작에 사용한 제3자 소싱 자료의 출처·라이선스를 기록한다. 절차 생성(Pillow) 산출물(타일셋·아이콘)의 출처는 해당 없음(자체 생성) — 이 문서는 **소싱 자료만** 다룬다.

---

## 1. 소싱 요약

| 대상 | 방식 | 소스 | 라이선스 |
|---|---|---|---|
| 전사 플레이어 (AR-1) | **플레이스홀더 (Pillow 절차 생성)** | 없음 — 아래 2장 참조 | 해당 없음 (자체 생성) |
| 들개 마수 (AR-2) | CC0 계열 소싱 + 방향 근사 보정 | LPC Wolf Animation | CC-BY 4.0 |
| 뿔토끼 (AR-2) | CC0 계열 소싱 + 합성 보완(공격/사망) | Bunny Rabbit LPC style for PixelFarm | CC-BY 3.0 |
| 균열 점액 (AR-2) | CC0 계열 소싱 (그대로 재색상화) | Animated Slime | CC-BY 3.0 |

---

## 2. 전사 플레이어 (AR-1) — 플레이스홀더 사유

**CC0/무료 소싱을 먼저 시도했으나 적합한 자료를 찾지 못했다.**

- OpenGameArt에서 판타지 검사(劍士) 계열을 검색한 결과, 대부분 **LPC(Liberated Pixel Cup)** 규격 캐릭터였다. LPC는 몸/의상/무기가 레이어로 분리되어 있어, 완성된 한 장의 스프라이트시트를 얻으려면 "Universal LPC Spritesheet Character Generator"라는 **인터랙티브 웹 생성기**를 통해 조합을 뽑아야 한다 — 이 세션 환경(Pillow 스크립트 + curl/WebFetch)에서는 JS 웹앱을 구동해 결과물을 내려받을 수 없어 자동화 파이프라인에 포함할 수 없었다.
- 정적으로 바로 내려받을 수 있는 CC0 캐릭터인 **"32x32 RPG Character Sprites" / RPGSoldier32x32.png**(CC0, https://opengameart.org/content/32x32-rpg-character-sprites)를 검토했으나, SF 우주복 스타일(헬멧·바이저)이라 판타지 전사 톤에 맞지 않고, walk/standing/차징 포즈만 있어 attack/hit/death 애니메이션이 없어 M2 완료 기준(idle/walk/attack/hit/death 5종)을 못 채운다.
- 위 사유로 이번 M2에서는 **Pillow 절차 생성 플레이스홀더**를 제작했다 (디렉터 지시 "M2는 손맛 검증 목적 — 플레이스홀더로 게이트 통과 가능"에 따름). 실루엣 크기·발밑 기준점·EDG32 팔레트·1px 아웃라인·프레임 예산(57/90)은 STYLE_GUIDE 규격을 그대로 준수한다.
- **추후 교체 필요**: 정식 전사 원화(CC0 소싱 재시도 또는 커미션)로 교체 시 `godot\assets\tools\gen_player_warrior.py`의 출력만 대체하면 된다 (파일명·시트 규격 유지).
- **2026-07-18 개정(G2-2, 스타듀밸리 비율 정합)**: STYLE_GUIDE 1-2장 개정으로 캔버스가 **32x32 → 16x32(1타일x2타일, 날씬한 인간형)**로 슬림화됐다. 세로(32px)는 기존과 동일하게 유지하고 가로(32→16)만 절반으로 좁혀 각 부위 X좌표를 재설계했다(실체 약 12x28, 머리 폭 8px). 파일명·행 구성(하/측/상)·프레임 수(idle4/walk6/attack4/hit1/death4)·애니메이션 순서는 변경 없음. 여전히 Pillow 절차 생성 플레이스홀더이며 교체 필요성은 그대로 유효하다.

---

## 3. 들개 마수 — LPC Wolf Animation

- **출처**: https://opengameart.org/content/lpc-wolf-animation
- **제작자**: zerohero (페이지 등록자), 기여자 Mumu, William.Thompsonj (LPC 베이스 자산 공동 제작 크레딧)
- **라이선스**: CC-BY 4.0 선택 사용 (원 페이지는 CC-BY 4.0/3.0, GPL 3.0/2.0, OGA-BY 3.0 중 택1 허용 — 모두 상업적 이용 가능. 본 프로젝트는 CC-BY 4.0 기준으로 표기)
- **원본 캐시**: `godot\assets\tools\_raw_src\wolfsheet1_zerohero.png` (재다운로드 시 위 URL, 640x384, 저장소에는 커밋하지 않음 — 스크립트 재실행용 로컬 캐시)
- **가공 내용**: 원본 시트 오른쪽 절반(4족 측면 늑대)에서 걷기(B행)/하울(고개 치켜듦, A행)/이빨 노출 물기(D행)/웅크림·정지(TOP행) 프레임을 추출, 휘도 기준 EDG32 재색상화(`sprite_source_common.recolor_by_luminance`) + 1px `#181425` 아웃라인 보강.
- **2026-07-18 개정(G2-2, 출력 캔버스 재조정)**: STYLE_GUIDE 1-2장 개정으로 **출력 캔버스가 32x32 → 32x24(표준 체급)로 축소**됐다. 추출 후 실체 bbox가 목표(가로 26/세로 16)를 넘으면 종횡비 유지 NEAREST 축소(`TARGET_W`/`TARGET_H`)를 팔레트 재양자화 전에 적용해 32x24 신규격에 맞췄다. 소싱 원본·라이선스는 변경 없음.
- **2026-07-26 수정(상반신 누락 버그)**: 원본 측면 늑대 한 마리는 **머리+앞다리(앞쪽 32px) + 몸통+뒷다리+꼬리(뒤쪽 32px) = 64px 폭 셀**을 차지한다. 이전 버전은 소스 그리드 피치를 32px로 잘못 잡아 한 마리를 반으로 갈라 **뒷부분만** 추출 → 게임에서 머리·앞다리 없는 늑대로 표시됐다. 수정본은 **64px 셀(`SRC_CELL_W`)** 단위로 크롭하고 셀 안 최대 연결 성분(scipy `ndimage.label`)만 남겨 인접 프레임 잔상을 제거한 뒤 autotrim → 머리~꼬리 온전한 늑대를 얻는다. 프레임 매핑도 온전한 소스 프레임 기준으로 재정의(idle=TOP0/1, walk=B0~3, attack=A2/A3 하울 예고+D2/D3 물기 발동+B0 회수, death=A3 젖힘/TOP2 웅크림/TOP3 주저앉음/페이드). 신규 의존성: `numpy`, `scipy`(로컬 설치 확인). 소싱 원본·라이선스·시트 크기·행 구성·프레임 수·애니메이션 순서는 변경 없음.
- **한계(방향 근사)**: 원본은 **측면(側面)만** 존재한다. 하(정면)/상(후면) 방향은 정식 원화가 없어, 측면 프레임의 좌우 폭을 압축한 **간이 근사**로 대체했다 (`gen_monster_wolf.py`의 `make_down_up_approx`). 완전한 정면/후면 원화가 아니므로 시각적으로 다소 뭉개져 보일 수 있음 — 추후 정식 4족 정면/후면 원화 확보 시 교체 권장.
- **필요 표기(CC-BY)**: "LPC Wolf Animation by zerohero, Mumu, William.Thompsonj (OpenGameArt, CC-BY 4.0)" — 이후 크레딧 화면/README 제작 시(M2 범위 밖) 반영.

## 4. 뿔토끼 — Bunny Rabbit LPC style for PixelFarm

- **출처**: https://opengameart.org/content/bunny-rabbit-lpc-style-for-pixelfarm
- **제작자**: Ablu (페이지 등록자), 기여자 pennomi, tebruno99, zerohero
- **라이선스**: CC-BY 3.0 선택 사용 (원 페이지는 CC-BY 3.0/CC-BY-SA 3.0/OGA-BY 3.0 중 택1)
- **원본 캐시**: `godot\assets\tools\_raw_src\bunnysheet5_ablu.png` (재다운로드 시 위 URL 하위 `bunnysheet5.png`)
- **가공 내용**: 원본이 하/상/측 3방향 각각 "정지 포즈 2종 + 홉 이동 8프레임"을 담고 있어 idle/walk는 그대로 프레임 추출(알파 bbox 자동 검출) 후 EDG32 재색상화. 원본에 없는 공격(박치기)·사망 모션은 홉/도약 포즈를 Pillow로 전단(lean)·확대(lunge)·회전+페이드(death) 변형해 합성했다(`gen_monster_rabbit.py`).
- **실루엣 식별 요소**: STYLE_GUIDE 6-3장 지침에 따라 정수리에 작은 뿔(EDG32 `tan #c28569`, 2~3px)을 절차적으로 추가해 "뿔토끼" 정체성을 표현했다 — 현재는 작은 점 형태라 다소 미미하므로 추후 다듬어도 좋음.
- **2026-07-18 개정(G2-2, 출력 캔버스 재조정)**: STYLE_GUIDE 1-2장 개정으로 **출력 캔버스가 32x32 → 16x16(경량 체급)로 축소**됐다. 크롭+autotrim한 원본 bbox의 최대 변 길이가 14px를 넘으면 팔레트 재양자화 전에 NEAREST로 비율 축소(`gen_monster_rabbit.py`의 `TARGET_MAX_DIM`)해 16x16 신규격에 맞췄고, 뿔도 1~2px로 비례 축소했다. 소싱 원본·라이선스는 변경 없음.
- **필요 표기(CC-BY)**: "Bunny Rabbit LPC style for PixelFarm by Ablu, pennomi, tebruno99, zerohero (OpenGameArt, CC-BY 3.0)"

## 5. 균열 점액 — Animated Slime

- **출처**: https://opengameart.org/content/animated-slime
- **제작자**: Calciumtrice
- **라이선스**: CC-BY 3.0
- **원본 캐시**: `godot\assets\tools\_raw_src\slime_calciumtrice.png` (재다운로드 시 위 URL 하위 `slime spritesheet calciumtrice.png`)
- **가공 내용**: 원본이 32x32 정확한 10열x20행 그리드(4색 변형 x idle/gesture/walk/attack/death x 10프레임)로 깔끔하게 정렬돼 있어 그리드 좌표로 직접 추출, EDG32 균열 팔레트(`dark_maroon`/`dark_purple`/`purple`)로 재색상화, 몸통 중심에 청록색(`cyan #2ce8f5`) 2x2 발광 코어를 추가해 `m2-monster-spec.md` 3-3장의 "핵" 시각 요구를 반영했다.
- **방향 처리**: 슬라임은 원형 대칭 실루엣이라 방향별 시각 차이가 없어 하/측/상 3행에 동일 프레임을 사용했다 (STYLE_GUIDE 3-3 "3방향 제작" 포맷은 유지, 내용은 대칭 단순화 — 의도된 결정).
- **필요 표기(CC-BY)**: "Animated Slime by Calciumtrice (OpenGameArt, CC-BY 3.0)"

---

## 6. 라이선스 표기 관련 참고

- pixel-artist 역할 정의(CLAUDE.md)는 "CC0(또는 상업적 이용 가능 무료) 라이선스만 사용"을 허용 범위로 명시하고 있어, 이번 3종 모두 **CC-BY(저작자 표시)** 라이선스를 채택했다 — CC0보다 한 단계 제약이 있는 라이선스이므로 정식 배포 전에는 위 5개 저작자 표기를 게임 크레딧에 반영해야 한다(현재 개인 프로젝트/비배포 단계라 즉시 조치는 불필요, 백로그로 기록).
- `STYLE_GUIDE.md` 7-3장은 "CC0만 허용"으로 더 엄격하게 적혀 있어 본 문서의 CC-BY 사용과 차이가 있다 — **디렉터 확인 필요**: 향후 배포를 고려한다면 CC-BY 자료를 CC0로 교체하거나, STYLE_GUIDE 7-3장을 "CC0 또는 상업적 이용 가능 무료(출처 표기)"로 개정할지 결정 필요.

## 7. 재현 방법 (스크립트 재실행)

원본 소싱 파일은 저장소에 커밋하지 않는다(제3자 파일 용량·재배포 부담 최소화). 재생성이 필요하면:

1. 위 각 항목의 URL에서 원본 PNG를 내려받아 `godot\assets\tools\_raw_src\` 아래 지정된 파일명으로 저장
2. `python godot\assets\tools\gen_monster_slime.py` / `gen_monster_wolf.py` / `gen_monster_rabbit.py` / `gen_player_warrior.py` 실행
3. `python godot\assets\tools\validate_palette.py` 로 팔레트 위반 0건 확인

## 8. 오디오 소싱 (SD-1·SD-2, audio-designer)

### 8-1. SD-1 전투 SFX — 자체 생성 (소싱 아님)

전투 SFX 8종(기본 공격 히트 약/중/강, 스킬 히트, 회피 대시, 플레이어 피격, 몬스터 사망, 포션 사용)은 전부 numpy 파형 합성 자체 생성물이다. 제3자 소싱 자료가 아니므로 본 장의 라이선스 기록 대상이 아니다(`godot\assets\CREDITS.md`에 자체 생성 명시만 기록). 생성 스크립트: `godot\assets\tools\gen_combat_sfx.py`.

### 8-2. SD-2 시작 지역 BGM — CC0 소싱 시도 및 임시 대체 사유

`audio-direction.md` 1-2장 기준 시작 지역(동부 변경 남측) BGM 요구: "개척·새싹·모험의 첫걸음", 보통 템포(100~120), 밝은 장조 필드곡 — `STYLE_GUIDE.md` 8장 요약 "재건과 긴장"(재건=희망, 긴장=변경의 위험). OpenGameArt.org에서 CC0 라이선스 곡을 검색해 아래 후보를 확인했다:

| 후보 곡 | 제작자 | 라이선스 | URL | 채택 여부 |
|---|---|---|---|---|
| Town Theme RPG | cynicmusic | CC0 | https://opengameart.org/content/town-theme-rpg | 보류 — 태그가 "calm/home/cabin"으로 마을 휴식곡에 가까워 "모험의 첫걸음" 필드곡보다는 평화(S2) 슬롯에 더 적합해 보임 |
| Adventure Theme | CleytonKauffman | CC0 | https://opengameart.org/content/adventure-theme | 보류 — 태그가 "Rock/fast/drums/racecar"로 록 하이브리드에 가까워 칩튠 톤·필드 탐험 템포(100~120)와 어긋날 가능성 |
| The Field Of Dreams | pauliuw | CC0 | https://opengameart.org/content/the-field-of-dreams | 보류 — 설명상 "밤(Night)" 멜로디의 리메이크로 차분한 야간/시네마틱 톤이라 밝은 장조 주간 필드곡과 결이 다름 |
| Overworld Theme | remaxim | CC-BY | https://opengameart.org/content/overworld-theme | 참고용(CC-BY, 디렉터의 CC-BY 허용 결정 전이라 미채택) |

세 CC0 후보 모두 페이지의 태그·설명만으로 확인한 것으로, **실제 청취 검증(템포·조성·악기 편성이 "개척+긴장"의 균형에 맞는지)을 거치지 않았다** — audio-designer가 오디오 파일을 직접 들어볼 수단이 없어(텍스트 기반 확인만 가능) 섣불리 확정하면 잘못된 곡이 기준 슬롯에 고정될 위험이 있다고 판단, 이번 M2에서는 **임시 numpy 합성 화음 패드**(`bgm_field_eastern_frontier_south_TEMP.ogg`, 생성 스크립트 `godot\assets\tools\gen_bgm_placeholder.py`)로 자리를 채웠다. 밝은 장조(C-G-Am-F) 진행에 3번째 마디(Am)만 은은한 텐션을 주어 "희망 속의 긴장"을 표현했다.

**추후 조치**: 위 3개 CC0 후보를 director 또는 후속 오디오 패스에서 실제로 청취해 채택 여부를 판정하거나, 추가 후보를 탐색해 정식 곡으로 교체한다. 교체 시 `godot\assets\audio\bgm\` 하위 파일명을 `bgm_field_eastern_frontier_south.ogg`(TEMP 접미사 제거)로 정리하고 본 장·`CREDITS.md`를 갱신한다.

## 9. 디렉터 결정 필요

- 6장의 CC-BY vs STYLE_GUIDE 7-3 "CC0만 허용" 불일치 — 현재는 비배포 개인 프로젝트라 즉시 리스크는 낮으나, 정책을 명확히 할지 결정 필요.
- 전사 플레이어(AR-1) 플레이스홀더를 정식 원화로 교체할 시점(다음 아트 패스 vs M2 이후 백로그) 결정 필요.
- **SD-2 BGM**: 위 8-2절 CC0 후보 3곡의 실제 청취 판정, 또는 임시 numpy 패드를 M2 게이트 통과용으로 유지한 채 정식 소싱을 M3 이후로 미룰지 결정 필요.
- **M3 3-A 소스 등급 변경(10-3절)**: 플레이어 정식화 베이스를 A등급(Foozle CC0)에서 **B등급(LPC, CC-BY-SA 3.0 선택)**으로 변경했다. `m3-character-art-plan.md` 3-2절의 "플레이어는 A등급으로 고정" 확정을 측정 결과(10-2절 두신 불일치)에 따라 뒤집은 것이므로 확인이 필요하다. 되돌릴 경우의 대안은 "2두신 치비 수용(= 2026-07-27 스톤샤드식 안 1 되돌림)" 또는 "전량 손그림 재작화(경로 5)"뿐이다.

---

## 10. M3 3-A — 플레이어 2직업 손그림 정식화 소스 (2026-07-28)

`docs\art\m3-character-art-plan.md` 4-2절이 지시한 **실체 bbox 측정**을 최선행으로 수행한 결과와 그에 따른 소스 판정을 기록한다. 측정 도구는 `godot\assets\tools\measure_source_bbox.py`(신설, 재실행 가능).

### 10-1. 측정 결과 (목표 실체 15x33 = `STYLE_GUIDE` 1-2)

| 소스 | 라이선스 | 실체 W0xH0 | r = min(15/W0, 33/H0) | 균등 축소 결과 | 계획서 경로 | 판정 |
|---|---|---|---:|---|---|---|
| **Foozle "Legend: Main Character"** (1순위 후보) | **CC0 (A등급)** | **16 x 23** (idle front) / 16x22 (side) / 20x23 (활 side) | **0.938** | **15 x 22** | 형식상 경로 3 | **픽셀 편입 부적합 — 아래 10-2** |
| **LPC 정적 레이어 합성** (2순위 후보) | OGA-BY 3.0 / CC-BY-SA 3.0 / GPL 3.0 택1 (**B등급**) | **20 x 47** (side) / 30x47 (front, 팔 벌림 포함) | **0.702** (높이 기준) | **14 x 33** | **경로 4** | **채택 — 아래 10-3** |

- Foozle 시트 구조(측정 중 확정): `1344x4928` = 64px 셀 21열 x 77행, **행 1개 = 애니메이션 1개**(`.aseprite` 프레임 태그 순서와 1:1 대응, 그룹 태그 DOWN/SIDE/UP은 행을 차지하지 않음). 방향별 주요 행 — front: idle 1 / walk 3 / 검 7·8·9 / 활 10·12 / death 24, side: idle 27 / walk 29 / 검 33·34·35 / 활 39·40 / death 50, back: idle 52 / walk 54 / 검 58·59·60 / 활 64·65 / death 75.
- **자동 다운로드는 성공했다** — 계획서 3-2절·12장 3번이 예상한 "디렉터 ZIP 수동 저장" 협조는 **불필요했다**. itch.io "name your own price" 무료 배포의 3단계 흐름(`/purchase` → `POST /download_url` → `POST /file/<upload_id>?source=game_download`)을 CSRF 토큰과 함께 따라가면 직접 내려받을 수 있다. 재현 절차는 11장.
- LPC도 **JS 웹앱을 구동하지 않고 확보했다** — 2장이 기록한 M2 실패 사유("생성기가 인터랙티브 웹앱이라 자동화 불가")를 계획서 3-2절이 제시한 우회로(리포지토리의 **정적 레이어 PNG를 Pillow로 직접 합성**)로 해소했다. 레이어 목록은 리포지토리 `CREDITS.csv`(약 4MB, 자산별 저작자·라이선스 포함)로 확인한다.

### 10-2. Foozle(CC0, A등급) 부적합 판정 — "왜 A등급으로 안 되는가" (3-3절 기록 의무)

**r 값만 보면 경로 3(비용 최소)이지만, r 공식은 오판을 유발한다.** 공식은 "원본이 목표보다 크다 → 축소한다"를 전제하는데, Foozle 원본은 **높이가 목표보다 작다**(23 < 33).

1. **균등 축소하면 15x22 — 목표 높이 33px에 11px(33%) 미달한다.** 20x36 캔버스의 아래쪽 22px만 차는 캐릭터가 되어, 세계(16px 타일) 대비 인간형 크기가 M2 이전 수준으로 되돌아간다.
2. **근본 원인은 해상도가 아니라 두신(頭身) 비율이다.** 측정한 폭 프로파일(위→아래 `8,10,12,12,14,15,16,16,...`)에서 실체 최대폭 16px이 **y=6부터** 나타난다 — 즉 후드/머리가 이미 몸통 최대폭과 같고, 머리가 전체 높이의 절반 가까이를 차지하는 **약 2두신 초변형(super-deformed) 체형**이다. 프리뷰 육안 확인으로도 동일하다.
3. **목표는 ~3.3두신**(`STYLE_GUIDE` 1-2)이다. 2두신 원본에서 3.3두신을 얻는 방법은 (a) 세로 1.43배 비균등 확대 — 머리가 달걀형으로 찌그러지고 1-1절 "비정수·비균등 스케일 금지"에 정면 위반, (b) 몸통·다리를 11px 새로 그려 넣기 — 그 시점에 원본 픽셀은 남지 않으므로 **경로 5(전량 재작화)와 같아진다**. 어느 쪽도 "CC0 완성 픽셀을 쓴다"는 채택 이유를 성립시키지 못한다.
4. **2두신을 그대로 수용하는 선택지는 아트 디렉션 되돌림이다.** 2026-07-27 디렉터 승인 "스톤샤드식 안 1"(치비 2.5두신 → 3.3두신 상향)을 무효화하게 되므로 pixel-artist 권한 밖이다 → 12장 디렉터 결정 항목.

**결론**: Foozle은 **자세·프레임 타이밍 참고 및 애니메이션 매핑 검증용**으로만 유지하고 픽셀은 편입하지 않는다. 원본 ZIP은 `_raw_src\`에 캐시돼 있어 판정 재검토 시 즉시 재측정할 수 있다.

### 10-3. LPC(B등급) 채택 — 근거와 기록 의무

계획서 3-1절 선정 기준을 측정값으로 다시 채점하면 LPC가 1·2·3·4·5·6 중 **라이선스(기준 1)를 제외한 전 항목에서 우위**다.

| 기준 | Foozle | LPC |
|---|---|---|
| 1 라이선스 등급 | **A (CC0)** | B (OGA-BY 3.0 / CC-BY-SA 3.0 / GPL 3.0 택1) |
| 2 탑다운 4방향 | O | O (행 순서 up / left / down / right) |
| 3 검 + 활 동시 보유 | O (검3·활2) | **O (slash / thrust / backslash / halfslash / shoot + 활 background·foreground 레이어)** |
| 4 **실체 bbox가 20x36에 근접** | **X (16x23, 2두신)** | **O (20x47, r=0.702 → 14x33 — 목표 높이 정확히 충족)** |
| 5 정적 다운로드 | O | O (GitHub raw, 레이어별 PNG) |
| 6 hurt / die 보유 | O | O (`hurt.png`) |
| (추가) 상태 커버리지 | 20종+ | idle / walk / run / slash / thrust / backslash / halfslash / shoot / spellcast / hurt / jump / climb / sit / emote (14종) x 전 레이어 공통 |

- **`STYLE_GUIDE` 7-3 / 계획서 3-3절 B등급 조건 충족**: 비배포 개인 프로젝트 전제(`CLAUDE.md`)를 명시하고 `godot\assets\CREDITS.md` + 본 문서 양쪽에 저작자·라이선스·URL·선택 라이선스를 기록한다. **선택 라이선스 = CC-BY-SA 3.0** (OGA-BY 3.0도 가능하나, 파생물 동일 라이선스 의무를 명시적으로 받아들이는 쪽을 골라 배포 검토 시 재검토 대상임을 분명히 남긴다).
- **A등급 우선 원칙의 예외 사유 1행(3-3절 기록 의무)**: *유일한 A등급 후보(Foozle)가 두신 2 대 목표 3.3의 비율 불일치로 픽셀 편입이 불가능해, B등급 중 규격이 맞는 LPC를 택했다.*
- **화풍 통일은 유지된다** — 전사·궁수 모두 동일 LPC 베이스(같은 body/head/두신/아웃라인 두께)에서 나오므로 계획서 4-3절 "화풍 통일 의무"를 충족한다. 계획서가 LPC를 이미 **인간형 적(무법자·노상강도·밀렵꾼) 보강용으로 병용 확정**했으므로, 플레이어까지 LPC로 통일하면 오히려 **플레이어와 인간형 적의 화풍이 자동 일치**한다(계획서 9-4절 "화풍 분열" 리스크가 축소된다).
- **디렉터 결정 필요**: 계획서 3-2절은 "플레이어는 가장 교체하기 어려운 자산이므로 A등급(CC0)으로 고정"을 명시 확정했다. 본 절은 그 확정의 **전제(A등급 후보가 규격에 맞는다)가 측정으로 무너진 결과**이므로 pixel-artist 판정으로 처리하되, 정책 확정 사항의 변경이라 12장에 디렉터 확인 항목으로 올린다.

### 10-4. 사용 LPC 레이어 (재현용 목록)

리포지토리: https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator (`master`, `spritesheets/` 하위). 각 레이어는 애니메이션별 PNG(`idle` `walk` `slash` `thrust` `shoot` `spellcast` `hurt` `jump` `run` ...)로 분리돼 있고, 프레임 셀은 64x64(무기 oversize 시트는 128x128), 행 = 방향(0 up / 1 left / 2 down / 3 right).

| 역할 | 경로(`spritesheets/` 기준) | 비고 |
|---|---|---|
| 몸(피부, 머리 제외) | `body/bodies/male/<anim>.png` | **머리가 포함되지 않는다** — 측정 시 이것만 재면 H0=30이 나와 두신을 오판한다 |
| 머리 | `head/heads/human/male/<anim>.png` | 몸과 합성해야 실체 H0=47 |
| 머리카락 | `hair/plain/adult/<anim>.png` | |
| 상의(전사) | `torso/armour/legion/male/<anim>.png` | 판금 느낌 → 강철 램프 |
| 상의(궁수) | `torso/clothes/longsleeve/longsleeve/male/<anim>.png` | 천 → 초록 램프(수림 궁수) |
| 하의 | `legs/pants/male/<anim>.png` | |
| 신발 | `feet/boots/basic/male/<anim>.png` | |
| 검 | `weapon/sword/longsword/{walk,hurt}.png` + `{slash,slash_reverse,thrust}_oversize.png` | oversize = 128x128 셀 |
| 활 | `weapon/ranged/bow/normal/universal/{background,foreground}/{walk,shoot,hurt}.png` | 손 앞/뒤 2레이어로 나뉘어 있어 몸 위·아래에 각각 합성 |
| 화살 | `weapon/ranged/bow/arrow/shoot.png` | |
| 화살통 | `quiver/{walk,shoot,slash,thrust,spellcast,hurt}.png` | 궁수 실루엣 보강 |

## 11. Foozle / LPC 원본 재확보 절차 (자동, 커밋 금지)

`_raw_src\`는 저장소에 커밋하지 않으므로 재현 시 아래를 실행한다. 두 소스 모두 **브라우저 수동 조작 없이** 확보된다.

1. `python godot\assets\tools\fetch_lpc_layers.py` — LPC 레이어 PNG를 `_raw_src\lpc\` 아래 원본 경로 구조로 내려받는다(GitHub raw, 인증 불필요).
2. Foozle(참고용, 선택): itch.io 무료 배포 흐름을 순서대로 따른다 — ① `GET https://foozlecc.itch.io/legend-main-character/purchase`에서 `<meta name="csrf_token">` 추출 ② 같은 토큰으로 `POST /legend-main-character/download_url` → JSON `url` ③ 그 페이지에서 `data-upload_id` 추출 ④ `POST /legend-main-character/file/<upload_id>?source=game_download` → JSON `url`이 실제 파일 링크. **주의**: ③의 다운로드 페이지 토큰은 수십 초 만에 만료되므로 ①~④를 한 프로세스에서 연속 실행해야 한다. `POST /download/<token>/file/<id>` 형태는 404다.
3. `python godot\assets\tools\gen_player_lpc.py` 실행 → 스프라이트시트 재생성.
4. `python godot\assets\tools\validate_palette.py` 로 팔레트 위반 0건 확인.
