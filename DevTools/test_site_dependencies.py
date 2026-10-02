import tempfile, unittest, sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from site_dependencies import include_modules
class WebsiteModules(unittest.TestCase):
 def test_nested_imports(self):
  with tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parents[1]/'.local') as directory:
   root=Path(directory)
   (root/'start.js').write_text("await import('./club.js?v=2');")
   (root/'club.js').write_text("import {x} from './metrics.js';")
   (root/'metrics.js').write_text('export const x=1;')
   self.assertEqual(include_modules(root,['start.js']),['start.js','club.js','metrics.js'])
   (root/'metrics.js').unlink()
   with self.assertRaisesRegex(ValueError,'Missing'):include_modules(root,['start.js'])
 def test_actual_website(self):
  root=Path(__file__).resolve().parents[1]/'Website'
  names=include_modules(root,['club-start.js'])
  self.assertTrue({'club.js','cloud-config.js','garden-metrics.js'}.issubset(names))
 def test_no_escape(self):
  with tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parents[1]/'.local') as directory:
   root=Path(directory);(root/'start.js').write_text("import '../secret.js';")
   with self.assertRaises(ValueError):include_modules(root,['start.js'])
if __name__=='__main__':unittest.main()
