"""실패한 아트 후보가 정상 PNG를 덮어쓰지 않는지 검사한다. 이미지 작화·파일 쓰기는 모킹한다."""

import contextlib
import io
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

import gen_player_lpc as generator


class PlayerAssetGateTest(unittest.TestCase):
    def run_generator(self, problems, report=False):
        image = Mock()
        image.width = 112
        image.height = 108

        def candidate(job, report_only, pending=None):
            if pending is not None:
                pending[Path(job + ".png")] = image
            return 90, problems.get(job, [])

        argv = ["gen_player_lpc.py"] + (["--report"] if report else [])
        with patch.object(generator, "build_job", side_effect=candidate), patch.object(
            generator.sys, "argv", argv
        ), patch.object(Path, "mkdir"), contextlib.redirect_stdout(io.StringIO()):
            result = generator.main()
        return result, image

    def test_report_returns_failure_for_invalid_art(self):
        result, image = self.run_generator({"archer": ["손잡이 부유"]}, report=True)
        self.assertEqual(result, 1, "점검 오류가 있는데 성공 종료하면 자동 검사가 결함을 놓친다")
        image.save.assert_not_called()

    def test_second_job_failure_prevents_first_job_from_being_written(self):
        result, image = self.run_generator({"archer": ["머리 침범"]})
        self.assertEqual(result, 1)
        image.save.assert_not_called()
        image.resize.assert_not_called()

    def test_valid_report_does_not_write_anything(self):
        result, image = self.run_generator({}, report=True)
        self.assertEqual(result, 0)
        image.save.assert_not_called()

    def test_valid_batch_is_written_after_validation(self):
        result, image = self.run_generator({})
        self.assertEqual(result, 0)
        self.assertEqual(image.save.call_count, 2, "두 직업 모두 통과한 뒤에만 출력")


if __name__ == "__main__":
    unittest.main()
