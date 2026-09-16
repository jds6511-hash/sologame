"""플레이 영상의 메타데이터와 검토용 프레임을 추출한다. 원본은 변경하지 않는다."""

import argparse
import json
from pathlib import Path

import cv2
from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("video", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--times", type=float, nargs="+", required=True)
    args = parser.parse_args()
    capture = cv2.VideoCapture(str(args.video))
    if not capture.isOpened():
        raise RuntimeError("영상 파일을 열 수 없습니다")
    fps = capture.get(cv2.CAP_PROP_FPS)
    metadata = {
        "file": args.video.name,
        "fps": fps,
        "frames": int(capture.get(cv2.CAP_PROP_FRAME_COUNT)),
        "width": int(capture.get(cv2.CAP_PROP_FRAME_WIDTH)),
        "height": int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT)),
    }
    metadata["duration_seconds"] = metadata["frames"] / fps
    args.output.mkdir(parents=True, exist_ok=True)
    board = Image.new("RGB", (1920, 296 * ((len(args.times) + 3) // 4)), (20, 20, 20))
    draw = ImageDraw.Draw(board)
    for index, seconds in enumerate(args.times):
        capture.set(cv2.CAP_PROP_POS_MSEC, seconds * 1000)
        ok, frame = capture.read()
        if not ok:
            raise RuntimeError(f"{seconds}초 프레임을 읽지 못했습니다")
        image = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
        image.save(args.output / f"video-{seconds:07.3f}.png")
        x, y = index % 4 * 480, index // 4 * 296
        board.paste(image.resize((480, 270)), (x, y + 26))
        draw.text((x + 8, y + 6), f"{seconds:.3f}s", fill="white")
    capture.release()
    board.save(args.output / "video-contact.png")
    (args.output / "metadata.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(metadata, ensure_ascii=False))


if __name__ == "__main__":
    main()
