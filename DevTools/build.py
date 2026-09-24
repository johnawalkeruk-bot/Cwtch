"""Build a checked portable game and native Windows launcher."""
import argparse,hashlib,json,os,shutil,subprocess,zipfile,sys,uuid
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from windows_icon import apply_icon
ROOT=Path(__file__).resolve().parents[1]

def fingerprint():
 digest=hashlib.sha256()
 for script in [Path(__file__),Path(__file__).with_name("windows_icon.py")]:digest.update(script.read_bytes())
 for folder in [ROOT/'Game',ROOT/'Launcher']:
  for path in sorted(folder.rglob('*')):
   if not path.is_file(): continue
   relative=path.relative_to(ROOT)
   if any(part in ['.godot','runtime','__pycache__'] for part in relative.parts) or path.suffix=='.log':continue
   digest.update(relative.as_posix().encode())
   with path.open('rb') as stream:
    while data:=stream.read(1024*1024):digest.update(data)
 return digest.hexdigest()

def zip_folder(source,output):
 with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
  for path in sorted(source.rglob('*')):
   if path.is_file() and path.suffix!='.tmp' and '__pycache__' not in path.parts:archive.write(path,path.relative_to(source))

def build(version):
 release=ROOT/'Dist'/('v'+version)
 stamp=release/'build.json'
 signature=fingerprint()
 if stamp.exists() and json.loads(stamp.read_text())['fingerprint']==signature:
  print('Using verified build v'+version,flush=True);return release
 release.mkdir(parents=True,exist_ok=True)
 stage=release/'Windows';stage.mkdir(exist_ok=True)
 godot=ROOT/'Game/runtime/Godot_v4.6.2-stable_win64_console.exe'
 env=os.environ.copy();env['APPDATA']=str(ROOT/'.local/build-data')
 def engine(name,args):
  with (release/(name+'.log')).open('w',encoding='utf-8') as output:
   result=subprocess.run([str(godot),*map(str,args)],stdout=output,stderr=subprocess.STDOUT,env=env)
  log=(release/(name+'.log')).read_text(encoding='utf-8',errors='replace')
  if result.returncode or 'SCRIPT ERROR' in log or 'Failed loading resource' in log or 'Safe save failed' in log:
   raise RuntimeError(name+' failed. See '+str(release/(name+'.log')))
 print('Importing and checking Godot...',flush=True)
 engine('import',['--headless','--path',ROOT/'Game','--editor','--import','--quit'])
 # A fresh export path prevents safe-save replacement conflicts in synced folders.
 export_directory=ROOT/'.local/build-export'
 export_directory.mkdir(parents=True,exist_ok=True)
 exported=export_directory/('CWTCH-'+uuid.uuid4().hex+'.pck')
 engine('export',['--headless','--path',ROOT/'Game','--export-pack','Windows Portable',exported])
 if not exported.is_file():raise RuntimeError('Game pack missing.')
 shutil.copy2(exported,stage/'CWTCH.pck')
 exported.unlink()
 for temporary in stage.glob('CWTCH.pck*.tmp'):
  if temporary.is_file() and temporary.resolve().parent==stage.resolve():temporary.unlink()
 shutil.copy2(ROOT/'Game/runtime/Godot_v4.6.2-stable_win64.exe',stage/'CWTCH.exe')
 apply_icon(stage/'CWTCH.exe',ROOT/'Game/assets/branding/cwtch.ico')
 (stage/'VERSION').write_text(version+'\n')
 for license in (ROOT/'Game/runtime').glob('*.txt'):shutil.copy2(license,stage/license.name)
 engine('smoke',['--headless','--path',stage,'--main-pack',stage/'CWTCH.pck','--quit-after','15'])
 print('Compressing game and launcher...',flush=True)
 archive=release/'CWTCH-Windows.zip';zip_folder(stage,archive)
 with archive.open('rb') as stream:checksum=hashlib.file_digest(stream,'sha256').hexdigest()
 (release/'CWTCH-Windows.zip.sha256').write_text(checksum+'  CWTCH-Windows.zip\n',encoding='ascii')
 if not (ROOT/'Launcher/Python/python.exe').exists():raise RuntimeError('Run DevTools/setup.py first.')
 zip_folder(ROOT/'Launcher',release/'CWTCH-Launcher.zip')
 stamp.write_text(json.dumps({'version':version,'fingerprint':fingerprint(),'sha256':checksum}),encoding='utf-8')
 print('Build checks passed: '+version,flush=True)
 return release

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--version',required=True);args=parser.parse_args()
 import re
 if not re.fullmatch(r'\d+\.\d+\.\d+',args.version):raise SystemExit('Use a version such as 0.1.0')
 build(args.version)
