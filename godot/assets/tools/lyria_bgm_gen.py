"""M3 BGM 정식 제작 — Google Lyria 3 생성·후처리 파이프라인 (audio-designer 도구).

`docs\\art\\bgm-lyria-prompts.md` 2장의 트랙별 영어 프롬프트를 그대로 담아, Gemini API의
Lyria 3 음악 모델로 BGM을 생성하고 3장 후처리 절차(루프 접합 → -16 LUFS 정규화 →
OGG 변환)를 자동 수행한다. 파일명 규약은 `docs\\art\\audio-direction.md` 5-1절
(`bgm_<슬롯>_<이름>.ogg`)을 따른다.

**중단·재개 가능**: 최종 OGG가 이미 있으면 건너뛴다. 생성 원본(raw)은
`godot\\assets\\audio\\bgm\\_lyria_raw\\`에 남겨 후처리만 다시 돌릴 수 있다
(raw 디렉터리는 커밋 제외 — `.gitignore` 참조).

사용법:
    python lyria_bgm_gen.py --list                    # 트랙 목록·우선순위·생성 여부
    python lyria_bgm_gen.py --priority 1              # 우선순위 1 전체 생성 (G3-1 필수분)
    python lyria_bgm_gen.py field_east_south battle_early
    python lyria_bgm_gen.py --all --model pro         # 전곡, 장척(pro) 모델
    python lyria_bgm_gen.py --priority 1 --repost     # 재생성 없이 후처리만 재실행

    --model clip|pro   clip=lyria-3-clip-preview(약 30초) / pro=lyria-3-pro-preview(약 2분 30초)
                       루프 트랙은 반복 피로 때문에 **pro 권장**. 스팅어·팡파레 등
                       짧은 논루프 트랙만 clip으로 뽑고 앞에서 잘라 쓴다.
    --force            최종 OGG가 있어도 덮어쓴다 (API 재호출 포함)
    --repost           raw는 재사용하고 후처리(루프·정규화·변환)만 다시 수행
    --xfade 초         루프 접합 크로스페이드 최대 길이 (기본 1.6초)

요구 사항:
    - 환경변수 `GEMINI_API_KEY` (**절대 코드·문서·커밋에 넣지 말 것**)
    - `google-genai` SDK, numpy, soundfile, ffmpeg(PATH)
    - Lyria 3는 실험적 API다 — SDK가 `Interactions usage is experimental` 경고를 낸다.
      모든 출력에 SynthID 오디오 워터마크가 포함된다.

라이선스 기록: 생성 결과는 `docs\\art\\ASSET_SOURCES.md`에 트랙별로 기록한다
(`bgm-lyria-prompts.md` 4장 방침).
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import soundfile as sf

BGM_DIR = Path(__file__).resolve().parents[1] / "audio" / "bgm"
RAW_DIR = BGM_DIR / "_lyria_raw"
LOG_PATH = RAW_DIR / "generation_log.json"

MODELS = {"clip": "lyria-3-clip-preview", "pro": "lyria-3-pro-preview"}
TARGET_LUFS = -16.0  # bgm-lyria-prompts.md 3장 4번
TARGET_TP = -1.0
OGG_QUALITY = "6"  # 3장 5번: q6 내외
MAX_RETRY = 3
DEFAULT_XFADE_SEC = 1.6


@dataclass(frozen=True)
class Track:
    """생성 대상 트랙 1곡. `bgm-lyria-prompts.md` 1장 표의 행 하나에 대응."""

    key: str  # CLI에서 지정하는 짧은 이름
    sheet_no: str  # 프롬프트 시트의 트랙 번호
    stem: str  # 파일명 (확장자 제외) — audio-direction 5-1 규약
    priority: int  # 1=G3-1 필수, 2=M3 후속, 3=중후반·엔드게임
    loop: bool  # False면 루프 접합 생략(논루프 트랙)
    title: str  # 한국어 트랙명
    prompt: str  # 시트 2장 영어 프롬프트 원문 (수정 없이 그대로)
    model: str = "pro"  # 기본 pro(약 2분 30초). 짧은 논루프 트랙만 clip으로 지정
    # 논루프 단곡의 클린 컷 허용 범위 (최소초, 최대초). None이면 자르지 않는다.
    cut_range: tuple[float, float] | None = None


# ---------------------------------------------------------------------------
# 트랙 표 — 프롬프트는 `docs\art\bgm-lyria-prompts.md` 2장에서 **원문 그대로** 옮겼다.
# 시트를 수정하면 이 표도 함께 갱신할 것(시트가 원본, 이 표는 실행용 사본).
# ---------------------------------------------------------------------------
TRACKS: list[Track] = [
    # --- 우선순위 1: G3-1(디렉터 직접 플레이)에서 실제로 들리는 곡 ---
    Track(
        key="field_east_south",
        sheet_no="M2-3",
        stem="bgm_field_eastern_frontier_south",
        priority=1,
        loop=True,
        title="동부 변경 남측 필드 — 주간 (시작 지역 노베라 들녘)",
        prompt=(
            "8-bit chiptune overworld exploration theme, bright major key melody suggesting a "
            "frontier being reclaimed and reborn, square wave lead with light syncopation, "
            "walking triangle bass, tempo around 110 BPM, hopeful yet with a subtle undertone "
            "of caution as if exploring a still-dangerous borderland, instrumental only, "
            "consistent energy throughout for seamless looping, no intro swell or ending fade."
        ),
    ),
    Track(
        key="field_night",
        sheet_no="25",
        stem="bgm_field_night_common",
        priority=1,
        loop=True,
        title="야간 활성 지역 공용 필드곡 (시작 지역 야간 겸용)",
        prompt=(
            "Tense 8-bit chiptune nighttime hunting-grounds theme, minor key, slower tempo than "
            "the daytime field theme around 80 BPM, wary square wave melody with more silence "
            "between phrases, low ominous triangle bass, clearly signals rising danger after "
            "dark, instrumental only, steady creeping tension throughout, seamless loop, no fade."
        ),
    ),
    Track(
        key="battle_early",
        sheet_no="M2-4",
        stem="bgm_battle_normal_early",
        priority=1,
        loop=True,
        title="일반 전투 — 전반 (디버그 전투장·신규 적 검증 필드 겸용)",
        prompt=(
            "Fast-paced 8-bit chiptune battle theme, urgent square wave lead riff over driving "
            "triangle bass ostinato and noise-channel snare-like percussion, tempo around 150 "
            "BPM, tense and aggressive but not despairing, minor key with a driving rhythmic "
            "pulse, instrumental only, high energy sustained evenly from start to end for "
            "seamless combat loop, no fade in or fade out."
        ),
    ),
    Track(
        key="town_novera",
        sheet_no="M2-2",
        stem="bgm_town_novera",
        priority=1,
        loop=True,
        title="노베라 거점 평화",
        prompt=(
            "Upbeat 8-bit chiptune village theme for a frontier boomtown, bright major key "
            'folk/country-inspired melody, square wave lead with a bouncy triangle wave bassline '
            "and light noise-channel percussion like a simple tambourine pulse, cheerful and "
            'welcoming "coming home" feeling, tempo around 120 BPM, instrumental only, steady '
            "groove throughout with no dramatic build or ending, loop-friendly."
        ),
    ),
    Track(
        key="fanfare",
        sheet_no="33",
        stem="bgm_fanfare_ceremony",
        priority=1,
        loop=False,
        title="의전·팡파레 (전직·승급 연출)",
        model="clip",
        cut_range=(5.0, 9.0),
        prompt=(
            "Short triumphant 8-bit chiptune ceremonial fanfare, about 5 to 8 seconds of usable "
            "material, bright square wave brass-style flourish building to a clear resolved "
            "ending, tempo around 110 BPM, formal and celebratory, instrumental only, does not "
            "need to loop, clean definite ending."
        ),
    ),
    Track(
        key="title",
        sheet_no="M2-1",
        stem="bgm_title_main_theme",
        priority=1,
        loop=True,
        title="타이틀 테마",
        prompt=(
            "Epic 8-bit chiptune title theme for a fantasy RPG, NES-style square wave lead "
            "melody over triangle wave bass and arpeggiated chords, starting hopeful and heroic "
            "then briefly dipping into a minor, melancholic bridge before returning to a "
            "triumphant major theme, moderate tempo around 100 BPM, orchestral-scale drama "
            "compressed into retro synth voices, instrumental only, seamless loop with "
            "consistent energy from start to end, no fade in or fade out."
        ),
    ),
    # --- 우선순위 2: M3 후속 (해당 씬·콘텐츠가 붙는 시점) ---
    Track(
        key="dungeon_rift",
        sheet_no="M2-6",
        stem="bgm_dungeon_rift_common",
        priority=2,
        loop=True,
        title="소균열 던전 (공용)",
        prompt=(
            "Eerie 8-bit chiptune dungeon theme representing a corrupted rift, slow tempo around "
            "70 BPM, dissonant square wave arpeggios with chromatic movement, sparse triangle "
            "wave drone bass, occasional detuned noise textures suggesting corruption and "
            "unnatural presence, unsettling but not horror — more like an alien hunger than "
            "fear, instrumental only, steady looping atmosphere with minimal melodic movement, "
            "no dramatic peak, seamless loop."
        ),
    ),
    Track(
        key="boss_normal",
        sheet_no="M2-5",
        stem="bgm_boss_normal",
        priority=2,
        loop=True,
        title="보스전 — 일반",
        prompt=(
            "Intense 8-bit chiptune boss battle theme, dramatic minor key square wave lead with "
            "a memorable aggressive riff, heavy triangle bass stabs, fast arpeggios and "
            "noise-percussion hits accenting strong beats, tempo around 160 BPM, feels like a "
            "dangerous one-on-one duel against a powerful single enemy, more intense and "
            "melodically distinct than a generic battle theme, instrumental only, even intensity "
            "throughout with no fade, loop-friendly."
        ),
    ),
    Track(
        key="boss_normal_stinger",
        sheet_no="M2-5-스팅어",
        stem="bgm_boss_normal_stinger",
        priority=2,
        loop=False,
        title="보스 등장 인트로 스팅어 (일반)",
        model="clip",
        cut_range=(2.0, 4.5),
        prompt=(
            "Short dramatic 8-bit chiptune stinger, a sudden intense minor-key sting with a "
            "rising noise sweep and a hard hit on the downbeat, signaling a boss enemy has "
            "appeared, instrumental only, no need to loop, clear hard ending within a few seconds."
        ),
    ),
    Track(
        key="village_common",
        sheet_no="17",
        stem="bgm_town_village_common",
        priority=2,
        loop=True,
        title="마을·부락 공용 목가",
        prompt=(
            "Simple, humble 8-bit chiptune pastoral theme for small villages and hamlets, plain "
            "square wave folk melody, gentle triangle bass, tempo around 90 BPM, modest and "
            "homely, instrumental only, unassuming steady loop with no dramatic moments, no fade."
        ),
    ),
    Track(
        key="sorrow",
        sheet_no="32",
        stem="bgm_sorrow_memory",
        priority=2,
        loop=True,
        title="슬픔·회상",
        prompt=(
            "Quiet, melancholic 8-bit chiptune theme for sorrowful memories, tempo around 65 "
            "BPM, sparse minor-key triangle wave melody, long sustained tones, restrained grief "
            "without melodrama, instrumental only, gentle and even throughout, seamless loop, "
            "no fade."
        ),
    ),
    Track(
        key="hidden",
        sheet_no="31",
        stem="bgm_hidden_mystery",
        priority=2,
        loop=True,
        title="히든·신비",
        prompt=(
            "Subtle, understated 8-bit chiptune theme for a quiet hidden discovery, tempo around "
            "80 BPM, soft triangle wave arpeggio with a faint mysterious sparkle motif, gentle "
            "and low-key rather than triumphant or attention-grabbing, instrumental only, brief "
            "and unobtrusive, gentle loop with minimal dynamic change."
        ),
    ),
    # --- 우선순위 3: 중후반·엔드게임 지역/연출 (M3 이후) ---
    Track(
        key="town_brantel",
        sheet_no="7",
        stem="bgm_town_brantel",
        priority=3,
        loop=True,
        title="브란텔 (왕도)",
        prompt=(
            'Regal 8-bit chiptune royal capital theme, ceremonial march feel with square wave '
            '"brass" fanfare motifs and a steady stately rhythm, triangle bass in strict march '
            "time, tempo around 90 BPM, grand and authoritative but cold, formal and slightly "
            "unwelcoming rather than warm, instrumental only, even grandeur sustained throughout "
            "for a seamless loop, no fade."
        ),
    ),
    Track(
        key="town_grancia",
        sheet_no="8",
        stem="bgm_town_grancia",
        priority=3,
        loop=True,
        title="그란시아",
        prompt=(
            "Elegant 8-bit chiptune courtly waltz in 3/4 time, ornate square wave melody with "
            "decorative grace-note flourishes, delicate triangle wave arpeggios, tempo around 80 "
            "BPM, beautiful but distant and exclusive, sharing the regal fanfare character of a "
            "royal capital theme but more decorative and dance-like, instrumental only, "
            "consistent waltz pulse throughout for seamless looping."
        ),
    ),
    Track(
        key="town_arcel",
        sheet_no="9",
        stem="bgm_town_arcel",
        priority=3,
        loop=True,
        title="아르셀",
        prompt=(
            "Calm and studious 8-bit chiptune theme for a scholarly lakeside city, slow lyrical "
            "triangle wave arpeggios rippling like still water, gentle square wave counter-melody "
            "entering sparingly, tempo around 70 BPM, quiet library-like stillness and "
            "intellectual serenity, instrumental only, minimal dynamic change for a peaceful "
            "seamless loop."
        ),
    ),
    Track(
        key="town_saleno",
        sheet_no="10",
        stem="bgm_town_saleno",
        priority=3,
        loop=True,
        title="살레노",
        prompt=(
            "Lively 8-bit chiptune sea shanty in a swung 6/8 shuffle rhythm, bright square wave "
            "hornpipe-style melody, bouncy triangle bass, light noise-channel percussion like a "
            "jaunty tambourine, tempo around 130 BPM, the most cheerful and bustling "
            "harbor-market energy in the kingdom, instrumental only, consistent festive energy "
            "throughout, seamless loop, no fade."
        ),
    ),
    Track(
        key="town_oranse",
        sheet_no="11",
        stem="bgm_town_oranse",
        priority=3,
        loop=True,
        title="오란세",
        prompt=(
            "Serene 8-bit chiptune hymn theme for a holy pilgrimage city, very slow tempo around "
            "60 BPM, sustained organ-like triangle/sine tones forming a simple chant-like melody, "
            "a soft recurring bell motif, gentle and all-embracing sacred atmosphere, "
            "instrumental only, no percussion, steady contemplative mood sustained throughout "
            "for a seamless loop with no fade."
        ),
    ),
    Track(
        key="town_mislan",
        sheet_no="12",
        stem="bgm_town_mislan",
        priority=3,
        loop=True,
        title="미스란",
        prompt=(
            "Mysterious 8-bit chiptune theme for an elven border trading post, pentatonic and "
            "dorian mode melody distinct from human city themes, square wave lead with an exotic, "
            "otherworldly interval feel, light shimmering triangle arpeggios, tempo around 90 "
            "BPM, evokes the threshold of an ancient forest, instrumental only, steady mysterious "
            "atmosphere throughout, seamless loop."
        ),
    ),
    Track(
        key="town_durgan",
        sheet_no="13",
        stem="bgm_town_durgan",
        priority=3,
        loop=True,
        title="두르간",
        prompt=(
            "Sturdy 8-bit chiptune dwarven mining city theme, heavy low square wave riff "
            "functioning as a work-song, strong hammering noise-channel percussion on the beat "
            "like forge hammers, tempo around 100 BPM, proud and industrious with a warm "
            "furnace-like undertone, instrumental only, consistent driving groove throughout, "
            "seamless loop, no fade."
        ),
    ),
    Track(
        key="town_hafna",
        sheet_no="14",
        stem="bgm_town_hafna",
        priority=3,
        loop=True,
        title="하프나",
        prompt=(
            "Gruff 8-bit chiptune northern fishing port theme, minor-key sea shanty rhythm, "
            "terse square wave melody over a rolling triangle bass like cold waves, sparse "
            "noise-channel percussion, tempo around 100 BPM, hardy and stoic, a colder darker "
            "counterpart to a cheerful harbor theme, instrumental only, steady wave-like "
            "repetition throughout, seamless loop."
        ),
    ),
    Track(
        key="town_valkren",
        sheet_no="15",
        stem="bgm_town_valkren",
        priority=3,
        loop=True,
        title="발크렌",
        prompt=(
            "Tense 8-bit chiptune military garrison theme, march rhythm with snare-like "
            "noise-channel percussion, minor key square wave brass-style motif, disciplined and "
            "watchful even in peacetime, tempo around 110 BPM, instrumental only, unbroken "
            "vigilant march energy throughout for a seamless loop, no fade."
        ),
    ),
    Track(
        key="town_kaelon_early",
        sheet_no="16-초기",
        stem="bgm_town_kaelon_early",
        priority=3,
        loop=True,
        title="카엘론 — 초기(느린) 버전",
        prompt=(
            "Slow, gentle 8-bit chiptune theme sharing the melodic motif of a cheerful frontier "
            "boomtown theme but rendered quietly and tenderly, sparse square wave lead, soft "
            "triangle bass, tempo around 85 BPM, quiet pride and healing after hardship, "
            "instrumental only, calm and steady throughout, seamless loop."
        ),
    ),
    Track(
        key="town_kaelon_grown",
        sheet_no="16-성장",
        stem="bgm_town_kaelon_grown",
        priority=3,
        loop=True,
        title="카엘론 — 성장 후(밝은) 버전",
        prompt=(
            "Warmer, slightly faster reprise of the same frontier-town melodic motif, fuller "
            "instrumentation with square wave lead, bouncy triangle bass and light percussion, "
            "tempo around 110 BPM, hopeful growth and recovered community pride, instrumental "
            "only, upbeat but not as boisterous as the main boomtown theme, seamless loop, no fade."
        ),
    ),
    Track(
        key="field_central",
        sheet_no="18",
        stem="bgm_field_central_crownland",
        priority=3,
        loop=True,
        title="중부 왕령 필드",
        prompt=(
            "Peaceful 8-bit chiptune overworld theme for open safe farmland plains, gentle "
            "unhurried square wave melody, warm triangle bass, tempo around 90 BPM, orderly and "
            "relaxed safe-zone atmosphere, instrumental only, even calm energy throughout, "
            "seamless loop, no fade."
        ),
    ),
    Track(
        key="field_south_coast",
        sheet_no="19",
        stem="bgm_field_southern_coast",
        priority=3,
        loop=True,
        title="남부 해안·구릉 필드",
        prompt=(
            "Breezy 8-bit chiptune coastal overworld theme, sunny travel-adventure feel sharing "
            "the shuffle-rhythm character of a lively harbor city but airier and more open, "
            "square wave lead, bouncy triangle bass, tempo around 120 BPM, instrumental only, "
            "consistent upbeat travel energy throughout, seamless loop."
        ),
    ),
    Track(
        key="field_silvien",
        sheet_no="20",
        stem="bgm_field_silvien_forest",
        priority=3,
        loop=True,
        title="서부 실비엔 대수림",
        prompt=(
            "Ancient and awe-inspiring 8-bit chiptune forest theme, slow tempo around 75 BPM, "
            "mysterious mode melody sharing motifs with an elven trading-post theme but deeper "
            "and more ambient, sparse square wave phrases over a sustained triangle drone, subtle "
            "shimmering textures like light through leaves, instrumental only, hushed reverent "
            "atmosphere throughout, seamless loop, no fade."
        ),
    ),
    Track(
        key="field_steelrange",
        sheet_no="21",
        stem="bgm_field_northern_steelrange",
        priority=3,
        loop=True,
        title="북부 강철산맥",
        prompt=(
            "Cold, high-altitude 8-bit chiptune mountain theme, austere square wave melody with "
            "wide open intervals suggesting thin mountain air, steady triangle bass, tempo around "
            "85 BPM, bleak grey-blue stony atmosphere, instrumental only, sparse and unhurried "
            "throughout, seamless loop, no fade."
        ),
    ),
    Track(
        key="field_ash_plain",
        sheet_no="22",
        stem="bgm_field_ash_plain",
        priority=3,
        loop=True,
        title="옛 전선·재의 평원",
        prompt=(
            "Somber 8-bit chiptune wasteland field theme, minor key, slow tempo around 80 BPM, "
            "mostly a low sustained drone with only occasional sparse melodic phrases, mournful "
            "but not horror-styled — a quiet grief rather than fear, evokes marching forward "
            "through ruin and loss, instrumental only, restrained and steady throughout, seamless "
            "loop, no fade."
        ),
    ),
    Track(
        key="field_rift_zone",
        sheet_no="23",
        stem="bgm_field_rift_zone",
        priority=3,
        loop=True,
        title="균열 지대·악마 세력권",
        prompt=(
            "Unsettling 8-bit chiptune theme for a demon-corrupted rift zone, irregular slow "
            "tempo around 70 BPM, dissonant chromatic arpeggios on square wave, unstable rhythm "
            "that avoids a steady pulse, conveys hollow craving and alien intelligence rather "
            "than jump-scare horror, instrumental only, unnerving but controlled atmosphere "
            "throughout, seamless loop, no dramatic climax."
        ),
    ),
    Track(
        key="field_abyss",
        sheet_no="24",
        stem="bgm_field_abyss_corridor",
        priority=3,
        loop=True,
        title="심연 회랑",
        prompt=(
            "Minimal dark ambient 8-bit chiptune theme for the deepest abyss corridor, very slow "
            "tempo around 60 BPM, near-melody-less, dominated by a low pulsing square wave tone "
            "and long reverberant triangle wave sustain, oppressive silence and dread pressure, "
            "instrumental only, sparse and unchanging throughout for a seamless tense loop."
        ),
    ),
    Track(
        key="field_ash_plain_night",
        sheet_no="26",
        stem="bgm_field_ash_plain_night",
        priority=3,
        loop=True,
        title="재의 평원 야간 전용 변주",
        prompt=(
            "Darker, sparser variant of a tense nighttime hunting theme, tempo around 75 BPM, "
            "minor key, even more silence and space between notes, faint dissonant textures "
            "suggesting whispers and lingering corruption, instrumental only, minimal and "
            "haunting throughout, seamless loop, no fade."
        ),
    ),
    Track(
        key="battle_late",
        sheet_no="27",
        stem="bgm_battle_normal_late",
        priority=3,
        loop=True,
        title="일반 전투 — 후반",
        prompt=(
            "Fast, grim 8-bit chiptune battle theme for the war-torn later chapters, tempo around "
            "155 BPM, driving minor-key square wave riff with a heavier, more desperate edge than "
            "an early-game battle theme, insistent noise-percussion hits, instrumental only, "
            "relentless energy sustained evenly throughout, seamless combat loop, no fade."
        ),
    ),
    Track(
        key="boss_elite",
        sheet_no="28",
        stem="bgm_boss_elite",
        priority=3,
        loop=True,
        title="보스전 — 상위",
        prompt=(
            "Epic 8-bit chiptune elite boss battle theme, tempo around 165 BPM, bigger and more "
            "menacing than a standard boss theme, layered square wave lead over driving triangle "
            "bass and aggressive noise percussion, dramatic minor-key riff suggesting an "
            "overwhelming siege-scale threat, instrumental only, sustained maximum intensity "
            "throughout, seamless loop, no fade."
        ),
    ),
    Track(
        key="boss_elite_stinger",
        sheet_no="28-스팅어",
        stem="bgm_boss_elite_stinger",
        priority=3,
        loop=False,
        title="보스 등장 인트로 스팅어 (상위)",
        model="clip",
        cut_range=(2.0, 4.5),
        prompt=(
            "Short intense 8-bit chiptune stinger, bigger and more ominous rising sweep and "
            "heavier hit than a standard boss stinger, signaling an elite threat, instrumental "
            "only, no loop needed, hard clear ending within a few seconds."
        ),
    ),
    Track(
        key="war_final",
        sheet_no="29",
        stem="bgm_war_final_alliance",
        priority=3,
        loop=True,
        title="최종전 1차 — 대규모 전쟁 (대체 불가 슬롯)",
        prompt=(
            "Massive 8-bit chiptune war theme depicting an alliance of three peoples fighting a "
            "demonic legion, tempo around 150 BPM, marching rhythm built from a military motif, "
            "layered with a human brass-like fanfare motif, an elven modal melodic motif, and a "
            "low dwarven riff motif all interweaving, periodically clashing against a dissonant "
            "chromatic demonic motif, the densest and most layered piece in the game, "
            "instrumental only, sustained epic intensity throughout, seamless loop, no fade."
        ),
    ),
    Track(
        key="boss_final",
        sheet_no="30",
        stem="bgm_boss_final",
        priority=3,
        loop=True,
        title="최종 보스전",
        prompt=(
            "Intense 8-bit chiptune final boss theme, tempo around 160 BPM, compresses the "
            "layered motifs of an epic three-faction war theme into a focused one-on-one duel, "
            "retains fragments of the brass, modal, and low-riff motifs now fighting for "
            "dominance against a dissonant demonic motif, dense minor-key climax, instrumental "
            "only, maximum sustained intensity throughout, seamless loop, no fade."
        ),
    ),
    Track(
        key="ending",
        sheet_no="34",
        stem="bgm_ending",
        priority=3,
        loop=False,
        title="엔딩",
        prompt=(
            "Triumphant 8-bit chiptune ending theme, a fully realized bright major-key version of "
            "the game's title theme motif, tempo around 105 BPM, resolves the earlier melancholic "
            "bridge into pure hope and warmth, instrumental only, swells to a satisfying "
            "uplifting conclusion, can fade out gracefully at the end, does not need to be a "
            "seamless loop."
        ),
    ),
]

BY_KEY = {t.key: t for t in TRACKS}


# ---------------------------------------------------------------------------
# API 생성
# ---------------------------------------------------------------------------
class QuotaError(RuntimeError):
    """쿼터·레이트 리밋(429 등) — 재시도해도 소용없으므로 즉시 중단한다."""


def _is_quota_error(exc: Exception) -> bool:
    text = f"{type(exc).__name__}: {exc}".lower()
    return any(k in text for k in ("429", "resource_exhausted", "quota", "rate limit"))


def generate_raw(track: Track, model_key: str) -> tuple[bytes, str]:
    """Lyria 3로 트랙 1곡을 생성해 (오디오 바이트, mime) 반환."""
    from google import genai

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise SystemExit("환경변수 GEMINI_API_KEY가 없습니다.")
    client = genai.Client(api_key=api_key)
    model = MODELS[model_key]

    # `response_format={"type":"audio","mime_type":"audio/wav"}`는 clip/pro 양쪽에서
    # 400 `Audio mime_type is not supported in response_format.`으로 거부된다(2026-07-29 실측).
    # 두 모델 모두 192kbps MP3(audio/mpeg, 44.1kHz 스테레오)만 반환한다.
    kwargs: dict = {"model": model, "input": track.prompt}

    last: Exception | None = None
    for attempt in range(1, MAX_RETRY + 1):
        try:
            started = time.monotonic()
            res = client.interactions.create(**kwargs)
            elapsed = time.monotonic() - started
            audio = res.output_audio
            data = base64.b64decode(audio.data)
            mime = getattr(audio, "mime_type", None) or "audio/mpeg"
            print(f"    생성 완료 {len(data):,}바이트 / mime={mime} / {elapsed:.1f}초")
            return data, mime
        except Exception as exc:  # noqa: BLE001 — API 예외 타입이 실험적이라 광범위 포착
            if _is_quota_error(exc):
                raise QuotaError(f"쿼터/레이트 리밋: {exc}") from exc
            last = exc
            print(f"    시도 {attempt}/{MAX_RETRY} 실패: {type(exc).__name__}: {exc}")
            if attempt < MAX_RETRY:
                time.sleep(5 * attempt)
    raise RuntimeError(f"{MAX_RETRY}회 재시도 실패: {last}")


def _ext_for_mime(mime: str) -> str:
    return {
        "audio/mpeg": ".mp3",
        "audio/mp3": ".mp3",
        "audio/wav": ".wav",
        "audio/x-wav": ".wav",
        "audio/ogg": ".ogg",
    }.get(mime.split(";")[0].strip(), ".bin")


# ---------------------------------------------------------------------------
# 후처리
# ---------------------------------------------------------------------------
def _ffmpeg(args: list[str]) -> str:
    proc = subprocess.run(
        ["ffmpeg", "-hide_banner", "-y", *args], capture_output=True, text=True
    )
    if proc.returncode != 0:
        raise RuntimeError(f"ffmpeg 실패: {proc.stderr[-1500:]}")
    return proc.stderr


def decode_to_wav(src: Path, dst: Path) -> None:
    _ffmpeg(["-i", str(src), "-ar", "44100", "-c:a", "pcm_s16le", str(dst)])


def _mono(samples: np.ndarray) -> np.ndarray:
    return samples.mean(axis=1) if samples.ndim > 1 else samples


def _rms_envelope(mono: np.ndarray, sr: int, hop_sec: float = 0.05) -> tuple[np.ndarray, int]:
    hop = max(1, int(sr * hop_sec))
    usable = (len(mono) // hop) * hop
    if usable == 0:
        return np.zeros(0), hop
    frames = mono[:usable].reshape(-1, hop)
    return np.sqrt((frames**2).mean(axis=1)), hop


def trim_edges(
    samples: np.ndarray, sr: int, thresh_ratio: float = 0.45, max_trim_frac: float = 0.30
) -> tuple[np.ndarray, dict]:
    """인트로 페이드인·아웃트로 페이드아웃 구간을 잘라낸다.

    Lyria 3는 프롬프트에 `no fade in or fade out`을 명시해도 곡 끝을 무음까지
    페이드아웃시킨다(pro 모델 실측: 마지막 0.25초 RMS가 본문의 1% 이하). 이 구간을
    남긴 채 루프하면 이음매에서 소리가 사라졌다 다시 커지는 것이 명확히 들리므로,
    루프 접합 **전에** 본문(정상 세기 구간)만 남긴다.

    판정: 50ms RMS 엔벨로프가 중앙값의 `thresh_ratio` 이상인 첫/마지막 프레임까지를
    본문으로 본다. 오판으로 곡을 과도하게 깎지 않게 편당 최대 `max_trim_frac`까지만 자른다.
    """
    mono = _mono(samples)
    env, hop = _rms_envelope(mono, sr)
    if len(env) < 4:
        return samples, {}
    thresh = float(np.median(env)) * thresh_ratio
    above = np.flatnonzero(env >= thresh)
    if len(above) == 0:
        return samples, {}
    limit = int(len(env) * max_trim_frac)
    lo = min(int(above[0]), limit)
    hi = max(int(above[-1]) + 1, len(env) - limit)
    s0 = lo * hop
    s1 = min(hi * hop, len(mono))
    if s1 - s0 < sr * 5:  # 5초 미만으로 남으면 판정 실패로 보고 원본 유지
        return samples, {}
    return samples[s0:s1].copy(), {
        "trim_head_sec": round(s0 / sr, 2),
        "trim_tail_sec": round((len(mono) - s1) / sr, 2),
    }


def clean_cut(
    samples: np.ndarray, sr: int, min_sec: float, max_sec: float, fade_sec: float = 0.12
) -> tuple[np.ndarray, dict]:
    """논루프 단곡(스팅어·팡파레)을 지정 범위 안의 에너지 최저점에서 잘라낸다.

    `bgm-lyria-prompts.md` 3장 3번의 "클린 컷". Lyria는 `about 5 to 8 seconds`를
    지시해도 30초 전체를 채워 보내므로(실측), 악구가 끊기는 지점 = RMS 최저점을 찾아
    자르고 짧은 등파워 페이드아웃으로 클릭을 막는다.
    """
    mono = _mono(samples)
    env, hop = _rms_envelope(mono, sr)
    lo = int(min_sec * sr / hop)
    hi = min(int(max_sec * sr / hop), len(env))
    if hi <= lo:
        return samples, {}
    idx = lo + int(np.argmin(env[lo:hi]))
    end = min((idx + 1) * hop, len(mono))
    out = samples[:end].copy()
    fade_n = min(int(sr * fade_sec), end)
    fade = np.sqrt(1.0 - np.linspace(0.0, 1.0, fade_n))
    out[-fade_n:] *= fade[:, None] if out.ndim > 1 else fade
    return out, {"cut_at_sec": round(end / sr, 2), "fade_out_sec": fade_sec}


def loopify(samples: np.ndarray, sr: int, max_xfade_sec: float) -> tuple[np.ndarray, dict]:
    """등파워 크로스페이드로 심리스 루프를 만든다.

    원리: 출력 길이를 N-x로 줄이고, 출력 **앞** x샘플을 (원본 꼬리 x) → (원본 머리 x)
    크로스페이드로 채운다. 그러면 루프 이음매에서 원본의 연속 구간이 이어져 클릭이 없다.
    x는 후보 길이 중 꼬리·머리 상관계수가 가장 높은 값을 골라 리듬 어긋남을 줄인다.
    """
    n = len(samples)
    candidates = [
        int(sr * s) for s in (0.6, 0.8, 1.0, 1.2, 1.4, 1.6, 2.0, 2.4) if s <= max_xfade_sec
    ]
    candidates = [c for c in candidates if 0 < c < n // 4] or [int(sr * 0.8)]
    mono = samples.mean(axis=1) if samples.ndim > 1 else samples

    def corr(x: int) -> float:
        a, b = mono[n - x : n], mono[:x]
        da, db = a - a.mean(), b - b.mean()
        denom = float(np.linalg.norm(da) * np.linalg.norm(db))
        return float(np.dot(da, db) / denom) if denom > 1e-9 else 0.0

    scored = [(corr(x), x) for x in candidates]
    best_corr, x = max(scored)

    fade_in = np.linspace(0.0, 1.0, x) ** 0.5  # 등파워
    fade_out = np.sqrt(1.0 - np.linspace(0.0, 1.0, x))
    if samples.ndim > 1:
        fade_in = fade_in[:, None]
        fade_out = fade_out[:, None]

    out = samples[: n - x].copy()
    out[:x] = samples[n - x : n] * fade_out + samples[:x] * fade_in
    return out, {"xfade_sec": round(x / sr, 3), "xfade_corr": round(best_corr, 3)}


def analyze(samples: np.ndarray, sr: int) -> dict:
    """루프 적합성·음량 근사 지표. 실제 청취 대신 쓰는 정량 판정 근거."""
    mono = samples.mean(axis=1) if samples.ndim > 1 else samples
    n = len(mono)
    edge = int(sr * 0.25)
    body_rms = float(np.sqrt(np.mean(mono**2)))
    head_rms = float(np.sqrt(np.mean(mono[:edge] ** 2)))
    tail_rms = float(np.sqrt(np.mean(mono[-edge:] ** 2)))
    # 이음매(끝→시작) 진폭 도약을 "본문의 통상적인 인접 샘플 변화량"과 비교한다.
    # 절대값을 RMS로 나누면 고역이 많은 소재에서 항상 커 보여 판정이 안 되므로,
    # 같은 트랙의 인접 샘플 변화량 중앙값을 기준으로 삼는다.
    # 1~3배면 이음매가 평범한 샘플 전이와 다를 바 없다(= 클릭 없음), 20배 이상이면 클릭 위험.
    step_median = float(np.median(np.abs(np.diff(mono)))) if n > 1 else 0.0
    seam_jump = abs(float(mono[0] - mono[-1]))
    return {
        "duration_sec": round(n / sr, 2),
        "peak": round(float(np.max(np.abs(mono))), 4),
        "rms": round(body_rms, 4),
        # 1.0에 가까울수록 시작/끝이 본문과 같은 세기 = 페이드 없음(루프 적합)
        "head_rms_ratio": round(head_rms / body_rms, 3) if body_rms > 1e-9 else 0.0,
        "tail_rms_ratio": round(tail_rms / body_rms, 3) if body_rms > 1e-9 else 0.0,
        "seam_click_ratio": round(seam_jump / step_median, 2) if step_median > 1e-12 else 0.0,
    }


def measure_loudness(wav: Path) -> dict:
    """ffmpeg loudnorm 1패스 측정값(JSON)."""
    log = _ffmpeg(
        ["-i", str(wav), "-af", "loudnorm=I=-16:TP=-1:LRA=11:print_format=json", "-f", "null", "-"]
    )
    start = log.rfind("{")
    end = log.rfind("}")
    if start < 0 or end < 0:
        raise RuntimeError("loudnorm 측정 결과 파싱 실패")
    return json.loads(log[start : end + 1])


def normalize_to_ogg(wav: Path, ogg: Path) -> dict:
    """-16 LUFS / -1 dBTP 2패스 정규화 후 OGG Vorbis q6으로 인코딩."""
    m = measure_loudness(wav)
    af = (
        f"loudnorm=I={TARGET_LUFS}:TP={TARGET_TP}:LRA=11"
        f":measured_I={m['input_i']}:measured_TP={m['input_tp']}"
        f":measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}"
        f":offset={m['target_offset']}:linear=true:print_format=summary"
    )
    _ffmpeg(["-i", str(wav), "-af", af, "-c:a", "libvorbis", "-q:a", OGG_QUALITY, str(ogg)])
    return {
        "input_lufs": float(m["input_i"]),
        "input_tp_db": float(m["input_tp"]),
        "target_lufs": TARGET_LUFS,
    }


# ---------------------------------------------------------------------------
# 실행
# ---------------------------------------------------------------------------
def process(track: Track, args: argparse.Namespace) -> dict:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    ogg = BGM_DIR / f"{track.stem}.ogg"
    raws = sorted(RAW_DIR.glob(f"{track.stem}.*"))
    raws = [p for p in raws if p.suffix != ".json"]

    if ogg.exists() and not (args.force or args.repost):
        print(f"[건너뜀] {track.stem}.ogg 이미 존재")
        return {"track": track.key, "status": "skipped"}

    model_key = args.model or track.model
    print(f"[{track.priority}] {track.key} — {track.title} (model={MODELS[model_key]})")
    if raws and (args.repost or not args.force):
        raw = raws[0]
        print(f"    raw 재사용: {raw.name} ({raw.stat().st_size:,}바이트)")
    else:
        data, mime = generate_raw(track, model_key)
        raw = RAW_DIR / f"{track.stem}{_ext_for_mime(mime)}"
        raw.write_bytes(data)

    work = RAW_DIR / f"{track.stem}._decoded.wav"
    decode_to_wav(raw, work)
    samples, sr = sf.read(str(work), always_2d=True, dtype="float32")
    before = analyze(samples, sr)

    edit_info: dict = {}
    if track.loop:
        # 페이드 제거 → 루프 접합 순서가 중요하다(페이드를 남기면 이음매가 무음으로 꺼진다).
        samples, trim = trim_edges(samples, sr)
        samples, join = loopify(samples, sr, args.xfade)
        edit_info = {**trim, **join}
        sf.write(str(work), samples, sr, subtype="PCM_16")
    elif track.cut_range:
        samples, edit_info = clean_cut(samples, sr, *track.cut_range)
        sf.write(str(work), samples, sr, subtype="PCM_16")
    after = analyze(samples, sr)

    loud = normalize_to_ogg(work, ogg)
    work.unlink(missing_ok=True)

    entry = {
        "track": track.key,
        "sheet_no": track.sheet_no,
        "file": ogg.name,
        "status": "ok",
        "model": MODELS[model_key],
        "loop": track.loop,
        "raw_bytes": raw.stat().st_size,
        "ogg_bytes": ogg.stat().st_size,
        "raw_analysis": before,
        "final_analysis": after,
        "post_edit": edit_info,
        "loudness": loud,
        "generated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
    }
    print(
        f"    → {ogg.name} {ogg.stat().st_size:,}바이트 / {after['duration_sec']}초 / "
        f"원본 {loud['input_lufs']:.1f} LUFS → {TARGET_LUFS} LUFS / "
        f"이음매 클릭비 {after['seam_click_ratio']} / 머리·꼬리 세기비 "
        f"{after['head_rms_ratio']}·{after['tail_rms_ratio']}"
    )
    return entry


def save_log(entries: list[dict]) -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    prev: dict[str, dict] = {}
    if LOG_PATH.exists():
        prev = {e["track"]: e for e in json.loads(LOG_PATH.read_text("utf-8"))}
    for e in entries:
        if e.get("status") == "ok":
            prev[e["track"]] = e
    LOG_PATH.write_text(
        json.dumps(list(prev.values()), ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"기록: {LOG_PATH}")


def main() -> int:
    # Windows 콘솔 기본 코드페이지(cp949)에서 한국어·기호 출력이 깨지지 않게 강제
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")

    ap = argparse.ArgumentParser(description="Lyria 3 BGM 생성·후처리")
    ap.add_argument("keys", nargs="*", help="생성할 트랙 key (생략 시 --priority/--all 사용)")
    ap.add_argument("--list", action="store_true", help="트랙 목록만 출력")
    ap.add_argument("--all", action="store_true", help="전 트랙")
    ap.add_argument("--priority", type=int, help="해당 우선순위 트랙만")
    ap.add_argument(
        "--model",
        choices=sorted(MODELS),
        default=None,
        help="트랙별 기본 모델을 무시하고 강제 지정",
    )
    ap.add_argument("--force", action="store_true", help="기존 OGG를 덮어쓰고 API도 재호출")
    ap.add_argument("--repost", action="store_true", help="raw 재사용, 후처리만 재실행")
    ap.add_argument("--xfade", type=float, default=DEFAULT_XFADE_SEC, help="루프 크로스페이드 상한(초)")
    args = ap.parse_args()

    if args.list:
        for t in TRACKS:
            done = "O" if (BGM_DIR / f"{t.stem}.ogg").exists() else " "
            loop = "루프" if t.loop else "논루프"
            print(f"[{done}] P{t.priority} {t.key:24s} {loop:4s} {t.sheet_no:12s} {t.title}")
        return 0

    if args.keys:
        unknown = [k for k in args.keys if k not in BY_KEY]
        if unknown:
            print(f"알 수 없는 트랙 key: {unknown}", file=sys.stderr)
            return 2
        targets = [BY_KEY[k] for k in args.keys]
    elif args.priority is not None:
        targets = [t for t in TRACKS if t.priority == args.priority]
    elif args.all:
        targets = list(TRACKS)
    else:
        ap.error("트랙 key, --priority, --all 중 하나를 지정하라")

    entries: list[dict] = []
    failed: list[tuple[str, str]] = []
    aborted = False
    for t in targets:
        try:
            entries.append(process(t, args))
        except QuotaError as exc:
            print(f"    !! 쿼터 소진으로 중단: {exc}", file=sys.stderr)
            failed.append((t.key, f"QUOTA: {exc}"))
            aborted = True
            break
        except Exception as exc:  # noqa: BLE001 — 한 곡 실패가 전체를 막지 않게
            print(f"    !! 실패 {t.key}: {type(exc).__name__}: {exc}", file=sys.stderr)
            failed.append((t.key, f"{type(exc).__name__}: {exc}"))

    save_log(entries)
    ok = [e for e in entries if e.get("status") == "ok"]
    print(f"\n요약: 생성 {len(ok)}곡 / 건너뜀 {len(entries) - len(ok)}곡 / 실패 {len(failed)}곡")
    for key, why in failed:
        print(f"  실패: {key} — {why}")
    if aborted:
        print("  (쿼터 소진 — 리셋 후 같은 명령으로 재실행하면 남은 곡부터 이어서 진행한다)")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
