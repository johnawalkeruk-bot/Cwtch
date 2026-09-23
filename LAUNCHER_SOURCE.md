# CWTCH launcher — complete source

## Launcher/Launcher.cs

```
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Diagnostics;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Web.Script.Serialization;
using System.Collections.Generic;

public sealed class DownloadBar : Control {
 public double Fraction; public bool Indeterminate; int phase;
 readonly Timer animation=new Timer {Interval=30};
 public DownloadBar() {DoubleBuffered=true; animation.Tick+=(s,e)=>{phase=(phase+4)%Math.Max(1,Width+100);Invalidate();};animation.Start();}
 protected override void OnPaint(PaintEventArgs e) {
  e.Graphics.Clear(Color.FromArgb(47,66,62));
  using(var brush=new SolidBrush(Color.FromArgb(235,190,107))) {
   if(Indeterminate)e.Graphics.FillRectangle(brush,phase-100,0,100,Height);
   else e.Graphics.FillRectangle(brush,0,0,(int)(Width*Math.Max(0,Math.Min(1,Fraction))),Height);
  }
 }
 protected override void Dispose(bool disposing){if(disposing)animation.Dispose();base.Dispose(disposing);}
}
public sealed class ValleyArtwork : Panel {
 public Image Logo;
 public ValleyArtwork(){DoubleBuffered=true;}
 protected override void OnPaint(PaintEventArgs e){
  using(var sky=new LinearGradientBrush(ClientRectangle,Color.FromArgb(49,81,75),Color.FromArgb(19,37,35),90))e.Graphics.FillRectangle(sky,ClientRectangle);
  e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;
  using(var ridge=new SolidBrush(Color.FromArgb(38,65,60)))e.Graphics.FillPolygon(ridge,new[]{new Point(0,380),new Point(120,260),new Point(200,320),new Point(330,180),new Point(Width,350),new Point(Width,Height),new Point(0,Height)});
  if(Logo!=null){e.Graphics.InterpolationMode=InterpolationMode.HighQualityBicubic;e.Graphics.DrawImage(Logo,new Rectangle(20,28,Width-40,Width-40));}
 }
 protected override void Dispose(bool disposing){if(disposing&&Logo!=null)Logo.Dispose();base.Dispose(disposing);}
}
public class CwtchLauncher : Form {
 readonly string root=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"CWTCH");
 readonly Label status=new Label(),versionLabel=new Label(),latestLabel=new Label(),detail=new Label(),heading=new Label();
 readonly Button play=new Button(),update=new Button();
 readonly DownloadBar progress=new DownloadBar();
 string game; bool busy;
 static readonly Color Gold=Color.FromArgb(235,190,107),Muted=Color.FromArgb(160,180,170),White=Color.FromArgb(238,241,231);
 public CwtchLauncher() {
  Text="CWTCH · Your slice of the valley";ClientSize=new Size(900,540);StartPosition=FormStartPosition.CenterScreen;
  AutoScaleMode=AutoScaleMode.Dpi;Icon=Icon.ExtractAssociatedIcon(Application.ExecutablePath);
  FormBorderStyle=FormBorderStyle.FixedSingle;MaximizeBox=false;BackColor=Color.FromArgb(19,30,28);Font=new Font("Segoe UI",10);
  var art=new ValleyArtwork();art.SetBounds(0,0,390,540);Controls.Add(art);
  string logo=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"logo.png");if(File.Exists(logo))art.Logo=Image.FromFile(logo);
  var caption=MakeLabel("A LITTLE SPACE TO SLOW DOWN",10,Gold);caption.SetBounds(30,444,345,25);art.Controls.Add(caption);
  var sub=MakeLabel("Your slice of the valley.",14,White);sub.SetBounds(30,475,345,32);art.Controls.Add(sub);
  var eyebrow=MakeLabel("C W T C H   /   LAUNCHER",10,Gold);eyebrow.SetBounds(434,40,422,24);Controls.Add(eyebrow);
  Configure(heading,"Welcome to the valley",25,White,434,84,430,47);
  Configure(versionLabel,"INSTALLED   —   Not installed",10,Muted,434,145,422,24);
  Configure(latestLabel,"LATEST         —   Checking…",10,Muted,434,173,422,24);
  var divider=new Panel {BackColor=Color.FromArgb(48,64,57)};divider.SetBounds(434,216,422,1);Controls.Add(divider);
  Configure(status,"Checking for updates…",12,White,434,243,422,80);
  progress.SetBounds(434,337,422,6);Controls.Add(progress);
  Configure(detail,"Connecting to the valley",10,Muted,434,357,422,36);
  StyleButton(play,"PLAY CWTCH",434,410,422,54,true);play.Enabled=false;
  StyleButton(update,"Check for updates",434,476,422,34,false);
  update.Click+=async(s,e)=>await UpdateGame();play.Click+=(s,e)=>Play();
  FormClosing+=(s,e)=>{if(busy){e.Cancel=true;detail.Text="Please let the update finish before closing.";}};
  try{Installed();}catch{versionLabel.Text="INSTALLED   —   Could not read version";}
 }
 static Label MakeLabel(string text,float size,Color color){return new Label {Text=text,Font=new Font("Segoe UI",size),ForeColor=color,BackColor=Color.Transparent,AutoSize=false};}
 void Configure(Label label,string text,float size,Color color,int x,int y,int w,int h){label.Text=text;label.Font=new Font("Segoe UI",size);label.ForeColor=color;label.SetBounds(x,y,w,h);Controls.Add(label);}
 void StyleButton(Button button,string text,int x,int y,int w,int h,bool primary){
  button.Text=text;button.SetBounds(x,y,w,h);button.FlatStyle=FlatStyle.Flat;button.FlatAppearance.BorderSize=0;
  button.BackColor=primary?Gold:BackColor;button.ForeColor=primary?Color.FromArgb(25,39,33):Muted;
  button.Font=new Font("Segoe UI",primary?12:10,primary?FontStyle.Bold:FontStyle.Regular);button.Cursor=Cursors.Hand;
  button.FlatAppearance.MouseOverBackColor=primary?Color.FromArgb(249,208,135):Color.FromArgb(35,50,44);Controls.Add(button);
 }
 Dictionary<string,object> Read(string file){return new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(file));}
 string Installed(){
  game=null;string file=Path.Combine(root,"installed.json");
  if(!File.Exists(file)){versionLabel.Text="INSTALLED   —   Not installed";return null;}
  var data=Read(file);string path=Path.GetFullPath((string)data["executable"]);
  if(!path.StartsWith(root+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase)||!File.Exists(path)||!File.Exists(Path.Combine(Path.GetDirectoryName(path),"CWTCH.pck")))return null;
  game=path;string version=(string)data["version"];versionLabel.Text="INSTALLED   —   "+version;return version;
 }
 void OnProgress(Dictionary<string,object> data){
  string stage=(string)data["stage"];
  if(data.ContainsKey("version"))latestLabel.Text="LATEST         —   "+data["version"];
  progress.Indeterminate=stage!="downloading"&&stage!="ready";
  switch(stage){
   case "checking":status.Text="Checking for updates…";detail.Text="Connecting to GitHub";break;
   case "available":status.Text="Preparing your garden…";detail.Text="Finding the latest game files";break;
   case "downloading":
    double received=Convert.ToDouble(data["downloaded"]),total=Convert.ToDouble(data["total"]),speed=Convert.ToDouble(data["speed"]);
    progress.Indeterminate=total<=0;progress.Fraction=total>0?received/total:0;
    status.Text=total>0?"Downloading update   "+Math.Min(100,(int)(received/total*100))+"%":"Downloading update…";
    detail.Text=(received/1048576).ToString("0.0")+" MB"+(total>0?" / "+(total/1048576).ToString("0.0")+" MB":"")+"   ·   "+(speed/1048576).ToString("0.0")+" MB/s";break;
   case "verifying":status.Text="Checking your download…";detail.Text="Verifying that every file arrived safely";break;
   case "installing":status.Text="Installing the update…";detail.Text="Your saved garden stays safe";break;
   case "ready":progress.Fraction=1;status.Text="Your garden is ready.";detail.Text="Up to date · Saves kept between updates";break;
  }
  progress.Invalidate();
 }
 public async Task UpdateGame(){
  if(busy)return;
  busy=true;play.Enabled=false;update.Enabled=false;progress.Fraction=0;
  OnProgress(new Dictionary<string,object>{{"stage","checking"}});
  try{
   Directory.CreateDirectory(root);string folder=AppDomain.CurrentDomain.BaseDirectory;
   string python=Path.Combine(folder,"Python","python.exe");if(!File.Exists(python))throw new Exception("Download the complete CWTCH-Launcher.zip.");
   string result=Path.Combine(root,"update-"+Guid.NewGuid().ToString("N")+".json");
   var info=new ProcessStartInfo(python,"\""+Path.Combine(folder,"update.py")+"\" --root \""+root+"\" --result \""+result+"\" --progress");
   info.UseShellExecute=false;info.CreateNoWindow=true;info.RedirectStandardOutput=true;
   using(var process=Process.Start(info)){
    await Task.Run(()=>{string line;while((line=process.StandardOutput.ReadLine())!=null){
     try{var data=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(line);BeginInvoke(new Action(()=>OnProgress(data)));}catch(ArgumentException){}
    }process.WaitForExit();});
   }
   if(!File.Exists(result))throw new Exception("The updater did not finish. Try again.");
   var response=Read(result);File.Delete(result);if(!(bool)response["ok"])throw new Exception((string)response["message"]);
   string installed=Installed();if(installed==null)throw new Exception("Installed game files could not be found.");
   OnProgress(new Dictionary<string,object>{{"stage","ready"},{"version",installed}});
  }catch(Exception error){
   string installed=null;try{installed=Installed();}catch{}
   progress.Indeterminate=false;progress.Fraction=0;progress.Invalidate();
   status.Text=installed==null?"The update couldn't finish.":"You can still play "+installed+".";
   detail.Text=error.Message;
  }finally{busy=false;play.Enabled=game!=null;update.Enabled=true;}
 }
 void Play(){
  if(game==null)return;
  try{
   var info=new ProcessStartInfo(game){UseShellExecute=false,WorkingDirectory=Path.GetDirectoryName(game)};
   string data=Path.Combine(root,"UserData");Directory.CreateDirectory(data);info.EnvironmentVariables["APPDATA"]=data;
   Process.Start(info);Close();
  }catch(Exception error){status.Text=error.Message;}
 }
 [STAThread] public static void Main(string[] args){
  Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);var form=new CwtchLauncher();
  if(args.Length==2&&args[0]=="--preview"){
   form.versionLabel.Text="INSTALLED   —   v0.1.0";
   form.OnProgress(new Dictionary<string,object>{{"stage","available"},{"version","v0.1.1"}});
   form.OnProgress(new Dictionary<string,object>{{"stage","downloading"},{"downloaded",260046848L},{"total",419430400L},{"speed",8388608L}});
   form.update.Enabled=false;form.Show();Application.DoEvents();
   using(var image=new Bitmap(form.Width,form.Height)){form.DrawToBitmap(image,new Rectangle(0,0,form.Width,form.Height));image.Save(args[1]);}
   form.Dispose();return;
  }
  form.Shown+=async(s,e)=>await form.UpdateGame();Application.Run(form);
 }
}

```

## Launcher/update.py

```
"""Public GitHub release installer: verified downloads and staged updates."""
import argparse
import hashlib
import json
import re
import shutil
import sys
import uuid
import time
from contextlib import contextmanager
import urllib.request
import zipfile
from pathlib import Path

HEADERS = {'User-Agent': 'CWTCH-Launcher', 'Accept': 'application/vnd.github+json'}

def read_url(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=60) as response:
        return response.read()

def safe_extract(archive, destination):
    destination = Path(destination).resolve()
    with zipfile.ZipFile(archive) as package:
        for entry in package.infolist():
            relative = Path(entry.filename.replace('\\', '/'))
            target = (destination / relative).resolve()
            if relative.is_absolute() or ':' in entry.filename or not target.is_relative_to(destination):
                raise ValueError('Unsafe path in release archive.')
            if ((entry.external_attr >> 16) & 0o170000) == 0o120000:
                raise ValueError('Links are not allowed in release archives.')
        package.extractall(destination)


@contextmanager
def download_directory(root):
    # Use inherited Windows permissions; restrictive temporary-directory ACLs
    # can prevent a sandboxed updater reading its own files.
    root=Path(root).resolve()
    target=root/('download-'+uuid.uuid4().hex)
    target.mkdir()
    try:
        yield target
    finally:
        if target.resolve().parent != root:
            raise ValueError('Unexpected temporary directory location.')
        shutil.rmtree(target)

def install(root, repository, progress=None):
    def report(stage, **values):
        if progress:
            progress(dict(stage=stage, **values))
    report('checking')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise ValueError('Invalid repository setting.')
    root = Path(root).resolve()
    root.mkdir(parents=True, exist_ok=True)
    release = json.loads(read_url('https://api.github.com/repos/' + repository + '/releases/latest'))
    version = release['tag_name']
    if not re.fullmatch(r'v\d+\.\d+\.\d+', version):
        raise ValueError('Unsupported release version.')
    report('available', version=version)
    assets = {asset['name']: asset for asset in release['assets']}
    destination = root / 'Versions' / version
    if not (destination / 'CWTCH.exe').is_file() or not (destination / 'CWTCH.pck').is_file():
        expected = read_url(assets['CWTCH-Windows.zip.sha256']['browser_download_url']).decode().split()[0].lower()
        if not re.fullmatch('[a-f0-9]{64}', expected):
            raise ValueError('Invalid release checksum.')
        with download_directory(root) as temporary:
            archive = Path(temporary) / 'release.zip'
            request = urllib.request.Request(assets['CWTCH-Windows.zip']['browser_download_url'], headers=HEADERS)
            with urllib.request.urlopen(request, timeout=120) as response, open(archive, 'wb') as output:
                total = int(response.headers.get('Content-Length') or assets['CWTCH-Windows.zip'].get('size') or 0)
                received = 0
                started = time.monotonic()
                last_report = started
                report('downloading', downloaded=0, total=total, speed=0)
                while chunk := response.read(256 * 1024):
                    output.write(chunk)
                    received += len(chunk)
                    now = time.monotonic()
                    if now - last_report >= 0.1:
                        report('downloading', downloaded=received, total=total, speed=received / max(now-started, 0.001))
                        last_report = now
                report('downloading', downloaded=received, total=total, speed=received / max(time.monotonic()-started, 0.001))
            report('verifying')
            with open(archive, 'rb') as source:
                actual = hashlib.file_digest(source, 'sha256').hexdigest()
            if actual != expected:
                raise ValueError('Download verification failed. The installed game was not changed.')
            stage = Path(temporary) / 'game'
            report('installing')
            safe_extract(archive, stage)
            if not (stage / 'CWTCH.exe').is_file() or not (stage / 'CWTCH.pck').is_file():
                raise ValueError('Game files are missing from this release.')
            destination.parent.mkdir(exist_ok=True)
            if destination.exists():
                raise ValueError('An incomplete version folder needs checking: ' + str(destination))
            shutil.move(str(stage), str(destination))
    result = {'version': version, 'executable': str(destination / 'CWTCH.exe')}
    pending = root / 'installed.tmp.json'
    pending.write_text(json.dumps(result), encoding='utf-8')
    pending.replace(root / 'installed.json')
    report('ready', version=version)
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', required=True)
    parser.add_argument('--result', required=True)
    parser.add_argument('--progress', action='store_true')
    args = parser.parse_args()
    try:
        config = json.loads((Path(__file__).parent / 'repository.json').read_text(encoding='utf-8-sig'))
        progress = (lambda event: print(json.dumps(event), flush=True)) if args.progress else None
        result = install(args.root, config['repository'], progress)
        result['ok'] = True
    except Exception as error:
        result = {'ok': False, 'message': str(error)}
    Path(args.result).write_text(json.dumps(result), encoding='utf-8')
    sys.exit(0 if result['ok'] else 1)

```

