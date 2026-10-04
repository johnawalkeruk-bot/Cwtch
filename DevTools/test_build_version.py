"""Release version is embedded before cached build checks, without publishing."""
import json,sys,unittest,uuid
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build
class BuildVersionTests(unittest.TestCase):
 def test_requested_version_is_embedded_even_for_cached_build(self):
  root=Path(__file__).resolve().parents[1]/'.local'/'build-version-tests'/uuid.uuid4().hex
  (root/'Game').mkdir(parents=True)
  for version in ['0.1.99','0.2.0']:
   release=root/'Dist'/('v'+version);release.mkdir(parents=True)
   (release/'build.json').write_text(json.dumps({'fingerprint':'fixture'}),encoding='utf-8')
   with patch.object(build,'ROOT',root),patch.object(build,'fingerprint',return_value='fixture'):
    self.assertEqual(build.build(version),release)
   self.assertEqual((root/'Game/build_version.gd').read_text(encoding='utf-8'),'extends RefCounted\nconst VERSION='+json.dumps(version)+'\n')
if __name__=='__main__':unittest.main()
