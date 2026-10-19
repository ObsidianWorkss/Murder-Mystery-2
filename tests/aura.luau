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
    local record={Item=knife,ThrowToken=0,Active=true,LastStab=-math.huge,LastThrow=-math.huge,StabbingUntil=0}
    local State={Running=true,Config={Aim=true,AuraExtendedReach=false,AuraEquipKnife=true,KillAuraRange=6},
        WeaponHandlers={[knife]=record},Stats={StabRequests=0,StabContactReports=0},
        IsPlayerExcluded=function(p) return p.Excluded==true end}
    f.Players={player,target}
    local Players={GetPlayers=function() f.ReportRosterScans=(f.ReportRosterScans or 0)+1; return f.Players end}
    function Players:FindFirstChild(name)
        for _,p in ipairs(f.Players) do if p.Name==name then return p end end
    end
    local bodyPartSet={UpperTorso=true,Head=true,Torso=true,LowerTorso=true}
    knife.Events=node("Events","Folder",knife)
    knife.Events.HandleTouched=node("HandleTouched","RemoteEvent",knife.Events)
    function knife.Events.HandleTouched:FireServer(part)
        f.ContactPart=part
        if f.ContactFail or f.FailPart==part then error("contact send failed") end
        if f.AfterContact then f.AfterContact(part) end
    end
    local function roleFor(p) return p.Role end
    State.IsCombatTarget=function(kind,p)
        if f.TargetPolicy then return f.TargetPolicy(kind,p) end
        return roleFor(p)~="Murderer"
    end
    State.CanUseCombatWeapon=function(kind)
        if f.UsePolicy then return f.UsePolicy(kind) end
        return roleFor(player)=="Murderer"
    end
    local function alive(p) return p.Alive and p.Character and p.Character.Humanoid.Health>0 end
    local function ready(r) return f.Ready and r and r.Active and r.Item.Parent==player.Character and r.Item.Enabled end
    local function clearPath(_,point)
        f.VisibilityChecks=(f.VisibilityChecks or 0)+1
        if f.FailVisibilityProbe then error("unexpected visibility query") end
        return not f.BlockAll and not f.Blocked[point]
    end
    local function stabKnife(r,p)
        if f.SwingFail then return false end
        r.LastStab=f.Now; r.StabbingUntil=f.Now+.85; r.StabTarget=p; r.AuraStab=false
        r.StabContacts={}; r.StabContactFailures={}
        State.Stats.StabRequests+=1
        return true
    end
    -- INSERT_AURA_CONTACT
    -- INSERT_AURA_READY
    local function startThrow(r,p,strict,guard)
        f.ThrowTarget,f.ThrowStrict,f.ReleaseGuard=p,strict,guard
        if f.ThrowFail then return false end
        r.Charging=true; r.LastThrow=f.Now
        return true
    end
    -- INSERT_AURA_STAB
    f.Player,f.Target,f.Knife,f.Record,f.State=player,target,knife,record,State
    local UIS={WindowFocusReleased={},WindowFocused={}}
    local heartbeat={}
    f.RoundEnd={}
    local C={State=State,Player=player,Players={GetPlayers=function() return f.Players end},UIS=UIS,
        RunService={Heartbeat=heartbeat},RoundEnd=f.RoundEnd,Clock=function() return f.Now end,
        Connect=function(signal,callback) f.Callbacks[signal]=callback end,
        RoleFor=roleFor,IsAlive=alive,ClearPath=clearPath,
        CanUseWeapon=State.CanUseCombatWeapon,IsTarget=State.IsCombatTarget,
        InputBlocked=function() return f.InputBlocked==true end,
        EquippedWeapon=function() if f.Equipped then return knife,"Knife" end end,
        CanStab=auraKnifeReady,Stab=auraStab,Burst=auraBurst,Throw=auraThrow,
        IsEliminated=function(p) return p.ServerDead==true end,
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
    f.Aura=installKillAura(C); f.UIS=UIS; f.Context=C
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
    check(f.State.GetKillAuraRange()==1000 and f.Aura.LastDistance==20,"extended range defaults to the 1000-stud attempt radius")
    f.State.SetAuraReachRange(10); f.Step(1)
    check(f.Aura.Attempts==1,"reducing extended range excludes the previous target")
    f.State.SetAuraExtendedReach(false)
    check(f.State.GetKillAuraRange()==6,"disabling reach restores the normal radius")
    check(f.State.SetAuraReachRange(1000) and f.State.GetKillAuraRange()==6,"extended reach setting accepts 1000 without changing the disabled normal radius")
    check(not f.State.SetAuraReachRange(1001) and not f.State.SetKillAuraRange(1001),"ranges above 1000 are refused")
    check(f.State.SetKillAuraRange(100) and f.State.GetKillAuraRange()==100 and f.State.Config.KillAuraRange==100,"main aura slider updates the active extended range beyond 6.5 studs")
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
    check(f.State.StartKillAll() and f.State.KillAll.Active and f.State.KillAll.Total==2,"Kill all snapshots eligible players")
    check(not f.State.StartKillAll(),"a second Kill all cannot duplicate the queue")
    f.Step(1/60)
    check(f.State.KillAll.Contacts==2 and f.State.KillAll.Attempts==2,"all clear players receive contact attempts on the first ready frame")
    check(f.State.Stats.StabRequests==1 and f.State.KillAll.Bursts==1,"one native swing covers multiple players without per-player cooldown waits")
    check(f.Record.StabTarget==nil,"burst releases its temporary single-player lock")
    f.Step(.4)
    check(f.State.KillAll.Contacts==2 and f.State.Stats.StabRequests==1,"cooldown prevents a second burst")
    f.Step(.5)
    check(f.State.KillAll.Contacts==4 and f.State.Stats.StabRequests==2,"next ready burst revisits every surviving clear player together")
    check(f.State.KillAll.Active and f.State.KillAll.Observed==0,"contact sends never count as eliminations")
    f.Target.ServerDead=true; second.Character.Humanoid.Health=0; f.Step()
    check(not f.State.KillAll.Active and not f.Aura.Enabled and f.State.KillAll.Observed==2,"observed deaths complete targets during cooldown")
    check(f.State.KillAll.Status:find("0 unresolved",1,true)~=nil,"completion distinguishes unresolved targets")
    f.Step(1)
    check(f.State.Stats.StabRequests==2,"completed action cannot start another swing")
end

do
    local f=fixture(); f.Enable(); f.State.StartKillAll(); f.Step(); f.Target.ServerDead=true; f.Step()
    check(not f.State.KillAll.Active and f.Aura.Enabled,"completion restores an existing aura")
    f=fixture(); f.State.StartKillAll(); f.State.StopKillAll("Cancelled"); f.Step()
    check(not f.State.KillAll.Active and not f.Aura.Enabled and f.Aura.Attempts==0,"stop cancels before any request")
    f=fixture(); f.State.StartKillAll(); f.State.StopKillAura("Emergency stop"); f.Step()
    check(not f.State.KillAll.Active and not f.Aura.Enabled,"stopping aura stops Kill all")
    f=fixture(); f.Player.Role="Innocent"
    check(not f.State.StartKillAll(),"Kill all refuses when not murderer")
    f=fixture(); f.Target.Excluded=true
    check(not f.State.StartKillAll(),"protected-only queue is refused")
end

for _,case in ipairs({
    {"new exclusion",function(f) f.Target.Excluded=true end},
    {"target respawn",function(f) f.Target.Character=f.Character(5) end},
    {"departed player",function(f) f.Players={f.Player} end},
}) do
    local f=fixture(); f.State.StartKillAll(); case[2](f); f.Step()
    check(f.State.KillAll.Skipped==1 and f.State.KillAll.Attempts==0 and not f.State.KillAll.Active,
        "Kill all removes "..case[1].." without a request")
end

for _,case in ipairs({
    {"out of range",function(f) f.Target.Character.HumanoidRootPart.Position=vec(201) end,
        function(f) f.Target.Character.HumanoidRootPart.Position=vec(5) end},
}) do
    local f=fixture(); f.State.StartKillAll(); case[2](f); f.Step()
    check(f.State.KillAll.Active and f.State.KillAll.Skipped==0 and f.Aura.Attempts==0,
        "temporary "..case[1].." preserves the target")
    case[3](f); f.Step()
    check(f.State.KillAll.Contacts==1,"queue attacks after "..case[1].." clears")
end

do
    local f=fixture(); f.State.StartKillAll(); f.InputBlocked=true; f.Step(2)
    check(f.State.KillAll.Elapsed==0 and f.State.KillAll.Attempts==0,"menus pause attacks and active deadline")
    f.InputBlocked=false; f.Step()
    check(f.State.KillAll.Contacts==1,"queue resumes when menu closes")
    f=fixture(); f.State.StartKillAll()
    for _=1,125 do f.Step(.25) end
    check(not f.State.KillAll.Active and f.State.KillAll.Attempts==3,"unconfirmed target gets at most three attempts before deadline")
    check(f.State.KillAll.Status:find("1 unresolved",1,true)~=nil and f.State.KillAll.Observed==0,"failed damage is reported as unresolved")
    f=fixture(); f.State.StartKillAll(); f.BlockAll=true
    for _=1,125 do f.Step(.25) end
    check(not f.State.KillAll.Active and f.State.KillAll.Attempts==3,"walls do not prevent the bounded contact attempts")
    f=fixture(); f.Equipped=false; f.EquipFail=true; f.State.StartKillAll()
    for _=1,125 do f.Step(.25) end
    check(not f.State.KillAll.Active and f.State.KillAll.Attempts==0,"missing knife still reaches the bounded deadline")
    f=fixture(); f.SwingFail=true; f.State.StartKillAll()
    for _=1,125 do f.Step(.25) end
    check(f.State.KillAll.Attempts==0 and f.State.KillAll.Targets[1]==nil,"failed swings stop at bounded deadline")
    f=fixture(); f.State.StartKillAll(); f.Callbacks[f.Player.CharacterRemoving]()
    check(not f.State.KillAll.Active and not f.Aura.Enabled,"own respawn cancels queue")
    f=fixture(); f.State.StartKillAll(); f.Player.Role="Sheriff"; f.Step()
    check(not f.State.KillAll.Active and f.State.KillAll.Attempts==0,"role loss cancels queue")
    f=fixture(); f.State.StartKillAll(); f.State.Running=false; f.Step()
    check(not f.State.KillAll.Active and f.Aura.Attempts==0,"unload cancels without attacking")
end

do
    local f=fixture(); f.State.SetKillAuraRange(1000)
    f.Target.Character=f.Character(800)
    local second={Name="Second",UserId=3,Character=f.Character(999),Role="Innocent",Alive=true}
    table.insert(f.Players,second)
    f.State.StartKillAll(); f.Step(1/60)
    check(f.State.KillAll.Contacts==2 and f.State.Stats.StabRequests==1,"map-wide contacts are attempted in one swing without throw charging")
    check(f.State.LastStabContact.Source=="KillAllBurst" and not f.Record.Charging,"burst uses explicit contact reports and never charges a throw")
    f=fixture(); f.State.SetKillAuraRange(1000); f.Target.Character=f.Character(1001); f.State.StartKillAll(); f.Step()
    check(f.State.KillAll.Contacts==0,"target beyond configured maximum is retained without a request")
end

for _,case in ipairs({
    {"protected",function(f,p) p.Excluded=true end},
    {"respawned",function(f,p) p.Character=f.Character(6) end},
    {"dead",function(f,p) p.Alive=false end},
    {"newly allied",function(f,p) p.Role="Murderer" end},
    {"out of range",function(f,p) p.Character.HumanoidRootPart.Position=vec(1001) end},
}) do
    local f=fixture(); f.State.SetKillAuraRange(1000)
    local second={Name="Second",UserId=3,Character=f.Character(6),Role="Innocent",Alive=true}
    table.insert(f.Players,second)
    f.AfterContact=function(part) if part.Parent==f.Target.Character then case[2](f,second) end end
    f.State.StartKillAll(); f.Step()
    check(f.State.KillAll.Contacts==1,"burst rechecks a "..case[1].." second player after first contact")
end

do
    local f=fixture(); local second={Name="Second",UserId=3,Character=f.Character(6),Role="Innocent",Alive=true}
    table.insert(f.Players,second); f.FailPart=f.Target.Character.UpperTorso
    f.State.StartKillAll(); f.Step()
    check(f.State.KillAll.Attempts==2 and f.State.KillAll.Contacts==1,"one contact failure does not prevent other players in the burst")
    f=fixture(); table.insert(f.Players,{Name="Second",UserId=3,Character=f.Character(6),Role="Innocent",Alive=true})
    f.AfterContact=function() f.State.StopKillAll("Stopped") end
    f.State.StartKillAll(); f.Step()
    check(f.State.Stats.StabContactReports==1 and not f.State.KillAll.Active and f.State.KillAll.Status=="Stopped","stop during contact delivery prevents remaining burst contacts and preserves stop status")
end
do
    local f=fixture(); f.State.SetKillAuraRange(1000)
    local second={Name="Second",UserId=3,Character=f.Character(800),Role="Innocent",Alive=true}
    table.insert(f.Players,second)
    f.BlockAll=true; f.FailVisibilityProbe=true
    f.State.StartKillAll(); f.Step(1/60)
    check(f.State.KillAll.Contacts==2 and f.State.Stats.StabRequests==1,"blocked and distant players receive same-frame burst attempts")
    check((f.VisibilityChecks or 0)==0,"Kill all makes no visibility queries in selection, burst validation or contact reporting")
    check(f.State.KillAll.Observed==0 and f.State.LastStabContact.DamageConfirmed==false,"ignoring local visibility does not mark server damage as confirmed")
    f=fixture(); f.Enable(); f.BlockAll=true; f.Step()
    check(f.State.Stats.StabRequests==0 and (f.VisibilityChecks or 0)>0,"ordinary aura retains its line-of-sight policy")
    f=fixture(); table.insert(f.Players,{Name="Second",UserId=3,Character=f.Character(6),Role="Innocent",Alive=true})
    f.AfterContact=function() f.BlockAll=true end
    f.State.StartKillAll(); f.Step()
    check(f.State.KillAll.Contacts==2,"new cover during a burst does not discard the next eligible player")
end

do
    local f=fixture(); f.Enable()
    table.insert(f.Players,{Name="Second",UserId=3,Character=f.Character(6),Role="Innocent",Alive=true})
    f.AfterContact=function() f.State.StopKillAll("Stopped") end
    f.State.StartKillAll(); f.Step()
    check(f.State.Stats.StabContactReports==1 and not f.State.KillAll.Active and f.Aura.Enabled,
        "stopping during a burst prevents further contacts even when ordinary aura is restored")
    f=fixture(); f.Enable()
    table.insert(f.Players,{Name="Second",UserId=3,Character=f.Character(6),Role="Innocent",Alive=true})
    local replaced=false
    f.AfterContact=function()
        if not replaced then replaced=true; f.State.StopKillAll(); f.State.StartKillAll() end
    end
    f.State.StartKillAll(); f.Step()
    check(f.State.Stats.StabContactReports==1 and f.State.KillAll.Active and f.State.KillAll.Attempts==0,
        "a replacement queue cannot continue the old burst or inherit its counters")
end
do
    local f=fixture()
    local empty=f.State.GetCombatResults()
    check(empty.Attempts==0 and empty.Unresolved==0 and empty.Text:find("not attributed",1,true),"results start empty and distinguish observations from attributed kills")
    f.State.StartKillAll(); f.Step()
    local sent=f.State.GetCombatResults()
    check(sent.Contacts==1 and sent.Observed==0 and sent.Unresolved==1 and sent.Bursts==1,"results separate contact requests and unresolved targets")
    sent.Contacts=999
    check(f.State.GetCombatResults().Contacts==1,"editing a results snapshot cannot change live counters")
    f.Target.ServerDead=true; f.Step()
    local observed=f.State.GetCombatResults()
    check(observed.Observed==1 and observed.Unresolved==0 and not observed.Active,"results retain observed eliminations after completion")
    check(not f.State.SetKillAllMode("Unknown") and not f.State.SetTargetPriority("Unknown"),"invalid mode and priority choices are refused")
end

do
    local f=fixture(); f.State.SetKillAuraRange(1000); f.State.Config.KnifeAim=true
    f.Target.Character=f.Character(40)
    check(f.State.SetKillAllMode("Aimed throws"),"aimed-throw mode can be selected")
    f.State.StartKillAll(); f.Step()
    check(f.State.KillAll.Throws==1 and f.State.KillAll.Bursts==0 and f.State.KillAll.Contacts==0
        and f.ThrowTarget==f.Target and f.ThrowStrict,"aimed mode starts one target-locked throw beyond stab reach")
    check(f.ReleaseGuard(),"active aimed throw passes its deferred action guard")
    f.Step(.5)
    check(f.State.KillAll.Throws==1,"a charged throw cannot start a duplicate")
    f.State.SetKillAllMode("Burst")
    check(not f.State.KillAll.Active and not f.ReleaseGuard(),"changing mode stops its queue and rejects a deferred throw")
    f=fixture(); f.State.SetKillAllMode("Aimed throws"); f.State.StartKillAll(); f.Step()
    check(f.State.KillAll.Contacts==1 and f.State.KillAll.Throws==0,"aimed mode uses a normal assisted stab for nearby players")
    f=fixture(); f.State.SetKillAllMode("Aimed throws"); f.State.StartKillAll(); f.BlockAll=true; f.Step()
    check(f.State.KillAll.Attempts==0 and (f.VisibilityChecks or 0)>0,"aimed mode requires a clear path rather than using burst wall attempts")
    f=fixture(); f.State.SetKillAllMode("Aimed throws"); f.State.SetKillAuraRange(1000)
    f.Target.Character=f.Character(40); f.State.Config.KnifeAim=false; f.State.StartKillAll(); f.Step()
    check(f.State.KillAll.Throws==0 and f.State.KillAll.Status:find("prediction",1,true),"aimed mode explains disabled prediction")
    f=fixture(); f.State.SetKillAllMode("Aimed throws"); f.State.SetKillAuraRange(1000)
    f.Target.Character=f.Character(40); f.State.Config.KnifeAim=true; f.State.StartKillAll(); f.Step(); f.InputBlocked=true
    check(not f.ReleaseGuard(),"opening input during charge prevents automatic release")
end

for _,case in ipairs({
    {"Nearest",nil,"Target"},
    {"Sheriff first",nil,"Far"},
    {"Selected player",3,"Far"},
    {"Selected player",999,"Target"},
}) do
    local f=fixture(); f.State.SetKillAuraRange(1000); f.State.Config.KnifeAim=true
    local far={Name="Far",UserId=3,Character=f.Character(40),Role="Sheriff",Alive=true}
    table.insert(f.Players,far)
    f.State.PlayerActions={SelectedId=case[2]}
    f.State.SetTargetPriority(case[1]); f.State.SetKillAllMode("Aimed throws")
    f.State.StartKillAll(); f.Step()
    check(case[3]=="Target" and f.State.KillAll.Contacts==1 or case[3]=="Far" and f.ThrowTarget==far,
        "aimed priority applies "..case[1].." with selection "..tostring(case[2]))
    f=fixture(); f.State.SetKillAuraRange(1000); table.insert(f.Players,far)
    f.State.PlayerActions={SelectedId=case[2]}; f.State.SetTargetPriority(case[1]); f.Enable(); f.Step()
    check(f.Record.StabTarget.Name==case[3],"ordinary aura applies "..case[1].." priority with nearest fallback")
end
do
    local f=fixture(); f.State.StartKillAll()
    for _=1,18 do f.Step(.25) end
    check(not f.State.KillAll.Active and f.State.KillAll.Elapsed<5 and f.State.KillAll.Attempts==3,
        "exhausted burst retries finish after feedback grace instead of idling for 30 seconds")
    local result=f.State.GetCombatResults()
    check(result.Unresolved==1 and result.Reasons["Retry budget used"]==1,"results retain the unresolved retry-budget reason")
    result.Reasons["Retry budget used"]=999
    check(f.State.GetCombatResults().Reasons["Retry budget used"]==1,"editing reason snapshots cannot change live results")
    check(f.State.RetryKillAll() and f.State.KillAll.Total==1 and f.State.KillAll.Attempts==0,"explicit retry starts a fresh budget only for unresolved players")
    f.Step(); f.Target.ServerDead=true; f.Step()
    check(not f.State.RetryKillAll(),"observed eliminated players cannot be retried")
    local history,text=f.State.GetRecentCombatRuns()
    check(#history==2 and type(text)=="string" and text:find("Burst",1,true),"recent-run history retains independent summaries")
    history[1].Contacts=999
    check(select(1,f.State.GetRecentCombatRuns())[1].Contacts~=999,"editing history snapshots cannot change retained summaries")
end

for _,case in ipairs({
    {"protection",function(f) f.Target.Excluded=true end},
    {"departure",function(f) f.Players={f.Player} end},
    {"target respawn",function(f) f.Target.Character=f.Character(5) end},
    {"server elimination",function(f) f.Target.ServerDead=true end},
    {"own respawn",function(f) f.Callbacks[f.Player.CharacterRemoving]() end},
    {"round end",function(f) f.Callbacks[f.RoundEnd]() end},
}) do
    local f=fixture(); f.State.StartKillAll(); f.Step(); f.State.StopKillAll()
    case[2](f)
    check(not f.State.RetryKillAll(),"retry refuses stale players after "..case[1])
end

do
    local f=fixture()
    for _=1,7 do f.State.StartKillAll(); f.Step(1); f.State.StopKillAll() end
    check(#select(1,f.State.GetRecentCombatRuns())==5,"recent-run history is bounded to five summaries")
    f=fixture(); f.Target.Character.HumanoidRootPart.Position=vec(200); f.State.StartKillAll(); f.Step()
    check(f.State.GetCombatResults().Reasons["Out of range"]==1,"results explain targets outside the current radius")
    f=fixture(); f.State.SetKillAllMode("Aimed throws"); f.BlockAll=true; f.State.StartKillAll(); f.Step()
    check(f.State.GetCombatResults().Reasons["Clear path blocked"]==1,"aimed-mode results explain obstructed paths")
    f=fixture(); f.Equipped=false; f.EquipFail=true; f.State.StartKillAll(); f.Step()
    check(f.State.GetCombatResults().Reasons["Knife unavailable"]==1,"results explain a missing knife")
    f=fixture(); f.State.SetKillAllMode("Aimed throws"); f.State.SetKillAuraRange(1000)
    f.Target.Character=f.Character(40); f.State.Config.KnifeAim=false; f.State.StartKillAll(); f.Step()
    check(f.State.GetCombatResults().Reasons["Knife prediction disabled"]==1,"results explain disabled ranged prediction")
    f.Step(.01)
    check(f.State.GetCombatResults().Reasons["Knife prediction disabled"]==1,"disabled prediction reason persists between retry checks")
end

do
    local f=fixture(); f.State.SetKillAuraRange(1000)
    for index=3,24 do table.insert(f.Players,{Name="Player"..index,UserId=index,Character=f.Character(index*5),Role="Innocent",Alive=true}) end
    f.State.StartKillAll(); f.Step()
    check(f.State.KillAll.Contacts==23 and (f.ReportRosterScans or 0)==0,
        "target-locked contacts avoid repeated full roster scans while preserving the whole burst")
    f=fixture(); local second={Name="Second",UserId=3,Character=f.Character(6),Role="Innocent",Alive=true}
    table.insert(f.Players,second)
    f.AfterContact=function() f.Players={f.Player,f.Target} end
    f.State.StartKillAll(); f.Step()
    check(f.State.KillAll.Contacts==1,"a player leaving mid-burst cannot receive a locked contact")
    f=fixture(); f.State.StartKillAll(); f.Callbacks[f.RoundEnd]()
    check(not f.State.KillAll.Active and not f.State.RetryKillAll(),"round end stops active attacks and clears retry eligibility")
end
do
    local f=fixture(); f.State.SetKillAllMode("Aimed throws"); f.State.SetKillAuraRange(1000)
    f.State.Config.KnifeAim=true; f.Target.Character=f.Character(400)
    f.State.StartKillAll(); f.Step(.1); f.Record.Charging=false
    f.Step(2.01); f.Record.Charging=false
    f.Step(2.01); f.Record.Charging=false
    f.Step(1.3)
    check(f.State.KillAll.Active and f.State.KillAll.Throws==3,"distant throws retain charge and flight feedback grace after retry exhaustion")
    f.Step(5)
    check(not f.State.KillAll.Active and f.State.KillAll.Elapsed<30,"ranged retries finish after their bounded flight grace")
    f=fixture(); f.State.StartKillAll(); f.Step(31)
    check(not f.State.KillAll.Active and f.State.KillAll.Elapsed==31 and f.State.KillAll.Attempts==0,
        "a stalled frame counts its full active time and cannot prolong the deadline")
    f=fixture(); f.Enable(); f.BlockAll=true; f.Step(.01); local before=f.VisibilityChecks
    f.Step(.005)
    check(f.VisibilityChecks==before,"idle ordinary aura does not repeat expensive rays every heartbeat")
    f.BlockAll=false; f.Step(.051)
    check(f.Aura.Contacts==1,"idle scan backoff still resumes with fresh visible target checks")
end
do
    local f=fixture();f.Player.Role="Zombie";f.Target.Role="Survivor"
    f.UsePolicy=function(kind) return kind=="Knife" end
    f.TargetPolicy=function(_,p) return p.Role=="Survivor" end
    check(f.State.StartKillAll(),"event knife role starts the existing queue through the shared capability adapter")
    f.Step()
    check(f.State.KillAll.Contacts==1,"event queue sends contact for an eligible opponent")
    f.Target.Role="Zombie";f.Step(1)
    check(f.State.KillAll.Contacts==1 and f.State.KillAll.Skipped==1,"event conversion removes the target before another queued contact")
    f=fixture();f.Player.Role="Freezer";f.Target.Role="Runner"
    f.UsePolicy=function(kind) return kind=="Knife" end
    f.TargetPolicy=function(_,p) return p.Role=="Runner" end
    f.Enable();f.Step()
    check(f.Aura.Contacts==1,"ordinary event aura accepts eligible runner through the adapter")
    f.UsePolicy=function() return false end;f.Step(1)
    check(f.Aura.Contacts==1 and not f.State.CanAuraContact(),"event role loss pauses aura and the final contact guard")
end
print(passed.." aura assertions passed")
