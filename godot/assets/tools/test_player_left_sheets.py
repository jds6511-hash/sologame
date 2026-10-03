"""좌측 전 상태 완전성/규격과 기존 리소스 불변을 검증한다. 그림의 손잡이는 검수하지 않는다."""
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

from PIL import Image

import gen_player_spriteframes as generator


class LeftSheetTest(unittest.TestCase):
    def setUp(self):
        self.prefix = "player_warrior_v2"
        self.states = generator.JOBS[self.prefix]

    def _write(self, folder, state, bad=False):
        cols, cell_width, height, suffix = generator.sheet_spec(self.prefix, state)
        width = cols * cell_width
        Image.new("RGBA", (width, height + int(bad))).save(folder / f"{self.prefix}_{state}{suffix}_left.png")

    def test_no_left_keeps_deployed_resource_identical(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertFalse(generator.validate_left_sheets(self.prefix, self.states, Path(directory)))
        self.assertEqual(generator.build(self.prefix, self.states),
                         (generator.OUT_DIR / f"{self.prefix}_frames.tres").read_text(encoding="utf-8"))

    def test_partial_left_set_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            self._write(folder, "walk")
            with self.assertRaises(ValueError):
                generator.validate_left_sheets(self.prefix, self.states, folder)

    def test_complete_set_emits_all_left_animations(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            for state in self.states:
                self._write(folder, state)
            self.assertTrue(generator.validate_left_sheets(self.prefix, self.states, folder))
            text = generator.build(self.prefix, self.states, with_left=True)
            for state in self.states:
                self.assertIn(f'"name": &"{state}_left"', text)

    def test_wrong_size_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            for state in self.states:
                self._write(folder, state, bad=state == "attack")
            with self.assertRaises(ValueError):
                generator.validate_left_sheets(self.prefix, self.states, folder)

    def test_later_job_validation_failure_does_not_write_first_resource(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            for state in self.states:
                suffix = generator.sheet_spec(self.prefix, state)[3]
                (folder / f"{self.prefix}_{state}{suffix}.png").touch()
            resource = folder / f"{self.prefix}_frames.tres"
            resource.write_text("기존 리소스", encoding="utf-8")
            with patch.object(generator, "OUT_DIR", folder):
                self.assertEqual(generator.main(), 1)
            self.assertEqual(resource.read_text(encoding="utf-8"), "기존 리소스")


if __name__ == "__main__":
    unittest.main()
