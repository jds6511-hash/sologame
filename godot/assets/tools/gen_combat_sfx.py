"""SD-1: 전투 SFX 골격 - numpy 파형 합성 (재생성 가능).

참조:
  docs\\art\\audio-direction.md 4-1장 - 전사(대검) 계열 합성 방향: 저역 사각파 임팩트 +
    노이즈 버스트, 피치 하강 스윕 - 묵직하고 느린 "쿵". 공통 전투음(몬스터/플레이어 피격,
    회피 대시, 몬스터 사망 등)도 이 문서 4-1장 목록 기준.
  docs\\design\\systems\\combat.md 5-3장 - 히트스톱 약(0.03s, 흔들림 없음) / 중(0.06s, 약)
    / 강(0.10s, 중) 3단 타이밍 -> HitFeedbackPreset 3종(hitfeedback_weak/medium/strong.tres)
    사운드 슬롯과 세기가 대응되도록 합성 강도를 3단으로 차등.

기법: 사각파/톱니파/노이즈 + ADSR 엔벨로프 + 주파수 스윕(8비트 레트로 톤 유지).
포맷: 44100Hz, 16bit, 모노 WAV. 파일명 `sfx_<카테고리>_<이름>.wav`.
출력: godot\\assets\\audio\\sfx\\

M2 수직 슬라이스(전사 1직업 + 몬스터 3종) 필요분만 우선 제작한다(SD-1 범위):
  기본 공격 히트 약/중/강, 스킬 히트, 회피 대시, 플레이어 피격, 몬스터 사망, 포션 사용.
"""

from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

SR = 44100
OUT_DIR = Path(__file__).resolve().parents[1] / "audio" / "sfx"


def _adsr(n: int, attack: float, decay: float, sustain_level: float, release: float) -> np.ndarray:
    """샘플 n개 길이의 선형 ADSR 엔벨로프(각 구간은 초 단위, 자동으로 정규화)."""
    a = max(1, int(attack * SR))
    d = max(1, int(decay * SR))
    r = max(1, int(release * SR))
    s = max(0, n - a - d - r)
    env = np.concatenate(
        [
            np.linspace(0.0, 1.0, a, endpoint=False),
            np.linspace(1.0, sustain_level, d, endpoint=False),
            np.full(s, sustain_level),
            np.linspace(sustain_level, 0.0, r, endpoint=True),
        ]
    )
    if len(env) < n:
        env = np.concatenate([env, np.zeros(n - len(env))])
    return env[:n]


def _square(freq_hz: np.ndarray, t: np.ndarray) -> np.ndarray:
    phase = np.cumsum(freq_hz) / SR
    return np.sign(np.sin(2.0 * np.pi * phase))


def _saw(freq_hz: np.ndarray, t: np.ndarray) -> np.ndarray:
    phase = np.cumsum(freq_hz) / SR
    return 2.0 * (phase - np.floor(0.5 + phase))


def _noise(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.uniform(-1.0, 1.0, n)


def _sine(freq_hz: np.ndarray, t: np.ndarray) -> np.ndarray:
    phase = np.cumsum(freq_hz) / SR
    return np.sin(2.0 * np.pi * phase)


def _triangle(freq_hz: np.ndarray, t: np.ndarray) -> np.ndarray:
    phase = np.cumsum(freq_hz) / SR
    return 2.0 * np.abs(2.0 * (phase - np.floor(phase + 0.5))) - 1.0


def _pitch_sweep(n: int, start_hz: float, end_hz: float, curve: float = 1.0) -> np.ndarray:
    x = np.linspace(0.0, 1.0, n) ** curve
    return start_hz + (end_hz - start_hz) * x


def _write_wav(path: Path, samples: np.ndarray) -> None:
    peak = np.max(np.abs(samples))
    if peak > 1e-9:
        samples = samples / peak * 0.98
    pcm = (samples * 32767.0).astype(np.int16)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())
    print(f"저장: {path.relative_to(path.parents[2])}")


def gen_hit_weak(rng: np.random.Generator) -> np.ndarray:
    """기본 공격 히트 - 약 (combat.md 5-3: 히트스톱 0.03s, 흔들림 없음).
    전사 대검 저역 임팩트를 가볍게 - 짧고 얕은 "톡" 쿵."""
    dur = 0.09
    n = int(SR * dur)
    t = np.arange(n) / SR
    freq = _pitch_sweep(n, 160.0, 70.0, curve=1.6)
    body = _square(freq, t) * _adsr(n, 0.001, 0.03, 0.15, 0.05)
    noise = _noise(n, rng) * _adsr(n, 0.001, 0.015, 0.0, 0.02)
    return body * 0.6 + noise * 0.35


def gen_hit_medium(rng: np.random.Generator) -> np.ndarray:
    """기본 공격 히트 - 중 (히트스톱 0.06s, 흔들림 약). 콤보 마무리급 무게."""
    dur = 0.14
    n = int(SR * dur)
    t = np.arange(n) / SR
    freq = _pitch_sweep(n, 130.0, 45.0, curve=1.4)
    body = _square(freq, t) * _adsr(n, 0.002, 0.05, 0.2, 0.08)
    sub = _sine(np.full(n, 55.0), t) * _adsr(n, 0.002, 0.05, 0.15, 0.09)
    noise = _noise(n, rng) * _adsr(n, 0.001, 0.03, 0.0, 0.03)
    return body * 0.55 + sub * 0.3 + noise * 0.4


def gen_hit_strong(rng: np.random.Generator) -> np.ndarray:
    """기본 공격 히트 - 강 (히트스톱 0.10s, 흔들림 중). 치명타급 - 묵직하고 느린 "쿵"."""
    dur = 0.22
    n = int(SR * dur)
    t = np.arange(n) / SR
    freq = _pitch_sweep(n, 110.0, 32.0, curve=1.3)
    body = _square(freq, t) * _adsr(n, 0.003, 0.08, 0.25, 0.13)
    sub = _sine(np.full(n, 42.0), t) * _adsr(n, 0.003, 0.09, 0.2, 0.15)
    noise = _noise(n, rng) * _adsr(n, 0.001, 0.05, 0.05, 0.05)
    return body * 0.5 + sub * 0.4 + noise * 0.45


def gen_skill_hit(rng: np.random.Generator) -> np.ndarray:
    """스킬 히트 (공용) - 기본 히트(강)에 고역 "쨍" 악센트를 얹어 스킬 특유의 존재감을 부여."""
    dur = 0.20
    n = int(SR * dur)
    t = np.arange(n) / SR
    freq = _pitch_sweep(n, 120.0, 40.0, curve=1.3)
    body = _square(freq, t) * _adsr(n, 0.002, 0.06, 0.2, 0.1)
    noise = _noise(n, rng) * _adsr(n, 0.001, 0.03, 0.0, 0.04)
    accent_n = int(SR * 0.05)
    accent = _triangle(np.full(accent_n, 1200.0), t[:accent_n]) * _adsr(accent_n, 0.001, 0.02, 0.0, 0.03)
    accent = np.concatenate([accent, np.zeros(n - accent_n)])
    return body * 0.45 + noise * 0.35 + accent * 0.5


def gen_dodge(rng: np.random.Generator) -> np.ndarray:
    """회피 대시 - 공기를 가르는 화이트노이즈 스윕(무게감 없이 가볍게)."""
    dur = 0.18
    n = int(SR * dur)
    noise = _noise(n, rng)
    # 대역 이동 인상을 주기 위해 사인 캐리어로 진폭 변조(간이 밴드패스 느낌)
    t = np.arange(n) / SR
    carrier_freq = _pitch_sweep(n, 500.0, 2200.0, curve=0.7)
    carrier = _sine(carrier_freq, t)
    swoosh = noise * (0.5 + 0.5 * carrier)
    env = _adsr(n, 0.02, 0.06, 0.3, 0.08)
    return swoosh * env * 0.8


def gen_player_hit(rng: np.random.Generator) -> np.ndarray:
    """플레이어 피격 - 몬스터 피격음과 구분되도록 저역 쿵 위에 짧은 경고성 고역 버즈를 겹침."""
    dur = 0.16
    n = int(SR * dur)
    t = np.arange(n) / SR
    freq = _pitch_sweep(n, 140.0, 55.0, curve=1.4)
    body = _square(freq, t) * _adsr(n, 0.002, 0.05, 0.2, 0.08)
    buzz_n = int(SR * 0.07)
    buzz = _square(np.full(buzz_n, 320.0), t[:buzz_n]) * _adsr(buzz_n, 0.001, 0.02, 0.3, 0.03)
    buzz = np.concatenate([buzz, np.zeros(n - buzz_n)])
    noise = _noise(n, rng) * _adsr(n, 0.001, 0.03, 0.0, 0.03)
    return body * 0.5 + buzz * 0.35 + noise * 0.35


def gen_monster_death(rng: np.random.Generator) -> np.ndarray:
    """몬스터 사망 (공용 1종) - 무너지는 인상의 하강 톱니 스윕 + 노이즈 붕괴, 긴 여운."""
    dur = 0.5
    n = int(SR * dur)
    t = np.arange(n) / SR
    freq = _pitch_sweep(n, 260.0, 40.0, curve=0.8)
    body = _saw(freq, t) * _adsr(n, 0.005, 0.15, 0.3, 0.35)
    noise = _noise(n, rng) * _adsr(n, 0.005, 0.2, 0.05, 0.3)
    return body * 0.5 + noise * 0.35


def gen_potion_use(rng: np.random.Generator) -> np.ndarray:
    """포션 사용 - 밝고 짧은 상승 아르페지오(사인/삼각) - 회복의 긍정적 피드백."""
    notes_hz = [523.25, 659.25, 783.99]  # C5-E5-G5
    note_dur = 0.08
    n_note = int(SR * note_dur)
    t_note = np.arange(n_note) / SR
    env = _adsr(n_note, 0.005, 0.02, 0.4, 0.04)
    out = np.zeros(0)
    for f in notes_hz:
        tone = _triangle(np.full(n_note, f), t_note) * 0.6 + _sine(np.full(n_note, f * 2.0), t_note) * 0.2
        out = np.concatenate([out, tone * env])
    tail_n = int(SR * 0.12)
    t_tail = np.arange(tail_n) / SR
    tail = _sine(np.full(tail_n, notes_hz[-1] * 2.0), t_tail) * _adsr(tail_n, 0.01, 0.03, 0.2, 0.08) * 0.3
    return np.concatenate([out, tail])


GENERATORS = {
    "sfx_combat_hit_weak.wav": gen_hit_weak,
    "sfx_combat_hit_medium.wav": gen_hit_medium,
    "sfx_combat_hit_strong.wav": gen_hit_strong,
    "sfx_combat_skill_hit.wav": gen_skill_hit,
    "sfx_combat_dodge.wav": gen_dodge,
    "sfx_combat_player_hit.wav": gen_player_hit,
    "sfx_combat_monster_death.wav": gen_monster_death,
    "sfx_combat_potion_use.wav": gen_potion_use,
}


def main() -> None:
    rng = np.random.default_rng(20260717)
    for filename, gen_fn in GENERATORS.items():
        samples = gen_fn(rng)
        _write_wav(OUT_DIR / filename, samples)


if __name__ == "__main__":
    main()
