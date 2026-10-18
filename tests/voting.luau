local passed=0
local function check(ok,message) assert(ok,message); passed+=1; print("PASS: "..message) end
-- INSERT_VOTING
-- INSERT_EMERGENCY
local function signal()
    local s={Connections={}}
    function s:Connect(fn)
        local c={Callback=fn}
        function c:Disconnect() self.Disconnected=true end
        table.insert(self.Connections,c); return c
    end
    function s:Fire(...)
        for _,c in ipairs(self.Connections) do if not c.Disconnected then c.Callback(...) end end
    end
    return s
end
local function fixture(noTouch)
    local f={Now=10,Resets=0,Begins=0,Ends=0,Restores=0,Char={},Hum={Health=100},Root={},OriginalFrame={}}
    f.Heartbeat=signal(); f.Pad={Touched=signal(),Parent=true,Frame=f.OriginalFrame}
    f.Entry={Pad=f.Pad,Map={},Name="Test map",Voting=true,Votes=1}
    f.State={Running=true,Config={MapVoteRepeat=true}}
    local function touch(root,pad,kind)
        if kind==0 then f.Begins+=1; if f.BeginError then error("begin") end
        else f.Ends+=1; if f.EndError then error("end") end end
    end
    installMapVoteRepeat({State=f.State,Clock=function() return f.Now end,Heartbeat=f.Heartbeat,
        Connect=function(s,fn) return s:Connect(fn) end,Watch=function(s,fn) return s:Connect(fn) end,
        Touch=not noTouch and touch or nil,ReadPads=function() return f.Removed and {} or {f.Entry} end,
        OwnTouch=function(hit) return hit==f.Root end,Blocked=function() return f.Blocked end,
        Character=function() return f.Char,f.Hum,f.Root end,
        PadFrame=function(pad) return pad.Frame end,
        MovePad=function(pad,root) pad.Frame=root; return root end,
        RestorePad=function(pad,original,moved)
            if f.RestoreError then error("restore") end
            if pad.Parent and (not moved or pad.Frame==moved) then pad.Frame=original; f.Restores+=1 end
        end,
        Reset=function(hum) f.Resets+=1; if f.ResetError then error("reset") end; hum.Health=0 end})
    function f.Advance(dt) f.Now+=dt or .26; f.Heartbeat:Fire() end
    function f.Enable() local ok=f.State.SetMapVoteRepeat(true); f.Advance(); return ok end
    function f.Select() f.Pad.Touched:Fire(f.Root) end
    function f.FirstReset() f.Enable(); f.Select(); f.Advance(1.01) end
    function f.Spawn() f.Char={}; f.Hum={Health=100}; f.Root={}; f.Advance(); f.Advance(.36) end
    function f.FinishTouch(increase)
        f.Advance(.11)
        if increase then f.Entry.Votes+=1 end
        f.Advance(1.51)
    end
    return f
end

do
    local f=fixture()
    check(not f.State.Config.MapVoteRepeat,"voting automation always starts off, including after reload")
    f.Enable(); f.Advance(10)
    check(f.Resets==0 and f.Begins==0,"enabling alone never respawns or touches a map")
    f.Pad.Touched:Fire({}); f.Advance(2)
    check(f.Resets==0,"another player's touch cannot select your map")
    f.Select(); f.Advance(.5)
    check(f.Resets==0,"natural vote gets a settling interval before reset")
    f.Advance(.6)
    check(f.Resets==1 and f.State.MapVote.Phase=="AwaitRespawn","your chosen live pad requests one respawn")
    f.Advance(1)
    check(f.Resets==1 and f.Begins==0,"old character is never treated as a respawn")
    f.Spawn()
    check(f.Begins==1 and f.Pad.Frame==f.Root,"new character gets one brief moved-pad touch")
    f.FinishTouch(false)
    check(f.Ends==1 and f.Pad.Frame==f.OriginalFrame,"touch ends and original pad position is restored")
    check(f.Resets==1 and not f.State.Config.MapVoteRepeat and f.State.MapVote.Status:find("No additional",1,true),
        "unchanged server count stops further respawns")
end

do
    local f=fixture(); f.FirstReset()
    for i=1,3 do f.Spawn(); f.FinishTouch(true) end
    check(f.Resets==3 and f.Begins==3 and f.Ends==3,"even growing totals cannot exceed three respawns per activation")
    check(not f.State.Config.MapVoteRepeat and f.State.MapVote.ObservedIncrease==3,"bounded run ends with observed total increase, not attributed votes")
    local snap=f.State.GetMapVoteSnapshot(); snap.Respawns=100
    check(f.State.MapVote.Respawns==3,"support snapshots cannot mutate voting counters")
end

for _,reason in ipairs({"off","voting ended","maps changed","pad removed","menu blocked","character replaced","unload"}) do
    local f=fixture(); f.FirstReset(); f.Spawn()
    if reason=="off" then f.State.SetMapVoteRepeat(false)
    elseif reason=="voting ended" then f.Entry.Voting=false; f.Advance()
    elseif reason=="maps changed" then f.Entry.Map={}; f.Advance()
    elseif reason=="pad removed" then f.Removed=true; f.Pad.Parent=false; f.Advance()
    elseif reason=="menu blocked" then f.Blocked=true; f.Advance()
    elseif reason=="character replaced" then f.Char={}; f.Advance()
    elseif reason=="unload" then f.State.DestroyMapVoteRepeat() end
    check(f.Ends==1 and (not f.Pad.Parent or f.Pad.Frame==f.OriginalFrame) and not f.State.Config.MapVoteRepeat,
        reason.." cancels touch and cleans up moved pads")
    f.Advance(2)
    check(f.Resets==1 and f.Begins==1,reason.." cannot continue a queued respawn or touch")
end

do
    local f=fixture(); f.FirstReset(); f.Advance(12.1)
    check(f.Resets==1 and not f.State.Config.MapVoteRepeat and f.Begins==0,"failed respawn times out without repeated resets")
    f=fixture(true)
    check(not f.Enable() and f.Resets==0,"missing touch API refuses activation before any respawn")
    f=fixture(); f.Enable(); f.Entry.Voting=false; f.Select(); f.Advance(2)
    check(f.Resets==0,"closed voting pads cannot select a map")
    f=fixture(); f.Enable(); f.Entry.Map=nil; f.Select(); f.Advance(2)
    check(f.Resets==0,"pads without a map cannot select a map")
    f=fixture(); f.FirstReset(); f.BeginError=true; f.Spawn()
    check(f.Begins==1 and f.Ends==1 and f.Pad.Frame==f.OriginalFrame and not f.State.Config.MapVoteRepeat,
        "touch begin errors still pair end and restore the pad")
    f=fixture(); f.ResetError=true; f.FirstReset(); f.Advance(2)
    check(f.Resets==1 and not f.State.Config.MapVoteRepeat,"reset errors stop without retry loops")
    f=fixture(); f.FirstReset(); f.Spawn(); f.RestoreError=true
    check(not f.State.SetMapVoteRepeat(false),"failed pad restoration is reported, not hidden")
    f.RestoreError=false; f.Advance()
    check(f.Pad.Frame==f.OriginalFrame and f.Ends==1,"cleanup can recover after a failed restoration without duplicate touch end")
    f=fixture(); f.FirstReset(); f.Spawn(); local external={}; f.Pad.Frame=external; f.FinishTouch(false)
    check(f.Pad.Frame==external,"cleanup preserves newer external pad positioning")
    f=fixture(); f.Enable(); f.State.Config.MapVoteRepeat=false; f.Advance(); f.Select(); f.Advance(2)
    check(f.Resets==0 and f.Pad.Touched.Connections[1].Disconnected,"direct off disconnects pad listeners")
    f=fixture(); f.State.Config.MapVoteRepeat=true; f.Enable(); f.Select(); f.Advance(1.1)
    check(f.Resets==1,"menu preassignment still initializes the armed session")
    f=fixture(); f.FirstReset(); f.Spawn(); installEmergencyStop({State=f.State}); f.State.EmergencyStop(); f.Advance(2)
    check(f.Resets==1 and f.Ends==1 and f.Pad.Frame==f.OriginalFrame and not f.State.Config.MapVoteRepeat,
        "emergency stop cancels voting and restores the pad")
end
print(passed.." voting assertions passed")
