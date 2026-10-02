import unittest, importlib.util, copy, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
GEN=ROOT/'tools/generate_chapter_content.py'
class ContentTests(unittest.TestCase):
 def setUp(self):
  self.assertTrue(GEN.exists(), '콘텐츠 생성기가 필요합니다')
  spec=importlib.util.spec_from_file_location('generator',GEN)
  self.g=importlib.util.module_from_spec(spec); spec.loader.exec_module(self.g)
  self.data=self.g.load_manifest(ROOT)
 def test_budget_and_generation_are_deterministic(self):
  self.g.validate(self.data,ROOT)
  self.assertEqual(self.g.render(self.data), self.g.render(copy.deepcopy(self.data)))
  q=self.data['chapters'][-1]['quests']
  self.assertEqual([sum(x[k] for x in q) for k in ['reward_exp','reward_gold','reward_reputation']],[33811,36660,600])
 def test_missing_prerequisite_and_cycle_rejected(self):
  q=self.data['chapters'][-1]['quests'][0]
  q['prerequisite']='없음'
  with self.assertRaises(ValueError): self.g.validate(self.data,ROOT)
  q['prerequisite']='MQ-03-05'
  with self.assertRaises(ValueError): self.g.validate(self.data,ROOT)
 def test_source_target_and_budget_rejected(self):
  for field,value in [('objective_sources',['없는source']),('objective_targets',['없는target']),('reward_exp',3501)]:
   bad=copy.deepcopy(self.data);bad['chapters'][-1]['quests'][0][field]=value
   with self.assertRaises(ValueError,msg=field): self.g.validate(bad,ROOT)
 def test_check_and_validation_failure_never_write(self):
  with tempfile.TemporaryDirectory() as directory:
   out=Path(directory)
   self.assertFalse(self.g.generate(self.data,ROOT,out,check=True))
   self.assertEqual(list(out.rglob('*')),[])
   bad=copy.deepcopy(self.data);bad['chapters'][-1]['quests'][0]['prerequisite']='없음'
   with self.assertRaises(ValueError): self.g.generate(bad,ROOT,out)
   self.assertEqual(list(out.rglob('*')),[])
   self.assertTrue(self.g.generate(self.data,ROOT,out))
   before={p:p.stat().st_mtime_ns for p in out.rglob('*') if p.is_file()}
   self.assertTrue(self.g.generate(self.data,ROOT,out,check=True))
   self.assertEqual(before,{p:p.stat().st_mtime_ns for p in before})
 def test_budget_cannot_be_redefined_in_the_same_table(self):
  ch=self.data['chapters'][-1]
  ch['quests'][0]['reward_exp']+=1
  ch['budget']['reward_exp']+=1
  ch['budget']['main_exp']+=1
  with self.assertRaises(ValueError): self.g.validate(self.data,ROOT)
 def test_wave_and_sites_match_actual_resources(self):
  for change in ['stats','scene','quest_id','index','position','marker']:
   bad=copy.deepcopy(self.data);c=bad['chapters'][-1]['constants']
   wave=c['DEFENSE_WAVES']['yeoulmok_defense_wave_1']
   if change=='position': wave['points'][0]={'$vector':[2048,192]}
   elif change=='marker': bad['constants']['MARKER_HABITATS']['yeoulmok_rabbit_habitat'][1]='Markers/Missing'
   else: wave[change]=99 if change=='index' else '없음'
   with self.assertRaises(ValueError,msg=change): self.g.validate(bad,ROOT)
 def test_generated_quest_paths_cannot_overwrite_scripts_or_each_other(self):
  for path in ['res://scripts/content/game_content.gd', 'res://data/quests/../../scripts/save.gd', self.data['chapters'][-1]['quests'][1]['path']]:
   bad=copy.deepcopy(self.data);bad['chapters'][-1]['quests'][0]['path']=path
   with self.assertRaises(ValueError): self.g.validate(bad,ROOT)
if __name__=='__main__': unittest.main()
