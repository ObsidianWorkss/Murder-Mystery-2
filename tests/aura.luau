local passed=0
local function check(ok,message) assert(ok,message); passed+=1; print("PASS: "..message) end
local vectorMeta={}
local function vec(x) return setmetatable({X=x},vectorMeta) end
vectorMeta.__sub=function(a,b) return vec(a.X-b.X) end
vectorMeta.__index=function(v,k) if k=="Magnitude" then return math.abs(v.X) end end
-- INSERT_AURA

local function fixture()
    local f={Now=10,Equipped=true,Ready=true,Blocked={},Callbacks={},EquipCount=0,Cancels=0}
    local os={clock=function() return f.Now end}
    local function node(name,class,parent)
        local n={Name=name,ClassName=class,Parent=parent,Transparency=0}
        function n:IsA(kind) return self.ClassName==kind end
        function n:FindFirstChild(name) return self[name] end
        function n:FindFirstChildOfClass(kind) return kind=="Humanoid" and self.Humanoid end
        function n:IsDescendantOf(parent)
            local current=self.Parent
            while current do if current==parent then return true end; current=current.Parent end
            return false
        end
        function n:GetAttribute(key) return self[key] end
        return n
    end
    function f.Character(x)
        local char=node("Character","Model")
        char.Humanoid={Health=100}
        for _,name in ipairs({"HumanoidRootPart","UpperTorso","Head"}) do
            char[name]=node(name,"BasePart",char); char[name].Position=vec(x)
        end
        return char
    end
    local player={Name="Own",UserId=1,Character=f.Character(0),Role="Murderer",Alive=true,CharacterRemoving={}}
    local target={Name="Target",UserId=2,Character=f.Character(5),Role="Innocent",Alive=true}
    local knife=node("Knife","Tool",player.Character); knife.Enabled=true
    local record={Item=knife,Active=true,LastStab=-math.huge,LastThrow=-math.huge,StabbingUntil=0}
    local State={Running=true,Config={Aim=true,AuraExtendedReach=false,AuraEquipKnife=true,KillAuraRange=6},
        WeaponHandlers={[knife]=record},Stats={StabRequests=0,StabContactReports=0},
        IsPlayerExcluded=function(p) return p.Excluded==true end}
    f.Players={player,target}
    local Players={GetPlayers=function() return f.Players end}
    local bodyPartSet={UpperTorso=true,Head=true,Torso=true,LowerTorso=true}
    knife.Events=node("Events","Folder",knife)
    knife.Events.HandleTouched=node("HandleTouched","RemoteEvent",knife.Events)
    function knife.Events.HandleTouched:FireServer(part)
        f.ContactPart=part
        if f.ContactFail then error("contact send failed") end
    end
    local function roleFor(p) return p.Role end
    local function alive(p) return p.Alive and p.Character and p.Character.Humanoid.Health>0 end
    local function ready(r) return f.Ready and r and r.Active and r.Item.Parent==player.Character and r.Item.Enabled end
    local function clearPath(_,point) return not f.BlockAll and not f.Blocked[point] end
    local function stabKnife(r,p)
        if f.SwingFail then return false end
        r.LastStab=f.Now; r.StabbingUntil=f.Now+.85; r.StabTarget=p; r.AuraStab=false
        r.StabContacts={}; r.StabContactFailures={}
        State.Stats.StabRequests+=1
        return true
    end
    -- INSERT_AURA_CONTACT
    -- INSERT_AURA_READY
    -- INSERT_AURA_STAB
    f.Player,f.Target,f.Knife,f.Record,f.State=player,target,knife,record,State
    local UIS={WindowFocusReleased={},WindowFocused={}}
    local heartbeat={}
    local C={State=State,Player=player,Players={GetPlayers=function() return f.Players end},UIS=UIS,
        RunService={Heartbeat=heartbeat},Clock=function() return f.Now end,
        Connect=function(signal,callback) f.Callbacks[signal]=callback end,
        RoleFor=roleFor,IsAlive=alive,ClearPath=clearPath,
        InputBlocked=function() return f.InputBlocked==true end,
        EquippedWeapon=function() if f.Equipped then return knife,"Knife" end end,
        CanStab=auraKnifeReady,Stab=auraStab,
        Prepare=function() if f.PrepareFail then error("prepare failed") end end,
        EquipKnife=function()
            f.EquipCount+=1
            if not f.EquipFail then f.Equipped=true; knife.Parent=player.Character end
        end,
        CancelStab=function()
            f.Cancels+=1
            if f.CancelFail then return false,"cleanup failed" end
            if record.AuraStab then record.AuraStab=false; record.StabbingUntil=0 end
            return true
        end}
    f.Aura=installKillAura(C); f.UIS=UIS
    function f.Step(dt) f.Now+=dt or .1; f.Callbacks[heartbeat](dt or .1) end
    function f.Enable() return State.SetKillAura(true) end
    return f
end

do
    local f=fixture(); f.Step()
    check(not f.Aura.Enabled and f.State.Stats.StabRequests==0,"aura starts off")
    check(f.Enable() and f.Aura.Enabled,"aura can be enabled")
    f.Step()
    check(f.Aura.Attempts==1 and f.Aura.Contacts==1 and f.State.Stats.StabContactReports==1,
        "normal aura reports target contact without a physical touch event")
    check(f.State.LastStabContact.Source=="AuraStabAssist" and f.ContactPart==f.Target.Character.UpperTorso,
        "normal aura reports the selected body part after its swing")
    check(f.Aura.LastDistance==5 and f.Aura.Status:find("damage unconfirmed",1,true),
        "aura reports distance and distinguishes contact requests from damage")
    f.Step(.4); check(f.Aura.Attempts==1,"aura respects stab cooldown")
    f.Step(.5); check(f.Aura.Attempts==2,"aura resumes after stab cooldown")
    check(f.State.StopKillAura() and not f.Aura.Enabled,"explicit stop disables aura")
    f.Step(1); check(f.Aura.Attempts==2,"stopped aura sends no later swing")
end

do
    local f=fixture(); f.Target.Character=f.Character(20); f.Enable(); f.Step()
    check(f.Aura.Attempts==0,"normal aura excludes targets beyond normal range")
    f.State.SetAuraExtendedReach(true); f.Step()
    check(f.Aura.Attempts==1 and f.Aura.Contacts==1 and f.State.LastStabContact.Source=="AuraReachAttempt",
        "extended aura attempts body contact at the configured extended range")
    check(f.State.GetKillAuraRange()==60 and f.Aura.LastDistance==20,"extended range defaults to the larger 60-stud attempt radius")
    f.State.SetAuraReachRange(10); f.Step(1)
    check(f.Aura.Attempts==1,"reducing extended range excludes the previous target")
    f.State.SetAuraExtendedReach(false)
    check(f.State.GetKillAuraRange()==6,"disabling reach restores the normal radius")
    check(f.State.SetAuraReachRange(200) and f.State.GetKillAuraRange()==6,"extended reach setting accepts 200 without changing the disabled normal radius")
    check(not f.State.SetAuraReachRange(201) and not f.State.SetKillAuraRange(7),"invalid aura ranges are refused")
    local before=f.Cancels; f.State.SetKillAuraRange(4)
    check(f.Cancels>before,"normal range changes cancel outstanding aura contacts")
end

do
    local f=fixture(); f.Blocked[f.Target.Character.HumanoidRootPart.Position]=true; f.Enable(); f.Step()
    check(f.Aura.Contacts==1,"blocked root center does not discard a clear body part")
    f=fixture(); f.Blocked[f.Target.Character.UpperTorso.Position]=true; f.Enable(); f.Step()
    check(f.Aura.Contacts==1 and f.ContactPart==f.Target.Character.Head,"aura selects a clear head when the torso is blocked")
    f=fixture(); f.BlockAll=true; f.Enable(); f.Step()
    check(f.Aura.Attempts==0,"fully obstructed targets are skipped")
    f=fixture(); local near=f.Target; local far={Name="Far",UserId=3,Character=f.Character(6),Alive=true}
    table.insert(f.Players,far); near.Excluded=true; f.Enable(); f.Step()
    check(f.Record.StabTarget==far,"protected nearer target is skipped for a clear eligible target")
end

do
    local f=fixture(); f.Equipped=false; f.Knife.Parent={}; f.Enable(); f.Step()
    check(f.EquipCount==1 and f.Aura.Contacts==1,"aura equips a backpack knife before swinging")
    f=fixture(); f.Equipped=false; f.State.Config.AuraEquipKnife=false; f.Enable(); f.Step()
    check(f.EquipCount==0 and f.Aura.Attempts==0,"automatic equip can be disabled")
    f=fixture(); f.Equipped=false; f.EquipFail=true; f.Enable(); f.Step(); f.Step(.2)
    check(f.EquipCount==1 and f.Aura.Attempts==0,"failed equipping is throttled and never counts a swing")
end

do
    local f=fixture(); f.Player.Role="Innocent"; f.Enable(); f.Step()
    check(f.Aura.Enabled and f.Aura.Attempts==0,"enabled aura waits through innocent rounds")
    f.Callbacks[f.Player.CharacterRemoving](); f.Player.Character=nil; f.Step()
    check(f.Aura.Enabled and f.State.Config.KillAura and f.Aura.Attempts==0,"character removal pauses aura instead of switching it off")
    f.Player.Character=f.Character(0); f.Knife.Parent=f.Player.Character; f.Player.Role="Murderer"
    f.Step(); f.Step()
    check(f.Aura.Contacts==1 and f.Aura.Character==f.Player.Character,"aura resumes on the new murderer character")
    f=fixture(); f.Enable(); f.Player.Character.Humanoid.Health=0; f.Step()
    check(f.Aura.Enabled and f.Aura.Attempts==0,"death waits for respawn without losing the enabled setting")
    f.Player.Character=f.Character(0); f.Knife.Parent=f.Player.Character; f.Step(); f.Step()
    check(f.Aura.Contacts==1,"a replacement character recovers after a dead humanoid")
end

for _,case in ipairs({
    {"menu and text input",function(f) f.InputBlocked=true end},
    {"master aim off",function(f) f.State.Config.Aim=false end},
    {"fling",function(f) f.State.Fling={Active=true} end},
    {"invisibility preparation",function(f) f.State.Invis={Busy=true} end},
    {"no invisible knife permission",function(f) f.State.Invis={Active=true}; f.State.Config.InvisibleKnife=false end},
    {"dead target",function(f) f.Target.Alive=false end},
    {"protected target",function(f) f.Target.Excluded=true end},
    {"disabled knife",function(f) f.Knife.Enabled=false end},
    {"charging throw",function(f) f.Record.Charging=true end},
    {"released throw cooldown",function(f) f.Record.LastThrow=f.Now end},
    {"handler not ready",function(f) f.Ready=false end},
}) do
    local f=fixture(); f.Enable(); case[2](f); f.Step()
    check(f.Aura.Attempts==0,"aura pauses or skips for "..case[1])
end

do
    local f=fixture(); f.Enable(); f.Callbacks[f.UIS.WindowFocusReleased](); f.Step()
    check(f.Aura.Attempts==0,"background window prevents aura contact")
    f.Callbacks[f.UIS.WindowFocused](); f.Step()
    check(f.Aura.Contacts==1,"window focus restores aura readiness")
    f=fixture(); f.SwingFail=true; f.Enable(); f.Step()
    check(f.Aura.Attempts==0 and f.State.Stats.StabContactReports==0,"failed swing never reports contact")
    f=fixture(); f.ContactFail=true; f.Enable(); f.Step()
    check(f.Aura.Attempts==1 and f.Aura.Contacts==0 and f.Aura.Status:find("contact report unavailable",1,true),
        "failed contact is distinguished from a successful swing")
    f=fixture(); f.CancelFail=true; f.Enable(); f.InputBlocked=true; f.Step()
    check(not f.Aura.Enabled and f.Aura.Status:find("cleanup",1,true),"cleanup failure stops aura")
    f=fixture(); f.PrepareFail=true
    check(not f.Enable() and not f.Aura.Enabled,"initialization failure leaves aura disabled")
    f=fixture(); f.Record.LastThrow=f.Now; f.Knife.ThrowSpeed=0/0; f.Enable(); f.Step()
    check(f.Aura.Attempts==0,"invalid throw-speed attribute cannot bypass throw cooldown")
end
do
    local f=fixture()
    local second={Name="Second",UserId=3,Character=f.Character(6),Role="Innocent",Alive=true}
    table.insert(f.Players,second)
    check(f.State.StartKillAll() and f.State.KillAll.Active and f.State.KillAll.Total==2,"Kill all snapshots eligible players for one pass")
    check(not f.State.StartKillAll(),"a second Kill all cannot duplicate an active queue")
    f.Step()
    check(f.Record.StabTarget==f.Target and f.State.KillAll.Contacts==1,"Kill all sends one contact to the first player")
    f.Step(.4)
    check(f.State.KillAll.Index==2 and f.State.KillAll.Attempts==1,"Kill all waits for native stab cooldown")
    f.Step(.5)
    check(f.Record.StabTarget==second and f.State.KillAll.Contacts==2,"Kill all advances to the next player instead of repeating the nearest")
    f.Step(1)
    check(not f.State.KillAll.Active and not f.Aura.Enabled and f.State.KillAll.Attempts==2,"completed pass stops aura when it was previously off")
    check(f.State.KillAll.Status:find("kills unconfirmed",1,true)~=nil,"completed pass does not claim contact requests are kills")
    f.Step(1)
    check(f.State.Stats.StabRequests==2,"completed Kill all never sends a queued extra swing")
end
do
    local f=fixture(); f.Enable(); f.State.StartKillAll(); f.Step(); f.Step(1)
    check(not f.State.KillAll.Active and f.Aura.Enabled,"finishing Kill all preserves a previously enabled aura")
    f.Step()
    check(f.Aura.Contacts==2,"ordinary nearest-target aura resumes after a completed pass")
    f=fixture(); f.State.StartKillAll(); f.State.StopKillAll("Cancelled"); f.Step()
    check(not f.State.KillAll.Active and not f.Aura.Enabled and f.Aura.Attempts==0,"Stop Kill all cancels before any attack")
    f=fixture(); f.State.StartKillAll(); f.State.StopKillAura("Emergency stop"); f.Step()
    check(not f.State.KillAll.Active and not f.Aura.Enabled,"stopping aura also stops Kill all")
    f=fixture(); f.Player.Role="Innocent"
    check(not f.State.StartKillAll() and not f.Aura.Enabled,"Kill all refuses when not murderer")
    f=fixture(); f.Target.Excluded=true
    check(not f.State.StartKillAll() and not f.State.KillAll.Active,"Kill all refuses an empty eligible queue")
end
for _,case in ipairs({
    {"new exclusion",function(f) f.Target.Excluded=true end},
    {"target death",function(f) f.Target.Alive=false end},
    {"target respawn",function(f) f.Target.Character=f.Character(5) end},
    {"departed player",function(f) f.Players={f.Player} end},
    {"out-of-range target",function(f) f.Target.Character=f.Character(201) end},
    {"obstructed target",function(f) f.BlockAll=true end},
}) do
    local f=fixture(); f.State.StartKillAll(); case[2](f); f.Step(); f.Step()
    check(f.State.KillAll.Skipped==1 and f.State.KillAll.Attempts==0 and not f.State.KillAll.Active,
        "Kill all skips "..case[1].." without a request")
end
do
    local f=fixture(); f.State.StartKillAll(); f.InputBlocked=true; f.Step()
    check(f.State.KillAll.Active and f.State.KillAll.Index==1 and f.Aura.Attempts==0,"menu pauses Kill all without losing its queue")
    f.InputBlocked=false; f.Step()
    check(f.State.KillAll.Contacts==1,"Kill all resumes after menu closes")
    f=fixture(); f.Equipped=false; f.Knife.Parent={}; f.State.StartKillAll(); f.Step()
    check(f.EquipCount==1 and f.State.KillAll.Contacts==1,"Kill all uses automatic knife equipping")
    f=fixture(); f.State.StartKillAll(); f.Callbacks[f.Player.CharacterRemoving]()
    check(not f.State.KillAll.Active and not f.Aura.Enabled,"respawn cancels Kill all instead of carrying it into a new round")
    f=fixture(); f.Enable(); f.State.StartKillAll(); f.Callbacks[f.Player.CharacterRemoving]()
    check(not f.State.KillAll.Active and f.Aura.Enabled,"respawn cancellation preserves the pre-existing ordinary aura")
    f=fixture(); f.State.StartKillAll(); f.Player.Role="Sheriff"; f.Step()
    check(not f.State.KillAll.Active and f.State.KillAll.Attempts==0,"losing murderer role cancels Kill all")
    f=fixture(); f.State.StartKillAll(); f.State.Running=false; f.Step()
    check(not f.State.KillAll.Active and not f.Aura.Enabled and f.State.KillAll.Attempts==0,"unload cancels Kill all without a final request")
    f=fixture(); f.ContactFail=true; f.State.StartKillAll(); f.Step(); f.Step(1)
    check(f.State.KillAll.Attempts==1 and f.State.KillAll.Contacts==0 and f.State.KillAll.Skipped==1,
        "failed batch contact is not reported as a hit or successful contact")
    f=fixture(); f.SwingFail=true; f.State.StartKillAll(); f.Step(); f.Step()
    check(f.State.KillAll.Attempts==0 and f.State.KillAll.Skipped==1 and not f.State.KillAll.Active,
        "failed batch swing advances and completes without retry spam")
end
print(passed.." aura assertions passed")
