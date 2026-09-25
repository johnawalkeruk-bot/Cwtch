"""Publish a completed version. Credentials remain in GitHub CLI's auth store."""
import argparse,json,os,re,subprocess,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from build import ROOT,build
GH=ROOT/'DevTools/gh/bin/gh.exe'

def main(version=None):
 os.chdir(ROOT)
 settings=ROOT/'.local/devsettings.json'
 if settings.exists():
  directory=json.loads(settings.read_text(encoding='utf-8-sig')).get('authDirectory')
  if directory:os.environ['GH_CONFIG_DIR']=directory
 repository=json.loads((ROOT/'Launcher/repository.json').read_text(encoding='utf-8-sig'))['repository']
 def run(args,capture=False,check=True):
  return subprocess.run(list(map(str,args)),check=check,text=True,capture_output=capture)
 login=run([GH,'api','user','--jq','.login'],capture=True).stdout.strip()
 if login!=repository.split('/')[0]:raise RuntimeError('Sign in to GitHub CLI as '+repository.split('/')[0]+'.')
 if not (ROOT/'.git').exists():run(['git','init','-b','main'])
 run(['git','config','user.name',login]);run(['git','config','user.email',login+'@users.noreply.github.com'])
 run(['git','lfs','install','--local'])
 remote=run(['git','remote','get-url','origin'],capture=True,check=False)
 if remote.returncode:run(['git','remote','add','origin','https://github.com/'+repository+'.git'])
 elif remote.stdout.strip()!='https://github.com/'+repository+'.git':raise RuntimeError('Unexpected origin; check the repository setting.')
 pending=ROOT/'.local/pending-version'
 if version is None and pending.exists():version=pending.read_text().strip()
 if version is None:
  old=(ROOT/'VERSION').read_text().strip()
  has_head=run(['git','rev-parse','--verify','HEAD'],capture=True,check=False).returncode==0
  if has_head:
   major,minor,patch=map(int,old.split('.'));version=f'{major}.{minor}.{patch+1}'
  else:version=old
 if not re.fullmatch(r'\d+\.\d+\.\d+',version):raise RuntimeError('Use a version such as 0.1.0')
 tag='v'+version
 existing=run([GH,'release','view',tag,'--repo',repository],capture=True,check=False)
 if existing.returncode==0:raise RuntimeError(tag+' is already published. Use a new version.')
 pending.parent.mkdir(exist_ok=True);pending.write_text(version)
 release=build(version)
 run([sys.executable,ROOT/'DevTools/build_changelog.py','--release',version])
 (ROOT/'VERSION').write_text(version+'\n',encoding='ascii')
 run(['git','add','--all'])
 if run(['git','diff','--cached','--quiet'],check=False).returncode!=0:
  run(['git','commit','-m','Release CWTCH '+tag])
 # Clear inherited credential helpers for this push and use only the authorized CLI.
 helper='!"'+str(GH).replace('\\','/')+'" auth git-credential'
 git=['git','-c','credential.helper=','-c','credential.helper='+helper]
 run(git+['push','origin','main'])
 if not run(['git','tag','--list',tag],capture=True).stdout.strip():run(['git','tag',tag])
 run(git+['push','origin',tag])
 run([GH,'release','create',tag,release/'CWTCH-Windows.zip',release/'CWTCH-Windows.zip.sha256',release/'CWTCH-Launcher.zip','--repo',repository,'--title','CWTCH '+tag,'--generate-notes','--latest'])
 pending.unlink()
 print('Published https://github.com/'+repository+'/releases/tag/'+tag,flush=True)
 site=run([sys.executable,ROOT/'DevTools/publish_site.py'],check=False)
 if site.returncode:
  print('Game release succeeded; website update failed. Retry DevTools/publish_site.py separately.',file=sys.stderr)

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--version');args=parser.parse_args()
 try:main(args.version)
 except Exception as error:
  print('Publishing stopped: '+str(error),file=sys.stderr)
  print('Your work and build are retained. Run this command again to resume.',file=sys.stderr)
  sys.exit(1)
