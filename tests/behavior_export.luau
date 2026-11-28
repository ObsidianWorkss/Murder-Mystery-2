-- Exercise the production queued completed-round exporter in isolation.
local queued,waits=nil,0
local writes,chunkWrites={},{}
local encodedPayload
local recorder
local task={
    spawn=function(fn) queued=fn end,
    wait=function()
        waits+=1
        if waits>=2 and recorder then recorder.Phase="Idle" end
    end,
}
local game={GetService=function(_,service)
    assert(service=="HttpService")
    return {JSONEncode=function(_,payload)
        encodedPayload=payload
        return "recorded-manifest"
    end}
end}
local writefile=function(path,data)
    writes[#writes+1]={Path=path,Data=data}
end
recorder={
    Round=1,Seq=310,RoundStartSeq=1,ExportSeq=0,
    ArchiveId="original-round",ArchiveEvents={},ArchiveFiles={},
    ArchiveSeq=0,ArchiveLost=0,ArchiveStatus="Ready",ArchiveIncomplete=false,
    PendingExports={},Phase="Idle",Events={{N=1,Kind="Round start",Round=1},
        {N=310,Kind="Round end",Round=1}},
}
for i=1,310 do
    recorder.ArchiveEvents[i]={N=i,Round=1,Kind="Sample"}
end
local State={}
function State.GetBehaviorSnapshot()
    return {Round=recorder.Round,Players={{Name="Alpha",Samples=120}},
        RetainedEvents=#recorder.Events,MatchHistory={}}
end
function State.GetWeaknessReport()
    return {Player={"One observed habit"},Opponents={},Script={}}
end
function State.FlushBehaviorChunk(force,job)
    assert(force and job~=recorder)
    local take=math.min(150,#job.ArchiveEvents)
    local first=job.ArchiveEvents[1].N
    local last=job.ArchiveEvents[take].N
    job.ArchiveSeq+=1
    local path=("chunk-%d-%d-%d"):format(job.Round,first,last)
    chunkWrites[#chunkWrites+1]=path
    job.ArchiveFiles[#job.ArchiveFiles+1]=path
    for _=1,take do table.remove(job.ArchiveEvents,1) end
    return true,path
end
local function behaviorEventsForRound(events,round)
    local out={}
    for _,item in ipairs(events) do
        if item.Round==round then out[#out+1]=item end
    end
    return out
end
-- INSERT_ROUND_EXPORTER
local passed=0
local function check(label,result)
    assert(result,label)
    passed+=1
end

local ok,path=State.QueueCompletedBehaviorExport("round")
check("round completion queues an export",
    ok and type(path)=="string" and #recorder.PendingExports==1)
check("round-ending heartbeat does not perform any disk writes",
    #writes==0 and #chunkWrites==0 and type(queued)=="function")
check("completed match data is captured before map reset",
    recorder.PendingExports[1].Snapshot.Players[1].Name=="Alpha"
        and recorder.PendingExports[1].RecordedEvents==310)

-- Start a new match before the queued job runs. Its manifest must still
-- contain only the old match, regardless of new active-round state.
recorder.Round=2
recorder.Phase="Playing"
recorder.ArchiveEvents={}
recorder.ArchiveFiles={}
recorder.Events={{N=311,Kind="Round start",Round=2}}
queued()
check("queued file I/O yields and waits for a safe idle phase",waits>=3)
check("large backlog is drained in paced chunks",#chunkWrites==3
    and chunkWrites[1]=="chunk-1-1-150"
    and chunkWrites[2]=="chunk-1-151-300"
    and chunkWrites[3]=="chunk-1-301-310")
check("subsequent match recorder remains untouched",
    recorder.Round==2 and #recorder.ArchiveEvents==0
        and #recorder.ArchiveFiles==0)
check("manifest retains the completed round even after new match began",
    encodedPayload.Snapshot.Round==1
        and encodedPayload.Archive.RecordedEvents==310
        and encodedPayload.Archive.Complete==true)
check("complete export includes all chunk paths",
    #encodedPayload.Archive.Files==3 and encodedPayload.Reason=="round"
        and #encodedPayload.Events==2)
check("manifest written only after all chunks",
    #writes==1 and writes[1].Path==path
        and writes[1].Data=="recorded-manifest")
check("completed export reports saved path and clears queue",
    recorder.LastExport==path and #recorder.PendingExports==0)
print(("%d queued match export assertions passed"):format(passed))
