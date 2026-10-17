local passed = 0
local function check(value, message)
    assert(value, message)
    passed += 1
    print("PASS: " .. message)
end
local vectorMeta = {}
local function vec(x) return setmetatable({X=x,Y=0,Z=0,Kind="Vector3"},vectorMeta) end
vectorMeta.__sub = function(a,b) return vec(a.X-b.X) end
vectorMeta.__index = function(v,k) if k=="Magnitude" then return math.abs(v.X) end end
local function frame(x) return {Position=vec(x),Kind="CFrame"} end
local function typeof(v) return type(v)=="table" and v.Kind or type(v) end
local now=10
local os={clock=function() return now end}

do
    local State={Config={ConservativeGun=true}}
    local Vector3={zero=vec(0)}
    local blockedX=nil
    local function sampleRayHitsBody(origin) return origin.X~=blockedX end
    -- INSERT_TIMING
    local shifts=State.GunTimingShifts(function(t) return vec(t*100) end,.04,vec(0))
    check(#shifts==5 and math.abs(shifts[2].X-8)<.00001 and math.abs(shifts[5].X-10)<.00001,
        "conservative mode samples a wider bounded timing range")
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
    State.Config.ConservativeGun=true; blockedX=nil
    shifts=State.GunTimingShifts(function() return vec(0) end,0,vec(0))
    check(gunTimingCoverage(vec(0),vec(10),shifts,{})==1,"stationary targets remain eligible")
    local latest=0
    State.GunTimingShifts(function(t) latest=math.max(latest,t); return vec(t) end,.15,vec(0))
    check(latest<=.2,"high-ping timing hypotheses remain bounded")
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
    local seenStrict,seenOrigin
    local function chooseTarget()
        return acquired and {Player=acquired,Character=acquired.Character}
    end
    local weapon={GetMouseTargetCFrame=function() return frame(30) end}
    local function aimPoint(_,preferred,strict,origin)
        seenStrict,seenOrigin=strict,origin
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
    -- INSERT_THROW
    local function release()
        local f=table.remove(jobs,1)
        assert(f,"missing charge job"); f()
    end
    sends=0; acquired=nil
    r=record()
    check(not startThrow(r) and #jobs==0 and r.LastThrow==-math.huge,
        "protected throw without target does not charge or consume cooldown")
    acquired=near; releaseLost=true; r=record()
    startThrow(r); release()
    check(sends==0 and not r.Charging and r.LastThrow==-math.huge,
        "losing protected target cancels without cursor fallback")
    releaseLost=false; releaseTarget=far; r=record()
    startThrow(r); release()
    check(sends==1 and seenStrict and State.LastRequest.Target==near.Name and seenOrigin==lastOrigin.Position,
        "protected throw stays on charged target and uses its sampled origin")
    r=record(); startThrow(r); near.Character=character(3); release()
    check(sends==1 and not r.Charging,"target respawn cancels charged throw")
    r=record(); startThrow(r); near.Dead=true; release(); near.Dead=false
    check(sends==1,"target death cancels charged throw")
    r=record(); startThrow(r); near.Excluded=true; release(); near.Excluded=false
    check(sends==1,"target exclusion cancels charged throw")
    r=record(); startThrow(r); blocked[near.Character]=true; release(); blocked[near.Character]=nil
    check(sends==1,"new obstruction cancels charged throw")
    r=record(); startThrow(r); State.Config.KnifeAim=false; release()
    check(sends==1,"disabling prediction cancels a protected charge")
    r=record()
    check(not startThrow(r,near,true),"selected-target automation requires prediction")
    startThrow(r); release()
    check(sends==2 and State.LastRequest.Target==nil,"prediction off retains manual throwing")
    State.Config.KnifeAim=true; State.Config.RequireClearKnifeTarget=false
    acquired=nil; releaseLost=true; r=record(); startThrow(r); release()
    check(sends==3 and State.LastRequest.ManualFallback,"explicit fallback setting allows cursor throwing")
    State.Config.RequireClearKnifeTarget=true; acquired=near; releaseLost=false
    r=record(); startThrow(r); excludedPath=true; release(); excludedPath=false
    check(sends==3,"excluded player in path cancels throw")
    r=record(); startThrow(r); weaponReady=false; release(); weaponReady=true
    check(sends==3,"unequip cancels throw")
    r=record(); startThrow(r); r.ThrowToken+=1; release()
    check(sends==3,"cancelled charge token cannot release")
    r=record(); startThrow(r); failRemote=true; release(); failRemote=false
    check(sends==3 and not r.Charging and r.LastThrow==-math.huge,"throw send failure releases charge and cooldown")
    r=record(); clickKnife(r)
    check(contacts==1 and r.StabTarget==near,"manual click requests one selected stab contact")
    clickKnife(r)
    check(contacts==1,"cooldown click does not repeat assisted contact")
end

do
    local State={Config={MagicBullet=true},Stats={SkippedGunShots=0,GunRequests=0},PendingGun={}}
    local attachment={WorldPosition=vec(0),WorldCFrame=frame(0)}
    local root={FindFirstChild=function() return attachment end}
    local own={FindFirstChild=function(_,name) return name=="HumanoidRootPart" and root end}
    local player={Character=own}
    local target={Name="Murderer",Character={}}
    local Players={FindFirstChild=function() return target end}
    local function alive() return true end
    local function roleFor() return "Murderer" end
    local function ready() return true end
    local function clearPath() return true end
    State.IsPlayerExcluded=function() return false end
    State.ExcludedPlayerInShotPath=function() return false end
    local payloadOrigin,predictionOrigin
    local calls,move=0,0
    local coverage,passes=1,5
    local function aimPoint(_,_,_,origin)
        calls+=1; predictionOrigin=origin
        attachment.WorldPosition=vec(attachment.WorldPosition.X+move)
        attachment.WorldCFrame=frame(attachment.WorldPosition.X)
        return frame(10),target.Name,{Player=target,Character=target.Character,TimingCoverage=coverage,TimingPassed=passes}
    end
    local remote={IsA=function(_,kind) return kind=="RemoteEvent" end,
        FireServer=function(_,origin) payloadOrigin=origin.Position end}
    local item={Enabled=true,FindFirstChild=function() return remote end}
    local function record() return {Item=item,LastGun=-math.huge} end
    -- INSERT_GUN
    move=.1
    check(sendGun(record()) and payloadOrigin==predictionOrigin and State.PendingGun[1].Origin==payloadOrigin,
        "gun prediction, pending record and payload share the sampled origin")
    move=1; calls=0; payloadOrigin=nil
    check(not sendGun(record()) and calls==2 and payloadOrigin==nil,
        "repeated muzzle movement cancels after one recalculation")
    move=0; target.Excluded=true
    State.IsPlayerExcluded=function(p) return p.Excluded end
    check(not sendGun(record()),"gun still refuses excluded targets")
    target.Excluded=false; State.Config.ConservativeGun=true; coverage=.8
    payloadOrigin=nil
    check(not sendGun(record()) and payloadOrigin==nil,"final firing gate rejects partial timing coverage")
    coverage=1; passes=3
    check(not sendGun(record()),"final firing gate rejects incomplete conservative sampling")
    passes=5
    check(sendGun(record()),"fully sampled conservative gun solution sends")
end
print(string.format("%d combat assertions passed",passed))
