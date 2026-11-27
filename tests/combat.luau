local passed = 0
local function check(value, message)
    assert(value, message)
    passed += 1
    print("PASS: " .. message)
end
local vectorMeta = {}
local function vec(x) return setmetatable({X=x,Y=0,Z=0,Kind="Vector3"},vectorMeta) end
vectorMeta.__sub = function(a,b) return vec(a.X-b.X) end
vectorMeta.__add = function(a,b) return vec(a.X+b.X) end
vectorMeta.__mul = function(a,b) return vec(a.X*b.X) end
vectorMeta.__eq = function(a,b) return a.X==b.X end
vectorMeta.__index = function(v,k) if k=="Magnitude" then return math.abs(v.X) end end
local function frame(x) return {Position=vec(x),Kind="CFrame"} end
local function typeof(v) return type(v)=="table" and v.Kind or type(v) end
local now=10
local os={clock=function() return now end}

do
    local workspace={}
    -- INSERT_HIT_CLASSIFIERS
    local character={Parent=workspace,IsA=function(_,name) return name=="Model" end,
        FindFirstChildOfClass=function(_,name) return name=="Humanoid" and {} or nil end}
    local tool={Parent=character,IsA=function(_,name) return name=="Tool" end}
    local function part(parent)
        return {Kind="Instance",Parent=parent,IsA=function(_,name) return name=="BasePart" end}
    end
    local torso,knifeHandle,mapPart=part(character),part(tool),part(workspace)
    check(isDirectBodyHit(torso,character),"direct torso hit counts as a body hit")
    check(not isDirectBodyHit(knifeHandle,character),"equipped knife handle is not a body hit")
    check(isCharacterEquipmentPart(knifeHandle),"equipped character weapon is not learned as map cover")
    check(not isCharacterEquipmentPart(mapPart),"map geometry may still be learned as cover")
end

do
    local State={Config={Ping=0.04}}
    -- INSERT_KNIFE_INTERCEPT
    -- INSERT_AIM_DELAY
    check(math.abs(State.AimNetworkDelay()-0.02)<1e-8,"20 ms one-way lead from 40 ms round-trip ping")
    check(math.abs(State.AimNetworkDelay(0.10)-0.05)<1e-8,"knife and gun use the same half-RTT estimate")
    check(State.AimNetworkDelay(0/0)==0,"non-finite ping never poisons target prediction")
    check(State.AimNetworkDelay(-1)==0,"negative ping is rejected")
    check(math.abs(State.AimNetworkDelay(1)-0.075)<1e-8,"implausible RTT stays within conservative bounds")
    local target={ReceiveAge=.1}
    local knifeDelay,knifeBasis=State.AimObservationDelay(target)
    check(math.abs(knifeDelay-.1)<1e-6 and knifeBasis=="ObservedAge",
        "knife intercept includes target replication age rather than using ping alone")
    local function moving(t) return vec(20+16*t) end
    local oldLead=solveIntercept(moving,vec(0),96,State.AimNetworkDelay(),8)
    local knifeLead=solveIntercept(moving,vec(0),96,knifeDelay,8)
    check(knifeLead and oldLead and math.abs(knifeLead-.37)<.0001 and knifeLead>oldLead+.09,
        "knife flight solution leads running targets further when their data is already old")
    local refinedPoint,refinedLead=refineKnifeIntercept(moving,vec(2),vec(0),96,knifeDelay,knifeLead,8)
    check(refinedPoint and refinedLead and math.abs(refinedLead-.395)<.0001
        and math.abs(refinedPoint.X-(22+16*refinedLead))<.0001,
        "offset knife aim refinement uses the same replication-aware delay as its initial intercept")
    local xyzMeta={}
    local function xyz(x,y,z) return setmetatable({X=x,Y=y,Z=z},xyzMeta) end
    xyzMeta.__add=function(a,b) return xyz(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
    xyzMeta.__sub=function(a,b) return xyz(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
    xyzMeta.__index=function(v,key)
        if key=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
    end
    local launch=xyz(0,3,0)
    local function jumping(t)
        return xyz(20+16*t,math.max(3,3+48*t-98.1*t*t),0)
    end
    local jumpLead=solveIntercept(jumping,launch,96,knifeDelay,8)
    check(jumpLead and jumpLead>knifeDelay and jumpLead<.9
        and math.abs((jumping(jumpLead)-launch).Magnitude-96*(jumpLead-knifeDelay))<.001,
        "knife interception solves a running target with a rising, falling and landing jump trajectory")
    local elevatedPoint,elevatedLead=refineKnifeIntercept(jumping,xyz(0,1,0),launch,96,knifeDelay,jumpLead,8)
    check(elevatedLead and elevatedPoint and math.abs((elevatedPoint-launch).Magnitude-96*(elevatedLead-knifeDelay))<.03,
        "3D jump interception preserves the offset target hit location")
    check(State.AimObservationDelay({ReceiveAge=.4})==nil,
        "knife aim refuses to extrapolate stale physics snapshots")
    knifeDelay,knifeBasis=State.AimObservationDelay({})
    check(math.abs(knifeDelay-.02)<1e-8 and knifeBasis=="PingOnly",
        "knife aim falls back to ping when no receive-age data is available")
    local moving={ReceiveAge=.1}
    local expected=.02+.1*.8
    local lead,source=State.GunPredictionLead(moving,{Stationary=false})
    check(math.abs(lead-expected)<1e-6 and source=="ObservedAge",
        "moving targets use observed physics age in addition to network transit delay")
    check(State.GunPredictionLead(moving,{Stationary=true})==0,
        "stable grounded targets retain zero lead regardless of packet age")
    check(State.GunPredictionLead({ReceiveAge=.3},{Stationary=false})==nil,
        "stale target replication cannot be extrapolated into blind automatic shots")
    lead=State.GunPredictionLead({ReceiveAge=.14},{Stationary=false})
    check(lead<=.16 and lead>.1,"late moving targets are predicted within a bounded horizon")
    lead,source=State.GunPredictionLead({},nil)
    check(math.abs(lead-.02)<1e-8 and source=="PingOnly",
        "missing receive-age data retains the original ping-only fallback")
    local function rigFrame(x)
        local result=frame(x)
        function result:PointToObjectSpace(point) return vec(point.X-self.Position.X) end
        function result:PointToWorldSpace(point) return vec(point.X+self.Position.X) end
        return result
    end
    check(State.GunMuzzleFollowsRig(rigFrame(0),rigFrame(.5),vec(0),vec(.5),vec(25),.025),
        "legitimate moving shooter's muzzle can follow its rig during the second scan")
    local turning=frame(0)
    function turning:PointToWorldSpace(point) return vec(-point.X) end
    check(State.GunMuzzleFollowsRig(rigFrame(0),turning,vec(1),vec(-1),vec(0),.016),
        "180-degree spin is accepted when the muzzle follows the real rig rotation")
    check(not State.GunMuzzleFollowsRig(rigFrame(0),rigFrame(5),vec(0),vec(5),vec(25),.025),
        "large teleport-like muzzle movement cannot be passed as ordinary walking")
    check(not State.GunMuzzleFollowsRig(rigFrame(0),rigFrame(.5),vec(0),vec(1.5),vec(25),.025),
        "unexpected attachment displacement is rejected despite plausible root motion")
    check(not State.GunMuzzleFollowsRig(rigFrame(0),rigFrame(.5),vec(0),vec(.5),vec(0),.025),
        "unexplained movement cannot be justified by a stationary character")
end

do
    local projected,visible={X=30,Y=40,Z=1},true
    local camera={CFrame={Position=vec(0)},ViewportSize={X=800,Y=600},WorldToViewportPoint=function() return projected,visible end}
    local workspace={CurrentCamera=camera}
    local State={}
    local cameraBlocked=false
    local function clearPath() return not cameraBlocked end
    -- INSERT_SCREEN
    check(State.IsAimPointOnScreen(vec(1)),"visible forward point is accepted")
    check(State.IsAimPointOnScreen(vec(1),{}),"camera line of sight accepts a visible clear body point")
    cameraBlocked=true
    check(not State.IsAimPointOnScreen(vec(1),{}),"a body point hidden from the camera is rejected")
    cameraBlocked=false
    visible=false; check(not State.IsAimPointOnScreen(vec(1)),"offscreen projection is rejected")
    visible=true; projected.Z=-1; check(not State.IsAimPointOnScreen(vec(1)),"behind-camera point is rejected")
    projected.Z=1; projected.X=800; check(not State.IsAimPointOnScreen(vec(1)),"right viewport edge is outside")
    projected.X=30; projected.Y=600; check(not State.IsAimPointOnScreen(vec(1)),"bottom viewport edge is outside")
    projected.Y=40; projected.X=-1; check(not State.IsAimPointOnScreen(vec(1)),"negative viewport coordinates are rejected")
    check(not State.IsAimPointOnScreen(vec(0/0)),"nonfinite aim point is rejected")
    check(not State.IsAimPointOnScreen(vec(math.huge)),"infinite aim point is rejected")
    workspace.CurrentCamera=nil; check(not State.IsAimPointOnScreen(vec(1)),"missing camera fails closed")
end

do
    local State={Config={MaxRange=1000}}
    local player={}
    local hitPartNames={Gun={"Torso"},Knife={"Torso"}}
    local hitOffsets={vec(0),vec(1)}
    local Vector3={zero=vec(0)}
    local part={CFrame={Position=vec(10),VectorToWorldSpace=function(_,v) return v end},
        Size=vec(1),Transparency=0,CanQuery=true,IsA=function() return true end}
    local root={CFrame=part.CFrame,Size=vec(1),Transparency=1,CanQuery=true,IsA=function() return true end}
    local char={FindFirstChild=function(_,name)
        if name=="Torso" then return part end
        if name=="HumanoidRootPart" then return root end
    end}
    local camera={WorldToViewportPoint=function(_,v) return {X=v.X,Y=0,Z=1},v.X==10 end}
    -- INSERT_RELIABLE_GUN_HELPER
    -- INSERT_VISIBLE
    local _,normal=visibleBodySamples(char,"Gun",vec(0),camera,nil,{Core=false},true)
    local _,screen=visibleBodySamples(char,"Gun",vec(0),camera,nil,{Core=false},true,true)
    check(#normal.Torso.Samples==2,"manual sampling keeps its existing offscreen option")
    check(#screen.Torso.Samples==1 and screen.Torso.Samples[1].Visible,
        "screen-only policy filters samples before target prediction even with all-direction selection")
    local _,missing=visibleBodySamples(char,"Gun",vec(0),nil,nil,{Core=false},true,true)
    check(#missing.Torso.Samples==0,"screen-only selection cannot acquire without a camera")
    local _,realBody=visibleBodySamples(char,"Gun",vec(0),camera,nil,{Core=true},true)
    check(realBody.HumanoidRootPart==nil and realBody.Torso~=nil,
        "gun aim cannot treat the native fully transparent root as a shootable body target")
    table.insert(hitPartNames.Gun,"RightUpperArm")
    local _,centralOnly=visibleBodySamples(char,"Gun",vec(0),camera,nil,{Core=false},true)
    check(centralOnly.Torso~=nil and centralOnly.RightUpperArm==nil,
        "gun aim does not spend scans or assisted shots on narrow moving arm targets")
    part.Transparency=1
    local _,invisible=visibleBodySamples(char,"Gun",vec(0),camera,nil,{Core=true},true)
    check(invisible.Torso==nil and invisible.HumanoidRootPart==nil,
        "fully transparent avatar parts cannot supply false-positive gun hitbox samples")
end

do
    local State={Config={ConservativeGun=true}}
    local Vector3={zero=vec(0)}
    local blockedX=nil
    local rays=0
    local function sampleRayHitsBody(origin) rays+=1; return origin.X~=blockedX end
    -- INSERT_TIMING
    local shifts=State.GunTimingShifts(function(t) return vec(t*100) end,.04,vec(0))
    check(#shifts==5 and math.abs(shifts[1].X-2.4)<.00001 and math.abs(shifts[3].X-4)<.00001
        and math.abs(shifts[5].X-5.6)<.00001,
        "conservative mode tests a centered bounded arrival window instead of an implausible double-latency sample")
    local coverage,passes=gunTimingCoverage(vec(0),vec(10),shifts,{})
    check(coverage==1 and passes==5,"conservative mode accepts all five intersecting timing samples")
    blockedX=-shifts[5].X
    coverage,passes=gunTimingCoverage(vec(0),vec(10),shifts,{})
    check(coverage==0 and passes==4,"one failed timing hypothesis rejects conservative aim point")
    State.Config.ConservativeGun=false
    coverage,passes=gunTimingCoverage(vec(0),vec(10),shifts,{})
    check(coverage>0 and coverage<1 and passes==4,"standard mode retains partial coverage ranking")
    check(#State.GunTimingShifts(function(t) return vec(t) end,.04,vec(0))==3,
        "standard mode retains the original three timing samples")
    local normal=State.GunTimingShifts(function(t) return vec(t*100) end,.04,vec(0))
    check(math.abs(normal[2].X-4)<.00001 and normal[1].X<normal[2].X and normal[3].X>normal[2].X,
        "standard aim samples around estimated arrival, not the outdated current target position")
    State.Config.ConservativeGun=true; blockedX=nil
    shifts=State.GunTimingShifts(function() return vec(0) end,0,vec(0))
    rays=0
    check(gunTimingCoverage(vec(0),vec(10),shifts,{})==1,"stationary targets remain eligible")
    check(rays==1,"five identical timing samples reuse one ray test")
    rays=0; blockedX=0
    check(gunTimingCoverage(vec(0),vec(10),shifts,{})==0 and rays==1,
        "conservative mode stops after its first failed hypothesis")
    local latest=0
    State.GunTimingShifts(function(t) latest=math.max(latest,t); return vec(t) end,.15,vec(0))
    check(latest<=.2,"high-ping timing hypotheses remain bounded")
    check(gunPartAimPriority("Gun","UpperTorso",{}) > gunPartAimPriority("Gun","LeftLowerArm",{})
        and gunPartAimPriority("Gun","Torso",{}) > gunPartAimPriority("Gun","LeftUpperLeg",{}),
        "assisted gun shots favor exposed center mass over small limb targets")
    check(gunPartAimPriority("Gun","HumanoidRootPart",{Core=true})
        > gunPartAimPriority("Gun","UpperTorso",{Core=true})
        and gunPartAimPriority("Gun","Head",{}) > gunPartAimPriority("Gun","RightFoot",{}),
        "validated core and head are preferred to limbs in their eligible cases")
    check(gunPartAimPriority("Knife","UpperTorso",{})>gunPartAimPriority("Knife","Head",{})
        and gunPartAimPriority("Knife","Head",{})>gunPartAimPriority("Knife","RightFoot",{})
        and gunPartAimPriority("Knife","RightLowerLeg",{})==0,
        "knife target selection prioritizes torso and head instead of feet and floor-level limbs")
    local original={"UpperTorso","Head","LeftUpperArm","LowerTorso","RightLowerLeg"}
    local movingRoot={AssemblyLinearVelocity={Y=48}}
    check(State.GunAutoPartNames(original,movingRoot,true)[1]=="UpperTorso"
        and #State.GunAutoPartNames(original,movingRoot,true)==2,
        "automatic jumping shots ignore fast-moving limbs and prefer the torso")
    movingRoot.AssemblyLinearVelocity={Y=0}
    check(State.GunAutoPartNames(original,movingRoot,true)==original,
        "grounded automatic targets retain all candidate body parts")
    movingRoot.AssemblyLinearVelocity={Y=-35}
    check(State.GunAutoPartNames(original,movingRoot,false)==original,
        "manual aim keeps its existing partial-body targeting during jumps")
end

do
    local State={Performance={MotionSweeps=0},Motion={}}
    local Players={GetPlayers=function() return {} end}
    -- INSERT_MOTION
    sampleMotion(10)
    for i=1,5 do sampleMotion(10+i*.003) end
    check(State.Performance.MotionSweeps==1,"motion sampling skips redundant high-FPS roster walks")
    sampleMotion(10.021)
    check(State.Performance.MotionSweeps==2,"motion sampling resumes at the recording interval")
    sampleMotion(10.022,true)
    check(State.Performance.MotionSweeps==3,"attack-time sampling bypasses the throttle")
    sampleMotion(1)
    check(State.Performance.MotionSweeps==4,"clock rollback cannot freeze motion sampling")
end

do
    local State={Config={ConservativeGun=true,KnifeAllDirections=true,KnifeAim=true},
        Performance={PreviewCacheHits=0},Stats={AimCalls=0,Redirects=0,KnifeRedirects=0},ExclusionsRevision=0}
    local player={Character={}}
    local targetPlayer={Character={},Role="Murderer",Name="Target"}
    local function alive(p) return not p.Dead end
    local function roleFor(p) return p.Role end
    State.IsCombatTarget=function(kind,p) return kind=="Gun" and roleFor(p)=="Murderer" or kind=="Knife" and roleFor(p)~="Murderer" end
    State.CanUseCombatWeapon=function(kind) return kind=="Knife" and roleFor(player)=="Murderer" end
    State.IsPlayerExcluded=function(p) return p.Excluded end
    State.RememberAimTarget=function() end
    local selected,scans=nil,0
    local seenScreenPolicy
    local function chooseTarget(_,_,_,_,_,onScreenOnly) scans+=1; seenScreenPolicy=onScreenOnly; return selected end
    local item={}
    local function snapshot() return {Player=targetPlayer,Character=targetPlayer.Character,Position=vec(10)} end
    selected=snapshot()
    -- INSERT_PREVIEW
    State.GetCachedAimPreview("Gun",item,vec(0))
    now+=.2; State.GetCachedAimPreview("Gun",item,vec(0))
    now+=.2; State.GetCachedAimPreview("Gun",item,vec(0))
    check(scans==1 and State.Performance.PreviewCacheHits==2,"gun HUD reuses preview across status ticks")
    now+=.2; State.GetCachedAimPreview("Gun",item,vec(0))
    check(scans==2,"expired preview performs a fresh scan")
    targetPlayer.Character={}; selected=snapshot(); State.GetCachedAimPreview("Gun",item,vec(0))
    check(scans==3,"target respawn invalidates preview")
    State.ExclusionsRevision+=1; State.GetCachedAimPreview("Gun",item,vec(0))
    check(scans==4,"exclusion changes invalidate preview")
    State.Config.ConservativeGun=false; State.GetCachedAimPreview("Gun",item,vec(0))
    check(scans==5,"timing policy changes invalidate preview")
    player.Character={}; State.GetCachedAimPreview("Gun",item,vec(0))
    check(scans==6,"own respawn invalidates preview")
    targetPlayer.Dead=true; selected=nil; State.GetCachedAimPreview("Gun",item,vec(0))
    check(scans==7,"dead target invalidates preview")
    State.GetCachedAimPreview("Gun",item,vec(0))
    check(scans==7,"no-target previews also avoid repeated expensive scans")
    targetPlayer.Dead=false; selected=snapshot()
    local CFrame={new=function(p) return {Position=p} end}
    local forced=false
    local function sampleMotion(_,force) forced=force end
    local function shotOrigin() return vec(0) end
    -- INSERT_AIMPOINT
    local _,name=aimPoint({Kind="Gun",Item=item})
    check(scans==8 and name=="Target" and forced,"attack bypasses stale empty HUD cache and forces fresh motion")
    State.Config.PerformancePreset="Low effects"; State.PreviewCache=nil
    State.GetCachedAimPreview("Gun",item,vec(0)); local before=scans
    now+=.6; State.GetCachedAimPreview("Gun",item,vec(0))
    check(scans==before,"low effects reuses visual previews beyond the normal half-second lifetime")
    aimPoint({Kind="Gun",Item=item})
    check(scans==before+1,"actual aim remains fresh under the low-effects preset")
    aimPoint({Kind="Gun",Item=item},nil,false,vec(0),true)
    check(seenScreenPolicy==true,"aim point forwards screen-only selection policy")
    State.PreviewCache=nil;selected=nil
    State.GetCachedAimPreview("Gun",item,vec(0))
    local mode="Classic"
    State.GameContext={Mode=function() return mode end}
    mode="Infection"; local beforeMode=scans
    State.GetCachedAimPreview("Gun",item,vec(0))
    check(scans==beforeMode+1,"mode change invalidates a cached empty target immediately")
    now=10
end

do
    local State={Config={StabAssist=true,KnifeAim=true,RequireClearKnifeTarget=true},
        Stats={StabRequests=0,SkippedKnifeThrows=0,KnifeRequests=0},IsPlayerExcluded=function(p) return p.Excluded end}
    local function character(x)
        local char={}
        local part={Position=vec(x),IsA=function(_,k) return k=="BasePart" end}
        function char:FindFirstChild(name)
            if name=="HumanoidRootPart" or name=="UpperTorso" then return part end
        end
        return char
    end
    local player={Character=character(0),Role="Murderer"}
    local near={Name="Near",Character=character(3)}
    local far={Name="Far",Character=character(6)}
    local Players={GetPlayers=function() return {player,far,near} end}
    local function alive(p) return not p.Dead end
    local function roleFor(p) return p.Role end
    State.IsCombatTarget=function(kind,p) return kind=="Gun" and roleFor(p)=="Murderer" or kind=="Knife" and roleFor(p)~="Murderer" end
    State.CanUseCombatWeapon=function(kind) return kind=="Knife" and roleFor(player)=="Murderer" end
    local blocked={}
    local function clearPath(_,_,char) return not blocked[char] end
    local weaponReady=true
    local function ready() return weaponReady end
    local failRemote,failAnimation=false,false
    local sends=0
    local lastOrigin
    local remote={IsA=function(_,k) return k=="RemoteEvent" end,
        FireServer=function(_,origin)
            if failRemote then error("mock send failure") end
            sends+=1; lastOrigin=origin
        end}
    local handle={CFrame=frame(0),Position=vec(0),IsA=function(_,k) return k=="BasePart" end,
        FindFirstChild=function() return nil end}
    local events={FindFirstChild=function() return remote end}
    local item={FindFirstChild=function(_,name) return name=="Events" and events or name=="Handle" and handle end,
        GetAttribute=function() return 1 end}
    local function stopTracks() end
    local function playTrack() if failAnimation then error("mock animation failure") end end
    local function record()
        return {Item=item,Kind="Knife",LastStab=-math.huge,LastThrow=-math.huge,ThrowToken=0,StabbingUntil=0}
    end
    -- INSERT_STAB
    check(State.SelectStabAssistTarget()==near,"clicked stab chooses nearest eligible opponent")
    near.Excluded=true
    check(State.SelectStabAssistTarget()==far,"clicked stab skips excluded opponents")
    near.Excluded=false; blocked[near.Character]=true
    check(State.SelectStabAssistTarget()==far,"clicked stab skips blocked opponents")
    blocked[near.Character]=nil; near.Dead=true
    check(State.SelectStabAssistTarget()==far,"clicked stab skips dead opponents")
    near.Dead=false; near.Character=character(7); far.Character=character(8)
    check(State.SelectStabAssistTarget()==nil,"clicked stab does not exceed 6.5 studs")
    near.Character=character(3); far.Character=character(6)
    player.Role="Sheriff"
    check(State.SelectStabAssistTarget()==nil,"clicked stab assist requires murderer role")
    player.Role="Murderer"; State.Config.StabAssist=false
    check(State.SelectStabAssistTarget()==nil,"clicked stab assist toggle works")
    State.IsAimPointOnScreen=function(point) return point.X==6 end
    check(State.SelectStabAssistTarget(true,true)==far,"automatic stab selects a visible target without requiring the click-assist toggle")
    far.Role="Murderer"
    check(State.SelectStabAssistTarget(true,true)==nil,"automatic stab skips other murderers instead of blocking eligible selection")
    far.Role=nil
    State.IsAimPointOnScreen=function() return false end
    check(State.SelectStabAssistTarget(true,true)==nil,"automatic stab never selects an offscreen body part")
    State.Config.StabAssist=true
    local r=record()
    failRemote=true
    check(not stabKnife(r,near) and r.LastStab==-math.huge and State.Stats.StabRequests==0,
        "failed stab request does not consume cooldown")
    failRemote=false; failAnimation=true
    check(stabKnife(r,near) and r.StabTarget==near,"animation failure does not prevent accepted stab")
    check(not stabKnife(r,far) and r.StabTarget==near and sends==1,
        "cooldown click preserves active stab target and sends no duplicate")
    failAnimation=false
    r=record(); r.LastThrow=now-1.99
    check(not stabKnife(r,near) and sends==1 and r.LastStab==-math.huge,
        "released knife cooldown prevents premature stab without consuming stab cooldown")
    r.LastThrow=now-2
    check(stabKnife(r,near) and sends==2,"stab becomes available at native throw cooldown boundary")
    r=record(); r.LastThrow=now; r.Charging=true
    check(stabKnife(r,near) and not r.Charging and r.LastThrow==-math.huge,
        "click can still cancel an unsent charge and stab")

    local jobs={}
    local task={spawn=function(f) table.insert(jobs,f) end,wait=function() end}
    local acquired,releaseTarget,releaseLost=near,near,false
    local seenStrict,seenOrigin,seenOnScreen,throwMove,throwAimCalls
    local function chooseTarget()
        return acquired and {Player=acquired,Character=acquired.Character}
    end
    local weapon={GetMouseTargetCFrame=function() return frame(30) end}
    local function aimPoint(_,preferred,strict,origin,onScreenOnly)
        seenStrict,seenOrigin,seenOnScreen=strict,origin,onScreenOnly
        throwAimCalls=(throwAimCalls or 0)+1
        if throwMove then
            local shift=type(throwMove)=="table" and table.remove(throwMove,1) or throwMove
            if shift then
                handle.CFrame=frame(shift)
                handle.Position=vec(shift)
            end
            if type(throwMove)~="table" or #throwMove==0 then throwMove=nil end
        end
        if not State.Config.KnifeAim then return frame(30) end
        if releaseLost then return nil end
        local target=strict and preferred or releaseTarget
        if not target then return nil end
        return frame(3),target.Name,{Player=target,Character=target.Character}
    end
    local excludedPath=false
    State.ExcludedPlayerInShotPath=function() return excludedPath end
    local contacts=0
    local function reportStabContact(_,_,source)
        assert(source=="ClickedStabAssist"); contacts+=1
    end
    local floorHit
    local workspace={Raycast=function()
        if floorHit=="error" then error("map is streaming") end
        return floorHit
    end}
    local RaycastParams={new=function() return {} end}
    local Enum={RaycastFilterType={Exclude="Exclude"}}
    local xyzMeta={}
    local function xyz(x,y,z) return setmetatable({X=x,Y=y,Z=z,Kind="Vector3"},xyzMeta) end
    xyzMeta.__sub=function(a,b) return xyz(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
    xyzMeta.__add=function(a,b) return xyz(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
    xyzMeta.__index=function(a,k)
        if k=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
    end
    local Vector3={new=xyz}
    local CFrame={new=function(point) return {Position=point,Kind="CFrame"} end}
    -- INSERT_THROW
    local ground=Vector3.new(30,0,0)
    local origin=Vector3.new(0,4,0)
    local corrected,raised=State.KnifeCursorFloorCorrection(origin,ground,0,1)
    check(raised and corrected.Y==3 and corrected.X==30,
        "manual cursor fallback lifts a nearby level-floor hit toward torso height")
    local ledge,ledgeRaised=State.KnifeCursorFloorCorrection(Vector3.new(0,20,0),ground,0,1)
    check(not ledgeRaised and ledge==ground,
        "downward throws from a high ledge stay aligned with the native cursor")
    local slope,slopeRaised=State.KnifeCursorFloorCorrection(origin,ground,0,.2)
    check(not slopeRaised and slope==ground,"steep ground aim is not forced upward")
    local airborne,airborneRaised=State.KnifeCursorFloorCorrection(origin,ground,4,1)
    check(not airborneRaised and airborne==ground,"a non-grounded cursor aim is not changed")
    local function release()
        local f=table.remove(jobs,1)
        assert(f,"missing charge job"); f()
    end
    sends=0; acquired=nil; releaseTarget=nil; releaseLost=true
    r=record()
    check(startThrow(r) and #jobs==1 and r.Charging,
        "manual right-click can charge a knife even without a clear assisted target")
    check(r.ThrowTargetUserId==nil,"manual throw never pins a player during its charge")
    release()
    check(sends==1 and State.LastRequest.ManualFallback and State.LastRequest.Target==nil,
        "manual throw without an assisted target releases toward the player's cursor")
    local beforeFloorSends=sends
    handle.CFrame=CFrame.new(origin);handle.Position=origin;floorHit={Position=ground,Normal=Vector3.new(0,1,0)}
    r=record();startThrow(r);release()
    check(sends==beforeFloorSends+1 and State.LastRequest.FloorCorrected and State.LastRequest.Position.Y==3,
        ("manual throw lifts floor fallback [sends=%s changed=%s y=%s feedback=%s]"):format(sends,tostring(State.LastRequest.FloorCorrected),tostring(State.LastRequest.Position.Y),tostring(State.KnifeFeedback and State.KnifeFeedback.Message)))
    floorHit="error"
    r=record();startThrow(r);release()
    check(sends==beforeFloorSends+2 and State.LastRequest.ManualFallback
        and not State.LastRequest.FloorCorrected,
        "map streaming errors during optional floor check do not cancel a manual throw")
    floorHit=nil;handle.CFrame=frame(0);handle.Position=vec(0)
    sends=beforeFloorSends
    r=record(); startThrow(r); excludedPath=true; release(); excludedPath=false
    check(sends==1 and not r.Charging and r.LastThrow==-math.huge,
        "manual cursor fallback still refuses shots crossing an excluded player")
    r=record(); releaseLost=false; releaseTarget=nil
    startThrow(r); releaseTarget=far; release()
    check(sends==2 and not State.LastRequest.ManualFallback and State.LastRequest.Target==far.Name
        and seenStrict==false and seenOnScreen==true,
        "manual charge selects a fresh eligible aim candidate only at release")
    r=record(); throwMove={1,2}; throwAimCalls=0; releaseTarget=near
    startThrow(r); release()
    check(sends==3 and throwAimCalls==3 and not State.LastRequest.ManualFallback
        and State.LastRequest.Target==near.Name and lastOrigin.Position.X==2 and seenOnScreen==true,
        "manual throw re-aims from repeated moving origins and keeps a clear torso target")
    r=record(); throwMove={1,2,3}; throwAimCalls=0
    startThrow(r);release()
    check(sends==4 and throwAimCalls==3 and State.LastRequest.ManualFallback
        and lastOrigin.Position.X==3,
        "continuous movement still falls back to native cursor after bounded re-aims")
    handle.CFrame=frame(0); handle.Position=vec(0)
    sends=0
    r=record()
    check(not startThrow(r,near,true) and #jobs==0 and r.LastThrow==-math.huge,
        "automated target-locked throws still require a clear target before charging")
    acquired=near; releaseTarget=near; releaseLost=true; r=record()
    startThrow(r); release()
    check(sends==1 and State.LastRequest.ManualFallback and not r.Charging,
        "manual charge uses native cursor when a previously selectable target disappears")
    releaseLost=false; releaseTarget=far; r=record()
    startThrow(r); release()
    check(sends==2 and not seenStrict and State.LastRequest.Target==far.Name and seenOrigin==lastOrigin.Position,
        "manual release is not forced to the target present when the charge started")
    sends=0; r=record(); releaseTarget=far
    startThrow(r,near,true); release()
    check(sends==1 and seenStrict and State.LastRequest.Target==near.Name and seenOrigin==lastOrigin.Position,
        "strict automated throw remains locked to its originally selected target")
    r=record(); throwMove=1; throwAimCalls=0; startThrow(r,near,true); release()
    check(sends==2 and throwAimCalls==2 and lastOrigin.Position.X==1 and seenOrigin==lastOrigin.Position,
        "moving thrower reaims once from the real release origin before sending")
    sends=1; handle.CFrame=frame(0); handle.Position=vec(0)
    r=record(); throwMove={1,2}; throwAimCalls=0; startThrow(r,near,true); release()
    check(sends==1 and throwAimCalls==2 and not r.Charging and r.LastThrow==-math.huge,
        "multiple moving-origin shifts cancel a stale throw rather than sending a bad trajectory")
    handle.CFrame=frame(0); handle.Position=vec(0)
    r=record(); startThrow(r,near,true); near.Character=character(3); release()
    check(sends==1 and not r.Charging,"target respawn cancels charged throw")
    r=record(); startThrow(r,near,true); near.Dead=true; release(); near.Dead=false
    check(sends==1,"target death cancels charged throw")
    r=record(); startThrow(r,near,true); near.Excluded=true; release(); near.Excluded=false
    check(sends==1,"target exclusion cancels charged throw")
    r=record(); startThrow(r,near,true); blocked[near.Character]=true; release(); blocked[near.Character]=nil
    check(sends==1,"new obstruction cancels charged throw")
    r=record(); startThrow(r,near,true); State.Config.KnifeAim=false; release()
    check(sends==1,"disabling prediction cancels a protected charge")
    r=record()
    check(not startThrow(r,near,true),"selected-target automation requires prediction")
    startThrow(r); release()
    check(sends==2 and State.LastRequest.Target==nil,"prediction off retains manual throwing")
    State.Config.KnifeAim=true; State.Config.RequireClearKnifeTarget=false
    acquired=nil; releaseLost=true; r=record(); startThrow(r); release()
    check(sends==3 and State.LastRequest.ManualFallback,"explicit fallback setting allows cursor throwing")
    State.Config.RequireClearKnifeTarget=true; releaseLost=false; releaseTarget=near
    r=record(); blocked[near.Character]=true; startThrow(r); release(); blocked[near.Character]=nil
    check(sends==4 and State.LastRequest.ManualFallback,
        "manual throw falls back to cursor if the release-time assisted path became obstructed")
    sends=3
    State.Config.RequireClearKnifeTarget=true; acquired=near; releaseLost=false
    r=record(); startThrow(r); excludedPath=true; release(); excludedPath=false
    check(sends==3,"excluded player in path cancels throw")
    r=record(); startThrow(r); weaponReady=false; release(); weaponReady=true
    check(sends==3,"unequip cancels throw")
    r=record(); startThrow(r); r.ThrowToken+=1; release()
    check(sends==3,"cancelled charge token cannot release")
    r=record(); startThrow(r); failRemote=true; release(); failRemote=false
    check(sends==3 and not r.Charging and r.LastThrow==-math.huge,"throw send failure releases charge and cooldown")
    r=record(); startThrow(r,near,true,function() return false end); release()
    check(sends==3 and not r.Charging and r.LastThrow==-math.huge,"stopping automatic action cancels its deferred throw before sending")
    r=record(); clickKnife(r)
    check(contacts==1 and r.StabTarget==near,"manual click requests one selected stab contact")
    clickKnife(r)
    check(contacts==1,"cooldown click does not repeat assisted contact")
end

do
    local State={Config={MagicBullet=true},Stats={SkippedGunShots=0,GunRequests=0},PendingGun={}}
    -- INSERT_MUZZLE
    local attachment={WorldPosition=vec(0),WorldCFrame=frame(0)}
    local root={FindFirstChild=function() return attachment end}
    local own={FindFirstChild=function(_,name) return name=="HumanoidRootPart" and root end}
    local player={Character=own}
    local target={Name="Murderer",Character={}}
    local Players={FindFirstChild=function() return target end}
    local function alive() return true end
    local function roleFor() return "Murderer" end
    State.IsCombatTarget=function(kind,p) return kind=="Gun" and roleFor(p)=="Murderer" or kind=="Knife" and roleFor(p)~="Murderer" end
    State.CanUseCombatWeapon=function(kind) return kind=="Knife" and roleFor(player)=="Murderer" end
    local function ready() return true end
    local function clearPath() return true end
    State.IsPlayerExcluded=function() return false end
    State.ExcludedPlayerInShotPath=function() return false end
    local payloadOrigin,predictionOrigin
    local calls,move=0,0
    local movingRig=false
    local function movingFrame(x)
        local result=frame(x)
        function result:PointToObjectSpace(point) return vec(point.X-self.Position.X) end
        function result:PointToWorldSpace(point) return vec(point.X+self.Position.X) end
        return result
    end
    local coverage,passes=1,5
    local seenScreenPolicy
    local assisted,blockedManual=true,false
    local weapon={GetMouseTargetCFrame=function() return frame(13) end}
    local bodyVisible,leadVisible=true,true
    State.IsAimPointOnScreen=function(point) return point and (point.X==9 and bodyVisible or point.X==10 and leadVisible) end
    local function aimPoint(_,_,_,origin,onScreenOnly)
        seenScreenPolicy=onScreenOnly
        calls+=1; predictionOrigin=origin
        if not assisted then return nil,nil,nil end
        attachment.WorldPosition=vec(attachment.WorldPosition.X+move)
        attachment.WorldCFrame=frame(attachment.WorldPosition.X)
        if movingRig then
            now+=.025
            root.Position=attachment.WorldPosition
            root.CFrame=movingFrame(root.Position.X)
            root.AssemblyLinearVelocity=vec(25)
        end
        return frame(10),target.Name,{Player=target,Character=target.Character,BodyPoint=vec(9),TimingCoverage=coverage,TimingPassed=passes}
    end
    local remote={IsA=function(_,kind) return kind=="RemoteEvent" end,
        FireServer=function(_,origin) payloadOrigin=origin.Position end}
    local item={Enabled=true,FindFirstChild=function() return remote end}
    local function record() return {Item=item,LastGun=-math.huge} end
    -- INSERT_PENDING_ACCOUNTING
    -- INSERT_GUN
    move=.1
    check(sendGun(record()) and payloadOrigin==predictionOrigin and State.PendingGun[1].Origin==payloadOrigin,
        "gun prediction, pending record and payload share the sampled origin")
    move=1; calls=0; payloadOrigin=nil
    check(not sendGun(record()) and calls==2 and payloadOrigin==nil,
        "repeated muzzle movement cancels after one recalculation")
    move=.4; movingRig=true; calls=0; payloadOrigin=nil
    root.Position=attachment.WorldPosition; root.CFrame=movingFrame(root.Position.X)
    root.AssemblyLinearVelocity=vec(25)
    check(sendGun(record()) and calls==2 and payloadOrigin==attachment.WorldPosition
        and State.PendingGun[#State.PendingGun].Origin==payloadOrigin,
        "moving and jumping shooter uses the final real muzzle while retaining only two aim scans")
    movingRig=false
    move=0; target.Excluded=true
    State.IsPlayerExcluded=function(p) return p.Excluded end
    check(not sendGun(record()),"gun still refuses excluded targets")
    target.Excluded=false; State.Config.ConservativeGun=true; coverage=.8
    payloadOrigin=nil
    check(not sendGun(record()) and payloadOrigin==nil,"final firing gate rejects partial timing coverage")
    State.LastGunFeedback={Message="Recent server ray result",SentAt=os.clock(),TargetHit=false}
    check(not sendGun(record()) and State.LastGunFeedback.Message=="Recent server ray result"
        and State.LastGunSkip and State.LastGunSkip.Message:find("Shot skipped",1,true),
        "rejected aim checks do not erase a recent correlated gun reply in the HUD")
    State.LastGunFeedback={Message="Late correlated server reply",
        SentAt=os.clock()-5,UpdatedAt=os.clock(),TargetHit=true}
    check(not sendGun(record()) and State.LastGunFeedback.Message=="Late correlated server reply",
        "a late server reply stays visible based on receipt time, not the older request time")
    State.LastGunFeedback.UpdatedAt=os.clock()-3
    check(not sendGun(record()) and State.LastGunFeedback.Message:find("Shot skipped",1,true),
        "an outdated server reply yields to the next actual aim-rejection reason")
    coverage=1; passes=3
    check(not sendGun(record()),"final firing gate rejects incomplete conservative sampling")
    passes=5
    check(sendGun(record()),"fully sampled conservative gun solution sends")
    check(sendGun(record(),nil,false,true) and seenScreenPolicy==true and State.LastRequest.Mode=="OnScreenAssist",
        "screen-only shot uses the assisted pipeline and records its policy")
    bodyVisible=false; payloadOrigin=nil
    check(not sendGun(record(),nil,false,true) and payloadOrigin==nil,"final send cancels when body point leaves the screen")
    bodyVisible=true; leadVisible=false
    check(not sendGun(record(),nil,false,true) and payloadOrigin==nil,"final send cancels when predicted lead point leaves the screen")
    leadVisible=true; assisted=false; State.Config.ConservativeGun=true; payloadOrigin=nil
    check(sendGun(record()) and State.LastRequest.ManualFallback and State.LastRequest.Target==nil
        and State.LastRequest.Position.X==13,
        "manual gun click falls back to the native cursor if assisted targeting fails")
    payloadOrigin=nil
    check(not sendGun(record(),nil,false,true) and payloadOrigin==nil,
        "automatic triggerbot still refuses all cursor fallback shots")
    check(not sendGun(record(),target,true) and payloadOrigin==nil,
        "explicit locked target refuses cursor fallback")
    State.ExcludedPlayerInShotPath=function() return blockedManual end
    blockedManual=true
    check(not sendGun(record()) and payloadOrigin==nil,
        "manual cursor fallback cannot fire through a protected player's body")
    blockedManual=false
    check(sendGun(record()) and State.LastRequest.ManualFallback,
        "screen-only rejection does not change manual cursor fallback behavior")
end
print(string.format("%d combat assertions passed",passed))
