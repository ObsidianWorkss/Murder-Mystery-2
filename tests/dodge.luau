local passed=0
local function check(ok,message) assert(ok,message); passed+=1; print("PASS: "..message) end
-- INSERT_DODGE
-- INSERT_EMERGENCY
local Vector3={zero={X=0,Y=0,Z=0}}
-- INSERT_TELEPORT
local function signal()
    local s={Callbacks={}}
    function s:Connect(fn) table.insert(self.Callbacks,fn) end
    function s:Fire(...) for _,fn in ipairs(self.Callbacks) do fn(...) end end
    return s
end
local function fixture(enabled)
    local f={Binds=0,Unbinds=0,Ticks=0,Lost=signal(),Gained=signal(),Removing=signal()}
    f.State={Running=true,Config={AutoKnifeDodge=enabled~=false}}
    f.Dodge={Tracked={},Focused=true,Decisions=0,Jumps=0,Sidesteps=0}
    installKnifeDodgeLifecycle({State=f.State,Dodge=f.Dodge,
        Bind=function(fn) f.Binds+=1; f.Callback=fn end,Unbind=function() f.Unbinds+=1; f.Callback=nil end,
        Step=function() if f.FailStep then error("private simulation failure") end; f.Ticks+=1 end,Connect=function(s,fn) s:Connect(fn) end,
        FocusLost=f.Lost,FocusGained=f.Gained,CharacterRemoving=f.Removing})
    function f.Frame() if f.Callback then f.Callback() end end
    function f.Moving() f.Dodge.Direction={}; f.Dodge.Character={} end
    return f
end
do
    local f=fixture(); f.Frame()
    check(f.Binds==1 and f.Ticks==1 and f.State.GetKnifeDodgeSnapshot().Bound,"enabled default installs an active frame hook")
    f.Moving(); f.State.StopKnifeDodge("Paused for invisibility")
    check(not f.Dodge.Direction and not f.Dodge.Character,"invisibility preparation cancels only the current movement override")
    check(f.Unbinds==0 and f.State.GetKnifeDodgeSnapshot().Bound,"invisibility pause does not permanently unbind dodge")
    f.Frame()
    check(f.Ticks==2,"later dodge frames still run after a temporary invisibility pause")
    f.State.SetAutoKnifeDodge(true); f.State.SetAutoKnifeDodge(true)
    check(f.Binds==1,"repeated enabling never duplicates the frame hook")
    f.Moving(); f.State.SetAutoKnifeDodge(false); f.Frame()
    check(f.Unbinds==1 and not f.Callback and not f.Dodge.Direction and f.Ticks==2,"explicit off clears movement and unbinds")
    f.State.SetAutoKnifeDodge(true); f.Frame()
    check(f.Binds==2 and f.Ticks==3 and f.State.GetKnifeDodgeSnapshot().Bound,"re-enabling after off restores the frame hook")
    f.State.Config.AutoKnifeDodge=false; f.Frame()
    check(f.Ticks==3,"direct setting off cannot run a queued frame")
    f.State.Config.AutoKnifeDodge=true; f.Frame()
    check(f.Ticks==4,"temporary direct setting pause can resume")
end
do
    local f=fixture(false); f.Frame()
    check(f.Binds==0 and f.Ticks==0 and f.Dodge.Status=="Knife dodge OFF","an explicit off installation remains inactive")
    f.State.SetAutoKnifeDodge(true); f.Frame()
    check(f.Binds==1 and f.Ticks==1,"enabling an initially off controller binds it")
    f.Moving(); f.Lost:Fire()
    check(not f.Dodge.Focused and not f.Dodge.Direction and f.Dodge.Status:find("not focused",1,true),"focus loss clears movement and reports its reason")
    f.Gained:Fire()
    check(f.Dodge.Focused,"focus return permits the guarded dodge loop to resume")
    f.Moving(); f.Removing:Fire()
    check(not f.Dodge.Character and not f.Dodge.Direction and f.Dodge.Status=="Waiting for your next character","respawn clears stale movement without removing the hook")
    f.Frame()
    check(f.Ticks==2 and f.Binds==1,"character replacement does not require manually re-enabling dodge")
    local snap=f.State.GetKnifeDodgeSnapshot(); snap.Bound=false; snap.Tracked=999
    check(f.State.GetKnifeDodgeSnapshot().Bound and f.State.GetKnifeDodgeSnapshot().Tracked==0,"dodge support snapshots are detached from controller state")
end
do
    local f=fixture(); installEmergencyStop({State=f.State}); f.State.EmergencyStop(); f.Frame()
    check(not f.State.Config.AutoKnifeDodge and not f.Callback and f.Ticks==0,"emergency stop really switches dodge off for the session")
    f.State.SetAutoKnifeDodge(true); f.Frame()
    check(f.Ticks==1,"explicit enabling after emergency stop can restart dodge")
    local queued=f.Callback; f.State.DestroyKnifeDodge(); queued(); f.Frame()
    check(not f.Callback and f.Ticks==1 and not f.State.GetKnifeDodgeSnapshot().Bound,"unload removes the hook and rejects queued callbacks")
    check(f.State.SetAutoKnifeDodge(true)==false and not f.Callback,"destroyed dodge cannot be rebound")
    f=fixture(); f.State.Running=false; f.Frame()
    check(f.Ticks==0,"non-running script cannot process dodge frames")
    f=fixture(); f.State.SetAutoKnifeDodge("true")
    check(not f.State.Config.AutoKnifeDodge and not f.Callback,"non-boolean enabling cannot leave contradictory enabled and bound states")
    f=fixture(); f.FailStep=true; f.Moving(); f.Frame()
    check(not f.Callback and not f.State.Config.AutoKnifeDodge and not f.Dodge.Direction and f.Dodge.Status:find("error",1,true),
        "unexpected frame failure is reported and stopped rather than leaving a silent enabled loop")
    check(f.State.GetKnifeDodgeSnapshot().LastError==nil,"support snapshot omits raw internal errors")
    f.FailStep=false; f.State.SetAutoKnifeDodge(true); f.Frame()
    check(f.Ticks==1 and f.Dodge.LastError==nil,"explicit retry can recover from a frame failure")
    f=fixture()
    check(f.State.GetKnifeDodgeSnapshot().Mode=="Side teleport","new dodge session defaults to side teleport mode")
    f.Moving(); f.State.SetKnifeDodgeMode("Jump / sidestep")
    check(not f.Dodge.Direction and f.State.Config.AutoKnifeDodge and f.Binds==1,"mode switch clears prior movement without disabling the loop")
    check(f.State.SetKnifeDodgeMode("Unknown")==false and f.State.Config.KnifeDodgeMode=="Jump / sidestep","invalid dodge mode preserves the selected mode")
    f.State.SetAutoKnifeDodge(false); f.State.SetKnifeDodgeMode("Side teleport")
    check(not f.State.Config.AutoKnifeDodge and not f.Callback,"selecting teleport mode does not override an explicit Off setting")
    f.State.DestroyKnifeDodge()
    check(f.State.SetKnifeDodgeMode("Jump / sidestep")==false,"destroyed script rejects mode changes")
end
do
    local f=fixture()
    local position={X=1,Y=5,Z=0}
    local target=setmetatable({Position=position},{__mul=function(a) return a end})
    local frame={ToObjectSpace=function() return {} end}
    local char={Parent=true,GetPivot=function() return frame end,PivotTo=function(_,value) f.Destination=value end}
    local root={Parent=char,CFrame=frame}
    local hum={Health=100}
    function char:FindFirstChildOfClass() return hum end
    function char:FindFirstChild() return root end
    installWorldTeleports({State=f.State,Player={Character=char},Workspace={},ResolveDestination=function() return target end})
    f.Moving()
    local ok=f.State.TeleportToArea("Map"); f.Frame()
    check(ok and f.Destination==target and not f.Dodge.Direction and f.State.Config.AutoKnifeDodge and f.Unbinds==0 and f.Ticks==1,
        "shipped area teleport cancels old movement without turning off the dodge loop")
    f.State.SetAutoKnifeDodge(false); f.State.TeleportToArea("Lobby")
    check(not f.State.Config.AutoKnifeDodge and not f.Callback,"area teleport preserves an explicitly disabled dodge setting")
end
print(passed.." dodge assertions passed")
