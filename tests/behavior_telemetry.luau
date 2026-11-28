-- Source-extracted motion classification, weakness hypotheses and 2D projection.
-- No invented player intent or unverified shot outcome is asserted.
-- INSERT_BEHAVIOR_POLICY

local passed=0
local function check(label,result)
    assert(result,label)
    passed+=1
end
local function sample(x,z,vx,vz,air,vy)
    return {X=x,Z=z,VX=vx,VZ=vz,
        Speed=math.sqrt(vx*vx+vz*vz),Air=air==true,VY=vy or 0}
end
local function contains(items,word)
    for _,item in ipairs(items) do if item==word then return true end end
    return false
end

check("initial sample has no inferred transitions",
    #behaviorTransitionEvents(nil,sample(0,0,0,0),0.2)==0)
check("a reliable movement start is logged",
    contains(behaviorTransitionEvents(sample(0,0,0,0),sample(2,0,10,0),0.2),"Start"))
check("a reliable movement stop is logged",
    contains(behaviorTransitionEvents(sample(2,0,10,0),sample(2,0,0,0),0.2),"Stop"))
check("jump uses observed upward airborne movement",
    contains(behaviorTransitionEvents(sample(0,0,9,0),sample(1,0,9,0,true,25),0.2),"Jump"))
check("landing is observable independently of a jump input",
    contains(behaviorTransitionEvents(sample(0,0,9,0,true,-10),sample(1,0,9,0,false),0.2),"Land"))
check("no jump is guessed from low-speed vertical jitter",
    not contains(behaviorTransitionEvents(sample(0,0,9,0),sample(1,0,9,0,true,1),0.2),"Jump"))
check("sharp movement reverse is classified",
    contains(behaviorTransitionEvents(sample(0,0,12,0),sample(1,0,-12,0),0.2),"Reverse"))
check("roughly perpendicular motion is a sharp turn",
    contains(behaviorTransitionEvents(sample(0,0,12,0),sample(1,0,0,12),0.2),"Sharp turn"))
check("smooth continued movement is not a turn",
    #behaviorTransitionEvents(sample(0,0,10,0),sample(2,0,11,0),0.2)==0)
check("large displacement is flagged as a warp, not a real dodge",
    contains(behaviorTransitionEvents(sample(0,0,10,0),sample(100,0,-10,0),0.2),"Warp"))
check("warps do not inflate false reverse metrics",
    not contains(behaviorTransitionEvents(sample(0,0,10,0),sample(100,0,-10,0),0.2),"Reverse"))
check("duplicate frame is ignored",
    #behaviorTransitionEvents(sample(0,0,10,0),sample(1,0,-10,0),0.01)==0)
check("stale previous frame is ignored",
    #behaviorTransitionEvents(sample(0,0,10,0),sample(1,0,-10,0),1.5)==0)

local x,z=behaviorMapCoordinate(50,25,0,100,0,50)
check("world midpoint maps to visual centre",x==0.5 and z==0.5)
x,z=behaviorMapCoordinate(-40,200,0,100,0,50)
check("outlying positions are clamped to the radar frame",x==0 and z==1)
x,z=behaviorMapCoordinate(0,0,0,0,0,0)
check("zero-size world does not create infinities",x==0 and z==0)

local x1,x2,z1,z2=behaviorBounds({})
check("empty world uses a centered fallback",
    x1==-50 and x2==50 and z1==-50 and z2==50)
x1,x2,z1,z2=behaviorBounds({{Last={X=120,Z=400}}})
check("single player still gets 90-stud context",
    x2-x1>=90 and z2-z1>=90 and (x1+x2)/2==120)
x1,x2,z1,z2=behaviorBounds({
    {Last={X=0,Z=-50}},{Last={X=200,Z=60}}
})
check("global view expands to fit all observed players",
    x1<0 and x2>200 and z1< -50 and z2>60)
check("normalization is consistent for current global bounds",
    select(1,behaviorMapCoordinate(200,60,x1,x2,z1,z2))>0.5)
check("role loss on elimination preserves last confirmed role",
    behaviorRoleUpdate("Murderer","Unknown")=="Murderer")
check("unknown player remains unknown without a role observation",
    behaviorRoleUpdate(nil,"Unknown")=="Unknown")
check("confirmed role change updates the previous role",
    behaviorRoleUpdate("Innocent","Sheriff")=="Sheriff")
check("genuine zero health is recorded as an observation, not a kill claim",
    behaviorLifeEvent(true,true,0)=="Health zero")
check("fake death or character disappearance is not mislabeled as a kill",
    behaviorLifeEvent(false,false,nil)=="Character unavailable")
check("temporary replication loss is not counted as a kill",
    behaviorLifeEvent(true,false,nil)=="Character unavailable")
local approach={}
check("first approach counts as a single episode",
    behaviorApproachTransition(approach,true,1))
check("continuous approach cannot count five times per second",
    not behaviorApproachTransition(approach,true,1.2)
        and not behaviorApproachTransition(approach,true,1.4))
check("stopping and immediately resuming does not create false episodes",
    not behaviorApproachTransition(approach,false,1.5)
        and not behaviorApproachTransition(approach,true,1.7))
check("a separated later approach is a new observation",
    not behaviorApproachTransition(approach,false,3)
        and behaviorApproachTransition(approach,true,3.1))

check("lobby movement is excluded from training and logs",
    not behaviorShouldSample(false,true,true))
check("lobby spectator is never sampled during a live match",
    not behaviorShouldSample(true,false,false))
check("player in a different map is excluded",
    not behaviorShouldSample(true,true,false))
check("players in the same live map can be recorded",
    behaviorShouldSample(true,true,true))
check("headless recording does not require a visual overview",
    not behaviorShouldShowMap(true,false,true))
check("overview is hidden while in the lobby",
    not behaviorShouldShowMap(true,true,false))
check("turning off recording hides the overview too",
    not behaviorShouldShowMap(false,true,true))
check("optional overview is visible only in a live round",
    behaviorShouldShowMap(true,true,true))
check("playing keeps full movement evidence in RAM without blocking writefile",
    not behaviorMayWriteArchive("Playing"))
check("spectator view also avoids blocking disk writes",
    not behaviorMayWriteArchive("Spectating"))
check("lobby can flush final evidence without slowing active movement",
    behaviorMayWriteArchive("Idle"))
check("unknown or unset phases never initiate unrequested disk writes",
    not behaviorMayWriteArchive(nil) and not behaviorMayWriteArchive("Unknown"))
local mixed={
    {Round=1,Kind="First start"},
    {Round=1,Kind="First end"},
    {Round=2,Kind="Second start"},
    {Round=2,Kind="Second movement"},
    {Round=3,Kind="Future data"},
}
local current=behaviorEventsForRound(mixed,2)
check("match export does not include lobby/earlier or later rounds",
    #current==2 and current[1].Kind=="Second start"
        and current[2].Kind=="Second movement")
check("missing round has no incorrectly inherited events",
    #behaviorEventsForRound(mixed,4)==0)

local normal={Samples=30,Reversals=0,Jumps=1,Still=2,
    CloseStill=0,Approaches=0}
check("no weakness is invented from insufficient evidence",
    #behaviorWeaknessTags({Samples=3,Reversals=30,Jumps=30,Still=3},true)==0)
check("normal mixed movement produces no weakness hint",
    #behaviorWeaknessTags(normal,true)==0)
local camper={Samples=30,Still=25,Jumps=1,Reversals=0,
    Approaches=0,CloseStill=0}
local insights=behaviorWeaknessTags(camper,false)
check("observed stationary ratio suggests a potential fixed-position habit",
    #insights==1 and insights[1]:find("stationary",1,true)~=nil)
insights=behaviorWeaknessTags({Samples=40,Still=30,Jumps=7,
    Reversals=6,Approaches=10,CloseStill=0},false)
check("repeat jumps and reversals yield distinct bounded hypotheses",#insights==4)
insights=behaviorWeaknessTags({Samples=30,Still=25,Jumps=1,
    Reversals=0,CloseStill=5},true)
check("self weakness analysis flags stationary exposure",
    contains(insights,"Stationary during nearby opposing-player approach"))
insights=behaviorWeaknessTags({Samples=40,Still=1,Jumps=0,
    Reversals=4,CloseStill=0},true)
check("self sharp reversals are treated as a possible aiming issue",
    #insights==1 and insights[1]:find("disrupt aim",1,true)~=nil)

print(("%d behavior, map and weakness assertions passed"):format(passed))
