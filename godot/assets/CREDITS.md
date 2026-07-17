# 에셋 크레딧 (CC0/무료 소싱 자료)

- **최종 수정일**: 2026-07-17
- **담당**: pixel-artist

> 소싱 출처·라이선스·가공 내용의 전체 기록은 `docs\art\ASSET_SOURCES.md`를 참조한다. 이 파일은 `STYLE_GUIDE.md` 7-3장이 요구하는 최소 크레딧 목록이다.

| 자산 | 제작자 | 라이선스 | 출처 |
|---|---|---|---|
| 들개 마수 스프라이트 원본 | zerohero, Mumu, William.Thompsonj | CC-BY 4.0 | https://opengameart.org/content/lpc-wolf-animation |
| 뿔토끼 스프라이트 원본 | Ablu, pennomi, tebruno99, zerohero | CC-BY 3.0 | https://opengameart.org/content/bunny-rabbit-lpc-style-for-pixelfarm |
| 균열 점액 스프라이트 원본 | Calciumtrice | CC-BY 3.0 | https://opengameart.org/content/animated-slime |

전사 플레이어 스프라이트는 소싱 자료가 아닌 Pillow 절차 생성 플레이스홀더(`godot\assets\tools\gen_player_warrior.py`)이며 저작자 표기가 필요 없다(자체 생성).

---

## 오디오 (SD-1·SD-2, audio-designer)

- 전투 SFX 8종(`godot\assets\audio\sfx\`)은 numpy 파형 합성 자체 생성물이며 저작자 표기가 필요 없다 — 재생성 스크립트 `godot\assets\tools\gen_combat_sfx.py`.
- 시작 지역 BGM(`godot\assets\audio\bgm\bgm_field_eastern_frontier_south_TEMP.ogg`)은 **임시 numpy 합성 화음 패드**다 — CC0 소싱 곡이 아니므로 저작자 표기 대상이 아니지만, **추후 정식 CC0/CC-BY 소싱 곡으로 교체 예정**(사유·후보는 `docs\art\ASSET_SOURCES.md` 참조). 재생성 스크립트 `godot\assets\tools\gen_bgm_placeholder.py`.
