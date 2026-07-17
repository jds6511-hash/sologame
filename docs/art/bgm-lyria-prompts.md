# BGM 리리아 3 생성 프롬프트 시트

- **최종 수정일**: 2026-07-18
- **담당**: audio-designer
- **의존 문서**:
  - `docs\art\audio-direction.md` (1장 지역별 BGM 무드 맵, 2장 상황별 BGM 슬롯·주야간 정책, 3장 전환 규칙, 5장 곡 수 추정 — 본 시트의 트랙 목록·우선순위·프롬프트 방향은 이 문서를 그대로 계승)
  - `docs\design\GAME_CONCEPT.md` (단일 왕국, 시작 지역 = 동부 변경, 주야간 시스템, 톤 밝음6:어둠4)
  - `docs\art\ASSET_SOURCES.md` (8-2절 — 시작 지역 BGM CC0 소싱 시도 실패 및 임시 numpy 패드 채택 경위. 본 시트의 결과물이 이 임시 파일들을 교체한다)
- **변경 이력**:
  - 2026-07-18: 최초 작성 — 디렉터가 Google 리리아 3(Lyria 3)로 BGM을 직접 생성하기로 함에 따라, 생성 대상 트랙 목록과 트랙별 영어 프롬프트, 후처리(루프·정규화·변환) 체크리스트, 라이선스 기록 방침을 정리

> **범위**: 본 문서는 리리아 3 생성을 위한 **입력 시트**다. 실제 생성은 디렉터가 API 또는 Gemini 웹 앱에서 수행하며, audio-designer는 파일이 도착한 뒤 3장 후처리 절차를 수행하고 4장 방침에 따라 `ASSET_SOURCES.md`에 기록한다.
> **리리아 3 제약 전제**: 1회 생성 = 약 30초 클립, 가사 없는 순수 기악(instrumental)만 요청, 칩튠/8비트 톤을 프롬프트 문구로 강하게 지정(신스 파형·템포·악기 편성을 명시하지 않으면 일반 오케스트라 톤으로 나올 위험이 있음).

---

## 1. 트랙 목록표

우선순위는 "높음(우선 생성)/중간/낮음(M3+ 콘텐츠 완성 후)" 3단계. 루프 여부는 `audio-direction.md` 2-1절 슬롯 표 기준.

### 1-1. M2 필수 트랙 (6곡 — 최우선 생성)

| # | 트랙명 | 슬롯 | 용도 | 루프 | 우선순위 |
|---|---|---|---|---|---|
| M2-1 | 타이틀 테마 | S1 | 타이틀 화면 | 루프 | 최상 |
| M2-2 | 노베라 거점 평화 | S2 | 시작 지역 마을(노베라) BGM | 루프 | 최상 |
| M2-3 | 동부 변경 남측 필드 (주간) | S3 | 시작 필드 탐험 BGM | 루프 | 최상 |
| M2-4 | 일반 전투 (전반) | S4-전반 | 정예·무리·퀘스트 전투 + **디버그 전투장 겸용** | 루프 | 최상 |
| M2-5 | 보스전 (일반) | S5-일반 | 일반 보스 루프 본편 (+ 스팅어 보조 프롬프트 별도) | 루프 | 최상 |
| M2-6 | 소균열 던전 (공용) | S3 변주 | 전 권역 공용 소균열 던전 | 루프 | 최상 |

**판단 사항 (지시된 두 가지, audio-designer 결정 — 디렉터 재가 불요 항목)**

1. **시작 지역 야간 트랙 필요 여부**: `audio-direction.md` 2-2절 정책상 동부 변경 남측은 "일반 필드" 등급이라 별도 야간 곡이 아니라 **런타임 로우패스 필터 + 볼륨 −4dB**로 처리한다(systems-dev 구현). 따라서 **M2-3(주간 필드) 1곡만 생성하면 충분**하며, 별도의 "시작 지역 야간" 트랙은 M2 목록에 넣지 않았다. 야간 전용 신규 트랙이 필요한 곳은 "야간 활성 지역"(균열 외곽·대수림·옛 전선)뿐이며 이는 M3+ 후보(2-3절 25~26번)로 분류했다.
2. **디버그 전투장 겸용 여부**: 디버그 전투장은 QA/개발용 임시 씬으로 별도 지역색이 필요 없으므로, 신규 트랙을 만들지 않고 **M2-4(일반 전투 전반) 트랙을 그대로 재생**한다.

### 1-2. M3+ 후보 트랙 (28곡)

| # | 트랙명 | 슬롯/지역 | 용도 | 루프 | 우선순위 |
|---|---|---|---|---|---|
| 7 | 브란텔 (왕도) | 정주지 | 왕도 BGM | 루프 | 높음 |
| 8 | 그란시아 | 정주지 | 곡창·문벌파 도시 | 루프 | 중간 |
| 9 | 아르셀 | 정주지 | 학술·호반 도시 | 루프 | 중간 |
| 10 | 살레노 | 정주지 | 항구·상업 도시 | 루프 | 중간 |
| 11 | 오란세 | 정주지 | 신성 도시국가(격상됨 — 특색 명확) | 루프 | 높음 |
| 12 | 미스란 | 정주지 | 엘프 접경 교역 도시 | 루프 | 중간 |
| 13 | 두르간 | 정주지 | 광산·드워프 도시 | 루프 | 중간 |
| 14 | 하프나 | 정주지 | 어항·냉해 도시 | 루프 | 중간 |
| 15 | 발크렌 | 정주지 | 요새·군사 도시 | 루프 | 중간 |
| 16 | 카엘론 (초기/성장 2단계) | 정주지 | 하사 도시(노베라 모티프 변주) | 루프 | 낮음(엔드게임 성장 콘텐츠) |
| 17 | 마을·부락 공용 목가 | 정주지 | 소규모 정주지 전체 공유 | 루프 | 높음(재생 빈도 高) |
| 18 | 중부 왕령 필드 | 필드 권역 | 안전 지대 필드 | 루프 | 높음 |
| 19 | 남부 해안·구릉 필드 | 필드 권역 | 여행 필드(살레노 야외판) | 루프 | 중간 |
| 20 | 서부 실비엔 대수림 | 필드 권역 | 신비 숲(미스란 모티프 공유) | 루프 | 중간 |
| 21 | 북부 강철산맥 | 필드 권역 | 한랭 필드 | 루프 | 중간 |
| 22 | 옛 전선·재의 평원 | 필드 권역 | 어둠4 주 무대 | 루프 | 낮음(중후반) |
| 23 | 균열 지대·악마 세력권 | 필드 권역 | 악마 세력권 필드 | 루프 | 낮음(중후반) |
| 24 | 심연 회랑 | 필드 권역 | 엔드게임 최심부 | 루프 | 낮음(엔드게임) |
| 25 | 야간 활성 지역 공용 필드곡 | 야간 정책 | 균열 외곽·대수림·옛 전선 야간 | 루프 | 높음(시스템 필수) |
| 26 | 재의 평원 야간 전용 변주 | 야간 정책 | 야간 전용 출몰 지역 강화판 | 루프 | 낮음 |
| 27 | 일반 전투 (후반) | S4-후반 | 옛 전선 이후 전투 | 루프 | 낮음(후반) |
| 28 | 보스전 (상위) | S5-상위 | 발크렌 방어전급 이상 (+ 스팅어 보조) | 루프 | 낮음(중후반) |
| 29 | 최종전 1차 — 대규모 전쟁 | S6 | 3종족 연합 vs 심연 군단 | 루프 | **최상(대체 불가 슬롯 — 후보 조기 확보 권장)** |
| 30 | 최종 보스전 | S7 | 최종 결전 | 루프(+스팅어) | 최상(엔드게임 필수) |
| 31 | 히든·신비 | S8 | 숨겨진 퀘스트·신비 연출 | 짧은 루프 | 낮음(발견 유도 금지) |
| 32 | 슬픔·회상 | S9 | 어둠4 서사 컷신 | 루프 | 중간 |
| 33 | 의전·팡파레 | S10 | 승급 의식·전직 | 논루프 | 중간 |
| 34 | 엔딩 | S11 | 크레딧(타이틀 완성형 변주) | 논루프(페이드아웃 가능) | 낮음(엔드게임) |

- 합계 34곡(M2 6 + M3+ 28)으로 `audio-direction.md` 5-2절 "약 29~31곡" 추정과 대체로 정합한다(차이는 야간 변주·카엘론 2단계 등 세부 변주를 별도 행으로 나눠 센 데서 발생, 실질 신규 작곡 부담은 동일).

---

## 2. 트랙별 리리아 3 프롬프트

각 항목은 **영어 프롬프트**(리리아 3 입력용) + **한국어 설명 한 줄**. 프롬프트는 공통적으로 "8-bit chiptune / 파형 악기 / 템포 BPM / instrumental only / 루프 친화 문구(사라짐 없는 균일한 에너지, 인트로·아웃트로 없음)"를 포함해 30초 클립이 루프 소스로 바로 쓰일 수 있게 설계했다. 논루프 트랙(팡파레·엔딩·스팅어)은 반대로 "명확한 시작과 끝"을 명시했다.

### 2-1. M2 필수 트랙

**M2-1. 타이틀 테마 (S1)**
- 프롬프트: `Epic 8-bit chiptune title theme for a fantasy RPG, NES-style square wave lead melody over triangle wave bass and arpeggiated chords, starting hopeful and heroic then briefly dipping into a minor, melancholic bridge before returning to a triumphant major theme, moderate tempo around 100 BPM, orchestral-scale drama compressed into retro synth voices, instrumental only, seamless loop with consistent energy from start to end, no fade in or fade out.`
- 설명: 밝음6:어둠4를 한 곡에 담은 서사적 메인 테마 — 노베라·엔딩과 모티프 공유 전제.

**M2-2. 노베라 거점 평화 (S2)**
- 프롬프트: `Upbeat 8-bit chiptune village theme for a frontier boomtown, bright major key folk/country-inspired melody, square wave lead with a bouncy triangle wave bassline and light noise-channel percussion like a simple tambourine pulse, cheerful and welcoming "coming home" feeling, tempo around 120 BPM, instrumental only, steady groove throughout with no dramatic build or ending, loop-friendly.`
- 설명: 게임의 밝음 6을 대표하는 "집" 같은 거점 곡.

**M2-3. 동부 변경 남측 필드 — 주간 (S3)**
- 프롬프트: `8-bit chiptune overworld exploration theme, bright major key melody suggesting a frontier being reclaimed and reborn, square wave lead with light syncopation, walking triangle bass, tempo around 110 BPM, hopeful yet with a subtle undertone of caution as if exploring a still-dangerous borderland, instrumental only, consistent energy throughout for seamless looping, no intro swell or ending fade.`
- 설명: 게임의 첫인상 — "재건 속의 긴장"을 옅게 유지.

**M2-4. 일반 전투 — 전반 (S4-전반, 디버그 전투장 겸용)**
- 프롬프트: `Fast-paced 8-bit chiptune battle theme, urgent square wave lead riff over driving triangle bass ostinato and noise-channel snare-like percussion, tempo around 150 BPM, tense and aggressive but not despairing, minor key with a driving rhythmic pulse, instrumental only, high energy sustained evenly from start to end for seamless combat loop, no fade in or fade out.`
- 설명: 잡몹전이 아닌 정예·스크립트 전투 전용 긴박 곡, 디버그 전투장에서도 재사용.

**M2-5. 보스전 — 일반 (S5-일반)**
- 본편 루프 프롬프트: `Intense 8-bit chiptune boss battle theme, dramatic minor key square wave lead with a memorable aggressive riff, heavy triangle bass stabs, fast arpeggios and noise-percussion hits accenting strong beats, tempo around 160 BPM, feels like a dangerous one-on-one duel against a powerful single enemy, more intense and melodically distinct than a generic battle theme, instrumental only, even intensity throughout with no fade, loop-friendly.`
- 인트로 스팅어 보조 프롬프트(2~4초 컷용): `Short dramatic 8-bit chiptune stinger, a sudden intense minor-key sting with a rising noise sweep and a hard hit on the downbeat, signaling a boss enemy has appeared, instrumental only, no need to loop, clear hard ending within a few seconds.`
- 설명: 30초 클립 전체를 스팅어로 쓰지 않고, 클립 도입부 2~4초를 잘라 쓰거나 위 보조 프롬프트로 별도 생성(3장 후처리 참조).

**M2-6. 소균열 던전 (공용, 균열 지대 곡의 축약 변주)**
- 프롬프트: `Eerie 8-bit chiptune dungeon theme representing a corrupted rift, slow tempo around 70 BPM, dissonant square wave arpeggios with chromatic movement, sparse triangle wave drone bass, occasional detuned noise textures suggesting corruption and unnatural presence, unsettling but not horror — more like an alien hunger than fear, instrumental only, steady looping atmosphere with minimal melodic movement, no dramatic peak, seamless loop.`
- 설명: 저레벨부터 "균열 = 이 소리"를 각인시키는 공용 던전 곡.

### 2-2. M3+ 후보 — 정주지 (11)

**7. 브란텔 (왕도)**
- `Regal 8-bit chiptune royal capital theme, ceremonial march feel with square wave "brass" fanfare motifs and a steady stately rhythm, triangle bass in strict march time, tempo around 90 BPM, grand and authoritative but cold, formal and slightly unwelcoming rather than warm, instrumental only, even grandeur sustained throughout for a seamless loop, no fade.`
- 장엄하되 "환영하지 않는" 위압감의 궁정 행진곡.

**8. 그란시아**
- `Elegant 8-bit chiptune courtly waltz in 3/4 time, ornate square wave melody with decorative grace-note flourishes, delicate triangle wave arpeggios, tempo around 80 BPM, beautiful but distant and exclusive, sharing the regal fanfare character of a royal capital theme but more decorative and dance-like, instrumental only, consistent waltz pulse throughout for seamless looping.`
- 브란텔과 같은 계열이되 더 장식적인 3박자 궁정 무곡.

**9. 아르셀**
- `Calm and studious 8-bit chiptune theme for a scholarly lakeside city, slow lyrical triangle wave arpeggios rippling like still water, gentle square wave counter-melody entering sparingly, tempo around 70 BPM, quiet library-like stillness and intellectual serenity, instrumental only, minimal dynamic change for a peaceful seamless loop.`
- 도서관의 정적 같은 잔잔한 물결.

**10. 살레노**
- `Lively 8-bit chiptune sea shanty in a swung 6/8 shuffle rhythm, bright square wave hornpipe-style melody, bouncy triangle bass, light noise-channel percussion like a jaunty tambourine, tempo around 130 BPM, the most cheerful and bustling harbor-market energy in the kingdom, instrumental only, consistent festive energy throughout, seamless loop, no fade.`
- 왕국에서 가장 명랑한 뱃노래·호른파이프풍.

**11. 오란세**
- `Serene 8-bit chiptune hymn theme for a holy pilgrimage city, very slow tempo around 60 BPM, sustained organ-like triangle/sine tones forming a simple chant-like melody, a soft recurring bell motif, gentle and all-embracing sacred atmosphere, instrumental only, no percussion, steady contemplative mood sustained throughout for a seamless loop with no fade.`
- 신성 도시국가 격상에 맞춘 성가풍 + 종소리 모티프.

**12. 미스란**
- `Mysterious 8-bit chiptune theme for an elven border trading post, pentatonic and dorian mode melody distinct from human city themes, square wave lead with an exotic, otherworldly interval feel, light shimmering triangle arpeggios, tempo around 90 BPM, evokes the threshold of an ancient forest, instrumental only, steady mysterious atmosphere throughout, seamless loop.`
- 인간 도시와 음계 자체가 다른 신비 교역지.

**13. 두르간**
- `Sturdy 8-bit chiptune dwarven mining city theme, heavy low square wave riff functioning as a work-song, strong hammering noise-channel percussion on the beat like forge hammers, tempo around 100 BPM, proud and industrious with a warm furnace-like undertone, instrumental only, consistent driving groove throughout, seamless loop, no fade.`
- 드워프 노동요풍 + 용광로의 온기.

**14. 하프나**
- `Gruff 8-bit chiptune northern fishing port theme, minor-key sea shanty rhythm, terse square wave melody over a rolling triangle bass like cold waves, sparse noise-channel percussion, tempo around 100 BPM, hardy and stoic, a colder darker counterpart to a cheerful harbor theme, instrumental only, steady wave-like repetition throughout, seamless loop.`
- 살레노의 명랑함을 뺀 북구풍 겨울 바다.

**15. 발크렌**
- `Tense 8-bit chiptune military garrison theme, march rhythm with snare-like noise-channel percussion, minor key square wave brass-style motif, disciplined and watchful even in peacetime, tempo around 110 BPM, instrumental only, unbroken vigilant march energy throughout for a seamless loop, no fade.`
- 평시인데도 경계가 풀리지 않는 군가풍.

**16. 카엘론 (하사 도시 — 2단계 변주)**
- 초기(느린) 버전: `Slow, gentle 8-bit chiptune theme sharing the melodic motif of a cheerful frontier boomtown theme but rendered quietly and tenderly, sparse square wave lead, soft triangle bass, tempo around 85 BPM, quiet pride and healing after hardship, instrumental only, calm and steady throughout, seamless loop.`
- 성장 후(밝은) 버전: `Warmer, slightly faster reprise of the same frontier-town melodic motif, fuller instrumentation with square wave lead, bouncy triangle bass and light percussion, tempo around 110 BPM, hopeful growth and recovered community pride, instrumental only, upbeat but not as boisterous as the main boomtown theme, seamless loop, no fade.`
- 노베라 모티프를 공유하는 재건 서사 — 영지 성장에 따라 교체.

**17. 마을·부락 공용 목가**
- `Simple, humble 8-bit chiptune pastoral theme for small villages and hamlets, plain square wave folk melody, gentle triangle bass, tempo around 90 BPM, modest and homely, instrumental only, unassuming steady loop with no dramatic moments, no fade.`
- 소박한 목가풍, 전 마을·부락 공유.

### 2-3. M3+ 후보 — 필드 권역 (7) + 야간 공용 (2)

**18. 중부 왕령**
- `Peaceful 8-bit chiptune overworld theme for open safe farmland plains, gentle unhurried square wave melody, warm triangle bass, tempo around 90 BPM, orderly and relaxed safe-zone atmosphere, instrumental only, even calm energy throughout, seamless loop, no fade.`

**19. 남부 해안·구릉**
- `Breezy 8-bit chiptune coastal overworld theme, sunny travel-adventure feel sharing the shuffle-rhythm character of a lively harbor city but airier and more open, square wave lead, bouncy triangle bass, tempo around 120 BPM, instrumental only, consistent upbeat travel energy throughout, seamless loop.`

**20. 서부 실비엔 대수림**
- `Ancient and awe-inspiring 8-bit chiptune forest theme, slow tempo around 75 BPM, mysterious mode melody sharing motifs with an elven trading-post theme but deeper and more ambient, sparse square wave phrases over a sustained triangle drone, subtle shimmering textures like light through leaves, instrumental only, hushed reverent atmosphere throughout, seamless loop, no fade.`

**21. 북부 강철산맥**
- `Cold, high-altitude 8-bit chiptune mountain theme, austere square wave melody with wide open intervals suggesting thin mountain air, steady triangle bass, tempo around 85 BPM, bleak grey-blue stony atmosphere, instrumental only, sparse and unhurried throughout, seamless loop, no fade.`

**22. 옛 전선·재의 평원**
- `Somber 8-bit chiptune wasteland field theme, minor key, slow tempo around 80 BPM, mostly a low sustained drone with only occasional sparse melodic phrases, mournful but not horror-styled — a quiet grief rather than fear, evokes marching forward through ruin and loss, instrumental only, restrained and steady throughout, seamless loop, no fade.`

**23. 균열 지대·악마 세력권**
- `Unsettling 8-bit chiptune theme for a demon-corrupted rift zone, irregular slow tempo around 70 BPM, dissonant chromatic arpeggios on square wave, unstable rhythm that avoids a steady pulse, conveys hollow craving and alien intelligence rather than jump-scare horror, instrumental only, unnerving but controlled atmosphere throughout, seamless loop, no dramatic climax.`

**24. 심연 회랑**
- `Minimal dark ambient 8-bit chiptune theme for the deepest abyss corridor, very slow tempo around 60 BPM, near-melody-less, dominated by a low pulsing square wave tone and long reverberant triangle wave sustain, oppressive silence and dread pressure, instrumental only, sparse and unchanging throughout for a seamless tense loop.`

**25. 야간 활성 지역 공용 필드곡**
- `Tense 8-bit chiptune nighttime hunting-grounds theme, minor key, slower tempo than the daytime field theme around 80 BPM, wary square wave melody with more silence between phrases, low ominous triangle bass, clearly signals rising danger after dark, instrumental only, steady creeping tension throughout, seamless loop, no fade.`

**26. 재의 평원 야간 전용 변주**
- `Darker, sparser variant of a tense nighttime hunting theme, tempo around 75 BPM, minor key, even more silence and space between notes, faint dissonant textures suggesting whispers and lingering corruption, instrumental only, minimal and haunting throughout, seamless loop, no fade.`

### 2-4. M3+ 후보 — 전투·최종전 (4)

**27. 일반 전투 — 후반**
- `Fast, grim 8-bit chiptune battle theme for the war-torn later chapters, tempo around 155 BPM, driving minor-key square wave riff with a heavier, more desperate edge than an early-game battle theme, insistent noise-percussion hits, instrumental only, relentless energy sustained evenly throughout, seamless combat loop, no fade.`

**28. 보스전 — 상위**
- 본편: `Epic 8-bit chiptune elite boss battle theme, tempo around 165 BPM, bigger and more menacing than a standard boss theme, layered square wave lead over driving triangle bass and aggressive noise percussion, dramatic minor-key riff suggesting an overwhelming siege-scale threat, instrumental only, sustained maximum intensity throughout, seamless loop, no fade.`
- 스팅어 보조: `Short intense 8-bit chiptune stinger, bigger and more ominous rising sweep and heavier hit than a standard boss stinger, signaling an elite threat, instrumental only, no loop needed, hard clear ending within a few seconds.`

**29. 최종전 1차 — 대규모 전쟁 (S6, 대체 불가)**
- `Massive 8-bit chiptune war theme depicting an alliance of three peoples fighting a demonic legion, tempo around 150 BPM, marching rhythm built from a military motif, layered with a human brass-like fanfare motif, an elven modal melodic motif, and a low dwarven riff motif all interweaving, periodically clashing against a dissonant chromatic demonic motif, the densest and most layered piece in the game, instrumental only, sustained epic intensity throughout, seamless loop, no fade.`
- **대체 불가 슬롯 방침**: `audio-direction.md` 5-2절 지시대로, 이 곡은 위 프롬프트에서 악기 비중(3종족 모티프 중 무엇을 전면에 둘지)만 조금씩 바꿔 **2~3개 변주를 미리 생성해 비교 확보**할 것을 권고한다.

**30. 최종 보스전 (S7)**
- `Intense 8-bit chiptune final boss theme, tempo around 160 BPM, compresses the layered motifs of an epic three-faction war theme into a focused one-on-one duel, retains fragments of the brass, modal, and low-riff motifs now fighting for dominance against a dissonant demonic motif, dense minor-key climax, instrumental only, maximum sustained intensity throughout, seamless loop, no fade.`

### 2-5. M3+ 후보 — 정서·연출 (4)

**31. 히든·신비 (S8)**
- `Subtle, understated 8-bit chiptune theme for a quiet hidden discovery, tempo around 80 BPM, soft triangle wave arpeggio with a faint mysterious sparkle motif, gentle and low-key rather than triumphant or attention-grabbing, instrumental only, brief and unobtrusive, gentle loop with minimal dynamic change.`
- 발견을 유도하지 않도록 과장 금지(반전 힌트 정책 동조).

**32. 슬픔·회상 (S9)**
- `Quiet, melancholic 8-bit chiptune theme for sorrowful memories, tempo around 65 BPM, sparse minor-key triangle wave melody, long sustained tones, restrained grief without melodrama, instrumental only, gentle and even throughout, seamless loop, no fade.`

**33. 의전·팡파레 (S10, 논루프)**
- `Short triumphant 8-bit chiptune ceremonial fanfare, about 5 to 8 seconds of usable material, bright square wave brass-style flourish building to a clear resolved ending, tempo around 110 BPM, formal and celebratory, instrumental only, does not need to loop, clean definite ending.`

**34. 엔딩 (S11, 논루프)**
- `Triumphant 8-bit chiptune ending theme, a fully realized bright major-key version of the game's title theme motif, tempo around 105 BPM, resolves the earlier melancholic bridge into pure hope and warmth, instrumental only, swells to a satisfying uplifting conclusion, can fade out gracefully at the end, does not need to be a seamless loop.`

---

## 3. 후처리 절차 (파일 도착 후 audio-designer 체크리스트)

리리아 3는 약 30초 단일 클립만 출력하므로, 게임에서 실제로 반복 재생 가능한 BGM으로 만들려면 아래 절차를 곡마다 수행한다.

1. **원본 확인**: 수령한 클립의 포맷(WAV/MP3), 길이(약 30초), 샘플레이트 확인. 원본은 `godot\assets\audio\bgm\_lyria_raw\`(신규, 커밋 제외 권장)에 보관.
2. **루프 포인트 탐색** (루프 트랙만 해당):
   - 파형 편집기(Audacity 등)에서 클립 끝부분과 시작부분의 리듬·화성이 자연스럽게 맞물리는 지점을 탐색.
   - 완전히 맞물리지 않으면(대부분의 경우) **끝 0.5~1초 구간과 시작 0.5~1초 구간을 등파워(equal-power) 크로스페이드**로 접합해 심리스 루프 파일을 재구성.
   - 접합이 어려운 경우 클립을 2회 이어붙여 중간 접합부를 새 루프 포인트로 사용하는 방식도 검토.
3. **스팅어/논루프 트랙 처리** (보스 인트로, 팡파레, 엔딩): 루프 접합 생략, 원하는 길이(2~8초 등)만큼 **클린 컷**(하드 인/아웃, 클릭 노이즈 없는 지점에서 절단).
4. **볼륨 정규화**: 전 트랙 **Integrated Loudness -16 LUFS** 기준으로 통일, True Peak **-1dBTP 이하**로 리미팅 (트랙 간 체감 음량 편차 방지).
5. **포맷 변환**: 정규화·루프 처리 완료된 WAV를 **OGG Vorbis**(품질 q6 내외, 44100Hz)로 변환. 파일명은 `audio-direction.md` 5-1절 규칙(`bgm_<슬롯>_<이름>.ogg`)을 따른다.
6. **Godot 임포트**: 임포트 설정에서 Loop 활성화(루프 트랙), 필요 시 루프 시작 지점 메타데이터 지정. 논루프 트랙은 Loop 비활성.
7. **QA 청취**: 루프 접합부를 헤드폰으로 재생해 클릭/팝/위상 어긋남이 없는지 확인, 최소 3~5분 연속 반복 재생으로 체감 이상 유무 점검.
8. **임시 파일 정리**: 정식 트랙으로 교체된 경우 `bgm_field_eastern_frontier_south_TEMP.ogg` 등 numpy 임시 패드를 제거하고 `ASSET_SOURCES.md` 8-2절을 갱신.

---

## 4. 라이선스·출처 기록 방침

- **AI 생성 BGM은 CC0/CC-BY 소싱과 별도 항목으로 `docs\art\ASSET_SOURCES.md`에 기록한다.** 형식:
  > `<트랙명> — Lyria 3 생성 (Gemini 웹 앱 / API), 생성일 YYYY-MM-DD, 사용 프롬프트 원문: "..."`
- 트랙마다 **실제로 사용한 프롬프트 원문**(본 문서 2장에서 수정 없이 썼다면 "본 시트 그대로", 디렉터가 변형했다면 최종 문구)을 남긴다 — 추후 재생성·변주 시 근거 자료가 된다.
- 본 프로젝트는 **개인용·비배포**이므로 AI 생성물의 저작권/이용 약관 리스크는 현재 낮다. 다만 추후 배포를 고려하게 될 경우 Google 생성형 AI 서비스 약관(출력물 이용 범위, 워터마크 등)을 재확인해야 한다는 점만 참고로 남겨둔다(지금 결정할 사안은 아님).

---

## 5. 디렉터 결정 필요

- 없음. 1장의 "시작 지역 야간 트랙 필요 여부"와 "디버그 전투장 겸용 여부"는 `audio-direction.md` 기존 정책(2-2절 야간 처리 규칙)의 직접 적용이라 audio-designer 판단으로 확정했다. 이견이 있으면 알려달라.
