-- Test production chunk writer under bounded memory, failed I/O and reload.
local archiveCalls={}
local failWrites=false
local folders={MM2Universal=true,["MM2Universal/diagnostics"]=true}
local isfolder=function(path) return folders[path]==true end
local makefolder=function(path) folders[path]=true end
local writefile=function(path,data)
    if failWrites then error("simulated disk failure") end
    archiveCalls[#archiveCalls+1]={Path=path,Data=data}
end
local game={GetService=function(_,name)
    assert(name=="HttpService")
    return {JSONEncode=function(_,value)
        -- Ensure the exact event count and sequence are passed for archiving.
        assert(value.Schema==1 and (value.Round==1 or value.Round==2) and value.Events)
        return ("%d:%d:%d"):format(#value.Events,value.FirstN,value.LastN)
    end}
end}
local recorder={ArchiveEvents={},ArchiveFiles={},ArchiveSeq=0,
    ArchiveLost=0,ArchiveId="test-round",Round=1,ArchiveStatus="Ready"}
local State={Performance={}}
-- INSERT_ARCHIVE_WRITER
local passed=0
local function check(label,condition)
    assert(condition,label)
    passed+=1
end
local function queue(n,start)
    for i=start,start+n-1 do
        recorder.ArchiveEvents[#recorder.ArchiveEvents+1]={N=i,Round=1}
    end
end
check("empty archive does not perform IO",not State.FlushBehaviorChunk(true))
queue(149,1)
check("routine archive flush waits for a full batch",
    not State.FlushBehaviorChunk(false) and #archiveCalls==0)
queue(1,150)
local good,path=State.FlushBehaviorChunk(false)
check("full batch writes successfully",good and #archiveCalls==1)
check("first chunk has stable sequential name",
    string.find(path,"events-test-round-001.json",1,true)~=nil)
check("first chunk captures all 150 original events",
    archiveCalls[1].Data=="150:1:150" and #recorder.ArchiveEvents==0)
check("production archive tracks the cost of executor file writes",
    State.Performance.ArchiveWrites==1 and
        type(State.Performance.LastArchiveWriteMs)=="number" and
        State.Performance.MaxArchiveWriteMs>=State.Performance.LastArchiveWriteMs)
queue(20,151)
failWrites=true
local result=State.FlushBehaviorChunk(true)
check("file error does not discard the unexported tail",
    not result and #recorder.ArchiveEvents==20 and #recorder.ArchiveFiles==1)
check("failed write does not advance part numbering",recorder.ArchiveSeq==1)
check("failed IO backs off instead of retrying every movement sample",
    recorder.ArchiveRetryAt>os.clock())
failWrites=false
good,path=State.FlushBehaviorChunk(true)
check("retry writes the retained tail safely",good and recorder.ArchiveSeq==2)
check("second chunk resumes without gaps or overlap",
    archiveCalls[2].Data=="20:151:170" and #recorder.ArchiveEvents==0
        and recorder.ArchiveRetryAt==0)
queue(1,171)
good=State.FlushBehaviorChunk(true)
check("end-of-round forced flush preserves a final partial chunk",
    good and archiveCalls[3].Data=="1:171:171")
check("archive files are listed in production order",#recorder.ArchiveFiles==3)
check("archive performance reports each attempted write, including failures",
    State.Performance.ArchiveWrites==4)
local finished={
    Round=2,ArchiveId="finished-round",ArchiveEvents={{N=200,Round=2}},
    ArchiveSeq=0,ArchiveFiles={},ArchiveStatus="Ready",
}
local oldRound=recorder.Round
recorder.Round=2
good,path=State.FlushBehaviorChunk(true,finished)
check("detached completed round saves through independent archive state",
    good and finished.ArchiveSeq==1 and #finished.ArchiveFiles==1
        and #finished.ArchiveEvents==0 and recorder.ArchiveSeq==3)
check("detached archive preserves its own round identity and path",
    string.find(path,"events-finished-round-001.json",1,true)~=nil)
recorder.Round=oldRound
writefile=nil
queue(1,172)
good=State.FlushBehaviorChunk(true)
check("unsupported executor storage retains pending evidence",
    not good and #recorder.ArchiveEvents==1
        and string.find(recorder.ArchiveStatus,"unavailable",1,true)~=nil)
print(("%d archive chunk assertions passed"):format(passed))
