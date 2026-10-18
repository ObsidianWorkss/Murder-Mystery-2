local passed=0
local function check(ok,message) assert(ok,message); passed+=1; print("PASS: "..message) end
local vmeta={}
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z},vmeta) end
vmeta.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vmeta.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vmeta.__index=function(v,key) if key=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end end
local fm={}
local function frame(x,y,z) return setmetatable({Position=vec(x,y,z)},fm) end
fm.__add=function(a,b) local p=a.Position+b; return frame(p.X,p.Y,p.Z) end
local Vector3={zero=vec(0,0,0),new=vec}
-- INSERT_VISIBILITY
local function signal()
    local s={}
    function s:Connect(fn) self.Callback=fn; return {Disconnect=function() self.Callback=nil end} end
    function s:Fire(...) if self.Callback then self.Callback(...) end end
    return s
end
local function fixture()
    local f={Now=10,Pre=signal(),Char={Parent=true}}
    f.Hum={Parent=f.Char,Health=100}
    f.Root={Parent=f.Char,CFrame=frame(10,5,0),Position=vec(10,5,0)}
    f.Hum.RootPart=f.Root
    f.Root.AssemblyRootPart=f.Root
    function f.Char:FindFirstChildOfClass() return f.Hum end
    function f.Char:FindFirstChild(name) return name=="HumanoidRootPart" and f.Root or nil end
    f.Player={Character=f.Char,CharacterAdded=signal(),CharacterRemoving=signal()}
    f.State={Running=true,Config={}}
    installSeatVisibility({State=f.State,Player=f.Player,Workspace={FallenPartsDestroyHeight=-500},
        NewInstance=function() error("unexpected instance creation") end,
        RunService={PreSimulation=f.Pre},Connect=function(s,fn) return s:Connect(fn) end,
        Clock=function() return f.Now end,HasGun=function() return f.Gun=="Backpack" or f.Gun=="Character" end})
    function f.StartActive(phase)
        local seat={Parent=f.Char}
        function seat:Destroy() if f.SeatError then error("seat removal") end; self.Parent=nil end
        local weld={Parent=seat}; function weld:Destroy() self.Parent=nil end
        f.Seat,f.Weld=seat,weld; f.Root.AssemblyRootPart=seat
        local r={Character=f.Char,Humanoid=f.Hum,Root=f.Root,StartFrame=frame(0,5,0),ParkFrame=frame(0,4096,0),
            LocalReady=phase=="Active",Seat=seat,Weld=weld,Started=f.Now,Attached=f.Now}
        f.State.Invis.Record=r
        f.State.Invis.Phase=phase or "Active"; f.State.Invis.Active=phase=="Active"
        f.State.Invis.Busy=phase~="Active"; f.State.Config.Invisibility=true
        return r
    end
    return f
end

for _,phase in ipairs({"Parking","Attaching","Active"}) do
    for _,where in ipairs({"Backpack","Character"}) do
        local f=fixture(); f.StartActive(phase); local current=f.Root.CFrame
        f.Gun=where; f.Pre:Fire()
        check(f.State.Invis.Record~=nil and f.State.Config.Invisibility and f.State.Invis.Phase==phase,
            where.." gun keeps invisibility during "..phase)
        check(f.Seat.Parent~=nil and f.Weld.Parent~=nil,where.." gun does not dismantle invisibility during "..phase)
        if phase=="Active" then check(f.Root.CFrame==current,"equipping a gun preserves current invisible position") end
    end
end
do
    local f=fixture(); f.StartActive("Active"); f.Pre:Fire()
    check(f.State.Invis.Record~=nil and f.State.Invis.Active,"no gun leaves a stable invisible character alone")
    f.State.Config.AutoRevealGun=true; f.Gun="Backpack"; f.Pre:Fire()
    check(f.State.Invis.Active,"obsolete auto-reveal setting cannot reveal a gun owner")
    f=fixture(); f.Gun="Backpack"
    local ok=f.State.SetInvisibility(true)
    check(ok==true and f.State.Invis.Record~=nil and f.State.Config.Invisibility,"owning a gun allows invisibility activation")
    f=fixture(); f.State.SetInvisibility(true); f.Gun="Backpack"; f.Pre:Fire()
    check(f.State.Invis.Record~=nil and f.State.Invis.Phase=="Parking","gun pickup does not cancel actual invisibility preparation")
    f=fixture(); f.StartActive("Active"); local current=f.Root.CFrame; f.State.SetInvisibility(false)
    check(not f.State.Invis.Record and f.Root.CFrame==current,"manual restoration still cleans up at the current safe position")
    f=fixture(); f.StartActive("Active"); f.Gun="Backpack"; f.SeatError=true; f.State.SetInvisibility(false)
    check(f.State.Invis.Phase=="RestoreFailed" and f.State.Invis.Record~=nil and f.State.Invis.Busy,
        "failed manual restoration retains the assembly record and reports incomplete restoration")
    f.SeatError=false; f.State.SetInvisibility(false)
    check(not f.State.Invis.Record and not f.State.Invis.Busy,"failed manual restoration can be retried")
    f=fixture(); f.StartActive("Active"); f.Gun="Character"
    check(f.State.ExitUndergroundForAttack("Gun") and f.State.Invis.Record~=nil and f.State.Invis.Active
        and f.Seat.Parent~=nil and f.Weld.Parent~=nil,"gun firing is allowed without revealing or dismantling invisibility")
    f=fixture(); f.StartActive("Active"); f.State.ExitUndergroundForAttack("Knife")
    check(f.State.Invis.Active,"knife use retains its existing invisible behavior")
    f.State.Config.InvisibleKnife=false
    check(not f.State.ExitUndergroundForAttack("Knife") and f.State.Invis.Active,"disabled invisible knife use pauses rather than revealing")
    for _,phase in ipairs({"Parking","Attaching","RestoreFailed"}) do
        f=fixture(); local record=f.StartActive(phase)
        check(not f.State.ExitUndergroundForAttack("Gun") and not f.State.ExitUndergroundForAttack("Knife")
            and f.State.Invis.Record==record and f.Seat.Parent~=nil,"weapon input waits during "..phase.." without restoring")
    end
    f=fixture()
    check(f.State.ExitUndergroundForAttack("Gun"),"normal visible gun input is still allowed")
    f=fixture(); f.StartActive("Active"); f.State.ExitUndergroundForAttack()
    check(not f.State.Invis.Record,"explicit non-weapon movement cleanup still restores its owned assembly")
end
print(passed.." visibility assertions passed")
