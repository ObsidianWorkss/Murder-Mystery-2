-- Execute production round lifecycle with fake map/snapshot/export providers.
local inRound=false
local liveMap=nil
local mapA={Object={Name="Map A"}}
local mapB={Object={Name="Map B"}}
local player={Name="Tester",Character={}}
local root={Position={X=0,Y=3,Z=0}}
function player.Character:FindFirstChild(name)
    return name=="HumanoidRootPart" and root or nil
end
local events,exports={},{}
local recorder={Round=0,InRound=false,People={},
    MatchHistory={},RoundMap=nil,LastExportRound=0}
local State={GameContext={
    InRound=function() return inRound end,
    MapAt=function() return liveMap end,
    Mode=function() return "Classic" end,
}}
local function pushEvent(kind,name,detail)
    events[#events+1]={Kind=kind,Round=recorder.Round,Name=name,Detail=detail}
end
function State.GetBehaviorSnapshot()
    local people={}
    for name,row in pairs(recorder.People) do
        people[#people+1]={Name=name,Role=row.Role,Samples=row.Samples,
            Jumps=0,Reversals=0,Turns=0,Starts=0,Stops=0,
            Approaches=0,Weaknesses={}}
    end
    return {Players=people,RetainedEvents=#events}
end
function State.ExportBehaviorLog(reason)
    local count=0
    for _ in pairs(recorder.People) do count+=1 end
    exports[#exports+1]={Reason=reason,Round=recorder.Round,
        PlayersBeforeClear=count}
    return true,"saved"
end

-- INSERT_RECORD_ROUND

local assertions=0
local function check(label,value)
    assert(value,label)
    assertions+=1
end
check("starting in lobby does not count as a match",recordRound(1)==false)
check("no lobby round or events are created",recorder.Round==0 and #events==0)
recorder.People.Lobby={Role="Unknown",Samples=10}
inRound=true;liveMap=mapA
check("live map begins first round",recordRound(2)==true)
check("match start resets previous lobby samples",
    recorder.People.Lobby==nil and recorder.Round==1)
check("round opener pins the active match map",recorder.RoundMap==mapA)
check("only a match-start event is logged",#events==1 and events[1].Kind=="Round start")
recorder.People.Alice={Role="Sheriff",Samples=35}
check("same round does not restart",recordRound(3)==true and recorder.Round==1)
check("same round does not duplicate start logs",#events==1)
inRound=false;liveMap=nil
check("return to lobby ends the active round",recordRound(4)==false)
check("round end automatically exports once",#exports==1
    and exports[1].Reason=="round" and exports[1].PlayersBeforeClear==1)
check("completed-round map data is removed from active state",
    next(recorder.People)==nil and recorder.RoundMap==nil)
check("compact last-round history remains",#recorder.MatchHistory==1
    and recorder.MatchHistory[1].Players[1].Name=="Alice")
check("more lobby time creates no additional match exports",
    recordRound(5)==false and #exports==1)
check("more lobby time does not create new events",
    #events==2 and events[2].Kind=="Round end")
inRound=true;liveMap=mapB
check("next live map starts a clean second round",
    recordRound(6)==true and recorder.Round==2 and recorder.RoundMap==mapB)
check("new round still has no previous-player data",
    next(recorder.People)==nil)
recorder.RoundMap=nil
check("mid-round reload can rebind its active map",
    recordRound(7)==true and recorder.RoundMap==mapB and recorder.Round==2)
check("mid-round reload does not duplicate round-start event",#events==3)

print(("%d round-only lifecycle assertions passed"):format(assertions))
