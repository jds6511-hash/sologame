"""SD-2: 시작 지역 BGM 임시 플레이스홀더 - numpy 화음 패드 루프.

**임시 파일 — 추후 CC0/CC-BY 소싱 곡으로 교체 예정** (자세한 사유는
docs\\art\\ASSET_SOURCES.md 참조: 웹에서 확인한 CC0 후보들의 무드가 필드 탐험곡
요구와 정확히 맞지 않아, 확실히 맞는 정식 소싱 전까지 자리를 채우는 용도).

참조: docs\\art\\audio-direction.md
  - 1-2장 "동부 변경 남측(1~20) - 시작 지역": 개척/새싹/모험의 첫걸음, 보통 템포(100~120),
    밝은 장조 필드곡. STYLE_GUIDE.md 8장 요약 "재건과 긴장"(재건=희망, 긴장=변경의 위험)
  - 4장 전제: BGM은 칩튠/레트로 톤(픽셀아트와 정합)

구성: 8비트 스타일 화음 패드 - 사각파/삼각파 화음(밝은 장조 진행 I-V-vi-IV) 위에
은은한 텐션(가끔 서스펜디드/마이너 보이싱)을 섞어 "희망 속의 긴장"을 표현.
심리스 루프(시작/끝 위상 정렬 + 짧은 크로스페이드)로 반복 재생 가능.

포맷: 44100Hz, 16bit, 모노 WAV로 합성 후 ffmpeg로 OGG(Vorbis)로 변환해 저장
(audio-direction.md 5-1장 "용량상 WAV 대신 OGG 권장" 준수). ffmpeg 미설치 환경에서는
WAV만 남는다.

출력: godot\\assets\\audio\\bgm\\bgm_field_eastern_frontier_south_TEMP.ogg
"""

from __future__ import annotations

import subprocess
import wave
from pathlib import Path

import numpy as np

SR = 44100
BPM = 110.0
BEAT_SEC = 60.0 / BPM
BAR_SEC = BEAT_SEC * 4.0
OUT_DIR = Path(__file__).resolve().parents[1] / "audio" / "bgm"
OUT_NAME_WAV = "bgm_field_eastern_frontier_south_TEMP.wav"
OUT_NAME_OGG = "bgm_field_eastern_frontier_south_TEMP.ogg"

# 밝은 장조(C 메이저) 진행: I - V - vi - IV, 4마디 중 3마디째(vi)에 은은한 긴장감
CHORDS_HZ = [
    (261.63, 329.63, 392.00),  # C  (I)  - 개척의 밝음
    (392.00, 493.88, 587.33),  # G  (V)  - 전진
    (220.00, 261.63, 329.63),  # Am (vi) - 은은한 긴장(변경의 위험)
    (349.23, 440.00, 523.25),  # F  (IV) - 다시 희망으로 회수
]


def _triangle(freq_hz: float, t: np.ndarray) -> np.ndarray:
    phase = freq_hz * t
    return 2.0 * np.abs(2.0 * (phase - np.floor(phase + 0.5))) - 1.0


def _square_soft(freq_hz: float, t: np.ndarray, duty: float = 0.5) -> np.ndarray:
    phase = (freq_hz * t) % 1.0
    return np.where(phase < duty, 1.0, -1.0)


def _bar(chord: tuple[float, float, float], root_bass: float) -> np.ndarray:
    n = int(SR * BAR_SEC)
    t = np.arange(n) / SR
    # 화음 패드: 삼각파 3성부, 살짝 디튠한 2성부를 섞어 8비트 코러스 느낌
    pad = np.zeros(n)
    for f in chord:
        pad += _triangle(f, t) * 0.22
        pad += _triangle(f * 1.003, t) * 0.10
    # 저역 사각파 베이스 - 마디 내내 은은하게 지속(레트로 신스 베이스)
    bass = _square_soft(root_bass, t, duty=0.5) * 0.16
    # 마디 전체에 걸친 부드러운 어택/릴리즈(펄스 노이즈 없이 패드 느낌 유지)
    fade = min(int(SR * 0.05), n // 8)
    env = np.ones(n)
    env[:fade] = np.linspace(0.0, 1.0, fade)
    env[-fade:] = np.linspace(1.0, 0.0, fade)
    return (pad + bass) * env


def _write_wav(path: Path, samples: np.ndarray) -> None:
    peak = np.max(np.abs(samples))
    if peak > 1e-9:
        samples = samples / peak * 0.9
    pcm = (samples * 32767.0).astype(np.int16)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())


def main() -> None:
    bass_roots = [130.81, 196.00, 110.00, 174.61]  # C2/G2/A2/F2 (화음 루트 한 옥타브 아래)
    bars = [_bar(chord, bass) for chord, bass in zip(CHORDS_HZ, bass_roots)]
    loop = np.concatenate(bars * 2)  # 4마디 진행을 2회 반복 - 약 17초 루프

    # 심리스 루프: 끝부분을 시작부분과 짧게 크로스페이드해 루프 이음매의 클릭/단절 방지
    xfade_n = int(SR * BEAT_SEC * 0.5)
    head = loop[:xfade_n].copy()
    tail = loop[-xfade_n:].copy()
    fade_in = np.linspace(0.0, 1.0, xfade_n)
    fade_out = 1.0 - fade_in
    blended = tail * fade_out + head * fade_in
    loop[-xfade_n:] = blended

    out_wav = OUT_DIR / OUT_NAME_WAV
    _write_wav(out_wav, loop)
    print(f"저장: {out_wav}")

    out_ogg = OUT_DIR / OUT_NAME_OGG
    try:
        subprocess.run(
            ["ffmpeg", "-y", "-i", str(out_wav), "-c:a", "libvorbis", "-q:a", "4", str(out_ogg)],
            check=True,
            capture_output=True,
        )
        out_wav.unlink()  # OGG 변환 성공 시 임시 WAV는 제거(OGG만 저장소에 둔다)
        print(f"저장: {out_ogg} (WAV는 OGG 변환 후 삭제)")
    except (FileNotFoundError, subprocess.CalledProcessError) as e:
        print(f"ffmpeg 변환 실패 - WAV만 유지: {e}")


if __name__ == "__main__":
    main()
