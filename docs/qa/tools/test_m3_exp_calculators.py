"""Run both complete reports, then check their EXP functions against saved legacy rules."""
import contextlib
import io
from pathlib import Path
import re
import runpy
import unittest
import os
import json
from m3_exp_math import roundi


TOOLS = Path(__file__).resolve().parent


class ExpCalculatorsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.calculators = {}
        for name in ("m3_phase_d_balance_calc.py", "m3_respawn_pace_calc.py"):
            with contextlib.redirect_stdout(io.StringIO()):
                cls.calculators[name] = runpy.run_path(str(TOOLS / name))

    def test_legacy_requirements_all_levels(self):
        source = (TOOLS.parents[2] / "godot/scripts/save/save_progression_rules.gd").read_text(encoding="utf-8")
        table = re.search(r"const REQUIREMENTS := \[(.*?)\]", source, re.S).group(1)
        expected = [int(value) for value in re.findall(r"\d+", table)]
        self.assertEqual(len(expected), 99)
        for name, calc in self.calculators.items():
            with self.subTest(calculator=name):
                profile = calc["LC"].get("profile", 0)
                try:
                    calc["LC"]["profile"] = 0
                    self.assertEqual([calc["req"](level) for level in range(1, 100)], expected)
                    self.assertEqual(sum(calc["req"](level) for level in range(1, 10)), 18612)
                finally:
                    calc["LC"]["profile"] = profile

    def test_shipped_c1_requirements_all_levels(self):
        source = (TOOLS.parents[2] / "godot/scripts/save/save_progression_rules.gd").read_text(encoding="utf-8")
        table = re.search(r"const C1_REQUIREMENTS := \[(.*?)\]", source, re.S).group(1)
        expected = [int(value) for value in re.findall(r"\d+", table)]
        self.assertEqual(len(expected), 99)
        for name, calc in self.calculators.items():
            with self.subTest(calculator=name):
                self.assertEqual(calc["LC"]["profile"], 1)
                self.assertEqual([calc["req"](level) for level in range(1, 100)], expected)
                self.assertEqual(sum(expected), 61860102)

    @unittest.skipUnless(os.environ.get("C1_ENGINE_JSON"), "엔진 출력 경로 미지정")
    def test_against_fresh_engine_export(self):
        engine = json.loads(Path(os.environ["C1_ENGINE_JSON"]).read_text(encoding="utf-8"))
        for name, calc in self.calculators.items():
            with self.subTest(calculator=name):
                self.assertEqual([calc["req"](level) for level in range(1, 100)], engine["c1"])
                self.assertEqual([calc["mob_exp"](level) for level in range(1, 101)], engine["mob"])
                profile = calc["LC"]["profile"]
                try:
                    calc["LC"]["profile"] = 0
                    self.assertEqual([calc["req"](level) for level in range(1, 100)], engine["legacy"])
                finally:
                    calc["LC"]["profile"] = profile
        self.assertEqual([roundi(x) for x in engine["ties"]], engine["rounded"])

    def test_half_ties_match_godot_roundi(self):
        for name, calc in self.calculators.items():
            original = calc["LC"].copy()
            try:
                calc["LC"].update(req_coefficient=2.5, req_exponent=1.0,
                                  pre_transition_req_multiplier=1.0,
                                  mob_exp_coefficient=2.5, mob_exp_exponent=1.0)
                with self.subTest(calculator=name):
                    self.assertEqual(calc["req"](1), 3)
                    self.assertEqual(calc["mob_exp"](1), 3)
            finally:
                calc["LC"].clear()
                calc["LC"].update(original)

    def test_rounding_signed_boundaries(self):
        for value, expected in ((2.49, 2), (2.5, 3), (2.51, 3),
                                (-2.49, -2), (-2.5, -3), (-2.51, -3), (0, 0)):
            with self.subTest(value=value):
                self.assertEqual(roundi(value), expected)

    def test_kill_rewards_half_tie(self):
        phase = self.calculators["m3_phase_d_balance_calc.py"]
        self.assertEqual(phase["exp_gain"](5, 1, 0.5, 1), 3)
        respawn = self.calculators["m3_respawn_pace_calc.py"]
        original = respawn["LC"]["night_exp_multiplier"]
        try:
            respawn["LC"]["night_exp_multiplier"] = 0.5
            self.assertEqual(respawn["exp_gain"]({"level": 1, "elite": False}, 1, True), 3)
        finally:
            respawn["LC"]["night_exp_multiplier"] = original


if __name__ == "__main__":
    unittest.main()
