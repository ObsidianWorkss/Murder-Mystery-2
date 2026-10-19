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
    local f={Now=10,Resets=0,Begins=0,Ends=0,Moves=0,Char={},Hum={Health=100},Root={},OriginalFrame={}}
    f.Heartbeat=signal(); f.Pad={Touched=signal(),Parent=true,Frame=f.OriginalFrame}
    f.Entry={Pad=f.Pad,Map={},Name="Test map",Voting=true,Votes=1}
    f.State={Running=true,Config={MapVoteRepeat=true}}
    local function touch(root,pad,kind)
        if kind==0 then f.Begins+=1; if f.BeginError then error("begin") end
        else f.Ends+=1; if f.EndError then error("end") end end
    end
    installMapVoteRepeat({State=f.State,Clock=function() return f.Now end,Heartbeat=f.Heartbeat,
        Connect=function(s,fn) return s:Connect(fn) end,Watch=function(s,fn) return s:Connect(fn) end,
        Touch=not noTouch and touch or nil,ReadPads=function() return f.Removed and {} or f.ReadOverride and f.ReadOverride() or {f.Entry} end,
        OwnTouch=function(hit) return hit==f.Root end,Blocked=function() return f.Blocked end,
        OnPad=function() return f.InPad==true end,
        Character=function() return f.Char,f.Hum,f.Root end,
        ApproachPad=function(root,pad)
            if f.ApproachError then error("approach") end
            f.Moves+=1; f.LastApproach={Root=root,Pad=pad}
        end,
        Reset=function(hum,char) f.Resets+=1; f.ResetCharacter=char; if f.ResetError then error("reset") end; hum.Health=0 end})
    function f.Advance(dt) f.Now+=dt or .26; f.Heartbeat:Fire() end
    function f.Enable() local ok=f.State.SetMapVoteRepeat(true); f.Advance(); return ok end
    function f.Select() f.Pad.Touched:Fire(f.Root) end
    function f.FirstReset() f.Enable(); f.Select(); f.Advance(1.01) end
    function f.Spawn() f.Char={}; f.Hum={Health=100}; f.Root={}; f.Advance(); f.Advance(.36) end
    function f.FinishTouch(increase)
        f.Advance(.26)
        if increase then f.Entry.Votes+=1 end
        f.Advance(2.01)
    end
    return f
end

do
    local f=fixture()
    check(not f.State.Config.MapVoteRepeat,"voting automation always starts off, including after reload")
    f.Enable(); f.Advance(10)
    check(f.Resets==0 and f.Begins==0,"enabling alone never respawns or touches a map")
    check(f.State.MapVote.Status:find("Voting is open",1,true),"armed status explains that voting is open but no map has been selected")
    f.Pad.Touched:Fire({}); f.Advance(2)
    check(f.Resets==0,"another player's touch cannot select your map")
    f.Select(); f.Advance(.5)
    check(f.Resets==0,"natural vote gets a settling interval before reset")
    f.Advance(.6)
    check(f.Resets==1 and f.State.MapVote.Phase=="AwaitRespawn","your chosen live pad requests one respawn")
    f.Advance(1)
    check(f.Resets==1 and f.Begins==0,"old character is never treated as a respawn")
    f.Spawn()
    check(f.Begins==1 and f.Moves==1 and f.LastApproach.Root==f.Root and f.LastApproach.Pad==f.Pad,
        "new character returns to the same actual voting detector before re-voting")
    f.FinishTouch(false)
    check(f.Ends==1 and f.Pad.Frame==f.OriginalFrame,"paired touch ends without ever moving the voting pad")
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
        reason.." cancels touch without moving map geometry")
    f.Advance(2)
    check(f.Resets==1 and f.Begins==1,reason.." cannot continue a queued respawn or touch")
end

do
    local f=fixture(); f.FirstReset(); f.Advance(12.1)
    check(f.Resets==1 and not f.State.Config.MapVoteRepeat and f.Begins==0,"failed respawn times out without repeated resets")
    f=fixture(true); f.FirstReset(); f.Spawn(); f.FinishTouch(false)
    check(f.Resets==1 and f.Moves==1 and f.Begins==0 and f.Ends==0,
        "normal physical re-voting works without the optional executor touch API")
    f=fixture(); f.Enable(); f.Entry.Voting=false; f.Select(); f.Advance(2)
    check(f.Resets==0,"closed voting pads cannot select a map")
    f=fixture(); f.Enable(); f.Entry.Map=nil; f.Select(); f.Advance(2)
    check(f.Resets==0,"pads without a map cannot select a map")
    f=fixture(); f.FirstReset(); f.BeginError=true; f.Spawn()
    check(f.Begins==1 and f.Ends==1 and f.Pad.Frame==f.OriginalFrame and not f.State.Config.MapVoteRepeat,
        "touch begin errors still pair end without moving the pad")
    f=fixture(); f.ResetError=true; f.FirstReset(); f.Advance(2)
    check(f.Resets==1 and not f.State.Config.MapVoteRepeat,"reset errors stop without retry loops")
    f=fixture(); f.FirstReset(); f.Spawn(); f.EndError=true
    check(not f.State.SetMapVoteRepeat(false),"failed touch end is reported, not hidden")
    f.EndError=false; f.Advance()
    check(f.Pad.Frame==f.OriginalFrame and f.Ends==2,"failed touch end retries cleanup without repeating vote or reset")
    f=fixture(); f.FirstReset(); f.Spawn(); local external={}; f.Pad.Frame=external; f.FinishTouch(false)
    check(f.Pad.Frame==external,"cleanup never writes external pad positioning")
    f=fixture(); f.Enable(); f.State.Config.MapVoteRepeat=false; f.Advance(); f.Select(); f.Advance(2)
    check(f.Resets==0 and f.Pad.Touched.Connections[1].Disconnected,"direct off disconnects pad listeners")
    f=fixture(); f.State.Config.MapVoteRepeat=true; f.Enable(); f.Select(); f.Advance(1.1)
    check(f.Resets==1,"menu preassignment still initializes the armed session")
    f=fixture(); f.FirstReset(); f.Spawn(); installEmergencyStop({State=f.State}); f.State.EmergencyStop(); f.Advance(2)
    check(f.Resets==1 and f.Ends==1 and f.Pad.Frame==f.OriginalFrame and not f.State.Config.MapVoteRepeat,
        "emergency stop cancels voting and pairs the touch")
    f=fixture(); f.Enable(); f.InPad=true; f.Advance(); f.Advance(1.01)
    check(f.Resets==1,"standing inside a real detector selects a map even without a fresh Touched event")
    check(f.ResetCharacter==f.Char,"reset receives the exact character that cast the vote")
    f=fixture(); f.FirstReset(); f.ApproachError=true; f.Spawn()
    check(f.Begins==0 and not f.State.Config.MapVoteRepeat,"failed physical approach stops before sending a fake contact")
    f=fixture(); f.Entry.Voting=false; f.Enable()
    check(f.State.MapVote.Status=="Waiting for map voting to open" and f.State.MapVote.ActivePads==0,"closed voting has an explicit waiting reason")
    f=fixture(); f.Blocked="Close the script menu"; f.Enable(); f.Select(); f.Advance(2)
    check(f.Resets==0 and f.State.MapVote.Status:find("Close the script menu",1,true),"input conflict reports the exact reason without resetting")
    f=fixture(); f.Removed=true; f.Enable()
    check(f.State.MapVote.Status:find("Voting pads unavailable",1,true),"missing pads report a separate waiting reason")
end

do
    local function node(kind,children,value)
        return {Value=value,FindFirstChild=function(_,name) return children and children[name] end,
            IsA=function(_,class) return kind==class end}
    end
    local icon=node("BasePart",{Map=node("ObjectValue",nil,{Name="Chosen map"}),
        Voting=node("BoolValue",nil,true),Votes=node("IntValue",nil,2)})
    local detector=node("BasePart")
    local lobby=node("Model",{VoteIcons=node("Model",{VotePad1=icon}),VotePads=node("Model",{Detector1=detector})})
    local entries=readMapVotePads(node("Workspace",{RegularLobby=lobby}))
    check(#entries==1 and entries[1].Pad==detector and entries[1].Pad~=icon,
        "shipped pad adapter selects actual Detector1, not its separate display icon")
    check(entries[1].Map.Name=="Chosen map" and entries[1].Voting and entries[1].Votes==2,
        "actual detector is paired with the same numbered display's server voting metadata")
    check(#readMapVotePads(node("Workspace",{RegularLobby=node("Model",{VoteIcons=node("Model",{VotePad1=icon})})}))==0,
        "display-only geometry cannot become a voting target")
    local label=node("TextLabel"); label.Text="House 2"
    local count=node("TextLabel"); count.Text="Votes: 2"
    local parts={MapName=label,Votes=count}
    local container=node("Frame",parts); container.Visible=true
    local guichildren={Container=container}
    local gui=node("SurfaceGui",guichildren); gui.Enabled=true
    local model=node("Model",{VoteInfoGui=gui,Pad=detector})
    local children={VoteIcons=node("Model",{VotePad1=icon}),VotePads=node("Model",{Detector1=detector}),VotePad1=model}
    local world=node("Workspace",{RegularLobby=node("Model",children)})
    icon:FindFirstChild("Map").Value=nil; icon:FindFirstChild("Voting").Value=false; icon:FindFirstChild("Votes").Value=0
    entries=readMapVotePads(world)
    check(entries[1].Voting and entries[1].Map=="House 2" and entries[1].Votes==2 and entries[1].Source=="VotingBoard",
        "live enabled board overrides legacy false/nil/zero fields observed in the real failure")
    local identity=entries[1].Map
    check(readMapVotePads(world)[1].Map==identity,"board map identity remains stable between adapter reads")
    gui.Enabled=false; icon:FindFirstChild("Voting").Value=true; icon:FindFirstChild("Map").Value={Name="Stale"}
    check(not readMapVotePads(world)[1].Voting,"disabled current board cannot fall back to stale legacy active flags")
    gui.Enabled=true; container.Visible=false
    check(not readMapVotePads(world)[1].Voting,"hidden voting container is not an active vote")
    container.Visible=true; parts.MapName=nil
    check(not readMapVotePads(world)[1].Voting,"partially loaded board never falls back to stale legacy metadata")
    guichildren.Container=nil
    check(not readMapVotePads(world)[1].Voting,"missing current board container waits without crashing or using stale values")
    guichildren.Container=container
    parts.MapName=label; count.Text="Waiting..."
    check(not readMapVotePads(world)[1].Voting,"unreadable current vote count cannot start a reset")
    count.Text="Votes: 2"; children.VoteIcons=nil; children.VotePads=nil
    check(readMapVotePads(world)[1].Pad==detector and readMapVotePads(world)[1].Voting,
        "current board and native Pad work even without legacy icon and detector folders")
    local f=fixture(); model=node("Model",{VoteInfoGui=gui,Pad=f.Pad}); f.Pad.IsA=function(_,class) return class=="BasePart" end
    world=node("Workspace",{RegularLobby=node("Model",{VotePad1=model})})
    f.ReadOverride=function() return readMapVotePads(world) end
    f.FirstReset()
    check(f.Resets==1 and f.State.MapVote.Detection=="Touch" and f.State.MapVote.MetadataSource=="VotingBoard",
        "shipped controller and board adapter start a reset after a genuine map-pad touch")
    f.Spawn(); count.Text="Votes: 3"; f.FinishTouch(false)
    check(f.Resets==2 and f.State.MapVote.ObservedIncrease==1,"board count updates drive the next repeated reset")
    local breaks=0; local char={BreakJoints=function() breaks+=1 end}; local hum={Health=100,Parent=char}
    resetMapVoteCharacter(hum,char)
    check(hum.Health==0 and breaks==1,"reset adapter requests death and breaks the current character's joints")
    check(not pcall(resetMapVoteCharacter,{Parent={}},char) and breaks==1,"reset adapter rejects a replaced character")

    local currentPads={}
    local nestedChildren={}
    for i=1,3 do
        currentPads[i]=node("BasePart")
        nestedChildren["VotePad"..i]=node("Model",{VoteInfoGui=gui,Pad=currentPads[i]})
    end
    local currentLobby=node("Model",{VotePads=node("Model",nestedChildren)})
    world=node("Workspace",{Lobby=currentLobby})
    entries=readMapVotePads(world)
    check(#entries==3 and entries[1].Pad==currentPads[1] and entries[3].Pad==currentPads[3],
        "current Lobby/VotePads/VotePad1-3 uses each model's actual Pad")
    check(entries[1].Layout=="NestedVotePads" and entries[1].Source=="VotingBoard" and entries[1].Slot==1,
        "nested current boards retain slot and layout diagnostics")
    check(entries[2].Voting and entries[2].Map=="House 2" and entries[2].Votes==3,
        "nested boards provide map identity and count without VoteIcons or Detector objects")
    gui.Enabled=false
    entries=readMapVotePads(world)
    check(#entries==3 and not entries[1].Voting and not entries[3].Voting,
        "disabled current nested boards remain available but inactive")
    local legacy=node("Model",{VoteIcons=node("Model",{VotePad1=icon}),VotePads=node("Model",{Detector1=detector})})
    local both=node("Workspace",{Lobby=currentLobby,RegularLobby=legacy})
    entries=readMapVotePads(both)
    check(#entries==3 and not entries[1].Voting and entries[1].Pad==currentPads[1],
        "closed current lobby never falls back to stale active RegularLobby votes")
    gui.Enabled=true
    local loading=node("Workspace",{Lobby=node("Model",{VotePads=node("Model",{})}),RegularLobby=legacy})
    check(#readMapVotePads(loading)==0,"empty current container waits for loading instead of activating old-lobby metadata")
    local decorative=node("Workspace",{Lobby=node("Model",{}),RegularLobby=legacy})
    check(readMapVotePads(decorative)[1].Pad==detector,"legacy lobby is supported when the new lobby has no voting structure")
    nestedChildren.VotePad2=node("Model",{VoteInfoGui=gui})
    check(#readMapVotePads(world)==2,"board without a physical pad is not a target")
    nestedChildren.VotePad2=node("Model",{VoteInfoGui=gui,Pad=node("Model")})
    check(#readMapVotePads(world)==2,"non-part nested pad is rejected")
    local current=fixture()
    current.Pad.IsA=function(_,kind) return kind=="BasePart" end
    local currentWorld=node("Workspace",{Lobby=node("Model",{VotePads=node("Model",{
        VotePad1=node("Model",{Pad=current.Pad,VoteInfoGui=gui})})})})
    current.ReadOverride=function() return readMapVotePads(currentWorld) end
    current.FirstReset()
    check(current.Resets==1 and current.State.MapVote.Detection=="Touch",
        "current nested pad touch reaches the shipped controller's first reset")
    local snapshot=current.State.GetMapVoteSnapshot()
    check(snapshot.Pads==1 and snapshot.ActivePads==1 and snapshot.Layout=="NestedVotePads",
        "support report distinguishes available nested pads from active votes")
    current.State.StopMapVoteRepeat();current.Advance(2)
    check(current.Resets==1,"explicit Off still prevents further resets after a nested-layout selection")
end
print(passed.." voting assertions passed")
