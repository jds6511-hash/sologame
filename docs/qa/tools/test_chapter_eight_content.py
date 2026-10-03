"""8장 예산·도보 경로·하사 전후 목표·처치 계획 계약."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


class ChapterEightTests(unittest.TestCase):
    def setUp(self):
        self.ch = json.loads((ROOT / 'godot/data/content/chapter_eight.json').read_text(encoding='utf-8'))
        self.c = self.ch['constants']
        self.q = {q['quest_id']: q for q in self.ch['quests']}

    def test_exact_budget(self):
        self.assertEqual(self.ch['content_revision'], 7)
        for prefix, count, totals in [('MQ', 5, [2036662, 244800, 700]), ('SQ', 12, [1357775, 293760, 400])]:
            quests = [q for key, q in self.q.items() if key.startswith(prefix)]
            self.assertEqual(len(quests), count)
            self.assertEqual([sum(q[k] for q in quests) for k in ['reward_exp', 'reward_gold', 'reward_reputation']], totals)

    def test_grant_and_free_sanctuary(self):
        self.assertEqual(self.q['MQ-08-01']['prerequisite'], 'MQ-07-06')
        self.assertEqual(self.c['QUEST_REQUIREMENTS']['MQ-08-01'], {'reputation': 5500})
        self.assertEqual(self.q['MQ-08-04']['npc_id'], 'brantel_herald')
        self.assertEqual(self.q['MQ-08-05']['prerequisite'], 'MQ-08-04')
        self.assertEqual(self.c['REGION_REQUIREMENTS']['jaetgol'], 'MQ-08-04')
        self.assertNotIn('oranse', self.c['WARP_ARRIVALS'])
        self.assertFalse(any(h[0] in ['oranse', 'pilgrimage_path'] for h in self.c['HABITATS'].values()))
        self.assertFalse(self.c.get('FIELD_REPORTS', {}))
        self.assertEqual(self.c['EDGES']['saleno_to_pilgrimage_path'][:2], ['saleno', 'pilgrimage_path'])
        self.assertEqual(self.c['EDGES']['novera_outskirts_to_jaetgol_approach'][:2], ['novera_outskirts', 'jaetgol_approach'])
        self.assertEqual(self.c['WARP_ARRIVALS']['jaetgol']['$vector'], [320, 536])

    def test_no_quest_is_locked_behind_its_own_report(self):
        gates = self.c['REGION_REQUIREMENTS']
        for q in self.q.values():
            completed = {'MQ-07-06'}
            previous = q['prerequisite']
            while previous in self.q:
                self.assertNotIn(previous, completed)
                completed.add(previous)
                previous = self.q[previous]['prerequisite']
            regions = [self.c['NPCS'][n][0] for n in [q['accept_npc_id'], q['npc_id']] if n in self.c['NPCS']]
            for kind, target, source in zip(q['objective_kinds'], q['objective_targets'], q['objective_sources']):
                if kind == 'KILL':
                    regions.append(self.c['HABITATS'][source][0])
                elif kind == 'TALK':
                    if target in self.c['NPCS']:
                        regions.append(self.c['NPCS'][target][0])
                else:
                    regions.append(self.c['SITES'][target][4])
            for region in regions:
                if region in gates:
                    self.assertIn(gates[region], completed, q['quest_id'])

    def test_sources_layouts_and_exp(self):
        all_constants = {}
        for path in (ROOT / 'godot/data/content').glob('*.json'):
            for key, value in json.loads(path.read_text(encoding='utf-8-sig'))['constants'].items():
                if isinstance(value, dict):
                    all_constants.setdefault(key, {}).update(value)
        kills = 0
        for q in self.q.values():
            self.assertIn(q['npc_id'], all_constants['NPCS'])
            self.assertIn(q['accept_npc_id'], all_constants['NPCS'])
            for kind, target, source, count in zip(q['objective_kinds'], q['objective_targets'], q['objective_sources'], q['objective_counts']):
                if kind == 'KILL':
                    kills += count
                    self.assertEqual(self.c['HABITATS'][source][3], target)
                elif kind == 'TALK':
                    self.assertIn(target, all_constants['NPCS'])
                    self.assertEqual(source, '')
                else:
                    self.assertEqual(self.c['SITES'][target][1:3], [source, kind])
        p = self.c['EXP_PROFILES']['8']
        self.assertEqual((p['expected_kills'], p['objective_kills'], p['encounter_kills']), (120, kills, 120-kills))
        self.assertEqual(p['budget'], 1454758)
        self.assertLessEqual(abs(p['base_exp'] * 120 - 1454758), 60)
        self.assertEqual(p['overlevel_factors'], [1.0, 0.5, 0.25])
        self.assertEqual(p['respawn_seconds'], 90)
        self.assertEqual(len({tuple(v['$rect']) for v in self.c['BOUNDS'].values()}), 4)
        self.assertEqual(set(self.c['LAYOUTS']), set(self.c['SCENES']))
        for monster, variant in self.c['MONSTER_VARIANTS'].items():
            self.assertTrue((ROOT / 'godot' / variant['stats'].removeprefix('res://')).is_file())
            self.assertIn('monster_level = ' + str(variant['level']), (ROOT / 'godot/data/drops' / (monster + '_drop_table.tres')).read_text(encoding='utf-8'))


if __name__ == '__main__':
    unittest.main()
