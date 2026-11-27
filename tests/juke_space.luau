-- Exercise the production swept-body and multi-sample ground checker with
-- controlled walls, missing floors, abrupt drops and fallback raycasts.
local vector={}
local function vec(x,y,z)
    return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vector)
end
vector.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vector.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vector.__mul=function(a,b)
    if type(a)=="number" then a,b=b,a end
    return vec(a.X*b,a.Y*b,a.Z*b)
end
vector.__unm=function(a) return vec(-a.X,-a.Y,-a.Z) end
function vector:Dot(other)
    return self.X*other.X+self.Y*other.Y+self.Z*other.Z
end
vector.__index=function(a,key)
    if key=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
    if key=="Unit" then
        local length=math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)
        return vec(a.X/length,a.Y/length,a.Z/length)
    end
    return rawget(vector,key)
end
local Vector3={new=vec}
local CFrame={new=function(position) return {Position=position} end}
local wallDistance,ledgeAfterX,floorAfterX,slopeAfterX
local blockcastUnavailable,noStartingFloor,laneWalls
local bodySweeps,groundChecks,rayFallbacks=0,0,0
local workspace={}
function workspace:Blockcast(_,_,direction)
    bodySweeps+=1
    if blockcastUnavailable then error("Blockcast unsupported") end
    local distance=wallDistance
    if laneWalls then
        local lane=direction.Unit
        local side=lane.X>0.5 and "right" or lane.X< -0.5 and "left" or "back"
        local category=lane.Z>0.3 and math.abs(lane.X)>0.3 and "diagonal"
            or lane.Z>0.7 and "back" or side
        distance=laneWalls[category]
    end
    if distance and distance<direction.Magnitude then
        return {Distance=distance}
    end
    return nil
end
function workspace:Raycast(origin,direction)
    if direction.Y< -0.5 then
        groundChecks+=1
        if noStartingFloor or ledgeAfterX and origin.X>ledgeAfterX then return nil end
        local y=floorAfterX and origin.X>floorAfterX and -3 or 0
        local normal=vec(0,slopeAfterX and origin.X>slopeAfterX and 0.2 or 1,0)
        return {Position=vec(origin.X,y,origin.Z),Normal=normal}
    end
    rayFallbacks+=1
    if wallDistance and wallDistance<direction.Magnitude then
        return {Distance=wallDistance}
    end
end

-- INSERT_JUKE_LANE
-- INSERT_MOTION_HORIZON

local passed=0
local function check(label,condition)
    assert(condition,label)
    passed+=1
end
local root={Position=vec(0,3,0),Size=vec(2,2,1)}
local hum={HipHeight=2,WalkSpeed=16}
local direction=vec(1,0,0)
local params={RespectCanCollide=true}
check("open floor and clear body sweep preserve whole route",
    math.abs(styleLaneClearance(root,hum,direction,6,params)-6)<0.001)
check("clear route checks whole standing body",bodySweeps==1)
check("clear route samples starting floor and four later support points",groundChecks==5)
wallDistance=3
check("wall inside desired distance trims standing-body clearance",
    math.abs(styleLaneClearance(root,hum,direction,6,params)-2.68)<0.001)
wallDistance=1.6
check("wall within one body step rejects route",styleLaneClearance(root,hum,direction,6,params)==0)
wallDistance=nil;ledgeAfterX=3
check("ledge stops planning before unsupported step",
    math.abs(styleLaneClearance(root,hum,direction,6,params)-3)<0.001)
ledgeAfterX=nil;floorAfterX=2
check("steep floor drop stops planning before falling",
    math.abs(styleLaneClearance(root,hum,direction,6,params)-1.5)<0.001)
floorAfterX=nil;slopeAfterX=3
check("steep ramp rejects unsupported final half",
    math.abs(styleLaneClearance(root,hum,direction,6,params)-3)<0.001)
slopeAfterX=nil
noStartingFloor=true
check("no start floor refuses a risky unsupported juke",
    styleLaneClearance(root,hum,direction,6,params)==0)
noStartingFloor=false
blockcastUnavailable=true;wallDistance=3
local before=rayFallbacks
check("raycast fallback still rejects a blocking wall",
    math.abs(styleLaneClearance(root,hum,direction,6,params)-2.68)<0.001)
check("missing Blockcast probes three standing-body heights",rayFallbacks-before==3)
wallDistance=nil
check("unsupported Blockcast with clear rays still permits route",
    math.abs(styleLaneClearance(root,hum,direction,6,params)-6)<0.001)

local style={LastSide=1}
local RaycastParams={new=function() return {} end}
local Enum={RaycastFilterType={Exclude="Exclude"}}
-- INSERT_JUKE_SPACE_POLICY
-- INSERT_JUKE_PLANNER
blockcastUnavailable=false
local ownCharacter={}
local opponent={Position=vec(0,3,-15),AssemblyLinearVelocity=vec(0,0,0),Parent=true}
local opponents={{Root=opponent}}
hum.MoveDirection=vec(0,0,0)

local openPlan,reason=stylePlanEscape(ownCharacter,hum,root,opponent,opponents,0.34)
check("open room has a valid escape",openPlan~=nil and reason==nil)
check("open room chooses a side to preserve maneuver options",
    openPlan.Kind=="Side" and openPlan.Space=="Open" and openPlan.CanFeint)
check("normal juke duration is clipped to measured free lane",openPlan.Duration<=0.34)
check("planner enables collision-respecting raycasts",openPlan.Params.RespectCanCollide==true)

laneWalls={left=1.5}
local corner=stylePlanEscape(ownCharacter,hum,root,opponent,opponents,0.34)
check("blocked left lane uses right corner exit",
    corner~=nil and corner.Kind=="Side" and corner.Sign==1 and corner.Space=="Corner"
        and not corner.CanFeint)
laneWalls={left=1.5,right=1.5}
local diagonal=stylePlanEscape(ownCharacter,hum,root,opponent,opponents,0.34)
check("both sides blocked chooses a supported diagonal instead",
    diagonal~=nil and diagonal.Kind=="Diagonal" and diagonal.Space=="Corner")
laneWalls={left=1.5,right=1.5,diagonal=1.5}
local retreat=stylePlanEscape(ownCharacter,hum,root,opponent,opponents,0.34)
check("no sideways/diagonal clearance falls back to retreat",
    retreat~=nil and retreat.Kind=="Retreat" and retreat.Space=="Retreat")
laneWalls={left=1.5,right=1.5,diagonal=1.5,back=1.5}
local trapped,rejected=stylePlanEscape(ownCharacter,hum,root,opponent,opponents,0.34)
check("fully trapped position refuses to move rather than hitting a wall",
    trapped==nil and type(rejected)=="string")
laneWalls=nil

print(("%d juke geometry assertions passed"):format(passed))
