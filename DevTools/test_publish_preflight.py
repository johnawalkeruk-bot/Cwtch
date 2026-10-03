"""Offline regression coverage; never executes a build, Git command or network call."""
import contextlib, copy, io, json, os, sys, uuid, unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parent))
import publish

class PreflightTests(unittest.TestCase):
 def setUp(self):
  self.root=Path(__file__).resolve().parents[1]/'.local/publish-tests'/uuid.uuid4().hex
  (self.root/'Website/blog').mkdir(parents=True)
  self.entry={'id':'unreleased','label':'Next update','date':None,'title':'A publishing fix','sections':[{'heading':'Fixed','items':['Checks notes before building.']} ]}
  self.data={'entries':[self.entry]};self.save()
 def save(self):
  (self.root/'Website/changelog.json').write_text(json.dumps(self.data),encoding='utf-8')
 def test_empty_notes_stop_before_any_build_or_external_call(self):
  self.entry['sections']=[];self.save()
  (self.root/'.local').mkdir();pending=self.root/'.local/pending-version';pending.write_text('0.1.31')
  before=(self.root/'Website/changelog.json').read_bytes()
  cwd=Path.cwd()
  try:
   with patch.object(publish,'ROOT',self.root),patch.object(publish,'build') as build,patch.object(publish.subprocess,'run') as run:
    with self.assertRaisesRegex(publish.ReleasePreparationError,'Nothing has been built or published'):
     publish.main()
    build.assert_not_called();run.assert_not_called()
  finally:os.chdir(cwd)
  self.assertEqual(pending.read_text(),'0.1.31')
  self.assertEqual(before,(self.root/'Website/changelog.json').read_bytes())
 def test_read_only_success(self):
  before=(self.root/'Website/changelog.json').read_bytes();cwd=Path.cwd()
  try:
   with patch.object(publish,'ROOT',self.root),patch.object(publish,'build') as build,patch.object(publish.subprocess,'run') as run,contextlib.redirect_stdout(io.StringIO()):
    publish.main('0.1.31',True);build.assert_not_called();run.assert_not_called()
  finally:os.chdir(cwd)
  self.assertEqual(before,(self.root/'Website/changelog.json').read_bytes())
  self.assertFalse((self.root/'.local').exists())
 def test_blank_placeholder_rejected(self):
  for change in [{'title':'In development'},{'sections':[{'heading':'Fixes','items':[]}]},{'sections':[{'heading':'Fixes','items':['   ']}]}]:
   self.data={'entries':[dict(self.entry,**change)]};self.save()
   with self.assertRaises(publish.ReleasePreparationError):publish.check_release_notes('0.1.31',self.root)
 def test_promoted_release_can_resume_without_new_notes(self):
  self.entry.update(id='0.1.31',date='2026-10-03',label='v0.1.31')
  self.data['entries'].insert(0,{'id':'unreleased','title':'In development','sections':[]});self.save()
  publish.check_release_notes('0.1.31',self.root)
 def test_missing_blog_image_is_caught_early(self):
  self.entry['blog']={'screenshots':[{'path':'assets/blog/missing.png','caption':'Missing image'}]};self.save()
  with self.assertRaisesRegex(publish.ReleasePreparationError,'Missing blog screenshot'):publish.check_release_notes('0.1.31',self.root)
 def test_corrupt_json_and_duplicate_versions_are_readable_errors(self):
  (self.root/'Website/changelog.json').write_text('{')
  with self.assertRaises(publish.ReleasePreparationError):publish.check_release_notes('0.1.31',self.root)
  self.data['entries'].append(copy.deepcopy(self.entry));self.save()
  with self.assertRaises(publish.ReleasePreparationError):publish.check_release_notes('0.1.31',self.root)
if __name__=='__main__':unittest.main()
