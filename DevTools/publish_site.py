"""Publish only Website/ to CWTCH's GitHub Pages branch using GitHub CLI."""
import base64,json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
GH=ROOT/'DevTools/gh/bin/gh.exe'
settings=ROOT/'.local/devsettings.json'
if settings.exists():
 directory=json.loads(settings.read_text(encoding='utf-8-sig')).get('authDirectory')
 if directory:os.environ['GH_CONFIG_DIR']=directory
REPO='repos/johnawalkeruk-bot/Cwtch'
def api(endpoint,method='GET',body=None,allow_missing=False):
 args=[str(GH),'api',endpoint,'--method',method]
 if body is not None:args+=['--input','-']
 result=subprocess.run(args,input=json.dumps(body) if body is not None else None,capture_output=True,text=True,encoding='utf-8')
 if result.returncode:
  if allow_missing and '(HTTP 404)' in result.stderr:return None
  raise RuntimeError(result.stderr)
 return json.loads(result.stdout) if result.stdout.strip() else None
subprocess.run([sys.executable,str(ROOT/'DevTools/build_changelog.py')],check=True)
subprocess.run([sys.executable,str(ROOT/'DevTools/build_blog.py')],check=True)
reference=api(REPO+'/git/ref/heads/gh-pages',allow_missing=True)
entries=[]
names=['club.html','club.css','club.js','cloud-config.js','index.html','changelog.html','blog.html','style.css','release.js','.nojekyll','favicon.ico','assets/logo.png','assets/garden.png']
names += [p.relative_to(ROOT/'Website').as_posix() for p in sorted((ROOT/'Website/blog').glob('*.html')) if p.name != 'preview.html']
# Include the current preview only while it is linked from the blog index.
if 'blog/preview.html' in (ROOT/'Website/blog.html').read_text(encoding='utf-8'):names.append('blog/preview.html')
names += [p.relative_to(ROOT/'Website').as_posix() for p in sorted((ROOT/'Website/assets/blog').glob('*')) if p.suffix.lower() in {'.png','.jpg','.webp'}]
for name in names:
 file=ROOT/'Website'/name
 blob=api(REPO+'/git/blobs','POST',{'content':base64.b64encode(file.read_bytes()).decode(),'encoding':'base64'})
 entries.append({'path':name,'mode':'100644','type':'blob','sha':blob['sha']})
body={'tree':entries}
if reference:
 parent=api(REPO+'/git/commits/'+reference['object']['sha'])
 body['base_tree']=parent['tree']['sha']
tree=api(REPO+'/git/trees','POST',body)
commit=api(REPO+'/git/commits','POST',{'message':'Publish CWTCH game and launcher download page','tree':tree['sha'],'parents':[reference['object']['sha']] if reference else []})
if reference:api(REPO+'/git/refs/heads/gh-pages','PATCH',{'sha':commit['sha'],'force':False})
else:api(REPO+'/git/refs','POST',{'ref':'refs/heads/gh-pages','sha':commit['sha']})
page=api(REPO+'/pages',allow_missing=True)
source={'source':{'branch':'gh-pages','path':'/'},'build_type':'legacy'}
if page is None:
 try:page=api(REPO+'/pages','POST',source)
 except RuntimeError as error:
  if '(HTTP 409)' not in str(error):raise
  # GitHub can automatically enable Pages when gh-pages first appears.
  page=api(REPO+'/pages')
  if page['source']!={'branch':'gh-pages','path':'/'}:api(REPO+'/pages','PUT',source)
else:api(REPO+'/pages','PUT',source)
api(REPO,'PATCH',{'homepage':'https://johnawalkeruk-bot.github.io/Cwtch/'})
print('Website published from commit '+commit['sha'])
print('https://johnawalkeruk-bot.github.io/Cwtch/')
