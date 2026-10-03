"""2막 처치 예산, 잘못된 표 거부, 성장 및 반복 사냥 상한 검사."""
import contextlib
import copy
import importlib.util
import io
import runpy
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('generator', ROOT / 'tools/generate_chapter_content.py')
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)


class ContentKillExpTests(unittest.TestCase):
    def test_budget_and_wrong_profile_rejection(self):
        data = gen.load_manifest(ROOT)
        gen.validate(data, ROOT)
        for field in ['base_exp', 'expected_kills', 'objective_kills', 'budget']:
            bad = copy.deepcopy(data)
            ch = next(c for c in bad['chapters'] if c['chapter'] == 4)
            ch['constants']['EXP_PROFILES']['4'][field] += 100
            with self.assertRaises(ValueError, msg=field):
                gen.validate(bad, ROOT)
        bad = copy.deepcopy(data)
        ch = next(c for c in bad['chapters'] if c['chapter'] == 3)
        ch['constants']['EXP_PROFILES'] = {'3': {}}
        with self.assertRaises(ValueError):
            gen.validate(bad, ROOT)

    def test_growth_and_extra_hour_upper_bound(self):
        with contextlib.redirect_stdout(io.StringIO()):
            result = runpy.run_path(str(ROOT / 'docs/qa/tools/calc_act_two_growth.py'))
        gates = result['gate_rows']
        self.assertGreaterEqual(gates[0]['supply'], result['g40'] * 1.2)
        self.assertGreaterEqual(gates[2]['supply'], result['g40'] * 1.01)
        # 추가 조우를 빼도 공식 B에서 Lv40은 넘는다. 20% 여유 보장은 아니다.
        minimum = result['objectives'][2]['total'] + 1000000 - gates[2]['loss']
        self.assertGreaterEqual(minimum, result['g40'])
        self.assertTrue(all(row['within_two_levels'] for row in result['farms']))


if __name__ == '__main__':
    unittest.main()
