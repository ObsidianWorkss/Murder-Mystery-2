local passed=0
local function check(value,message)
    assert(value,message); passed+=1; print("PASS: "..message)
end
do
    local State={Version="1.0.0-rc.1",Build="test",ReleaseChannel="Release candidate",Running=true,
        Config={Aim=true,ExcludedPlayers={SecretPlayer=true}},Stats={GunRequests=2,SecretKey="do not include"},
        WeaponHandlers={[{}]={}},Connections={{Connected=true},{Connected=false},{}},PendingGun={{}},
        Performance={Selections=5,TargetName="do not include"},Target="PrivatePlayer"}
    local Players={GetPlayers=function() return {{},{}} end}
    local encoded
    local game={PlaceId=142823291,PlaceVersion=1,GetService=function()
        return {JSONEncode=function(_,value) encoded=value; return "encoded-report" end}
    end}
    local setclipboard,toclipboard,firetouchinterest,readfile,isfile,writefile,makefolder,isfolder
    -- INSERT_SUPPORT
    local report=State.GetSupportSnapshot()
    check(report.Version==State.Version and report.Players==2,"support report identifies version and counts")
    check(report.WeaponHandlers==1 and report.Connections==2 and report.PendingShots==1,"support resource counts are accurate")
    check(report.Settings.Aim and not report.Settings.KillAura,"support settings are explicit booleans")
    check(report.Target==nil and report.Settings.ExcludedPlayers==nil and report.Stats.SecretKey==nil
        and report.Performance.TargetName==nil,"support report excludes identity and arbitrary secret fields")
    check(not report.Capabilities.Clipboard and not report.Capabilities.FileWrite,"missing optional capabilities are reported")
    toclipboard=function() end; readfile=function() end; isfile=function() end
    report=State.GetSupportSnapshot()
    check(report.Capabilities.Clipboard and report.Capabilities.FileRead,"fallback clipboard and file capabilities are detected")
    check(State.GetSupportReport()=="encoded-report" and encoded.Version==State.Version,"support report serializes the bounded snapshot")
end
do
    local mode,executions="success",0
    local game={HttpGet=function()
        if mode=="network" then error("mock network failure") end
        return mode=="html" and "<html>error</html>" or "local createLibrary = function() end"
    end}
    local loadstring=function(source,name)
        assert(name=="@MM2Universal" and type(source)=="string")
        if mode=="syntax" then return nil,"mock syntax error" end
        return function()
            executions+=1
            if mode=="startup" then error("mock startup error") end
            return "loaded"
        end
    end
    local function boot()
        -- INSERT_LOADER
    end
    check(boot()=="loaded" and executions==1,"loader executes a successful download once")
    for _,case in ipairs({{"network","download failed"},{"html","not the expected script"},
        {"syntax","compilation failed"},{"startup","startup failed"}}) do
        mode=case[1]
        local ok,message=pcall(boot)
        check(not ok and tostring(message):find(case[2],1,true)~=nil,"loader reports "..case[1].." failure")
    end
    check(executions==2,"network, invalid response and syntax failures never execute the script")
    loadstring=nil
    local ok,message=pcall(boot)
    check(not ok and tostring(message):find("does not provide loadstring",1,true)~=nil,"loader reports unsupported environment")
end
do
    -- Role reveal: a fake Send records messages, so nothing reaches a real chat.
    local now=100
    local me,killer,cop,lobbyKiller={Name="Me"},{Name="Killer"},{Name="Cop"},{Name="OldKiller"}
    local roles={[me]="Innocent",[killer]="Murderer",[cop]="Sheriff",[lobbyKiller]="Murderer"}
    local inRound={[me]=true,[killer]=true,[cop]=true,[lobbyKiller]=false}
    local excluded,sent,sendResult={},{},{true}
    local State={IsPlayerExcluded=function(p) return excluded[p]==true end}
    local C={State=State,Player=me,Clock=function() return now end,
        Players={GetPlayers=function() return {me,lobbyKiller,cop,killer} end},
        RoleFor=function(p) return roles[p] end,InRound=function(p) return inRound[p]==true end,
        ViewerInRound=function() return false end,
        Send=function(message) table.insert(sent,message); return table.unpack(sendResult) end}
    -- INSERT_REVEAL
    installRoleReveal(C)
    check(State.GetRoleReveal()=="Murderer: @Killer • Sheriff: @Cop","reveal names the round murderer and sheriff")
    inRound[cop]=false
    check(State.GetRoleReveal()=="Murderer: @Killer • Sheriff: dead","reveal reports a dead sheriff")
    inRound[cop]=true; roles[cop],roles[me]="Innocent","Sheriff"
    check(State.GetRoleReveal()=="Murderer: @Killer","reveal never names you as sheriff")
    roles[me],roles[killer]="Murderer","Innocent"; inRound[lobbyKiller]=false
    local message,reason=State.GetRoleReveal()
    check(message==nil and reason=="You are the murderer","reveal refuses when you are the murderer")
    roles[me],roles[killer],roles[cop]="Innocent","Murderer","Sheriff"
    excluded[killer]=true
    message,reason=State.GetRoleReveal()
    check(message==nil and reason=="The murderer is protected","reveal skips a protected murderer")
    excluded[killer],excluded[cop]=nil,true
    check(State.GetRoleReveal()=="Murderer: @Killer","reveal omits a protected sheriff")
    excluded[cop]=nil; inRound[killer]=false
    message,reason=State.GetRoleReveal()
    check(message==nil and reason=="Murderer not known yet","lobby leftovers are not revealed as murderer")
    inRound[killer],inRound[me]=true,false
    message,reason=State.GetRoleReveal()
    check(message==nil and reason=="Available during a round","reveal waits for a round")
    inRound[me]=true
    check(#sent==0,"previews never send a chat message")
    local ok,result=State.RevealRolesInChat()
    check(ok and #sent==1 and sent[1]=="Murderer: @Killer • Sheriff: @Cop" and result:find("Sent",1,true),"reveal sends one message")
    now+=1
    ok,result=State.RevealRolesInChat()
    check(not ok and #sent==1 and result=="Wait 3 s","reveal cooldown blocks repeat messages")
    now+=4; sendResult={false,"Chat send failed: mock"}
    ok,result=State.RevealRolesInChat()
    check(not ok and result=="Chat send failed: mock" and State.RoleReveal.Sent==1,"failed send is reported and not counted")
    sendResult={true}
    ok=State.RevealRolesInChat()
    check(ok and #sent==3 and State.RoleReveal.Sent==2,"a failed send does not start the cooldown")
end
print(string.format("%d release assertions passed",passed))
