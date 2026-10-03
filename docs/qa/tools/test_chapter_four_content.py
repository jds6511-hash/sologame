"""4장 예산과 수도 입성 전 보상, 세 신규 전투 계열 계약."""
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('generator', ROOT / 'tools/generate_chapter_content.py')
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)


class ChapterFourTests(unittest.TestCase):
    def test_budget_routes_and_enemy_contracts(self):
        data = gen.load_manifest(ROOT)
        chapter = next(c for c in data['chapters'] if c['chapter'] == 4)
        gen.validate(data, ROOT)
        quests = chapter['quests']
        self.assertEqual([sum(q[k] for q in quests) for k in ['reward_exp', 'reward_gold', 'reward_reputation']], [198351, 68850, 750])
        c = chapter['constants']
        self.assertEqual(c['REGION_REQUIREMENTS']['brantel'], 'MQ-04-02')
        self.assertEqual(c['QUEST_REQUIREMENTS']['MQ-04-01']['reputation'], 800)
        self.assertEqual(quests[0]['npc_id'], 'han_patrol')
        self.assertEqual(len(c['MONSTER_VARIANTS']), 3)
        self.assertEqual(len(set(v['scene'] for v in c['MONSTER_VARIANTS'].values())), 3)


if __name__ == '__main__':
    unittest.main()
