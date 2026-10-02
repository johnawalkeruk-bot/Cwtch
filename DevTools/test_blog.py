"""Offline tests: never invokes the release or network publishers."""
import copy
import json
import sys
import uuid
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_blog
import build_changelog

class BlogTests(unittest.TestCase):
 def test_preview_release_retry_and_screenshots(self):
  scratch=Path(__file__).resolve().parents[1]/'.local/blog-tests'
  scratch.mkdir(parents=True,exist_ok=True)
  site=scratch/uuid.uuid4().hex
  site.mkdir()
  (site/'assets/blog').mkdir(parents=True)
  (site/'assets/blog/proof.png').write_bytes(b'fixture')
  entry={'id':'unreleased','label':'Next update','date':None,'title':'Tea < rain','sections':[{'heading':'Fixed','items':['A & B']}], 'blog':{'intro':'Mind the mud.','why':['A reason.'],'issues':['A limitation.'],'screenshots':[{'path':'assets/blog/proof.png','caption':'Proof < test'}]}}
  data={'entries':[entry]}
  def save(): (site/'changelog.json').write_text(json.dumps(data),encoding='utf-8')
  save();self.assertEqual(build_blog.build(site),[])
  self.assertIn('not released',(site/'blog/preview.html').read_text(encoding='utf-8'))
  self.assertFalse((site/'blog/posts.json').exists())
  build_changelog.promote(data,'9.8.7');save()
  posts=build_blog.build(site,'9.8.7')
  original=(site/'blog/posts.json').read_bytes()
  data['entries'][1]['title']='Changed afterwards';save()
  build_blog.build(site,'9.8.7')
  self.assertEqual(original,(site/'blog/posts.json').read_bytes())
  self.assertEqual(posts[0]['author'],'Waldas Game Studios')
  html=(site/'blog/v9.8.7.html').read_text(encoding='utf-8')
  self.assertIn('Tea &lt; rain',html)
  self.assertIn('../assets/blog/proof.png',html)
  self.assertNotIn('blog/preview.html',(site/'blog.html').read_text(encoding='utf-8'))
  bad=copy.deepcopy(posts[0]);bad['screenshots'][0]['path']='../private.png'
  with self.assertRaises(ValueError):build_blog.article(bad,site)
  bad['screenshots'][0]['path']='assets/blog/missing.png'
  with self.assertRaises(ValueError):build_blog.article(bad,site)
 def test_fallback_is_honest(self):
  post=build_blog.make_post({'id':'1.0.0','date':'2026-09-29','title':'Update','sections':[]})
  self.assertIn('not recorded',post['why'][0])
  self.assertIn('No additional issues were recorded',post['issues'][0])

if __name__=='__main__':unittest.main()
