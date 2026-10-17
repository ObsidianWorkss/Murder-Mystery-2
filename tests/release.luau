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
print(string.format("%d release assertions passed",passed))
