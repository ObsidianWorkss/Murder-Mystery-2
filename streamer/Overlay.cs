// MM2 Windows overlay: authenticated, loopback-only display transport. No input injection.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

namespace MM2Streamer {
    public sealed class Item {
        public string Kind, Text, Image, Color = "FFFFFF", Stroke = "000000";
        public double X, Y, W, H, Alpha = 1, Radius, Font = 14, Border, StrokeAlpha, Rotation;
        public double ClipX, ClipY, ClipW, ClipH, ImageX, ImageY, ImageW, ImageH;
        public int Z;
        public bool Bold, Center, Right, Wrap;
    }
    public sealed class Frame {
        public int Protocol, Width, Height;
        public string Session;
        public List<Item> Items = new List<Item>();
    }
    internal static class Protocol {
        public const int Limit = 1048576;
        public static bool Finite(double n) { return !Double.IsNaN(n) && !Double.IsInfinity(n); }
        public static bool Valid(Frame f) {
            if (f == null || f.Protocol != 1 || f.Width < 200 || f.Height < 200 || f.Width > 16384 || f.Height > 16384
                || String.IsNullOrEmpty(f.Session) || f.Session.Length > 128 || f.Items == null || f.Items.Count > 1600) return false;
            foreach (Item i in f.Items) {
                if (i == null || (i.Kind != "rect" && i.Kind != "text" && i.Kind != "image" && i.Kind != "line")
                    || (i.Text != null && i.Text.Length > 4096) || (i.Image != null && i.Image.Length > 1024)) return false;
                foreach (double n in new [] {i.X,i.Y,i.W,i.H,i.Alpha,i.Radius,i.Font,i.Border,i.StrokeAlpha,i.Rotation,
                    i.ClipX,i.ClipY,i.ClipW,i.ClipH,i.ImageX,i.ImageY,i.ImageW,i.ImageH}) if (!Finite(n) || Math.Abs(n) > 100000) return false;
                if (i.W < 0 || i.H < 0 || i.Alpha < 0 || i.Alpha > 1 || i.Font < 1 || i.Font > 256 || i.Border < 0 || i.Border > 32) return false;
            }
            return true;
        }
        public static bool TrustedImage(Uri uri) {
            return uri!=null && uri.Scheme=="https" && String.IsNullOrEmpty(uri.UserInfo)
                && (uri.Host.EndsWith(".rbxcdn.com",StringComparison.OrdinalIgnoreCase) || uri.Host=="rbxcdn.com"
                    || uri.Host=="www.roblox.com" || uri.Host=="assetdelivery.roblox.com");
        }
        public static bool SameToken(string actual, string expected) {
            if (actual == null || expected == null || actual.Length != expected.Length) return false;
            int difference = 0;
            for (int n=0;n<actual.Length;n++) difference |= actual[n] ^ expected[n];
            return difference == 0;
        }
    }
    internal sealed class Bridge : IDisposable {
        readonly TcpListener listener;
        readonly string token;
        readonly Func<bool> ready;
        readonly Action<Frame> receive;
        readonly SemaphoreSlim slots = new SemaphoreSlim(4,4);
        volatile bool stopped;
        readonly HashSet<string> closedSessions=new HashSet<string>();
        readonly object sessionLock=new object();
        public int Port { get { return ((IPEndPoint)listener.LocalEndpoint).Port; } }
        public Bridge(string key, Func<bool> isReady, Action<Frame> handler) {
            token=key; ready=isReady; receive=handler;
            listener=new TcpListener(IPAddress.Loopback,0); listener.Start(8);
            new Thread(Accept) {IsBackground=true,Name="MM2 loopback display"}.Start();
        }
        void Accept() {
            while (!stopped) {
                try {
                    TcpClient client=listener.AcceptTcpClient();
                    if (!slots.Wait(0)) { client.Close(); continue; }
                    ThreadPool.QueueUserWorkItem(delegate { try { Handle(client); } finally { client.Close(); slots.Release(); } });
                } catch (SocketException) { if (!stopped) Thread.Sleep(50); }
                catch (ObjectDisposedException) { return; }
            }
        }
        void Handle(TcpClient client) {
            try {
                client.ReceiveTimeout=1500; client.SendTimeout=1500;
                NetworkStream stream=client.GetStream();
                var header=new List<byte>(); int b;
                while (header.Count<8192 && (b=stream.ReadByte())>=0) {
                    header.Add((byte)b); int n=header.Count;
                    if (n>=4 && header[n-4]==13 && header[n-3]==10 && header[n-2]==13 && header[n-1]==10) break;
                }
                if (header.Count==8192) { Reply(stream,413,"{}"); return; }
                string[] lines=Encoding.ASCII.GetString(header.ToArray()).Split(new [] {"\r\n"},StringSplitOptions.None);
                string[] first=lines[0].Split(' '); string supplied=null,session=null; int length=0; bool hasLength=false;
                if (first.Length!=3) { Reply(stream,400,"{}"); return; }
                foreach(string line in lines) {
                    int colon=line.IndexOf(':'); if(colon<0) continue;
                    string name=line.Substring(0,colon).Trim(), value=line.Substring(colon+1).Trim();
                    if(name.Equals("X-MM2-Token",StringComparison.OrdinalIgnoreCase)) supplied=value;
                    if(name.Equals("X-MM2-Session",StringComparison.OrdinalIgnoreCase)) session=value;
                    if(name.Equals("Content-Length",StringComparison.OrdinalIgnoreCase)) {
                        if(hasLength || !Int32.TryParse(value,out length)) { Reply(stream,400,"{}"); return; }
                        hasLength=true;
                    }
                    if(name.Equals("Transfer-Encoding",StringComparison.OrdinalIgnoreCase) || name.Equals("Origin",StringComparison.OrdinalIgnoreCase)) { Reply(stream,403,"{}"); return; }
                }
                if(!Protocol.SameToken(supplied,token)) { Reply(stream,401,"{}"); return; }
                if(length<0 || length>Protocol.Limit) { Reply(stream,413,"{}"); return; }
                if(first[0]=="GET" && first[1]=="/status") {
                    bool active=ready(); Reply(stream,200,"{\"Protocol\":1,\"Ready\":"+(active?"true":"false")+",\"CaptureExcluded\":"+(active?"true":"false")+"}"); return;
                }
                if(first[0]=="POST" && first[1]=="/clear" && length==0 && !String.IsNullOrEmpty(session) && session.Length<=128) {
                    lock(sessionLock) { if(closedSessions.Count>=128) closedSessions.Clear(); closedSessions.Add(session); receive(null); }
                    Reply(stream,200,"{}"); return;
                }
                if(first[0]!="POST" || first[1]!="/frame") { Reply(stream,404,"{}"); return; }
                var data=new byte[length]; int read=0;
                while(read<length) { int count=stream.Read(data,read,length-read); if(count==0) { Reply(stream,400,"{}"); return; } read+=count; }
                var serializer=new JavaScriptSerializer {MaxJsonLength=Protocol.Limit,RecursionLimit=20};
                Frame frame=serializer.Deserialize<Frame>(Encoding.UTF8.GetString(data));
                if(!Protocol.Valid(frame)) { Reply(stream,422,"{}"); return; }
                if(!ready()) { Reply(stream,503,"{}"); return; }
                lock(sessionLock) {
                    if(closedSessions.Contains(frame.Session)) { Reply(stream,409,"{}"); return; }
                    receive(frame);
                }
                Reply(stream,200,"{\"Accepted\":true}");
            } catch(Exception) { /* Malformed/local requests close without exposing keys or stack traces. */ }
        }
        static void Reply(Stream stream,int status,string body) {
            byte[] data=Encoding.UTF8.GetBytes(body);
            byte[] head=Encoding.ASCII.GetBytes("HTTP/1.1 "+status+" Result\r\nContent-Type: application/json\r\nCache-Control: no-store\r\nConnection: close\r\nContent-Length: "+data.Length+"\r\n\r\n");
            stream.Write(head,0,head.Length); stream.Write(data,0,data.Length);
        }
        public void Dispose() { stopped=true; listener.Stop(); }
    }
    internal static class Native {
        [StructLayout(LayoutKind.Sequential)] internal struct Rect { public int Left,Top,Right,Bottom; }
        [StructLayout(LayoutKind.Sequential)] internal struct Point { public int X,Y; }
        [DllImport("user32.dll")] internal static extern bool GetClientRect(IntPtr h,out Rect r);
        [DllImport("user32.dll")] internal static extern bool ClientToScreen(IntPtr h,ref Point p);
        [DllImport("user32.dll")] internal static extern bool IsIconic(IntPtr h);
        [DllImport("user32.dll")] internal static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] internal static extern IntPtr GetWindowLongPtr(IntPtr h,int n);
        [DllImport("user32.dll")] internal static extern IntPtr SetWindowLongPtr(IntPtr h,int n,IntPtr v);
        [DllImport("user32.dll",SetLastError=true)] internal static extern bool SetWindowDisplayAffinity(IntPtr h,uint value);
        [DllImport("user32.dll")] internal static extern bool GetWindowDisplayAffinity(IntPtr h,out uint value);
    }
    internal sealed class Surface : FrameworkElement {
        public Frame Current;
        readonly Dictionary<string,BitmapSource> images=new Dictionary<string,BitmapSource>();
        readonly HashSet<string> loading=new HashSet<string>();
        public string ContentRoot;
        static SolidColorBrush Brush(string hex,double alpha) {
            uint rgb; if(hex==null || hex.Length!=6 || !UInt32.TryParse(hex,NumberStyles.HexNumber,CultureInfo.InvariantCulture,out rgb)) rgb=0xffffff;
            var brush=new SolidColorBrush(Color.FromArgb((byte)(Math.Max(0,Math.Min(1,alpha))*255),(byte)(rgb>>16),(byte)(rgb>>8),(byte)rgb)); brush.Freeze(); return brush;
        }
        BitmapSource Image(string source) {
            if(String.IsNullOrEmpty(source)) return null;
            BitmapSource bitmap; if(images.TryGetValue(source,out bitmap)) return bitmap;
            if(loading.Contains(source) || loading.Count>=4 || images.Count>=192) return null;
            string local=null,remote=null;
            if(source.StartsWith("rbxasset://",StringComparison.OrdinalIgnoreCase) && ContentRoot!=null) {
                string root=Path.GetFullPath(ContentRoot)+Path.DirectorySeparatorChar;
                string candidate=Path.GetFullPath(Path.Combine(root,source.Substring(11).Replace('/',Path.DirectorySeparatorChar)));
                if(candidate.StartsWith(root,StringComparison.OrdinalIgnoreCase) && File.Exists(candidate)) local=candidate;
            } else {
                string id=null;
                if(source.StartsWith("rbxassetid://")) id=source.Substring(13);
                Uri uri;
                if(id!=null) { long number; if(Int64.TryParse(id,out number) && number>0) remote="https://assetdelivery.roblox.com/v1/asset/?id="+number; }
                else if(Uri.TryCreate(source,UriKind.Absolute,out uri) && Protocol.TrustedImage(uri)) remote=source;
            }
            if(local==null && remote==null) { images[source]=null; return null; }
            loading.Add(source);
            Task.Run(delegate {
                BitmapSource result=null;
                try {
                    byte[] bytes;
                    if(local!=null) { var info=new FileInfo(local); if(info.Length>2097152) throw new IOException(); bytes=File.ReadAllBytes(local); }
                    else {
                        bytes=null;
                        for(int hop=0;hop<4;hop++) {
                            var request=(HttpWebRequest)WebRequest.Create(remote); request.Timeout=2500; request.ReadWriteTimeout=2500; request.AllowAutoRedirect=false;
                            using(var response=(HttpWebResponse)request.GetResponse()) {
                                int status=(int)response.StatusCode;
                                if(status>=300 && status<400) {
                                    Uri next;
                                    if(!Uri.TryCreate(new Uri(remote),response.Headers["Location"],out next) || !Protocol.TrustedImage(next)) throw new IOException();
                                    remote=next.AbsoluteUri; continue;
                                }
                                using(var stream=response.GetResponseStream()) using(var memory=new MemoryStream()) {
                                    var buffer=new byte[8192]; int count;
                                    while((count=stream.Read(buffer,0,buffer.Length))>0) { if(memory.Length+count>2097152) throw new IOException(); memory.Write(buffer,0,count); }
                                    bytes=memory.ToArray();
                                }
                                break;
                            }
                        }
                        if(bytes==null) throw new IOException();
                    }
                    using(var stream=new MemoryStream(bytes)) {
                        var image=new BitmapImage(); image.BeginInit(); image.CacheOption=BitmapCacheOption.OnLoad; image.StreamSource=stream; image.EndInit(); image.Freeze(); result=image;
                    }
                } catch(Exception) { }
                Dispatcher.BeginInvoke(new Action(delegate { loading.Remove(source); images[source]=result; InvalidateVisual(); }));
            });
            return null;
        }
        protected override void OnRender(DrawingContext dc) {
            Frame f=Current; if(f==null || ActualWidth<=0 || ActualHeight<=0) return;
            dc.PushTransform(new ScaleTransform(ActualWidth/f.Width,ActualHeight/f.Height));
            foreach(Item i in f.Items) {
                if((i.Alpha<=0 && !(i.Kind=="rect" && i.StrokeAlpha>0 && i.Border>0)) || i.W<0 || i.H<0) continue;
                int pushed=0;
                try {
                    bool clip=i.ClipW>0 && i.ClipH>0;
                    if(clip) { dc.PushClip(new RectangleGeometry(new Rect(i.ClipX,i.ClipY,i.ClipW,i.ClipH))); pushed++; }
                    dc.PushTransform(new RotateTransform(i.Rotation,i.X+i.W/2,i.Y+i.H/2)); pushed++;
                    var rect=new Rect(i.X,i.Y,i.W,i.H);
                    if(i.Kind=="rect") dc.DrawRoundedRectangle(Brush(i.Color,i.Alpha),i.Border>0?new Pen(Brush(i.Stroke,i.StrokeAlpha),i.Border):null,rect,i.Radius,i.Radius);
                    else if(i.Kind=="line") dc.DrawLine(new Pen(Brush(i.Color,i.Alpha),Math.Max(1,i.Border)),new Point(i.X,i.Y),new Point(i.X+i.W,i.Y+i.H));
                    else if(i.Kind=="text" && !String.IsNullOrEmpty(i.Text)) {
                        var text=new FormattedText(i.Text,CultureInfo.InvariantCulture,FlowDirection.LeftToRight,
                            new Typeface(new FontFamily("Segoe UI"),FontStyles.Normal,i.Bold?FontWeights.SemiBold:FontWeights.Normal,FontStretches.Normal),i.Font,Brush(i.Color,i.Alpha),1);
                        text.MaxTextWidth=Math.Max(1,i.W); text.MaxTextHeight=Math.Max(1,i.H); if(!i.Wrap) text.MaxLineCount=1;
                        text.Trimming=TextTrimming.CharacterEllipsis; text.TextAlignment=i.Center?TextAlignment.Center:i.Right?TextAlignment.Right:TextAlignment.Left;
                        dc.DrawText(text,new Point(i.X,i.Y+Math.Max(0,(i.H-text.Height)/2)));
                    } else if(i.Kind=="image") {
                        BitmapSource source=Image(i.Image);
                        if(source!=null) {
                            BitmapSource shown=source;
                            if(i.ImageW>0 && i.ImageH>0 && i.ImageX>=0 && i.ImageY>=0 && i.ImageX+i.ImageW<=source.PixelWidth && i.ImageY+i.ImageH<=source.PixelHeight)
                                shown=new CroppedBitmap(source,new Int32Rect((int)i.ImageX,(int)i.ImageY,(int)i.ImageW,(int)i.ImageH));
                            dc.PushOpacity(i.Alpha); pushed++; dc.DrawImage(shown,rect); dc.Pop(); pushed--;
                        }
                    }
                } catch(Exception) { /* Invalid individual art cannot stop other overlay items. */ }
                finally { while(pushed-->0) dc.Pop(); }
            }
            dc.Pop();
        }
    }
    internal sealed class Overlay : Window {
        readonly Surface surface=new Surface();
        readonly Bridge bridge;
        readonly DispatcherTimer timer;
        readonly string configPath;
        readonly int targetPid;
        Frame pending;
        long received;
        volatile bool excluded,targetFound;
        IntPtr handle;
        public Overlay(int pid,string output) {
            targetPid=pid; configPath=output;
            Title="MM2 Streamer Overlay"; WindowStyle=WindowStyle.None; ResizeMode=ResizeMode.NoResize;
            AllowsTransparency=true; Background=Brushes.Transparent; ShowInTaskbar=false; ShowActivated=false; Topmost=true;
            IsHitTestVisible=false; Width=1; Height=1; Content=surface;
            byte[] bytes=new byte[32]; using(var rng=RandomNumberGenerator.Create()) rng.GetBytes(bytes);
            string token=Convert.ToBase64String(bytes);
            bridge=new Bridge(token,delegate { return excluded && targetFound; },delegate(Frame f) { Interlocked.Exchange(ref pending,f); Interlocked.Exchange(ref received,Stopwatch.GetTimestamp()); });
            string lua="-- Local display connection. Keep this session token private.\ngetgenv().MM2StreamerConnection = {Port="+bridge.Port+",Token=\""+token+"\"}\nlocal s=getgenv().MM2Assist\nif s and s.SetStreamerMode then local ok,message=s.SetStreamerMode(true); print(message) else print(\"Load MM2 Universal first, then run this connection file again.\") end\n";
            File.WriteAllText(configPath,lua,new UTF8Encoding(false));
            SourceInitialized+=delegate {
                handle=new WindowInteropHelper(this).Handle;
                long flags=Native.GetWindowLongPtr(handle,-20).ToInt64();
                Native.SetWindowLongPtr(handle,-20,new IntPtr(flags|0x20|0x80|0x08000000)); // click through, tool window, no activate
                uint applied; excluded=Native.SetWindowDisplayAffinity(handle,0x11) && Native.GetWindowDisplayAffinity(handle,out applied) && applied==0x11;
            };
            Closed+=delegate { excluded=false; bridge.Dispose(); timer.Stop(); };
            timer=new DispatcherTimer {Interval=TimeSpan.FromMilliseconds(33)}; timer.Tick+=Tick; timer.Start();
        }
        void Tick(object sender,EventArgs args) {
            uint affinity; excluded=Native.GetWindowDisplayAffinity(handle,out affinity) && affinity==0x11;
            Process selected=null;
            foreach(Process process in Process.GetProcessesByName("RobloxPlayerBeta")) {
                bool usable=false;
                try { usable=process.MainWindowHandle!=IntPtr.Zero && (targetPid==0 || process.Id==targetPid); } catch(InvalidOperationException) { }
                if(!usable) { process.Dispose(); continue; }
                if(selected!=null) { selected.Dispose(); process.Dispose(); selected=null; break; }
                selected=process;
            }
            targetFound=selected!=null;
            if(selected==null) { surface.Current=null; surface.InvalidateVisual(); return; }
            using(selected) {
                Native.Rect rect; var point=new Native.Point();
                IntPtr window=selected.MainWindowHandle;
                if(!Native.GetClientRect(window,out rect) || !Native.ClientToScreen(window,ref point) || Native.IsIconic(window)) {
                    targetFound=false; surface.Current=null; surface.InvalidateVisual(); return;
                }
                try { if(surface.ContentRoot==null) surface.ContentRoot=Path.Combine(Path.GetDirectoryName(selected.MainModule.FileName),"content"); } catch(Exception) { }
                var transform=PresentationSource.FromVisual(this).CompositionTarget.TransformFromDevice;
                var origin=transform.Transform(new Point(point.X,point.Y));
                var size=transform.Transform(new Vector(rect.Right-rect.Left,rect.Bottom-rect.Top));
                Left=origin.X; Top=origin.Y; Width=Math.Max(1,size.X); Height=Math.Max(1,size.Y);
                double age=(Stopwatch.GetTimestamp()-Interlocked.Read(ref received))/(double)Stopwatch.Frequency;
                surface.Current=(excluded && age<1 && Native.GetForegroundWindow()==window)?pending:null;
                surface.InvalidateVisual();
            }
        }
    }
    internal static class Program {
        [STAThread] static int Main(string[] args) {
            if(args.Length>0 && args[0]=="--self-test") {
                try { return SelfTest.Run(); } catch(Exception e) { Console.Error.WriteLine(e.Message); return 1; }
            }
            int pid=0; if(args.Length>0 && !Int32.TryParse(args[0],out pid)) return 2;
            try {
                bool created;
                using(var single=new Mutex(true,"Local\\MM2Streamer.Companion.v1",out created)) {
                    if(!created) return 3;
                    try {
                        var application=new Application();
                        return application.Run(new Overlay(pid,Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"connect.lua")));
                    } finally { single.ReleaseMutex(); }
                }
            } catch(Exception e) { File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"overlay-error.txt"),e.GetType().Name+": "+e.Message); return 1; }
        }
    }
    internal static class SelfTest {
        public static int Run() {
            int checks=0;
            Action<bool> check=delegate(bool value) { if(!value) throw new Exception("Overlay self-test failed at "+checks); checks++; };
            var frame=new Frame {Protocol=1,Width=800,Height=600,Session="test"};
            frame.Items.Add(new Item {Kind="rect",W=30,H=40});
            check(Protocol.Valid(frame)); frame.Protocol=2; check(!Protocol.Valid(frame)); frame.Protocol=1;
            frame.Items[0].X=Double.NaN; check(!Protocol.Valid(frame)); frame.Items[0].X=0;
            frame.Items[0].Kind="execute"; check(!Protocol.Valid(frame)); frame.Items[0].Kind="rect";
            frame.Items[0].Text=new string('x',4097); check(!Protocol.Valid(frame)); frame.Items[0].Text=null;
            check(Protocol.SameToken("test-key","test-key")); check(!Protocol.SameToken("test-key","test-kez")); check(!Protocol.SameToken(null,"test-key"));
            check(Protocol.TrustedImage(new Uri("https://assetdelivery.roblox.com/v1/asset/?id=1")));
            check(Protocol.TrustedImage(new Uri("https://a.rbxcdn.com/image")));
            check(!Protocol.TrustedImage(new Uri("http://a.rbxcdn.com/image")));
            check(!Protocol.TrustedImage(new Uri("https://rbxcdn.com.attacker.example/image")));
            check(!Protocol.TrustedImage(new Uri("https://private@www.roblox.com/image")));
            frame.Width=16385; check(!Protocol.Valid(frame)); frame.Width=800;
            frame.Items[0].StrokeAlpha=Double.PositiveInfinity; check(!Protocol.Valid(frame)); frame.Items[0].StrokeAlpha=0;
            frame.Items[0].W=-1; check(!Protocol.Valid(frame)); frame.Items[0].W=30;
            frame.Items[0].Font=257; check(!Protocol.Valid(frame)); frame.Items[0].Font=14;
            frame.Session=""; check(!Protocol.Valid(frame)); frame.Session="test";
            for(int n=1;n<1601;n++) frame.Items.Add(new Item {Kind="rect"});
            check(!Protocol.Valid(frame)); frame.Items.RemoveRange(1,1600);
            bool received=false,ready=true;
            using(var bridge=new Bridge("private",delegate { return ready; },delegate(Frame f) { received=f!=null; })) {
                Func<string,string,string,string> request=delegate(string method,string path,string token) {
                    using(var client=new TcpClient("127.0.0.1",bridge.Port)) {
                        var stream=client.GetStream(); client.ReceiveTimeout=3000;
                        byte[] body=path=="/clear"?new byte[0]:Encoding.UTF8.GetBytes(new JavaScriptSerializer().Serialize(frame));
                        string text=method+" "+path+" HTTP/1.1\r\nHost: localhost\r\nX-MM2-Token: "+token+"\r\nX-MM2-Session: test\r\nContent-Length: "+(method=="POST"?body.Length:0)+"\r\n\r\n";
                        byte[] header=Encoding.ASCII.GetBytes(text); stream.Write(header,0,header.Length); if(method=="POST") stream.Write(body,0,body.Length);
                        return new StreamReader(stream).ReadToEnd();
                    }
                };
                check(request("GET","/status","wrong").Contains("401")); check(request("GET","/status","private").Contains("\"Ready\":true"));
                check(request("POST","/frame","private").Contains("200") && received); received=false;
                frame.Protocol=0; check(request("POST","/frame","private").Contains("422") && !received);
                check(request("GET","/unknown","private").Contains("404"));
                frame.Protocol=1; ready=false;
                check(request("GET","/status","private").Contains("\"CaptureExcluded\":false"));
                check(request("POST","/frame","private").Contains("503") && !received);
                ready=true;
                check(request("POST","/frame","private").Contains("200") && received);
                check(request("POST","/clear","private").Contains("200") && !received);
                check(request("POST","/frame","private").Contains("409") && !received);
                frame.Session="fresh";
                check(request("POST","/frame","private").Contains("200") && received);
                check(request("GET","/status","private\r\nOrigin: https://example.com").Contains("403"));
                check(request("GET","/status","private\r\nTransfer-Encoding: chunked").Contains("403"));
                check(request("GET","/status","private\r\nContent-Length: 1048577").Contains("400"));
            }
            Console.WriteLine(checks+" Windows overlay protocol assertions passed (no windows opened)"); return 0;
        }
    }
}
