"""6장 보고 예산·단계별 접근·드랍 연결 계약. 전투 체감 검증과 구분한다."""
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('generator', ROOT / 'tools/generate_chapter_content.py')
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)


class ChapterSixTests(unittest.TestCase):
    def setUp(self):
        self.data = gen.load_manifest(ROOT)
        self.chapter = next(c for c in self.data['chapters'] if c['chapter'] == 6)

    def test_exact_report_budget_and_four_enemy_drop_tables(self):
        gen.validate(self.data, ROOT)
        chapter = self.chapter
        quests = chapter['quests']
        self.assertEqual(chapter['content_revision'], 5)
        self.assertEqual(len(quests), 15)
        self.assertEqual(sum(q['quest_id'].startswith('MQ-') for q in quests), 5)
        self.assertEqual([sum(q[k] for q in quests) for k in ['reward_exp', 'reward_gold', 'reward_reputation']], [944345, 238200, 1500])
        self.assertEqual(sum(q['reward_exp'] for q in quests if q['quest_id'].startswith('MQ-')), 566607)
        c = chapter['constants']
        self.assertEqual(c['QUEST_REQUIREMENTS']['MQ-06-01']['reputation'], 2300)
        self.assertEqual(set(c['SCENES']), {'misran', 'forest_edge', 'mosswood', 'sylvien'})
        self.assertEqual(set(c['WARP_ARRIVALS']), {'misran'})
        self.assertEqual(len(c['MONSTER_VARIANTS']), 4)
        registry = (ROOT / 'godot/scripts/world/monster_drop_registry.gd').read_text(encoding='utf-8')
        for key, variant in c['MONSTER_VARIANTS'].items():
            text = (ROOT / 'godot/data/drops' / (key + '_drop_table.tres')).read_text(encoding='utf-8')
            self.assertIn('monster_level = ' + str(variant['level']), text)
            self.assertIn('tier = 0', text)
            self.assertIn('"' + variant['title'] + '": preload(', registry)

    def test_reports_acceptance_and_sources_do_not_require_their_own_completion(self):
        c = self.chapter['constants']
        quests = {q['quest_id']: q for q in self.chapter['quests']}
        for quest in quests.values():
            completed = {'MQ-05-05'}
            prerequisite = quest['prerequisite']
            while prerequisite in quests:
                self.assertNotIn(prerequisite, completed)
                completed.add(prerequisite)
                prerequisite = quests[prerequisite]['prerequisite']
            for npc in [quest['accept_npc_id'], quest['npc_id']]:
                if npc == 'arsel_scholar':
                    continue
                region = c['NPCS'][npc][0]
                self.assertIn(c['REGION_REQUIREMENTS'][region], completed)
            for kind, target, source in zip(quest['objective_kinds'], quest['objective_targets'], quest['objective_sources']):
                if kind == 'TALK':
                    region = c['NPCS'][target][0]
                elif kind == 'KILL':
                    habitat = c['HABITATS'][source]
                    self.assertEqual(habitat[3], target)
                    region = habitat[0]
                else:
                    site = c['SITES'][target]
                    self.assertEqual(site[1:3], [source, kind])
                    region = site[4]
                self.assertIn(c['REGION_REQUIREMENTS'][region], completed)


if __name__ == '__main__':
    unittest.main()
