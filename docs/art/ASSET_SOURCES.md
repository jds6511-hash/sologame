# 아트 에셋 소싱 출처 (CC0/무료 라이선스)

- **최종 수정일**: 2026-07-17
- **담당**: pixel-artist
- **의존 문서**:
  - `docs\art\STYLE_GUIDE.md` (2장 EDG32 팔레트, 3장 아웃라인/명암/프레임 규격, 7-3장 CC0 소싱 규칙)
  - `docs\design\M2_PLAN.md` (2-5장 AR-1·AR-2 태스크)
  - `docs\design\systems\m2-monster-spec.md` (몬스터 3종 실루엣·기믹 힌트)
- **변경 이력**:
  - 2026-07-17: 최초 작성 — AR-1(전사 플레이어) 플레이스홀더 제작 결정, AR-2(몬스터 3종: 들개 마수·뿔토끼·균열 점액) CC0/CC-BY 소싱 및 EDG32 재색상화 완료 기록
  - 2026-07-17: (audio-designer) 8장 추가(기존 8장 디렉터 결정 필요는 9장으로 이동) — SD-1 전투 SFX 자체 생성 기록, SD-2 시작 지역 BGM CC0 후보 소싱 시도 결과와 임시 numpy 플레이스홀더 채택 사유 기록

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

---

## 3. 들개 마수 — LPC Wolf Animation

- **출처**: https://opengameart.org/content/lpc-wolf-animation
- **제작자**: zerohero (페이지 등록자), 기여자 Mumu, William.Thompsonj (LPC 베이스 자산 공동 제작 크레딧)
- **라이선스**: CC-BY 4.0 선택 사용 (원 페이지는 CC-BY 4.0/3.0, GPL 3.0/2.0, OGA-BY 3.0 중 택1 허용 — 모두 상업적 이용 가능. 본 프로젝트는 CC-BY 4.0 기준으로 표기)
- **원본 캐시**: `godot\assets\tools\_raw_src\wolfsheet1_zerohero.png` (재다운로드 시 위 URL, 640x384, 저장소에는 커밋하지 않음 — 스크립트 재실행용 로컬 캐시)
- **가공 내용**: 원본 시트 오른쪽 절반(4족 측면 늑대, 32x32 그리드 10열x12행)에서 걷기/하울(포효)/이빨 노출 돌진/누운 포즈 프레임을 추출, 휘도 기준 EDG32 재색상화(`sprite_source_common.recolor_by_luminance`) + 1px `#181425` 아웃라인 보강.
- **한계(방향 근사)**: 원본은 **측면(側面)만** 존재한다. 하(정면)/상(후면) 방향은 정식 원화가 없어, 측면 프레임의 좌우 폭을 압축한 **간이 근사**로 대체했다 (`gen_monster_wolf.py`의 `make_down_up_approx`). 완전한 정면/후면 원화가 아니므로 시각적으로 다소 뭉개져 보일 수 있음 — 추후 정식 4족 정면/후면 원화 확보 시 교체 권장.
- **필요 표기(CC-BY)**: "LPC Wolf Animation by zerohero, Mumu, William.Thompsonj (OpenGameArt, CC-BY 4.0)" — 이후 크레딧 화면/README 제작 시(M2 범위 밖) 반영.

## 4. 뿔토끼 — Bunny Rabbit LPC style for PixelFarm

- **출처**: https://opengameart.org/content/bunny-rabbit-lpc-style-for-pixelfarm
- **제작자**: Ablu (페이지 등록자), 기여자 pennomi, tebruno99, zerohero
- **라이선스**: CC-BY 3.0 선택 사용 (원 페이지는 CC-BY 3.0/CC-BY-SA 3.0/OGA-BY 3.0 중 택1)
- **원본 캐시**: `godot\assets\tools\_raw_src\bunnysheet5_ablu.png` (재다운로드 시 위 URL 하위 `bunnysheet5.png`)
- **가공 내용**: 원본이 하/상/측 3방향 각각 "정지 포즈 2종 + 홉 이동 8프레임"을 담고 있어 idle/walk는 그대로 프레임 추출(알파 bbox 자동 검출) 후 EDG32 재색상화. 원본에 없는 공격(박치기)·사망 모션은 홉/도약 포즈를 Pillow로 전단(lean)·확대(lunge)·회전+페이드(death) 변형해 합성했다(`gen_monster_rabbit.py`).
- **실루엣 식별 요소**: STYLE_GUIDE 6-3장 지침에 따라 정수리에 작은 뿔(EDG32 `tan #c28569`, 2~3px)을 절차적으로 추가해 "뿔토끼" 정체성을 표현했다 — 현재는 작은 점 형태라 다소 미미하므로 추후 다듬어도 좋음.
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
