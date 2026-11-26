local passed=0
local function check(value,message)
    assert(value,message); passed+=1; print("PASS: "..message)
end
local mt={}
local function vec(x) return setmetatable({X=x,Y=0,Z=0},mt) end
mt.__sub=function(a,b) return vec(a.X-b.X) end
mt.__index=function(v,key)
    if key=="Magnitude" then return math.abs(v.X) end
    if key=="Unit" then return vec(v.X>0 and 1 or -1) end
    if key=="Dot" then return function(self,other) return self.X*other.X end end
end
local function typeof(value)
    if getmetatable(value)==mt then return "Vector3" end
    return type(value)
end
local State={PendingGun={},WeaponHandlers={}}
-- INSERT_GUN_FEEDBACK
installAimFeedbackSafety(State)
local item,char,hitPart={},{},{}
local record={Active=true}
State.WeaponHandlers[item]=record
local origin,target=vec(1),vec(11)
local function pending(id,sentAt)
    return {ShotId=id,Item=item,Record=record,OwnCharacter=char,
        Origin=origin,AimPoint=target,SentAt=sentAt}
end
table.insert(State.PendingGun,pending(1,10))
local match,status=State.MatchGunFeedback(item,origin,target,hitPart,char,10.13)
check(match==1 and status=="Heuristic","first unique reply matches its pending gun request")
table.remove(State.PendingGun,match)
match,status=State.MatchGunFeedback(item,origin,target,hitPart,char,10.15)
check(match==nil and status=="Duplicate or indistinguishable reply",
    "replaying an already-counted reply without another request remains a duplicate")
table.insert(State.PendingGun,pending(2,11.6))
match,status=State.MatchGunFeedback(item,origin,target,hitPart,char,11.73)
check(match==1 and status=="Heuristic",
    "identical ray geometry from a later legitimate shot can correlate independently")
table.remove(State.PendingGun,match)
match,status=State.MatchGunFeedback(item,origin,target,hitPart,char,11.74)
check(match==nil and status=="Duplicate or indistinguishable reply",
    "duplicate of the second response is still rejected")
table.insert(State.PendingGun,pending(31,11.71))
match,status=State.MatchGunFeedback(item,origin,target,hitPart,char,11.76)
check(match==nil and status=="Duplicate or indistinguishable reply",
    "an older overlapping request cannot steal a reply already matched to a newer shot")
table.clear(State.PendingGun)
table.insert(State.PendingGun,pending(3,13.2))
State.WeaponHandlers[item]=nil
match,status=State.MatchGunFeedback(item,origin,target,hitPart,char,13.3)
check(match==nil,"inactive/removed weapon cannot claim a late gun reply")
State.WeaponHandlers[item]=record
match,status=State.MatchGunFeedback(item,origin,target,hitPart,{},13.3)
check(match==nil,"character change invalidates pending gun feedback")
match,status=State.MatchGunFeedback(item,origin,target,hitPart,char,13.3)
check(match==1 and status=="Heuristic","valid pending shot still correlates after safety checks")
table.remove(State.PendingGun,match)
check(#State.PendingGun==0,"fixture consumes one pending shot per distinct reply")
print(passed.." gun feedback assertions passed")
