local passed=0
local function check(ok,message) assert(ok,message); passed+=1; print("PASS: "..message) end
local player={Character={}}
local State={Stats={GunUnconfirmed=0},ShotLog={},PendingGun={},GunShotSequence=2,
    LastGunFeedback={ShotId=2,Message="Awaiting shot"}}
-- INSERT_GUN_PENDING_LIFECYCLE
local target={Name="MockTarget"}
local function shot(id,sentAt)
    return {ShotId=id,SentAt=sentAt,Target=target,OwnCharacter=player.Character,
        AimPart="Head",VelocitySource="sample",AimPoint={X=1},
        TimingCoverage=1,TimingPassed=5,OnScreenOnly=true}
end
table.insert(State.PendingGun,shot(1,1))
table.insert(State.PendingGun,shot(2,3.5))
expirePendingGun(4.1)
check(State.Stats.GunUnconfirmed==1 and #State.PendingGun==1,
    "expired request is counted without dropping a newer outstanding request")
check(State.ShotLog[1].ShotId==1 and State.ShotLog[1].Status=="NoCorrelatedResponse"
    and State.ShotLog[1].SentAt==1 and State.ShotLog[1].Target==target.Name
    and State.ShotLog[1].TimingCoverage==1 and State.ShotLog[1].TimingPassed==5
    and State.ShotLog[1].OnScreenOnly==true,
    "unconfirmed log retains shot identity, timing checks and screen-only intent")
check(State.LastGunFeedback.Message=="Awaiting shot",
    "a stale timeout cannot erase newer in-flight shot feedback")
expirePendingGun(6.6)
check(State.Stats.GunUnconfirmed==2 and #State.PendingGun==0,
    "current unanswered shot expires after the normal three-second window")
check(State.LastGunFeedback.Message:find("outcome unknown",1,true)~=nil,
    "current expired shot reports unknown outcome rather than a miss")
check(State.LastGunFeedback.UpdatedAt==6.6 and State.LastGunFeedback.SentAt==3.5,
    "timeout message carries both the original request time and fresh outcome time")
table.insert(State.PendingGun,shot(3,7))
table.insert(State.PendingGun,shot(4,8))
drainPendingGun("InterruptedByUnload")
check(State.Stats.GunUnconfirmed==4 and #State.PendingGun==0
    and State.ShotLog[3].ShotId==3 and State.ShotLog[4].ShotId==4,
    "unload reconciles every unfinished request rather than losing it")
check(State.ShotLog[3].Status=="InterruptedByUnload",
    "unload reason is recorded distinctly from a timed-out reply")
drainPendingGun("InterruptedByUnload")
check(State.Stats.GunUnconfirmed==4,
    "repeated unload cleanup cannot double-count an already reconciled shot")
for id=5,15 do table.insert(State.PendingGun,shot(id,id)) end
trimPendingGun()
check(#State.PendingGun==8 and State.PendingGun[1].ShotId==8
    and State.Stats.GunUnconfirmed==7,
    "full pending queue records each evicted request instead of silently losing it")
check(State.ShotLog[#State.ShotLog].ShotId==7
    and State.ShotLog[#State.ShotLog].Status=="QueueCapacityExceeded",
    "overflow diagnostics retain evicted request identifiers")
check(#State.ShotLog==7,"shot log stays bounded after the queue is trimmed")
drainPendingGun("InterruptedByUnload")
check(#State.ShotLog==10 and State.Stats.GunUnconfirmed==15 and #State.PendingGun==0,
    "large shutdown preserves the ten most recent entries and counts every unresolved request")
print(passed.." gun pending lifecycle assertions passed")
