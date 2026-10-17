local passed=0
local function check(ok,message)
    assert(ok,message)
    passed+=1
    print("PASS: "..message)
end
local vectorMeta={}
local function vec(x,y) return setmetatable({X=x,Y=y or 0},vectorMeta) end
vectorMeta.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y) end
vectorMeta.__div=function(a,b) return vec(a.X/b,a.Y/b) end
vectorMeta.__index=function(a,k) if k=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y) end end
local Enum={RaycastFilterType={Exclude="Exclude"}}
local RaycastParams={new=function() return {} end}
-- INSERT_TRIGGERBOT
-- INSERT_EMERGENCY

local function fixture()
    local f={Now=10,Attempts=0,Contacts=0,Rays=0,Blocked=false,Ready=true,Clear=true,Mode="PC",Locked=false,Send=true}
    local world={}
    local function instance(name,class,parent)
        local obj={Name=name,ClassName=class,Parent=parent,Transparency=0}
        function obj:IsA(kind) return self.ClassName==kind end
        function obj:FindFirstChild(key) return self[key] end
        function obj:GetAttribute(key) return self[key] end
        return obj
    end
    function f.MakePlayer(name,x,role)
        local char=instance(name,"Model",world)
        char.HumanoidRootPart=instance("HumanoidRootPart","BasePart",char)
        char.HumanoidRootPart.Position=vec(x)
        char.Head=instance("Head","BasePart",char)
        char.Head.Position=vec(x)
        local p={Name=name,Character=char,Alive=true,Role=role}
        char.Player=p
        return p
    end
    local own=f.MakePlayer("Own",0,"Sheriff")
    local target=f.MakePlayer("Target",5,"Murderer")
    local gun=instance("Gun","Tool",own.Character)
    gun.Enabled=true
    local record={Item=gun,Active=true,Kind="Gun",LastGun=-math.huge,LastStab=-math.huge,LastThrow=-math.huge}
    local State={Running=true,Config={Triggerbot=true,KnifeTriggerbot=true,Aim=true,MagicBullet=true,MaxRange=1000},
        WeaponHandlers={[gun]=record},PendingGun={}}
    State.IsPlayerExcluded=function(p) return p.Excluded==true end
    local uis={WindowFocusReleased={},WindowFocused={}}
    function uis:GetMouseLocation() return f.Cursor or vec(220,160) end
    local camera={ViewportSize=vec(800,600)}
    function camera:ViewportPointToRay(x,y)
        f.RayPoint=vec(x,y)
        return {Origin=0,Direction=1}
    end
    world.CurrentCamera=camera
    function world:Raycast(_,distance,params)
        f.Rays+=1
        f.Distance=distance
        f.Filter=params.FilterDescendantsInstances
        local part=f.Hit
        if f.Path then
            part=nil
            for _,entry in ipairs(f.Path) do
                if not table.find(params.FilterDescendantsInstances,entry) then part=entry; break end
            end
        end
        return part and {Instance=part} or nil
    end
    f.Own,f.Target,f.Gun,f.Record,f.State,f.UIS,f.World=own,target,gun,record,State,uis,world
    f.Instance=instance
    f.Hit=target.Character.Head
    local callbacks={}
    local heartbeat={}
    f.Callbacks=callbacks
    local C={State=State,Player=own,World=world,UIS=uis,Heartbeat=heartbeat,
        Players={GetPlayerFromCharacter=function(_,char) return char.Player end},
        BodyParts={Head=true},Clock=function() return f.Now end,
        Connect=function(signal,callback) callbacks[signal]=callback end,
        Equipped=function() if not f.Unequipped then return gun,record.Kind end end,
        Alive=function(p) return p.Alive end,Role=function(p) return p.Role end,
        Ready=function() return f.Ready end,InputBlocked=function() return f.Blocked end,
        InputMode=function() return f.Mode end,MouseLocked=function() return f.Locked end,
        GetPassthrough=function() return f.Passthrough or {} end,
        ClearPath=function() return f.Clear end,
        SendGun=function(r,p,strict)
            f.Attempts+=1; f.SentTarget=p; f.Strict=strict
            if f.ThrowError then error("injected failure") end
            if f.Send then r.LastGun=f.Now else State.LastGunFeedback={Message="No timing-safe solution"} end
            return f.Send
        end,
        StabKnife=function(r,p) f.Attempts+=1; f.SentTarget=p; if f.Send then r.LastStab=f.Now end; return f.Send end,
        ReportContact=function(_,part) f.Contacts+=1; f.ContactPart=part end}
    installTriggerbot(C)
    f.Bot=State.Triggerbot
    function f.Step(dt) f.Now+=dt or .04; callbacks[heartbeat]() end
    function f.Hold(count) for _=1,count or 5 do f.Step(.04) end end
    function f.EnableKnife()
        record.Kind="Knife"; own.Role="Murderer"; target.Role="Innocent"
        State.SetKnifeTriggerbot(true)
    end
    return f
end

do
    local f=fixture()
    f.Hold()
    check(not f.State.Config.Triggerbot and not f.State.Config.KnifeTriggerbot and f.Attempts==0 and f.Rays==0,
        "reload resets saved trigger settings and does no disabled raycasts")
    f.State.Config.Aim=false; f.State.Config.MagicBullet=false
    f.State.SetTriggerbot(true)
    check(not f.State.Config.Aim and not f.State.Config.MagicBullet and not f.State.Config.KnifeTriggerbot,
        "enabling gun trigger never changes aim or knife settings")
    f.Hold()
    check(f.Attempts==0 and f.Bot.Status=="Turn on Aim assist","master aim off blocks trigger")
    f.State.Config.Aim=true; f.Hold()
    check(f.Attempts==0 and f.Bot.Status=="Turn on Gun aim","gun aim off blocks gun trigger")
    f.State.Config.MagicBullet=true
    f.Step()
    check(f.Attempts==0 and f.Bot.Active,"first body sample arms but does not fire")
    f.Hold(3)
    check(f.Attempts==1 and f.Bot.Shots==1 and f.SentTarget==f.Target and f.Strict==true,
        "steady murderer body hit sends once with strict target and honest counter")
    check(f.RayPoint.X==220 and f.RayPoint.Y==160,"cursor coordinates use viewport without a GUI inset offset")
    f.Hold(20)
    check(f.Attempts==1,"gun cannot spam while the crosshair stays on target")
    f.State.SetTriggerbot(false); f.State.SetTriggerbot(true); f.Hold()
    check(f.Attempts==1,"toggling cannot bypass the shot cooldown")
    f.Step(3); f.Hold(3)
    check(f.Attempts==2,"gun can fire again after cooldown and fresh acquisition")
end

for _,case in ipairs({
    {"menu/chat/input suppression",function(f) f.Blocked=true end},
    {"local death or inactive round",function(f) f.Own.Alive=false end},
    {"target death",function(f) f.Target.Alive=false end},
    {"protected target",function(f) f.Target.Excluded=true end},
    {"innocent crosshair target",function(f) f.Target.Role="Innocent" end},
    {"unknown crosshair role",function(f) f.Target.Role="Unknown" end},
    {"own murderer role with gun",function(f) f.Own.Role="Murderer" end},
    {"unequipped gun",function(f) f.Unequipped=true end},
    {"tool disabled",function(f) f.Gun.Enabled=false end},
    {"inactive handler",function(f) f.Record.Active=false end},
    {"readiness refusal",function(f) f.Ready=false end},
    {"weapon ownership change",function(f) f.Gun.Parent=f.Target.Character end},
    {"missing handler",function(f) f.State.WeaponHandlers={} end},
    {"invisibility",function(f) f.State.Invis={Active=true} end},
    {"experimental invisibility",function(f) f.State.ExperimentalInvis={Busy=true} end},
    {"fling",function(f) f.State.Fling={Active=true} end},
    {"queued fling",function(f) f.State.FlingQueue={Active=true} end},
    {"selected-player auto attack",function(f) f.State.PlayerActions={Enabled=true} end},
    {"kill aura",function(f) f.State.KillAura={Enabled=true} end},
    {"recent manual shot",function(f) f.Record.LastGun=f.Now end},
    {"pending reply",function(f) f.State.PendingGun={{Item=f.Gun,SentAt=f.Now}} end},
    {"in-progress gun send",function(f) f.Record.GunSending=true end},
    {"missing camera",function(f) f.World.CurrentCamera=nil end},
    {"cursor outside viewport",function(f) f.Cursor=vec(-1,60) end},
    {"touch without mouse lock",function(f) f.Mode="Mobile" end},
    {"empty crosshair",function(f) f.Hit=nil end},
    {"own body",function(f) f.Hit=f.Own.Character.Head end},
    {"visible wall",function(f) f.Hit=f.Instance("Wall","BasePart",f.World) end},
    {"avatar hat",function(f)
        f.Hit=f.Instance("Handle","BasePart",f.Instance("Hat","Accessory",f.Target.Character))
    end},
}) do
    local f=fixture(); f.State.SetTriggerbot(true); case[2](f); f.Hold()
    check(f.Attempts==0,"trigger refuses "..case[1])
end

do
    local f=fixture(); f.State.SetTriggerbot(true); f.State.Config.ConservativeGun=false
    f.Send=false; f.Hold()
    check(f.Attempts==1 and f.Bot.Shots==0 and f.Bot.LastShot==-math.huge and f.Bot.Status=="No timing-safe solution",
        "rejected shot preserves counter and exposes actual reason")
    f.Hold(4)
    check(f.Attempts==1,"failed predictions are throttled")
    f.Step(.2)
    check(f.Attempts==2,"failed prediction can retry without consuming a gun cooldown")
    check(f.State.Config.ConservativeGun==false,"trigger preserves conservative mode preference")
    f.Blocked=true; f.Hold(2)
    check(f.Bot.BeforePause=="No timing-safe solution","opening menu preserves the actual reason for a skipped shot")
end

do
    local f=fixture(); f.State.SetTriggerbot(true); f.Step()
    f.Hit=nil; f.Step(); f.Hit=f.Target.Character.Head; f.Hold(2)
    check(f.Attempts==0,"loss of crosshair target cancels acquisition")
    f.Hold(2)
    check(f.Attempts==1,"reacquired target must remain under crosshair again")
    f=fixture(); f.State.SetTriggerbot(true); f.Step(); f.Step(.5)
    check(f.Attempts==0,"slow frame cannot fire on a stale acquisition")
    f.Hold(3); check(f.Attempts==1,"fresh samples after frame stall can fire")
    f=fixture(); f.State.SetTriggerbot(true); f.Step()
    local replacement=f.MakePlayer("Replacement",5,"Murderer")
    f.Target.Character=replacement.Character; f.Target.Character.Player=f.Target; f.Hit=f.Target.Character.Head
    f.Hold(2); check(f.Attempts==0,"target respawn resets acquisition")
    f.Hold(2); check(f.Attempts==1,"new target character needs fresh dwell")
end

do
    local f=fixture(); f.State.SetTriggerbot(true); f.Step()
    f.Callbacks[f.UIS.WindowFocusReleased](); f.Hold()
    check(f.Attempts==0,"window focus loss prevents shots and cancels acquisition")
    f.Callbacks[f.UIS.WindowFocused](); f.Step()
    check(f.Attempts==0,"restoring focus requires fresh acquisition")
    f.Hold(3); check(f.Attempts==1,"focused window resumes after dwell")
    f=fixture(); f.State.SetTriggerbot(true); f.Step()
    local rays=f.Rays
    f.Step(.001); f.Step(.001)
    check(f.Rays==rays,"raycasts are capped at 30 Hz")
    f=fixture(); f.State.SetTriggerbot(true); f.ThrowError=true; f.Hold()
    check(not f.State.Config.Triggerbot and f.Bot.Shots==0 and f.Bot.Status:find("injected failure",1,true),
        "callback failure disables trigger and reports error without false shot count")
    f=fixture(); f.Callbacks[f.UIS.WindowFocusReleased](); f.Hold()
    check(f.Bot.Status=="Off","disabled trigger still reads Off after window focus loss")
    f.Callbacks[f.UIS.WindowFocused](); f.Hold()
    check(f.Bot.Status=="Off","disabled trigger stays Off when focus returns")
end

do
    local f=fixture(); f.State.SetTriggerbot(true); f.Mode="Mobile"; f.Locked=true; f.Hold()
    check(f.Attempts==1 and f.RayPoint.X==400 and f.RayPoint.Y==300,"touch mouse lock uses the native center crosshair")
    f=fixture(); f.State.SetTriggerbot(true)
    local transparent=f.Instance("Effect","BasePart",f.World); transparent.Transparency=1
    f.Path={transparent,f.Target.Character.Head}; f.Hold()
    check(f.Attempts==1 and table.find(f.Filter,transparent),"transparent effects are skipped like native aiming")
    f=fixture(); f.State.SetTriggerbot(true)
    local passthrough=f.Instance("Passthrough","BasePart",f.World)
    f.Passthrough={passthrough}; f.Path={passthrough,f.Target.Character.Head}; f.Hold()
    check(f.Attempts==1 and table.find(f.Filter,passthrough),"weapon passthrough tags are respected")
    f=fixture(); f.State.SetTriggerbot(true); f.Path={}
    for i=1,9 do local part=f.Instance("Effect"..i,"BasePart",f.World); part.Transparency=1; table.insert(f.Path,part) end
    table.insert(f.Path,f.Target.Character.Head); f.Step()
    check(f.Rays==8 and f.Attempts==0,"transparency traversal is bounded and fails closed")
end

do
    local f=fixture(); f.EnableKnife()
    check(not f.State.Config.Triggerbot,"knife toggle is independent of gun toggle")
    f.Hold()
    check(f.Bot.Stabs==1 and f.Bot.Shots==0 and f.Contacts==1 and f.ContactPart==f.Target.Character.Head and f.SentTarget==f.Target,
        "knife swings only at aimed nearby opponent and reports that body part")
    f.Hold(10); check(f.Attempts==1,"knife respects native stab cooldown")
    f.Step(.9); f.Hold(3); check(f.Attempts==2,"knife resumes after cooldown and fresh dwell")
    f=fixture(); f.EnableKnife(); f.Send=false; f.Hold()
    check(f.Attempts==1 and f.Bot.Stabs==0 and f.Contacts==0,"rejected stab does not report contact or increment requests")
end

for _,case in ipairs({
    {"out-of-range opponent despite extended aura preference",function(f)
        f.State.Config.AuraExtendedReach=true; f.Target.Character.HumanoidRootPart.Position=vec(7)
    end},
    {"knife path obstruction",function(f) f.Clear=false end},
    {"charging throw",function(f) f.Record.Charging=true end},
    {"released throw cooldown",function(f) f.Record.LastThrow=f.Now; f.Gun.ThrowSpeed=2 end},
    {"other murderer",function(f) f.Target.Role="Murderer" end},
    {"non-murderer local role",function(f) f.Own.Role="Innocent" end},
}) do
    local f=fixture(); f.EnableKnife(); case[2](f); f.Hold()
    check(f.Attempts==0 and f.Contacts==0,"knife trigger refuses "..case[1])
end

do
    local f=fixture(); f.State.SetTriggerbot(true); f.State.SetKnifeTriggerbot(true)
    installEmergencyStop({State=f.State})
    check(f.State.EmergencyStop() and not f.State.Config.Triggerbot and not f.State.Config.KnifeTriggerbot,
        "real emergency stop disables both trigger modes")
    f.Hold(); check(f.Attempts==0 and f.Rays==0,"emergency stop leaves no queued shot")
    f=fixture(); f.State.SetTriggerbot(true); f.Step(); f.State.Running=false; f.Hold()
    check(f.Attempts==0 and not f.Bot.Active,"unloaded state cannot finish an armed shot")
end
print(passed.." triggerbot assertions passed")
