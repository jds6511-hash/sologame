"""7장 예산·전진 인계·전직 전 첫 보고 계약. 전투 체감과 구분한다."""
import copy
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('generator', ROOT / 'tools/generate_chapter_content.py')
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)


class ChapterSevenTests(unittest.TestCase):
    def setUp(self):
        self.data = gen.load_manifest(ROOT)
        self.chapter = next(c for c in self.data['chapters'] if c['chapter'] == 7)

    def test_exact_budget_and_first_report_without_trial(self):
        gen.validate(self.data, ROOT)
        ch = self.chapter
        quests = ch['quests']
        self.assertEqual(ch['content_revision'], 6)
        self.assertEqual(sum(not q['quest_id'].startswith('TR-') for q in quests), 19)
        mains = [q for q in quests if q['quest_id'].startswith('MQ-')]
        self.assertEqual(len(mains), 6)
        self.assertEqual([sum(q[k] for q in quests) for k in ['reward_exp', 'reward_gold', 'reward_reputation']], [2696494, 402960, 2100])
        first = mains[0]
        self.assertEqual(first['prerequisite'], 'MQ-06-05')
        self.assertEqual(first['reward_exp'], 1000000)
        self.assertEqual(sum(q['reward_exp'] for q in mains[1:]), 817896)
        self.assertFalse(ch['constants'].get('QUEST_REQUIREMENTS', {}).get('MQ-07-01'))
        self.assertNotIn('KILL', first['objective_kinds'])
        self.assertNotIn('TR-', str(first))
        bad = copy.deepcopy(self.data)
        next(c for c in bad['chapters'] if c['chapter'] == 7)['quests'][0]['reward_exp'] += 1
        with self.assertRaises(ValueError):
            gen.validate(bad, ROOT)

    def test_all_goals_and_handoffs_are_reachable_before_report(self):
        c = gen.merged(self.data)
        qs = {q['quest_id']: q for q in self.chapter['quests']}
        for q in qs.values():
            if q['quest_id'].startswith('TR-'):
                continue  # 별도 시련 표는 아래 계약 검사에서 확인한다.
            completed = {'MQ-05-05', 'MQ-06-01', 'MQ-06-02', 'MQ-06-03', 'MQ-06-04', 'MQ-06-05'}
            prev = q['prerequisite']
            while prev in qs:
                self.assertNotIn(prev, completed)
                completed.add(prev)
                prev = qs[prev]['prerequisite']
            regions = [c['NPCS'][n][0] for n in [q['accept_npc_id'], q['npc_id']]]
            for kind, target, source in zip(q['objective_kinds'], q['objective_targets'], q['objective_sources']):
                if kind == 'KILL': regions.append(c['HABITATS'][source][0])
                elif kind == 'TALK': regions.append(c['NPCS'][target][0])
                else: regions.append(c['SITES'][target][4])
            for region in regions:
                self.assertIn(c['REGION_REQUIREMENTS'][region], completed, q['quest_id'])

    def test_varied_pacing_and_five_data_variants_with_drops(self):
        c = self.chapter['constants']
        quests = self.chapter['quests']
        self.assertEqual(sum('KILL' in q['objective_kinds'] for q in quests), 6)
        self.assertGreaterEqual(sum(q.get('accept_npc_id', q['npc_id']) != q['npc_id'] for q in quests), 15)
        self.assertEqual(set(c['WARP_ARRIVALS']), {'durgan'})
        self.assertEqual(len(c['MONSTER_VARIANTS']), 5)
        registry = (ROOT / 'godot/scripts/world/monster_drop_registry.gd').read_text(encoding='utf-8')
        for key, v in c['MONSTER_VARIANTS'].items():
            drop = (ROOT / 'godot/data/drops' / (key + '_drop_table.tres')).read_text(encoding='utf-8')
            self.assertIn('monster_level = ' + str(v['level']), drop)
            self.assertIn('tier = 0', drop)
            self.assertIn('"' + v['title'] + '": preload(', registry)

    def test_trials_are_zero_budget_and_registered_sources(self):
        trials = [q for q in self.chapter['quests'] if q['quest_id'].startswith('TR-')]
        self.assertEqual({q['quest_id'] for q in trials}, {'TR-WAR-02', 'TR-ARC-02'})
        for trial in trials:
            self.assertEqual([trial[key] for key in ['reward_exp', 'reward_gold', 'reward_reputation']], [0, 0, 0])
            self.assertEqual(trial['prerequisite'], 'MQ-07-01')
        for mutation in ['reward', 'source']:
            bad = copy.deepcopy(self.data)
            trial = next(q for ch in bad['chapters'] for q in ch['quests'] if q['quest_id'] == 'TR-WAR-02')
            if mutation == 'reward': trial['reward_exp'] = 1
            else: trial['objective_sources'][0] = 'missing_trial_source'
            with self.assertRaises(ValueError): gen.validate(bad, ROOT)


if __name__ == '__main__':
    unittest.main()
