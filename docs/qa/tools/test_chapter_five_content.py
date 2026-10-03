"""5장 보고 예산·관문 순환·신규 적과 기존 BGM 연결 계약."""
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('generator', ROOT / 'tools/generate_chapter_content.py')
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)


class ChapterFiveTests(unittest.TestCase):
    def test_budget_and_report_destination_are_reachable(self):
        data = gen.load_manifest(ROOT)
        gen.validate(data, ROOT)
        chapter = next(c for c in data['chapters'] if c['chapter'] == 5)
        quests = chapter['quests']
        self.assertEqual(chapter['content_revision'], 4)
        self.assertEqual(len(quests), 12)
        self.assertEqual([sum(q[k] for q in quests) for k in ['reward_exp', 'reward_gold', 'reward_reputation']], [410663, 135150, 1150])
        self.assertEqual(sum(q['reward_exp'] for q in quests if q['quest_id'].startswith('MQ-')), 246398)
        c = chapter['constants']
        self.assertEqual(c['REGION_REQUIREMENTS']['arsel'], 'MQ-05-02')
        self.assertEqual(c['REGION_REQUIREMENTS']['arsel_library'], 'MQ-05-03')
        self.assertEqual(c['QUEST_REQUIREMENTS']['MQ-05-01']['reputation'], 1400)
        self.assertEqual(len(c['SCENES']), 5)
        self.assertEqual(len(c['MONSTER_VARIANTS']), 3)
        self.assertEqual(len(set(v['scene'] for v in c['MONSTER_VARIANTS'].values())), 3)

    def test_field_and_library_reuse_appropriate_music(self):
        chapter = next(c for c in gen.load_manifest(ROOT)['chapters'] if c['chapter'] == 5)
        contexts = chapter['constants']['BGM_CONTEXTS']
        for region in ['saleno', 'saleno_coast', 'reed_marsh']:
            self.assertEqual(contexts[region], 'res://scenes/world/eastern_frontier_starting_area.tscn')
        self.assertEqual(contexts['arsel_library'], 'res://scenes/world/novera_gate.tscn')


if __name__ == '__main__':
    unittest.main()
