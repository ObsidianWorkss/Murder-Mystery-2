-- FSS-style bounded motion learning, extracted from MM2's production script.
local style={OpponentMotion={},ObservedReversals=0,NextMotionSweep=0}
-- INSERT_STYLE_POLICY
-- INSERT_MOTION_TRACKER

local passed=0
local function check(label,condition)
    assert(condition,label)
    passed+=1
end
local function vel(x,z)
    return {X=x,Y=0,Z=z}
end
local function root(velocity)
    return {AssemblyLinearVelocity=velocity,Parent=true}
end
local player={UserId=2048}
local opponent=root(vel(14,0))

check("Motion sample begins with zero learned turns",
    styleObserveOpponent(player,opponent,100).Reversals==0)
opponent.AssemblyLinearVelocity=vel(0,14)
local first=styleObserveOpponent(player,opponent,100.20)
check("Plausible 90-degree change registers a reversal",first.Reversals==1)
check("A reversal is counted once",style.ObservedReversals==1)
styleObserveOpponent(player,opponent,100.20)
check("Duplicate tick cannot invent another reversal",style.ObservedReversals==1)
styleObserveOpponent(player,opponent,100.28)
check("Unchanged direction is not double counted",style.ObservedReversals==1)
opponent.AssemblyLinearVelocity=vel(-14,0)
styleObserveOpponent(player,opponent,100.39)
check("Reversal debounce protects rapid duplicate observations",style.ObservedReversals==1)
opponent.AssemblyLinearVelocity=vel(14,0)
styleObserveOpponent(player,opponent,100.71)
check("Separate reversal is learned after debounce",style.ObservedReversals==2)
opponent.AssemblyLinearVelocity=vel(-14,0)
styleObserveOpponent(player,opponent,101.0)
check("Repeated opponent reversals accumulate",style.ObservedReversals==3)

check("Fresh feint with weak approach should be held",
    styleFeintResponse(3,101,12,3,101.1)=="Hold")
check("Strong approach through same feint triggers a counter",
    styleFeintResponse(3,101,12,9,101.1)=="Counter")
check("Immediate close danger is never held back",
    styleFeintResponse(4,101,5,0,101.1)~="Hold")
check("Repeated bait is contained briefly even beyond the first reversal",
    styleFeintResponse(3,101,12,3,102.0)=="Hold")
check("Old reversal evidence loses influence",
    styleFeintResponse(6,101,12,3,105)=="Normal")
check("Future timestamp cannot shape current reaction",
    styleFeintResponse(6,110,12,3,105)=="Normal")
check("Recent reversal caps overconfident prediction",
    styleMotionHorizon(100,100.1)==0.045)
check("Stable motion uses the normal lead",
    styleMotionHorizon(100,101)==0.15)
check("Implausible 80-stud velocity jump is ignored",
    not styleMotionReversed(vel(16,0),vel(-80,0),0.2))
check("Tiny jitter does not look like intentional feint",
    not styleMotionReversed(vel(3,0),vel(-3,0),0.2))
check("Stale motion cannot trigger false learning",
    not styleMotionReversed(vel(12,0),vel(-12,0),0.6))
check("Duplicate motion observations cannot trigger false learning",
    not styleMotionReversed(vel(12,0),vel(-12,0),0.01))
check("Valid sharp reversal is recognized",
    styleMotionReversed(vel(12,0),vel(-12,0),0.2))
check("Normal same-direction acceleration is not a feint",
    not styleMotionReversed(vel(9,0),vel(14,0),0.2))
check("Valid recent feint can choose an immediate counter",
    styleJukePattern(12,9,23,7,true,true,1,"Open",true)=="Counter cut")
check("Counter cut never moves initially toward the feinter",
    styleJukePhase(0,"Counter cut",0.3)==1)
check("Narrow escape overrules fancy counter animation",
    styleJukePattern(12,9,23,7,true,true,1,"Narrow",true)=="Tight cut")
check("Corner escape overrules fancy counter animation",
    styleJukePattern(12,9,23,7,true,true,1,"Corner",true)=="Corner escape")

local newModel=root(vel(20,0))
check("Respawn resets same-player velocity memory",
    styleObserveOpponent(player,newModel,102.0).Reversals==0)
check("Respawn resets prior reversal timestamp",
    style.OpponentMotion[tostring(player.UserId)].LastReverseAt==-math.huge)
check("Old rows expire instead of affecting later rounds",
    styleObserveOpponent(player,newModel,116.0).Reversals==0)
check("Old rows are renewed with current sampling timestamp",
    style.OpponentMotion[tostring(player.UserId)].SeenAt==116.0)

print(("%d FSS-inspired MM2 motion-learning assertions passed"):format(passed))
