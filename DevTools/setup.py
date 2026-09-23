"""Download pinned official development runtimes, without requiring admin access."""
import urllib.request
import zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
RUNTIMES=[
 ('https://github.com/godotengine/godot/releases/download/4.6.2-stable/Godot_v4.6.2-stable_win64.exe.zip',ROOT/'Game'/'runtime'),
 ('https://www.python.org/ftp/python/3.13.7/python-3.13.7-embed-amd64.zip',ROOT/'Launcher'/'Python'),
 ('https://github.com/cli/cli/releases/download/v2.101.0/gh_2.101.0_windows_amd64.zip',ROOT/'DevTools'/'gh')]
for url,destination in RUNTIMES:
 destination.mkdir(parents=True,exist_ok=True)
 archive=ROOT/'.local'/url.rsplit('/',1)[-1]
 archive.parent.mkdir(exist_ok=True)
 if not archive.exists(): urllib.request.urlretrieve(url,archive)
 with zipfile.ZipFile(archive) as zipped: zipped.extractall(destination)
 print('Ready:',destination.relative_to(ROOT))
(ROOT/'Game'/'runtime'/'.gdignore').touch()

import subprocess,os
compiler=Path(os.environ['WINDIR'])/'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
subprocess.run([str(compiler),'/nologo','/target:winexe','/out:'+str(ROOT/'Launcher/CWTCHLauncher.exe'),'/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll','/reference:System.Web.Extensions.dll',str(ROOT/'Launcher/Launcher.cs')],check=True)
