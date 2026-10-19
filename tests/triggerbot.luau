local passed=0
local function check(ok,message) assert(ok,message); passed+=1; print("PASS: "..message) end
local mt={}
local function vec(x) return setmetatable({X=x},mt) end
mt.__sub=function(a,b) return vec(a.X-b.X) end
mt.__index=function(v,k) if k=="Magnitude" then return math.abs(v.X) end end
-- INSERT_TRIGGERBOT
-- INSERT_EMERGENCY
local function fixture()
    local f={Now=10,Attempts=0,Contacts=0,Selections=0,Ready=true,Clear=true,Send=true,OnScreen=true}
    function f.Character(x)
        local c={}; c.HumanoidRootPart={Position=vec(x),Parent=c}; c.Head={Position=vec(x),Parent=c}
        function c:FindFirstChild(key) return self[key] end
        return c
    end
    local own={Name="Own",Character=f.Character(0),Alive=true,Role="Sheriff"}
    local target={Name="Target",Character=f.Character(5),Alive=true,Role="Murderer"}
    local gun={Parent=own.Character,Enabled=true}
    function gun:GetAttribute(key) return self[key] end
    local record={Item=gun,Kind="Gun",Active=true,LastGun=-math.huge,LastStab=-math.huge,LastThrow=-math.huge}
    local State={Running=true,Config={Aim=true,MagicBullet=true,Triggerbot=true,KnifeTriggerbot=true},
        WeaponHandlers={[gun]=record},PendingGun={}}
    State.IsPlayerExcluded=function(p) return p.Excluded==true end
    local UIS={WindowFocusReleased={},WindowFocused={}}
    function UIS:GetMouseLocation() error("trigger must not depend on cursor position") end
    local heartbeat,callbacks={},{}
    local world={CurrentCamera={}}
    local C={State=State,Player=own,UIS=UIS,World=world,Heartbeat=heartbeat,Clock=function() return f.Now end,
        Connect=function(signal,callback) callbacks[signal]=callback end,
        InputBlocked=function() return f.Blocked==true end,Ready=function() return f.Ready end,
        Alive=function(p) return p.Alive end,Role=function(p) return p.Role end,
        Equipped=function() if not f.Unequipped then return gun,record.Kind end end,
        ClearPath=function() return f.Clear end,
        SendGun=function(r,p,strict,onScreenOnly)
            f.Attempts+=1; f.RecordUsed=r; f.Preferred=p; f.Strict=strict; f.ScreenOnly=onScreenOnly
            if f.ThrowError then error("injected failure") end
            if f.Send then r.LastGun=f.Now else State.LastGunFeedback={Message="No clear on-screen shot"} end
            return f.Send
        end,
        ScreenKnifeTarget=function()
            f.Selections+=1
            if f.OnScreen and not f.NoTarget then return f.Target,f.Part or f.Target.Character.Head end
        end,
        StabKnife=function(r,p) f.Attempts+=1; f.SentTarget=p; if f.Send then r.LastStab=f.Now end; return f.Send end,
        ReportContact=function(_,part) f.Contacts+=1; f.ContactPart=part end}
    installTriggerbot(C)
    f.Own,f.Target,f.Gun,f.Record,f.State,f.UIS,f.World,f.Callbacks=own,target,gun,record,State,UIS,world,callbacks
    f.Context=C; f.Bot=State.Triggerbot
    function f.Step(dt) f.Now+=dt or .04; callbacks[heartbeat]() end
    function f.Hold(n) for _=1,n or 5 do f.Step() end end
    function f.EnableKnife() record.Kind="Knife"; own.Role="Murderer"; target.Role="Innocent"; State.SetKnifeTriggerbot(true) end
    return f
end
do
    local f=fixture(); f.Hold()
    check(not f.State.Config.Triggerbot and not f.State.Config.KnifeTriggerbot and f.Attempts==0,"reload resets both triggers")
    f.State.Config.Aim=false; f.State.Config.MagicBullet=false; f.State.SetTriggerbot(true); f.Step()
    check(f.Attempts==0 and not f.State.Config.Aim and not f.State.Config.MagicBullet,"trigger preserves other aim switches")
    f.State.Config.Aim=true; f.Step()
    check(f.Attempts==0 and f.Bot.Status=="Turn on Gun aim","gun trigger waits for gun aim")
    f.State.Config.MagicBullet=true; f.Step(1/60)
    check(f.Attempts==1 and f.Bot.Shots==1 and f.Bot.AimChecks==1,"ready gun reacts on the first active frame")
    check(f.RecordUsed==f.Record and f.Preferred==nil and f.Strict==false and f.ScreenOnly==true,
        "automatic gun always passes the screen-only firing policy")
    f.Step(.1); check(f.Attempts==1,"fast reaction respects the bounded request interval")
    f.State.SetTriggerbot(false); f.State.SetTriggerbot(true); f.Step()
    check(f.Attempts==1,"toggle cannot reset gun cooldown")
    f.Step(.051); check(f.Attempts==2,"gun retries without the old three-second delay")
end
for _,case in ipairs({
    {"menu or text input",function(f) f.Blocked=true end},
    {"inactive round",function(f) f.Own.Alive=false end},
    {"wrong gun role",function(f) f.Own.Role="Murderer" end},
    {"unequipped weapon",function(f) f.Unequipped=true end},
    {"disabled gun",function(f) f.Gun.Enabled=false end},
    {"inactive handler",function(f) f.Record.Active=false end},
    {"missing handler",function(f) f.State.WeaponHandlers={} end},
    {"readiness refusal",function(f) f.Ready=false end},
    {"ownership change",function(f) f.Gun.Parent=f.Target.Character end},
    {"invisibility transition",function(f) f.State.Invis={Active=true,Busy=true} end},
    {"experimental invisibility",function(f) f.State.ExperimentalInvis={Busy=true} end},
    {"fling",function(f) f.State.Fling={Active=true} end},
    {"fling queue",function(f) f.State.FlingQueue={Active=true} end},
    {"selected-player attack",function(f) f.State.PlayerActions={Enabled=true} end},
    {"kill aura",function(f) f.State.KillAura={Enabled=true} end},
    {"recent manual shot",function(f) f.Record.LastGun=f.Now end},
    {"pending feedback",function(f) f.State.PendingGun={{Item=f.Gun,SentAt=f.Now}} end},
    {"gun send in progress",function(f) f.Record.GunSending=true end},
    {"missing camera",function(f) f.World.CurrentCamera=nil end},
}) do
    local f=fixture(); f.State.SetTriggerbot(true); case[2](f); f.Step(.01)
    check(f.Attempts==0,"trigger respects "..case[1])
end
do
    local f=fixture(); f.State.SetTriggerbot(true); f.Send=false; f.Step(1/60)
    check(f.Bot.Shots==0 and f.Bot.LastShot==-math.huge and not f.Bot.LastAimCheck.Sent,"failed check never counts a gun request")
    f.Step(.004); check(f.Attempts==2,"aim is reconsidered on the next heartbeat even below the old 50 ms interval")
    f.Send=true; f.Step(.004)
    check(f.Attempts==3 and f.Bot.Shots==1,"new target fires on the next heartbeat with no artificial wait")
    f=fixture(); f.State.SetTriggerbot(true); f.State.PendingGun={{Item=f.Gun,SentAt=f.Now}}; f.Step(.74)
    check(f.Attempts==0,"unresolved feedback blocks automatic retry after the request interval")
    f.Step(.02)
    check(f.Attempts==1,"unanswered feedback has a bounded timeout instead of stalling three seconds")
    f=fixture(); f.State.SetTriggerbot(true); f.Send=false; f.Step(); f.Blocked=true; f.Step()
    check(f.Bot.BeforePause=="No clear on-screen shot" and f.Bot.LastAimCheck.Message=="No clear on-screen shot","pause preserves last rejection")
    f=fixture(); f.State.SetTriggerbot(true); f.ThrowError=true; f.Step()
    check(not f.State.Config.Triggerbot and f.Bot.Shots==0 and f.Bot.Status:find("injected failure",1,true),"callback failure stops trigger")
end
do
    local f=fixture(); f.EnableKnife(); f.Step(1/60)
    check(f.Attempts==1 and f.Bot.Stabs==1 and f.Contacts==1 and f.ContactPart==f.Target.Character.Head,
        "knife reacts on first frame to visible nearby target without cursor contact")
    check(not f.State.Config.Triggerbot and f.SentTarget==f.Target,"knife mode stays independent")
    f.Hold(10); check(f.Attempts==1,"fast knife acquisition respects cooldown")
    f.Step(.9); check(f.Attempts==2,"knife rechecks fresh target after cooldown")
    f=fixture(); f.EnableKnife(); f.Send=false; f.Step()
    check(f.Bot.Stabs==0 and f.Contacts==0,"failed stab never reports contact")
end
for _,case in ipairs({
    {"offscreen opponent",function(f) f.OnScreen=false end},
    {"no eligible target",function(f) f.NoTarget=true end},
    {"dead target",function(f) f.Target.Alive=false end},
    {"protected target",function(f) f.Target.Excluded=true end},
    {"own target",function(f) f.Target=f.Own end},
    {"other murderer",function(f) f.Target.Role="Murderer" end},
    {"stale body part",function(f) f.Part=f.Target.Character.Head; f.Target.Character=f.Character(5) end},
    {"out of reach",function(f) f.Target.Character.HumanoidRootPart.Position=vec(7) end},
    {"blocked path",function(f) f.Clear=false end},
    {"charging throw",function(f) f.Record.Charging=true end},
    {"released throw",function(f) f.Record.LastThrow=f.Now end},
    {"wrong local role",function(f) f.Own.Role="Sheriff" end},
}) do
    local f=fixture(); f.EnableKnife(); case[2](f); f.Step()
    check(f.Attempts==0 and f.Contacts==0,"knife skips "..case[1])
end
do
    local f=fixture(); f.EnableKnife(); f.OnScreen=false; f.Step(); f.OnScreen=true; f.Step(.06)
    check(f.Attempts==1,"knife reacts on the next heartbeat when target becomes visible")
    f=fixture(); f.EnableKnife(); f.NoTarget=true; f.Step(.5)
    check(f.Attempts==0,"frame stall never fires at a cached knife target")
    f=fixture(); f.State.SetTriggerbot(true); f.Callbacks[f.UIS.WindowFocusReleased](); f.Step()
    check(f.Attempts==0,"unfocused window pauses firing")
    f.Callbacks[f.UIS.WindowFocused](); f.Step()
    check(f.Attempts==1 and f.ScreenOnly,"focus return recalculates screen-only shot")
    f=fixture(); f.Callbacks[f.UIS.WindowFocusReleased](); f.Step()
    check(f.Bot.Status=="Off","disabled trigger stays Off on focus changes")
    f=fixture(); f.State.SetTriggerbot(true); f.State.SetKnifeTriggerbot(true); installEmergencyStop({State=f.State})
    f.State.EmergencyStop(); f.Hold()
    check(not f.State.Config.Triggerbot and not f.State.Config.KnifeTriggerbot and f.Attempts==0,"emergency stop cancels both modes")
    f=fixture(); f.State.SetTriggerbot(true); f.State.Running=false; f.Step()
    check(f.Attempts==0,"unloaded script cannot fire")
end
do
    local f=fixture(); f.Own.Role="Survivor"; f.Target.Role="Zombie"
    f.Context.CanUseWeapon=function(kind) return kind=="Gun" end
    f.State.SetTriggerbot(true); f.Step()
    check(f.Attempts==1,"event gun role uses the shared capability adapter rather than requiring Sheriff")
    f=fixture(); f.EnableKnife();f.Own.Role="Zombie";f.Target.Role="Survivor"
    f.Context.CanUseWeapon=function(kind) return kind=="Knife" end
    f.Context.IsTarget=function(_,p) return p.Role=="Survivor" end
    f.Step()
    check(f.Attempts==1 and f.Contacts==1,"event knife role can stab an eligible opposite team")
    f.Target.Role="Zombie"; f.Step(1)
    check(f.Attempts==1,"conversion prevents a further trigger stab on the new teammate")
    f=fixture();f.Own.Role="Freezer";f.Context.CanUseWeapon=function() return false end
    f.State.SetTriggerbot(true);f.Step()
    check(f.Attempts==0,"capability refusal cannot fall back to an event gun role")
    f=fixture();f.State.Invis={Active=true,Busy=false};f.State.ExperimentalInvis={Active=true,Busy=false}
    f.State.SetTriggerbot(true);f.Step()
    check(f.Attempts==1 and f.State.Invis.Active and f.State.ExperimentalInvis.Active,"stable invisibility uses the ordinary gun trigger path without changing visibility state")
    f=fixture();f.EnableKnife();f.State.Invis={Active=true,Busy=false};f.State.Config.InvisibleKnife=true;f.Step()
    check(f.Attempts==1 and f.State.Invis.Active,"stable invisibility allows an explicitly enabled invisible knife trigger")
    f=fixture();f.EnableKnife();f.State.Invis={Active=true,Busy=false};f.State.Config.InvisibleKnife=false;f.Step()
    check(f.Attempts==0 and f.State.Invis.Active and f.Bot.Status=="Knife while invisible is off","invisible knife preference pauses input without revealing the character")
end
print(passed.." triggerbot assertions passed")
