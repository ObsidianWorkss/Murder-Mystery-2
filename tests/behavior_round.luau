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
local actor1={Name="Alice",Role="Murderer",OnMap=false,Character={}}
local actor2={Name="Bob",Role="Sheriff",OnMap=false,Character={}}
local actorRoot1={Position={Map=mapA}}
local actorRoot2={Position={Map=mapA}}
for _,entry in ipairs({{actor1,actorRoot1},{actor2,actorRoot2}}) do
    local other,part=entry[1],entry[2]
    function other.Character:FindFirstChild(name)
        return name=="HumanoidRootPart" and part or nil
    end
    function other.Character:FindFirstChildOfClass(name)
        return name=="Humanoid" and {Health=100} or nil
    end
end
local Players={GetPlayers=function() return {player,actor1,actor2} end}
local function roleFor(other) return other.Role or "Unknown" end
local events,exports={},{}
local recorder={Round=0,InRound=false,People={},Seq=0,
    ArchiveEvents={},ArchiveFiles={},ArchiveSeq=0,ArchiveLost=0,
    MatchHistory={},RoundMap=nil,LastExportRound=0,Phase="Idle",
    Session="test-job"}
local State={Config={BehaviorSpectate=true},GameContext={
    InRound=function(other)
        if other==player then return inRound end
        return other.OnMap==true
    end,
    MapAt=function(position)
        if position==root.Position then return liveMap end
        return position.Map
    end,
    Areas=function() return {mapA,mapB} end,
    Mode=function() return "Classic" end,
}}
local function pushEvent(kind,name,detail)
    recorder.Seq+=1
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
function State.QueueCompletedBehaviorExport(reason)
    -- In production this captures the match immediately and schedules I/O;
    -- the lifecycle test records the request without executing any disk work.
    return State.ExportBehaviorLog(reason)
end

-- INSERT_OBSERVER_PHASE
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
check("round start creates a fresh archive identity",
    type(recorder.ArchiveId)=="string" and recorder.RoundStartSeq==1
        and #recorder.ArchiveFiles==0)
check("round opener pins the active match map",recorder.RoundMap==mapA)
check("only a match-start event is logged",#events==1 and events[1].Kind=="Round start")
recorder.People.Alice={Role="Sheriff",Samples=35}
check("same round does not restart",recordRound(3)==true and recorder.Round==1)
check("same round does not duplicate start logs",#events==1)
inRound=false;liveMap=nil
actor1.OnMap=true;actor2.OnMap=true
check("death and lobby respawn keep recording the same live match",
    recordRound(4)==true and recorder.Round==1)
check("match recorder enters spectator state",recorder.Phase=="Spectating"
    and recorder.SpectatorSince==4)
check("spectator mode preserves opponent data and pins the active map",
    recorder.People.Alice~=nil and recorder.RoundMap==mapA)
check("spectating does not prematurely export",#exports==0)
check("spectator transition is logged once",
    #events==2 and events[2].Kind=="Spectator recording")
actor1.OnMap=false
check("still records when only one map participant is alive",
    recordRound(5)==true and recorder.Phase=="Spectating")
actor2.OnMap=false
check("last opponent leaving map enters a short end-of-round grace window",
    recordRound(5.5)==true and recorder.EmptySince==5.5)
check("temporary respawn or network gap does not immediately split match",
    recordRound(7.9)==true and #exports==0)
check("match ends after no living map players remain",
    recordRound(8.1)==false and recorder.Phase=="Idle")
check("round end automatically exports once",#exports==1
    and exports[1].Reason=="round" and exports[1].PlayersBeforeClear==1)
check("completed-round map data is removed from active state",
    next(recorder.People)==nil and recorder.RoundMap==nil)
check("compact last-round history remains",#recorder.MatchHistory==1
    and recorder.MatchHistory[1].Players[1].Name=="Alice")
check("more lobby time creates no additional match exports",
    recordRound(9)==false and #exports==1)
check("more lobby time does not create new events",
    #events==3 and events[3].Kind=="Round end")
actorRoot1.Position.Map=mapB;actorRoot2.Position.Map=mapB
actor1.OnMap=true;actor2.OnMap=true
actor1.Role="Unknown";actor2.Role="Unknown"
check("lobby never invents a spectator round when actors lack match roles",
    recordRound(10)==false and recorder.Round==1)
actor2.Role="Sheriff"
check("can start spectating an ongoing match without entering the map",
    recordRound(11)==true and recorder.Round==2 and recorder.RoundMap==mapB
        and recorder.Phase=="Spectating")
check("new round still has no previous-player data",
    next(recorder.People)==nil)
check("second observer tick does not duplicate the round",
    recordRound(11.2)==true and recorder.Round==2)
inRound=true;liveMap=mapB
check("returning to the fight resumes playing within the same round",
    recordRound(12)==true and recorder.Phase=="Playing" and recorder.Round==2)
check("resuming local play is logged separately",
    events[#events].Kind=="Resumed play")
recorder.RoundMap=nil
check("mid-round reload can rebind its active map",
    recordRound(13)==true and recorder.RoundMap==mapB and recorder.Round==2)
check("mid-round reattachment does not add a new round-start event",
    #events==6)
inRound=false;liveMap=nil
State.Config.BehaviorSpectate=false
check("disabling spectator mode stops recording after local elimination",
    recordRound(14)==false and recorder.Phase=="Idle")
check("disabled spectating closes exactly the second round",
    #exports==2 and exports[2].Round==2)
State.Config.BehaviorSpectate=true
actor1.OnMap=false;actor2.OnMap=false
check("lobby with no live players remains idle",
    recordRound(20)==false and recorder.Round==2)

print(("%d round-only lifecycle assertions passed"):format(assertions))
