# 에셋 크레딧 (CC0/무료 소싱 자료)

- **최종 수정일**: 2026-07-28
- **담당**: pixel-artist

> 소싱 출처·라이선스·가공 내용의 전체 기록은 `docs\art\ASSET_SOURCES.md`를 참조한다. 이 파일은 `STYLE_GUIDE.md` 7-3장이 요구하는 최소 크레딧 목록이다.

| 자산 | 제작자 | 라이선스 | 출처 |
|---|---|---|---|
| 들개 마수 스프라이트 원본 | zerohero, Mumu, William.Thompsonj | CC-BY 4.0 | https://opengameart.org/content/lpc-wolf-animation |
| 뿔토끼 스프라이트 원본 | Ablu, pennomi, tebruno99, zerohero | CC-BY 3.0 | https://opengameart.org/content/bunny-rabbit-lpc-style-for-pixelfarm |
| 균열 점액 스프라이트 원본 | Calciumtrice | CC-BY 3.0 | https://opengameart.org/content/animated-slime |

## 플레이어 2직업 정식 스프라이트 (M3 3-A, 2026-07-28) — B등급 표기 의무

전사·궁수의 정식 스프라이트(`player_warrior_v2_*`, `player_archer_*`)는 **Universal LPC Spritesheet** 프로젝트의 정적 레이어 PNG를 합성·축소·EDG32 재색상해 제작했다. `docs\art\m3-character-art-plan.md` 3-3장의 **B등급 표기 의무** 대상이므로 아래를 필수 기록한다.

- **선택 라이선스**: **CC-BY-SA 3.0** (원본은 `OGA-BY 3.0 / CC-BY-SA 3.0 / GPL 3.0` 중 택1 허용)
- **전제**: 본 프로젝트는 `CLAUDE.md`에 명시된 **비배포 개인 프로젝트**다. CC-BY-SA 3.0은 파생물에 동일 라이선스 의무가 있으므로, **배포를 검토하는 시점에 전면 재검토가 필요**하다(`docs\art\ASSET_SOURCES.md` 9·10-3장).
- **출처**: https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator · https://opengameart.org/content/lpc-character-bases · https://opengameart.org/content/lpc-medieval-fantasy-character-sprites · https://opengameart.org/content/lpc-extended-weapon-animations

| 사용 레이어 | 저작자 |
|---|---|
| 몸(`body/bodies/male`) | bluecarrot16, JaidynReiman, Benjamin K. Smith (BenCreating), Evert, Eliza Wyatt (ElizaWy), TheraHedwig, MuffinElZangano, Durrani, Johannes Sjölund (wulax), Stephen Challener (Redshrike) |
| 머리(`head/heads/human/male`) | bluecarrot16, Benjamin K. Smith (BenCreating), Stephen Challener (Redshrike) |
| 머리카락·상의·하의·신발 | 위 LPC 기여자 및 각 자산 기여자 — 자산별 전체 목록은 리포지토리 `CREDITS.csv` 참조 |
| 검(`weapon/sword/longsword`) | Johannes Sjölund (wulax), bluecarrot16 |
| 활(`weapon/ranged/bow/normal`) · 화살 · 화살통(`quiver`) | Johannes Sjölund (wulax) |

> 위 저작자 목록은 리포지토리 `CREDITS.csv`의 해당 행에서 그대로 옮긴 것이다. 사용 레이어를 추가하면 `CREDITS.csv`를 다시 확인해 이 표를 갱신한다.

**참고 전용(픽셀 미편입)**: Foozle "Legend - Main Character"(CC0, https://foozlecc.itch.io/legend-main-character, Atari Boy 제작 / Foozle 배포)는 두신 비율 불일치로 픽셀을 편입하지 않았다(`ASSET_SOURCES.md` 10-2장). CC0라 표기 의무는 없으나 판정 이력 보존을 위해 기록한다.

M2 시절 전사 플레이스홀더(`godot\assets\tools\gen_player_warrior.py`, 파일명 `player_warrior_*`)는 Pillow 절차 생성물이라 저작자 표기가 필요 없다(자체 생성). 회귀 대비로 병존 보존한다.

---

## 오디오 (SD-1·SD-2, audio-designer)

- 전투 SFX 8종(`godot\assets\audio\sfx\`)은 numpy 파형 합성 자체 생성물이며 저작자 표기가 필요 없다 — 재생성 스크립트 `godot\assets\tools\gen_combat_sfx.py`.
- 시작 지역 BGM(`godot\assets\audio\bgm\bgm_field_eastern_frontier_south_TEMP.ogg`)은 **임시 numpy 합성 화음 패드**다 — CC0 소싱 곡이 아니므로 저작자 표기 대상이 아니지만, **추후 정식 CC0/CC-BY 소싱 곡으로 교체 예정**(사유·후보는 `docs\art\ASSET_SOURCES.md` 참조). 재생성 스크립트 `godot\assets\tools\gen_bgm_placeholder.py`.
