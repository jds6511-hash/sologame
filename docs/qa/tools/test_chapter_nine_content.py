"""9장 보고 예산·예약 사건·보스 가중 EXP 계약."""
import copy
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools'))
import generate_chapter_content as generator


class ChapterNineTests(unittest.TestCase):
    def setUp(self):
        path = ROOT / 'godot/data/content/chapter_nine.json'
        self.assertTrue(path.is_file(), '9장 콘텐츠 원본 필요')
        self.ch = json.loads(path.read_text(encoding='utf-8'))
        self.c = self.ch['constants']
        self.q = {q['quest_id']: q for q in self.ch['quests']}

    def test_budget_and_unlocks(self):
        self.assertEqual(self.ch['content_revision'], 8)
        for prefix, count, totals in [('MQ', 5, [3870011, 321600, 900]), ('SQ', 13, [2580008, 418080, 500])]:
            quests = [q for key, q in self.q.items() if key.startswith(prefix)]
            self.assertEqual(len(quests), count)
            self.assertEqual([sum(q[k] for q in quests) for k in ['reward_exp', 'reward_gold', 'reward_reputation']], totals)
        self.assertEqual(self.q['MQ-09-01']['prerequisite'], 'MQ-08-05')
        for i in range(1, 14):
            self.assertEqual(self.q[f'SQ-09-{i:03}']['prerequisite'], f'MQ-09-{1 if i <= 4 else 2 if i <= 9 else 4:02}')
        self.assertEqual(set(self.c['FIELD_REPORTS']), {k for k in self.q if k != 'MQ-09-05'})

    def test_reserved_encounters_and_boss_weight(self):
        encounters = self.c['ENCOUNTERS']
        self.assertEqual(len(encounters), 4)
        for source, encounter in encounters.items():
            q = self.q[encounter['quest_id']]
            self.assertEqual(q['objective_sources'][encounter['index']], source)
            self.assertNotIn(source, [v[1] for v in self.c['SITES'].values()])
            self.assertEqual(encounter['max_active'], 4)
        p = self.c['EXP_PROFILES']['9']
        self.assertEqual((p['expected_kills'], p['objective_kills'], p['encounter_kills'], p['weighted_kills'], p['base_exp']), (150, 10, 140, 189, 14626))
        generator.validate_exp_profile(self.ch, ROOT)
        broken = copy.deepcopy(self.ch)
        broken['constants']['EXP_PROFILES']['9']['weighted_kills'] = 150
        with self.assertRaises(ValueError):
            generator.validate_exp_profile(broken, ROOT)

    def test_roundtrip_routes_and_monster_levels(self):
        self.assertEqual(len(self.c['SCENES']), 4)
        for edge in self.c['EDGES'].values():
            reverse = self.c['EDGES'][edge[4]]
            self.assertEqual(reverse[:2], edge[:2][::-1])
            self.assertEqual(sum((a-b)**2 for a,b in zip(edge[3]['$vector'], reverse[2]['$vector'])), 64**2)
        self.assertEqual({k: v['level'] for k,v in self.c['MONSTER_VARIANTS'].items()}, {'demon_scout': 62, 'ogre': 65, 'ruin_wraith': 66, 'warlord': 68})


if __name__ == '__main__':
    unittest.main()
