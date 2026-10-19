local passed=0
local function check(value,message)
    assert(value,message); passed+=1
end
-- INSERT_CONTROLLER
-- INSERT_SURFACES

local function controller()
    local h={Now=0,Entered=0,Left=0,Queue={},Sent={},Ready={Protocol=1,Ready=true,CaptureExcluded=true},Ack={Accepted=true},Snapshot={Width=800,Height=600,Items={}},LeaveOK=true}
    local State={Running=true,Config={StreamerMode=true}}
    h.State=State
    local C={State=State,Clock=function() return h.Now end,Session=function() return "instance" end,
        Enter=function() h.Entered+=1; if h.EnterError then error("denied") end; return h.EnterOK end,
        Leave=function() h.Left+=1; return h.LeaveOK end,
        Snapshot=function() if h.SnapshotError then error("bad snapshot") end; return h.Snapshot end,
        Send=function(path,data,id)
            table.insert(h.Sent,{Path=path,Data=data,Session=id})
            if h.Hook then h.Hook(path,data,id) end
            if h.SendError then error("offline") end
            if path=="/status" then return h.ReadyOK~=false,h.Ready end
            return h.FrameOK~=false,h.Ack
        end,
        Spawn=function(callback) table.insert(h.Queue,callback) end,
        Tick=function(callback) h.Tick=callback end,
        Changed=function(on) h.Changed=on end}
    installStreamerMode(C)
    function h.Flush() local queue=h.Queue; h.Queue={}; for _,callback in ipairs(queue) do callback() end end
    return h,State
end
do
    local h,s=controller()
    check(not s.Config.StreamerMode and not s.StreamerActive,"startup never restores saved streamer activation")
    for _,ready in ipairs({{}, {Protocol=1,Ready=true,CaptureExcluded=false},{Protocol=2,Ready=true,CaptureExcluded=true},{Protocol=1,Ready=false,CaptureExcluded=true},{Protocol=1,Ready=1,CaptureExcluded=1}}) do
        h.Ready=ready
        check(s.SetStreamerMode(true)==false and h.Entered==0,"incomplete or unsupported handshake never changes UI")
    end
    h.SendError=true
    check(not s.SetStreamerMode(true) and h.Entered==0,"HTTP error cannot hide UI")
    s.Running=false
    check(not s.SetStreamerMode(true),"unloaded activation refused")
end
do
    local h,s=controller()
    check(s.SetStreamerMode(true) and s.Config.StreamerMode and s.StreamerActive and h.Entered==1,"authenticated accepted first frame enables mode")
    check(h.Sent[2].Data.Protocol==1 and h.Sent[2].Data.Session=="instance:1","first frame carries isolated protocol/session")
    check(h.Changed==true and s.Streamer.Frames==1,"success refreshes controls and counts first accepted frame")
    check(s.SetStreamerMode(true) and h.Entered==1,"duplicate activation does not hide twice")
    local snapshot=s.GetStreamerSnapshot()
    check(snapshot.RecordingVerified==false and snapshot.NativeHidden and not snapshot.Token and not snapshot.Session,"support snapshot does not expose token or claim recording verification")
    snapshot.Frames=99
    check(s.Streamer.Frames==1,"support snapshot is independent")
    h.Tick(); check(#h.Queue==0,"frame limit holds until due")
    h.Now=.06; h.Tick(); h.Tick()
    check(#h.Queue==1,"only one frame request may be in flight")
    h.FrameOK=false; h.Flush()
    check(s.Streamer.Failures==1 and s.StreamerActive and s.Config.StreamerMode and h.Left==0,"disconnect keeps native UI hidden")
    h.Now=.3; h.Tick(); check(#h.Queue==0,"failure backoff prevents a request storm")
    h.FrameOK=true; h.Now=.7; h.Tick(); h.Flush()
    check(s.Streamer.Frames==2 and s.Streamer.Failures==1,"transport recovers without revealing UI")
    check(s.StopStreamerMode() and not s.StreamerActive and not s.Config.StreamerMode and h.Left==1,"explicit stop restores native UI")
    h.Flush()
    check(h.Sent[#h.Sent].Path=="/clear" and h.Sent[#h.Sent].Session=="instance:1","stop clears only its session")
end
do
    for _,failure in ipairs({"EnterError","SnapshotError","FrameOK"}) do
        local h,s=controller()
        h[failure]=failure~="FrameOK"
        check(not s.SetStreamerMode(true) and not s.Config.StreamerMode and h.Left==1,"failed activation rolls back native presentation: "..failure)
        h.Flush(); check(h.Sent[#h.Sent].Path=="/clear","failed activation tombstones its pending frames")
    end
    local h,s=controller(); h.Ack={Accepted=1}
    check(not s.SetStreamerMode(true),"first-frame acknowledgment must be a true boolean")
    for _,bad in ipairs({{Width=0,Height=600,Items={}},{Width=800,Height=math.huge,Items={}},{Width=0/0,Height=600,Items={}},{Width=800,Height=600,Items=table.create(1601,{})}}) do
        local x,y=controller(); x.Snapshot=bad
        check(not y.SetStreamerMode(true) and x.Left==1,"invalid or over-limit snapshot rolls back")
    end
end
do
    local h,s=controller(); check(s.SetStreamerMode(true),"setup restoration retry")
    h.LeaveOK=false
    check(not s.SetStreamerMode(false) and s.Config.StreamerMode and s.StreamerActive,"failed restoration preserves hidden state for retry")
    check(not s.SetStreamerMode(true) and h.Entered==1,"reconnect refused until restoration completes")
    h.LeaveOK=true
    check(s.SetStreamerMode(false) and not s.Config.StreamerMode,"restoration can be retried")
end
do
    local h,s=controller()
    h.Hook=function(path)
        if path=="/status" then
            h.Hook=nil; s.SetStreamerMode(false)
        end
    end
    check(not s.SetStreamerMode(true) and h.Entered==0 and not s.Streamer.Pending,"stop cancels an in-progress handshake")
    h,s=controller()
    h.Hook=function(path)
        if path=="/frame" then
            check(not s.SetStreamerMode(true),"first-frame handshake remains pending during a concurrent activation")
            h.Hook=nil; s.SetStreamerMode(false)
        end
    end
    check(not s.SetStreamerMode(true) and not s.Config.StreamerMode and h.Left==1,"stop while first frame is pending cannot reactivate mode")
    h,s=controller(); s.SetStreamerMode(true)
    h.Now=1; h.Tick(); s.SetStreamerMode(false); h.Flush()
    check(s.Streamer.Frames==1 and not s.Config.StreamerMode,"late frame reply cannot revive a stopped session")
    h,s=controller(); s.SetStreamerMode(true)
    h.Now=1; h.Tick(); s.Running=false; h.Flush()
    check(s.Streamer.Frames==1,"late reply cannot mutate unloaded counters")
    h,s=controller(); s.SetStreamerMode(true); h.SnapshotError=true; h.Now=1; h.Tick()
    check(s.Streamer.Failures==1 and s.StreamerActive and #h.Queue==0,"snapshot failure stays hidden without a malformed send")
end

local function signal()
    local listeners={}
    return {Connect=function(_,callback)
        local c={Connected=true}; table.insert(listeners,{c,callback})
        function c:Disconnect() self.Connected=false end
        return c
    end,Fire=function(_,...) for _,pair in ipairs(listeners) do if pair[1].Connected then pair[2](...) end end end}
end
local function object(class,properties)
    local values=properties or {}; local signals={}; local methods={}
    values.ClassName=class; values.DescendantAdded=signal(); values.Destroying=signal(); values.Children=values.Children or {}
    function methods:IsA(name)
        return class==name or name=="GuiObject" and (class=="TextLabel" or class=="ImageButton" or class=="ScrollingFrame" or class=="ViewportFrame")
    end
    function methods:GetPropertyChangedSignal(key) signals[key]=signals[key] or signal(); return signals[key] end
    function methods:GetDescendants() return values.Children end
    return setmetatable({}, {__index=function(_,key) return methods[key] or values[key] end,
        __newindex=function(self,key,value)
            if values.Refuse==key then error("denied property") end
            if values[key]~=value then values[key]=value; if signals[key] then signals[key]:Fire() end end
        end})
end
local function surfaceHarness()
    local label=object("TextLabel",{BackgroundTransparency=.2,BorderSizePixel=2,TextTransparency=.3,TextStrokeTransparency=.4,Visible=true,Active=true})
    local image=object("ImageButton",{BackgroundTransparency=1,BorderSizePixel=0,ImageTransparency=.1,Visible=true})
    local scroll=object("ScrollingFrame",{BackgroundTransparency=.7,BorderSizePixel=0,ScrollBarImageTransparency=.2})
    local root=object("ScreenGui",{Children={label,image,scroll},Enabled=true})
    local mouse=object("UserInputService",{MouseIconEnabled=true})
    local h={Label=label,Image=image,Scroll=scroll,Root=root,Mouse=mouse,Failures=0}
    h.Surfaces=createStreamerSurfaces({Roots=function() return {root} end,UIS=mouse,
        Visuals=function(hidden) h.Hidden=hidden end,Failed=function() h.Failures+=1 end})
    return h,h.Surfaces
end
do
    local h,s=surfaceHarness()
    check(s.Enter() and h.Label.BackgroundTransparency==1 and h.Label.TextTransparency==1,"surface hides text and fill")
    check(h.Label.TextStrokeTransparency==1 and h.Label.BorderSizePixel==0,"surface hides text outlines and borders")
    check(h.Image.ImageTransparency==1 and h.Scroll.ScrollBarImageTransparency==1 and not h.Mouse.MouseIconEnabled,"surface hides images, scrollbars and native cursor")
    check(h.Label.Visible and h.Label.Active and h.Root.Enabled,"native visibility and input hitboxes remain available")
    check(s.Read(h.Label,"TextTransparency")==.3 and s.Read(h.Label,"Visible"),"mirror reads original presentation")
    h.Label.TextTransparency=.65
    check(h.Label.TextTransparency==1 and s.Read(h.Label,"TextTransparency")==.65,"live presentation changes stay hidden and update the mirror")
    local added=object("ViewportFrame",{BackgroundTransparency=0,BorderSizePixel=0,ImageTransparency=0})
    h.Root.DescendantAdded:Fire(added)
    check(added.ImageTransparency==1,"new viewport surfaces are suppressed")
    check(s.Leave() and h.Label.TextTransparency==.65 and h.Label.BackgroundTransparency==.2,"stop restores latest observed text state and original fill")
    check(h.Mouse.MouseIconEnabled and h.Image.ImageTransparency==.1 and added.ImageTransparency==0 and h.Hidden==false,"stop restores cursor/images/new surfaces")
    h.Label.TextTransparency=.8
    check(h.Label.TextTransparency==.8,"disconnected observer no longer suppresses changes")
    check(s.Leave(),"repeat cleanup is harmless")
end
do
    local h,s=surfaceHarness(); s.Enter(); h.Label.Refuse="TextTransparency"
    check(not s.Leave() and h.Label.TextTransparency==1,"failed property restore stays tracked")
    h.Label.Refuse=nil
    check(s.Leave() and h.Label.TextTransparency==.3,"failed property restore succeeds on retry")
    h,s=surfaceHarness(); s.Enter()
    local denied=object("ImageButton",{BackgroundTransparency=0,BorderSizePixel=0,ImageTransparency=0,Refuse="ImageTransparency"})
    h.Root.DescendantAdded:Fire(denied)
    check(h.Failures==1,"new inaccessible surface reports incomplete coverage")
    check(s.Leave(),"partially hidden new surface can still be cleaned up")
    h,s=surfaceHarness(); s.Enter(); h.Label.Destroying:Fire(); h.Label.Refuse="TextTransparency"
    check(s.Leave(),"destroyed widgets release restoration tracking and cannot block cleanup")
end
print(string.format("%d streamer assertions passed",passed))
