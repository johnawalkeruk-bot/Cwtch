using System;
using System.IO;
using System.Drawing;
using System.Diagnostics;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Web.Script.Serialization;
using System.Collections.Generic;
public class CwtchLauncher : Form {
 readonly string root=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"CWTCH");
 readonly Label status=new Label();
 readonly Button play=new Button(),update=new Button();
 string game; bool busy;
 public CwtchLauncher() {
  Text="CWTCH Launcher"; ClientSize=new Size(620,360); StartPosition=FormStartPosition.CenterScreen;
  FormBorderStyle=FormBorderStyle.FixedDialog; MaximizeBox=false; BackColor=Color.FromArgb(23,45,42);
  var title=new Label {Text="C W T C H",Font=new Font("Georgia",32,FontStyle.Bold),ForeColor=Color.FromArgb(229,193,124)};
  title.SetBounds(40,35,540,65);Controls.Add(title);
  var tagline=new Label {Text="Your slice of the valley.",Font=new Font("Georgia",14),ForeColor=Color.Beige};
  tagline.SetBounds(45,110,520,35);Controls.Add(tagline);
  status.Text="Checking for the latest version...";status.Font=new Font("Segoe UI",11);status.ForeColor=Color.Beige;
  status.SetBounds(45,163,525,84);Controls.Add(status);
  play.Text="PLAY";play.SetBounds(45,270,240,48);play.Enabled=false;play.BackColor=Color.FromArgb(229,193,124);Controls.Add(play);
  update.Text="CHECK FOR UPDATES";update.SetBounds(305,270,270,48);update.BackColor=play.BackColor;Controls.Add(update);
  update.Click+=async (sender,args)=>await UpdateGame();
  play.Click+=(sender,args)=>Play();
  FormClosing+=(sender,args)=>{if(busy)args.Cancel=true;};
 }
 Dictionary<string,object> Read(string file) {return new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(file));}
 string Installed() {
  string file=Path.Combine(root,"installed.json");
  if(!File.Exists(file))return null;
  var data=Read(file);string path=Path.GetFullPath((string)data["executable"]);
  if(!path.StartsWith(root+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase)||!File.Exists(path))return null;
  game=path;play.Enabled=true;return (string)data["version"];
 }
 public async Task UpdateGame() {
  if(busy)return;busy=true;play.Enabled=false;update.Enabled=false;
  status.Text="Checking and installing the latest release. The first download may take a few minutes.";
  try {
   Directory.CreateDirectory(root);
   string folder=AppDomain.CurrentDomain.BaseDirectory;
   string python=Path.Combine(folder,"Python","python.exe");
   if(!File.Exists(python))throw new Exception("Download the complete CWTCH-Launcher.zip.");
   string result=Path.Combine(root,"update-"+Guid.NewGuid().ToString("N")+".json");
   var info=new ProcessStartInfo(python,"\""+Path.Combine(folder,"update.py")+"\" --root \""+root+"\" --result \""+result+"\"");
   info.UseShellExecute=false;info.CreateNoWindow=true;
   using(var process=Process.Start(info)) { await Task.Run(()=>process.WaitForExit()); }
   if(!File.Exists(result))throw new Exception("The updater did not finish. Try again.");
   var data=Read(result);File.Delete(result);
   if(!(bool)data["ok"])throw new Exception((string)data["message"]);
   status.Text="Ready to play "+Installed()+". Saves are kept between updates.";
  } catch(Exception error) {
   string version=null;try {version=Installed();}catch{}
   status.Text=(version==null?"Could not install yet. ":"Update unavailable. You can still play "+version+". ")+error.Message;
  } finally {busy=false;update.Enabled=true;}
 }
 void Play() {
  if(game==null)return;
  var info=new ProcessStartInfo(game);info.UseShellExecute=false;info.WorkingDirectory=Path.GetDirectoryName(game);
  string data=Path.Combine(root,"UserData");Directory.CreateDirectory(data);info.EnvironmentVariables["APPDATA"]=data;
  try {Process.Start(info);Close();}catch(Exception error){status.Text=error.Message;}
 }
 [STAThread] public static void Main(string[] args) {
  Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
  var form=new CwtchLauncher();
  if(args.Length==2&&args[0]=="--preview") {
   form.status.Text="Ready to install the latest CWTCH release. Saves are kept between updates.";
   form.Show();Application.DoEvents();
   using(var image=new Bitmap(form.Width,form.Height)) {form.DrawToBitmap(image,new Rectangle(0,0,form.Width,form.Height));image.Save(args[1]);}
   form.Dispose();return;
  }
  form.Shown+=async (sender,eventArgs)=>await form.UpdateGame();Application.Run(form);
 }
}
