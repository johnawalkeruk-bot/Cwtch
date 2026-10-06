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
  using(var brush=new SolidBrush(Color.FromArgb(255,202,114))) {
   if(Indeterminate)e.Graphics.FillRectangle(brush,phase-100,0,100,Height);
   else e.Graphics.FillRectangle(brush,0,0,(int)(Width*Math.Max(0,Math.Min(1,Fraction))),Height);
  }
 }
 protected override void Dispose(bool disposing){if(disposing)animation.Dispose();base.Dispose(disposing);}
}
public sealed class ValleyArtwork : Panel {
 public Image Logo, Landscape;
 public ValleyArtwork(){DoubleBuffered=true;}
 protected override void OnPaint(PaintEventArgs e){
  using(var sky=new LinearGradientBrush(ClientRectangle,Color.FromArgb(49,81,75),Color.FromArgb(19,37,35),90))e.Graphics.FillRectangle(sky,ClientRectangle);
  if(Landscape!=null){
   var source=new Rectangle(0,(int)(Landscape.Height*0.20),Landscape.Width,(int)(Landscape.Height*0.66));
   float scale=Math.Max((float)Width/source.Width,(float)Height/source.Height);
   int w=(int)(source.Width*scale),h=(int)(source.Height*scale);
   e.Graphics.DrawImage(Landscape,new Rectangle((Width-w)/2,(Height-h)/2,w,h),source,GraphicsUnit.Pixel);
   using(var veil=new SolidBrush(Color.FromArgb(190,16,41,31)))e.Graphics.FillRectangle(veil,ClientRectangle);
  }
  e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;
  if(Landscape==null)using(var ridge=new SolidBrush(Color.FromArgb(38,65,60)))e.Graphics.FillPolygon(ridge,new[]{new Point(0,380),new Point(120,260),new Point(200,320),new Point(330,180),new Point(Width,350),new Point(Width,Height),new Point(0,Height)});
  if(Logo!=null){e.Graphics.InterpolationMode=InterpolationMode.HighQualityBicubic;e.Graphics.DrawImage(Logo,new Rectangle(20,28,Width-40,Width-40));}
 }
 protected override void Dispose(bool disposing){if(disposing){if(Logo!=null)Logo.Dispose();if(Landscape!=null)Landscape.Dispose();}base.Dispose(disposing);}
}
public class CwtchLauncher : Form {
 readonly string root=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"CWTCH");
 readonly Label status=new Label(),versionLabel=new Label(),latestLabel=new Label(),detail=new Label(),heading=new Label();
 readonly Button play=new Button(),update=new Button();
 readonly DownloadBar progress=new DownloadBar();
 readonly Label notesTitle=new Label();
 readonly TextBox notes=new TextBox();
 string game; bool busy;
 static readonly Color Gold=Color.FromArgb(255,202,114),Muted=Color.FromArgb(100,112,98),White=Color.FromArgb(34,57,47);
 public CwtchLauncher() {
  Text="CWTCH · Your slice of the valley";ClientSize=new Size(1100,640);StartPosition=FormStartPosition.CenterScreen;
  AutoScaleMode=AutoScaleMode.Dpi;Icon=Icon.ExtractAssociatedIcon(Application.ExecutablePath);
  FormBorderStyle=FormBorderStyle.FixedSingle;MaximizeBox=false;BackColor=Color.FromArgb(243,238,226);Font=new Font("Segoe UI",10);
  var art=new ValleyArtwork();art.SetBounds(0,0,390,640);Controls.Add(art);
  string logo=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"logo.png");if(File.Exists(logo))art.Logo=Image.FromFile(logo);
  string landscape=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"garden.png");if(File.Exists(landscape))art.Landscape=Image.FromFile(landscape);
  string studio=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"wgs.png");
  if(File.Exists(studio)){var mark=new PictureBox{Image=Image.FromFile(studio),SizeMode=PictureBoxSizeMode.Zoom,BackColor=Color.Transparent};mark.SetBounds(26,525,100,90);art.Controls.Add(mark);mark.Disposed+=(s,e)=>mark.Image.Dispose();}
  var studioName=MakeLabel("WALDAS GAME STUDIOS",9,Color.FromArgb(238,211,155));studioName.SetBounds(130,562,245,26);art.Controls.Add(studioName);
  var caption=MakeLabel("A LITTLE SPACE TO SLOW DOWN",10,Gold);caption.SetBounds(30,444,345,25);art.Controls.Add(caption);
  var sub=MakeLabel("YOUR SLICE OF THE VALLEY.",13,Color.FromArgb(247,234,208));sub.SetBounds(30,475,345,32);art.Controls.Add(sub);
  var eyebrow=MakeLabel("C W T C H   /   YOUR GARDEN AWAITS",10,Muted);eyebrow.SetBounds(434,40,422,24);Controls.Add(eyebrow);
  Configure(heading,"WELCOME TO THE VALLEY",23,White,434,84,622,47);heading.Font=new Font("Georgia",23);
  Configure(versionLabel,"INSTALLED   —   Not installed",10,Muted,434,145,422,24);
  Configure(latestLabel,"LATEST         —   Checking…",10,Muted,434,173,422,24);
  Configure(notesTitle,"LATEST PATCH NOTES",10,White,434,212,622,24);
  notes.SetBounds(434,243,622,179);notes.ReadOnly=true;notes.Multiline=true;notes.WordWrap=true;notes.TabStop=true;
  notes.BorderStyle=BorderStyle.None;notes.BackColor=Color.FromArgb(255,250,240);notes.ForeColor=White;
  notes.Font=new Font("Segoe UI",10);notes.ScrollBars=ScrollBars.Vertical;
  notes.Text="Patch notes will appear when the latest release is found.";Controls.Add(notes);
  try{var cached=Read(Path.Combine(root,"patch-notes.json"));ShowNotes((string)cached["version"],(string)cached["notes"],true);}catch{}
  Configure(status,"Checking for updates…",12,White,434,442,622,34);
  progress.SetBounds(434,486,622,6);Controls.Add(progress);
  Configure(detail,"Connecting to the valley",10,Muted,434,506,622,40);
  StyleButton(play,"PLAY CWTCH",434,562,380,54,true);play.Enabled=false;
  StyleButton(update,"CHECK FOR UPDATES",828,562,228,54,false);
  update.Click+=async(s,e)=>await UpdateGame();play.Click+=(s,e)=>Play();
  FormClosing+=(s,e)=>{if(busy){e.Cancel=true;detail.Text="Please let the update finish before closing.";}};
  try{Installed();}catch{versionLabel.Text="INSTALLED   —   Could not read version";}
 }
 static Label MakeLabel(string text,float size,Color color){return new Label {Text=text,Font=new Font("Segoe UI",size),ForeColor=color,BackColor=Color.Transparent,AutoSize=false};}
 void Configure(Label label,string text,float size,Color color,int x,int y,int w,int h){label.Text=text;label.Font=new Font("Segoe UI",size);label.ForeColor=color;label.SetBounds(x,y,w,h);Controls.Add(label);}
 void StyleButton(Button button,string text,int x,int y,int w,int h,bool primary){
  button.Text=text;button.SetBounds(x,y,w,h);button.FlatStyle=FlatStyle.Flat;button.FlatAppearance.BorderSize=0;
  button.BackColor=primary?Gold:Color.FromArgb(34,57,47);button.ForeColor=primary?Color.FromArgb(25,39,33):Color.FromArgb(247,234,208);
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
 void ShowNotes(string version,string body,bool cached){
  notesTitle.Text="PATCH NOTES  ·  "+version+(cached?"  ·  SAVED COPY":"");
  notes.Text=body.Replace("\r\n","\n").Replace("\n",Environment.NewLine);notes.SelectionStart=0;notes.SelectionLength=0;notes.ScrollToCaret();
 }
 void OnProgress(Dictionary<string,object> data){
  string stage=(string)data["stage"];
  if(data.ContainsKey("notes"))ShowNotes((string)data["version"],(string)data["notes"],false);
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
   form.versionLabel.Text="INSTALLED   —   DESIGN PREVIEW";
   form.OnProgress(new Dictionary<string,object>{{"stage","available"},{"version","DESIGN PREVIEW"}});
   form.OnProgress(new Dictionary<string,object>{{"stage","downloading"},{"downloaded",260046848L},{"total",419430400L},{"speed",8388608L}});
   form.ShowNotes("DESIGN PREVIEW","A familiar place to return to\n\nMenus and sound\n• Consistent uppercase menu labels.\n• Six sound controls from the garden and village pause menus.\n\nA launcher from the same valley\n• Forest green, parchment and gold to match the website.\n• Version details, latest patch notes and download progress remain available.",false);
   form.update.Enabled=false;form.Show();Application.DoEvents();
   using(var image=new Bitmap(form.Width,form.Height)){form.DrawToBitmap(image,new Rectangle(0,0,form.Width,form.Height));image.Save(args[1]);}
   form.Dispose();return;
  }
  form.Shown+=async(s,e)=>await form.UpdateGame();Application.Run(form);
 }
}
