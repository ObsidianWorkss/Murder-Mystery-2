local passed=0
local function check(ok,message) assert(ok,message); passed+=1; print("PASS: "..message) end
local vm={}
local function v(x,y,z) return setmetatable({X=x,Y=y,Z=z},vm) end
vm.__add=function(a,b) return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vm.__sub=function(a,b) return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vm.__mul=function(a,b) return v(a.X*b,a.Y*b,a.Z*b) end
vm.__div=function(a,b) return v(a.X/b,a.Y/b,a.Z/b) end
vm.__unm=function(a) return v(-a.X,-a.Y,-a.Z) end
vm.__index=function(a,key)
    if key=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
    if key=="Unit" then return a/a.Magnitude end
    if key=="Dot" then return function(self,b) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end end
end
local Vector3={new=v,zero=v(0,0,0)}
local typeof=function(value) return getmetatable(value)==vm and "Vector3" or type(value) end
-- INSERT_SIDE_DODGE
local function near(a,b) return math.abs(a-b)<.0001 end
local function context()
    return {Position=v(0,3,0),Velocity=v(0,0,0),Low=0,High=6,Radius=1.4,Grounded=true,Gravity=196.2,Horizon=.55,Now=10}
end
local function incoming(x) return {Position=v(x or 0,2,-20),Velocity=v(0,0,100),Time=.2} end
local function fixture()
    local f={Now=10,Moves=0,Valid=true,Safe=true,State={Running=true,Config={AutoKnifeDodge=true,KnifeDodgeMode="Side teleport"}},Dodge={}}
    f.Checks={Landing=function(_,point) if not f.NoFloor then return point,0 end end,
        Clear=function(_,point) return not f.Wall and not (f.LeftWall and point.X<0) end}
    f.Caps={State=f.State,Dodge=f.Dodge,Clock=function() return f.Now end,
        Valid=function() return f.Valid end,Safe=function(ctx,action)
            if f.DuringCheck then f.DuringCheck() end
            return f.Safe and f.Checks.Clear(ctx,action.Position)
        end,
        Move=function(ctx,point)
            f.Moves+=1
            if f.MoveError then error("private movement failure") end
            f.Destination=point
            if f.Reentrant then f.Nested=commitKnifeTeleport(f.Caps,ctx,f.Action) end
        end}
    f.Ctx=context()
    function f.Plan(motions) f.Ctx.Now=f.Now; f.Action=planKnifeTeleport(f.Checks,f.Ctx,incoming(),motions or {}); return f.Action end
    function f.Commit() return commitKnifeTeleport(f.Caps,f.Ctx,f.Action) end
    return f
end
do
    local f=fixture(); local a=f.Plan()
    check(a and a.Kind=="Teleport" and near(math.abs(a.Position.X),4) and near(a.Position.Z,0),"first safe teleport is four studs perpendicular to the knife trajectory")
    check(a.Clearance>f.Ctx.Radius+.8 and a.Distance<=8.5,"planned position clears the knife corridor within the displacement cap")
    f.LeftWall=true; a=f.Plan()
    check(a and a.Position.X>0,"blocked left route chooses the clear right side")
    f.Wall=true
    check(not f.Plan(),"both blocked routes reject teleport rather than crossing a wall")
    f=fixture(); f.NoFloor=true
    check(not f.Plan(),"unsupported destinations reject teleport instead of moving over a ledge")
    f=fixture(); a=f.Plan({{Position=v(-4,2,-10),Velocity=v(0,0,100)}})
    check(a and a.Position.X>0,"another incoming knife blocks the otherwise preferred side")
    a=f.Plan({{Position=v(-4,2,-10),Velocity=v(0,0,100)},{Position=v(4,2,-10),Velocity=v(0,0,100)}})
    check(a and near(a.Distance,8),"planner expands only as far as needed when both nearer positions intersect other knives")
    f.Checks.Landing=function(_,point) return point+v(0,10,0),10 end
    check(not f.Plan(),"an invalid large vertical displacement cannot bypass the teleport cap")
    f=fixture(); local knife=incoming(); knife.Time=1
    check(not planKnifeTeleport(f.Checks,f.Ctx,knife,{}),"out-of-horizon threats cannot generate teleport plans")
    knife=incoming(); knife.Velocity=v(0,0,0)
    check(not planKnifeTeleport(f.Checks,f.Ctx,knife,{}),"zero direction cannot choose an arbitrary side")
    knife=incoming(); knife.Time=0/0
    check(not planKnifeTeleport(f.Checks,f.Ctx,knife,{}),"non-finite timing cannot generate a teleport")
    f=fixture(); f.Ctx.Grounded=false; f.Ctx.Velocity=v(0,-50,0)
    local point=v(-4,3,0); local landingKnife={Position=v(-4,1,-20),Velocity=v(0,0,100)}
    check(not knifeTeleportClearance(f.Ctx,point,incoming(),{landingKnife},0),"airborne clearance includes landing on the supported floor")
    f=fixture()
    a=f.Plan({{Position=v(-4,15,0),Velocity=v(0,-100,0)}})
    check(a and a.Position.X>0,"vertical falling knife also blocks an otherwise clear side destination")
    f=fixture(); f.Ctx.ControlVelocity=v(16,0,0); a=f.Plan()
    check(a and a.Position.X>0,"held movement toward the knife corridor selects the side that stays clear while walking")
end
do
    local f=fixture(); f.Plan()
    check(f.Commit() and f.Moves==1 and f.Dodge.Teleports==1,"fresh validated plan sends one movement request")
    f.Now=10.1; f.Plan()
    check(not f.Commit() and f.Moves==1,"global cooldown blocks a fresh second plan")
    f.Now=10.31; f.Plan()
    check(f.Commit() and f.Moves==2,"a new safe plan can run after cooldown")
    f=fixture(); f.Plan(); f.Now=10.081
    check(not f.Commit() and f.Moves==0,"stale geometry plan is rejected before movement")
    f=fixture(); f.Plan(); f.Action.Time=.02; f.Now=10.03
    check(not f.Commit(),"a plan cannot execute after its estimated impact")
    for _,case in ipairs({"off","unload","mode","character","new wall"}) do
        f=fixture(); f.Plan()
        if case=="off" then f.State.Config.AutoKnifeDodge=false
        elseif case=="unload" then f.State.Running=false
        elseif case=="mode" then f.State.Config.KnifeDodgeMode="Jump / sidestep"
        elseif case=="character" then f.Valid=false
        elseif case=="new wall" then f.LeftWall=true; f.Wall=true end
        check(not f.Commit() and f.Moves==0,case.." cancels a pending side teleport")
    end
    for _,case in ipairs({"off","unload","mode"}) do
        f=fixture(); f.Plan()
        f.DuringCheck=function()
            if case=="off" then f.State.Config.AutoKnifeDodge=false
            elseif case=="unload" then f.State.Running=false
            else f.State.Config.KnifeDodgeMode="Jump / sidestep" end
        end
        check(not f.Commit() and f.Moves==0,case.." during destination recheck still cancels movement")
    end
    f=fixture(); f.Plan(); f.MoveError=true
    check(not f.Commit() and f.Dodge.FailedTeleports==1 and not f.Dodge.TeleportBusy,"movement failure releases the action lock and records failure")
    f.Plan()
    check(not f.Commit() and f.Moves==1,"failed movement also starts cooldown instead of retrying every frame")
    f=fixture(); f.Reentrant=true; f.Plan()
    check(f.Commit() and f.Nested==false and f.Moves==1,"reentrant movement cannot duplicate a teleport")
end
do
    local r={}
    local velocity,source=resolveKnifeVelocity(r,v(0,0,0),10,v(0,0,2),100,Vector3.zero)
    check(source=="Direction" and near(velocity.Magnitude,100),"non-unit knife direction is normalized before applying speed")
    r={}; velocity,source=resolveKnifeVelocity(r,v(0,0,0),10,nil,nil,v(0,0,80))
    check(source=="Physics" and near(velocity.Z,80),"physical projectile velocity works without direction attributes")
    r={}; velocity=resolveKnifeVelocity(r,v(0,0,0),10,nil,nil,Vector3.zero)
    check(not velocity,"one position sample alone does not invent velocity")
    velocity,source=resolveKnifeVelocity(r,v(0,0,2),10.02,nil,nil,Vector3.zero)
    check(source=="Sampled" and near(velocity.Z,100),"anchored visual movement supplies velocity when replicated attributes are absent")
    velocity,source=resolveKnifeVelocity(r,v(0,0,2),10.021,nil,nil,Vector3.zero)
    check(source=="Recent sample" and near(velocity.Z,100),"an immediate pre-move recheck can reuse the recent motion sample")
    velocity=resolveKnifeVelocity(r,v(0,0,2),10.04,nil,nil,Vector3.zero)
    check(not velocity,"observed stationary knife invalidates previously moving sample")
    r={}; resolveKnifeVelocity(r,v(0,0,0),10,nil,nil,Vector3.zero)
    velocity=resolveKnifeVelocity(r,v(0,0,100),10.01,nil,nil,Vector3.zero)
    check(not velocity,"discontinuous visual movement cannot become an impossible velocity")
    velocity=resolveKnifeVelocity({},v(0,0,0),10,v(0/0,0,0),0/0,v(0,0,50))
    check(velocity and velocity.Z==50,"invalid replicated motion falls back to finite physics velocity")
    check(not resolveKnifeVelocity({},v(0/0,0,0),10,v(0,0,1),96,Vector3.zero),"invalid world position is rejected")
end
do
    local f=fixture()
    local teleportChecks=f.Checks
    local primary={Parent=true}
    local dodge={Tracked={[primary]={}}}
    local state={PrimaryIncoming=true,Motions={[primary]=incoming()}}
    local teleportCommit={}
    local function projectileMotion(projectile)
        local motion=state.Motions[projectile]
        return motion and motion.Position,motion and motion.Velocity
    end
    local function threat() return state.PrimaryIncoming and {} or nil end
    -- INSERT_RUNTIME_SAFE
    local action=f.Plan(); action.Projectile=primary
    check(teleportCommit.Safe(f.Ctx,action),"real runtime recheck accepts a supported clear route while primary knife remains incoming")
    primary.Parent=nil
    check(not teleportCommit.Safe(f.Ctx,action),"removed primary knife cancels the actual runtime teleport recheck")
    primary.Parent=true; state.PrimaryIncoming=false
    check(not teleportCommit.Safe(f.Ctx,action),"knife turning away cancels the actual runtime teleport recheck")
    state.PrimaryIncoming=true
    local added={Parent=true}; dodge.Tracked[added]={}; state.Motions[added]={Position=v(action.Position.X,2,-10),Velocity=v(0,0,100)}
    check(not teleportCommit.Safe(f.Ctx,action),"freshly observed second knife invalidates the runtime destination before movement")
    dodge.Tracked[added]=nil; f.Wall=true
    check(not teleportCommit.Safe(f.Ctx,action),"newly blocked route fails the actual runtime recheck")
end
print(passed.." side dodge assertions passed")
