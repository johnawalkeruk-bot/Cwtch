"""Offline installer checks, including real byte counts in progress events."""
import hashlib, importlib.util, io, json, tempfile, unittest, uuid, zipfile
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('updater',ROOT/'Launcher/update.py')
u=importlib.util.module_from_spec(spec);spec.loader.exec_module(u)
class Response(io.BytesIO):
 def __init__(self,blob,length=True):
  super().__init__(blob);self.headers={'Content-Length':str(len(blob))} if length else {}
class InstallerTests(unittest.TestCase):
 def setUp(self):
  self.root=ROOT/'.local'/('progress-test-'+uuid.uuid4().hex);self.root.mkdir(parents=True)
  out=io.BytesIO()
  with zipfile.ZipFile(out,'w') as z:
   z.writestr('CWTCH.exe',b'x'*800000);z.writestr('CWTCH.pck',b'y'*300000)
  self.blob=out.getvalue();self.digest=hashlib.sha256(self.blob).hexdigest()
  self.release={'tag_name':'v0.1.1','assets':[{'name':'CWTCH-Windows.zip','browser_download_url':'https://example.test/game'},{'name':'CWTCH-Windows.zip.sha256','browser_download_url':'https://example.test/hash'}]}
 def fetch(self,url):return json.dumps(self.release).encode() if '/latest' in url else self.digest.encode()
 def install(self,blob=None,length=True):
  events=[]
  with patch.object(u,'read_url',side_effect=self.fetch),patch.object(u.urllib.request,'urlopen',return_value=Response(self.blob if blob is None else blob,length)):
   result=u.install(self.root,'owner/game',events.append)
  return result,events
 def test_progress_and_existing_install(self):
  result,events=self.install()
  downloads=[e for e in events if e['stage']=='downloading']
  self.assertEqual(downloads[0]['downloaded'],0)
  self.assertEqual(downloads[-1]['downloaded'],len(self.blob))
  self.assertEqual(downloads[-1]['total'],len(self.blob))
  self.assertGreater(downloads[-1]['speed'],0)
  self.assertEqual([e['stage'] for e in events[-3:]],['verifying','installing','ready'])
  self.assertTrue(Path(result['executable']).exists())
  _,again=self.install()
  self.assertNotIn('downloading',[e['stage'] for e in again])
 def test_unknown_length(self):
  _,events=self.install(length=False)
  download=[e for e in events if e['stage']=='downloading'][-1]
  self.assertEqual(download['total'],0)
  self.assertEqual(download['downloaded'],len(self.blob))
 def test_corrupt_update_keeps_version_and_save(self):
  self.install();save=self.root/'UserData/save.json';save.parent.mkdir();save.write_text('garden')
  self.release['tag_name']='v0.1.2'
  with self.assertRaises(ValueError):self.install(blob=b'corrupt')
  self.assertEqual(json.loads((self.root/'installed.json').read_text())['version'],'v0.1.1')
  self.assertEqual(save.read_text(),'garden')
 def test_unsafe_archive(self):
  archive=self.root/'unsafe.zip'
  with zipfile.ZipFile(archive,'w') as z:z.writestr('../escape','bad')
  with self.assertRaises(ValueError):u.safe_extract(archive,self.root/'output')
if __name__=='__main__':unittest.main()
