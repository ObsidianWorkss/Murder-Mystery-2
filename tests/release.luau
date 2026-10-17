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
    local me,killer,cop,hero,lobbyKiller={Name="Me"},{Name="Killer"},{Name="Cop"},{Name="Hero"},{Name="OldKiller"}
    -- roles holds the round data role; RoleFor folds it the way the script's roleFor does.
    local roles={[me]="Innocent",[killer]="Murderer",[cop]="Sheriff",[hero]="Innocent",[lobbyKiller]="Murderer"}
    local inRound={[me]=true,[killer]=true,[cop]=true,[hero]=true,[lobbyKiller]=false}
    local guns,excluded,sent,sendResult={},{},{},{true}
    local State={IsPlayerExcluded=function(p) return excluded[p]==true end}
    local C={State=State,Player=me,Clock=function() return now end,
        Players={GetPlayers=function() return {me,lobbyKiller,cop,hero,killer} end},
        RawRole=function(p) return roles[p] end,HasGun=function(p) return guns[p]==true end,
        RoleFor=function(p)
            local role=roles[p]
            if role=="Murderer" then return "Murderer" end
            if guns[p] or role=="Sheriff" or role=="Hero" then return "Sheriff" end
            return role or "Unknown"
        end,
        InRound=function(p) return inRound[p]==true end,
        ViewerInRound=function() return false end,
        Send=function(message) table.insert(sent,message); return table.unpack(sendResult) end}
    -- INSERT_REVEAL
    installRoleReveal(C)
    local both="🔪 Murderer: @Killer • 🔫 Sheriff: @Cop"
    check(State.GetRoleReveal()==both,"reveal names the round murderer and sheriff")
    inRound[cop]=false
    check(State.GetRoleReveal()=="🔪 Murderer: @Killer • 💀 Sheriff: dead","reveal reports a dead sheriff")
    roles[hero],guns[hero]="Hero",true
    check(State.GetRoleReveal()=="🔪 Murderer: @Killer • 💀 Sheriff: dead • 🦸 Hero: @Hero","reveal names the hero after the sheriff dies")
    roles[hero]="Innocent"
    check(State.GetRoleReveal()=="🔪 Murderer: @Killer • 💀 Sheriff: dead • 🦸 Hero: @Hero","a gun holder counts as hero before round data updates")
    excluded[hero]=true
    check(State.GetRoleReveal()=="🔪 Murderer: @Killer • 💀 Sheriff: dead","reveal omits a protected hero")
    excluded[hero],guns[hero],roles[hero]=nil,nil,"Innocent"
    roles[me],guns[me]="Hero",true
    check(State.GetRoleReveal()=="🔪 Murderer: @Killer • 💀 Sheriff: dead","reveal never names you as hero")
    roles[me],guns[me]="Innocent",nil
    inRound[cop],roles[cop],guns[cop]=true,nil,true
    check(State.GetRoleReveal()==both,"without round data the gun holder counts as sheriff")
    roles[cop],guns[cop]="Innocent",nil; roles[me]="Sheriff"
    check(State.GetRoleReveal()=="🔪 Murderer: @Killer","reveal never names you as sheriff")
    roles[me],roles[killer]="Murderer","Innocent"
    local message,reason=State.GetRoleReveal()
    check(message==nil and reason=="You are the murderer","reveal refuses when you are the murderer")
    roles[me],roles[killer],roles[cop]="Innocent","Murderer","Sheriff"
    excluded[killer]=true
    message,reason=State.GetRoleReveal()
    check(message==nil and reason=="The murderer is protected","reveal skips a protected murderer")
    excluded[killer],excluded[cop]=nil,true
    check(State.GetRoleReveal()=="🔪 Murderer: @Killer","reveal omits a protected sheriff")
    excluded[cop]=nil; inRound[killer]=false
    message,reason=State.GetRoleReveal()
    check(message==nil and reason=="Murderer not known yet","lobby leftovers are not revealed as murderer")
    inRound[killer],inRound[me]=true,false
    message,reason=State.GetRoleReveal()
    check(message==nil and reason=="Available during a round","reveal waits for a round")
    inRound[me]=true
    check(#sent==0,"previews never send a chat message")
    local ok,result=State.RevealRolesInChat()
    check(ok and #sent==1 and sent[1]==both and result:find("Sent",1,true),"reveal sends one message")
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
do
    -- Movement: a fake character and signals; nothing here touches a real game.
    local now=0
    local vector
    local vectorMeta={__add=function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end,
        __sub=function(a,b) return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end,
        __mul=function(a,k) return vector(a.X*k,a.Y*k,a.Z*k) end,
        __index=function(a,key) if key=="Unit" then return vector(a.X/a.Magnitude,a.Y/a.Magnitude,a.Z/a.Magnitude) end return nil end}
    function vector(x,y,z) return setmetatable({X=x,Y=y,Z=z,Magnitude=math.sqrt(x*x+y*y+z*z)},vectorMeta) end
    local Vector3={new=vector,zero=vector(0,0,0),yAxis=vector(0,1,0)}
    local CFrame={lookAt=function(position) return {Position=position,LookVector=vector(0,0,-1)} end}
    local Enum={KeyCode={Space="Space",LeftControl="LeftControl"},Material={Air="Air",Grass="Grass"},
        HumanoidStateType={Jumping="Jumping"}}
    local workspace={Gravity=196.2}
    local created={}
    local Instance={new=function(class)
        local object={ClassName=class,Parent=nil}
        function object:Destroy() self.Parent=nil; self.Destroyed=true end
        table.insert(created,object)
        return object
    end}
    local function part(collide) return {CanCollide=collide,Parent=true,IsA=function(_,class) return class=="BasePart" end} end
    local head,torso,leg=part(true),part(true),part(false)
    local root=part(true); root.Position=vector(0,5,0); root.CFrame={LookVector=vector(0,0,-1),RightVector=vector(1,0,0)}
    local states={}
    local hum={Health=100,Parent=true,WalkSpeed=16,JumpPower=50,JumpHeight=7.2,UseJumpPower=true,PlatformStand=false,
        FloorMaterial="Grass",MoveDirection=vector(0,0,0)}
    function hum:ChangeState(state) table.insert(states,state) end
    local char={hum=hum}
    function char:FindFirstChildOfClass(class) return class=="Humanoid" and hum or nil end
    function char:FindFirstChild(name) return name=="HumanoidRootPart" and root or nil end
    function char:GetChildren() return {head,torso,leg,root} end
    local player={Character=char}
    local keys={}
    local UIS={GetFocusedTextBox=function() return nil end,IsKeyDown=function(_,key) return keys[key]==true end,JumpRequest={}}
    local State={Running=true,Config={WalkSpeed=24,JumpPower=80,FlySpeed=50,SpeedBoost=true,Noclip=true}}
    local connections={}
    local C={State=State,Player=player,UIS=UIS,Clock=function() return now end,
        RunService={Stepped="Stepped",Heartbeat="Heartbeat"},Connect=function(signal,callback) connections[signal]=callback end}
    -- INSERT_MOVEMENT
    installMovement(C)
    local move,cfg=State.Movement,State.Config
    check(not cfg.SpeedBoost and not cfg.Noclip,"movement toggles start off after a reload")
    check(connections.Stepped and connections.Heartbeat and connections[UIS.JumpRequest],"movement hooks physics and jump input")
    cfg.SpeedBoost=true; move.Step()
    check(hum.WalkSpeed==24,"speed boost sets walk speed")
    hum.WalkSpeed=17; move.Step()
    check(hum.WalkSpeed==24,"speed boost holds after the game changes speed")
    cfg.SpeedBoost=false; move.Step()
    check(hum.WalkSpeed==17,"switching speed off restores the game's latest speed")
    hum.WalkSpeed=0; cfg.SpeedBoost=true; move.Step()
    check(hum.WalkSpeed==0,"speed boost never unfreezes a frozen player")
    hum.WalkSpeed=16; move.Step(); cfg.SpeedBoost=false; move.Step()
    cfg.JumpBoost=true; move.Step()
    check(hum.JumpPower==80,"jump boost sets jump power")
    cfg.JumpBoost=false; move.Step()
    check(hum.JumpPower==50,"jump boost restores jump power")
    hum.UseJumpPower=false; cfg.JumpBoost=true; move.Step()
    check(math.abs(hum.JumpHeight-80^2/(2*196.2))<1e-6,"jump boost converts power to height for height-based rigs")
    cfg.JumpBoost=false; move.Step()
    check(hum.JumpHeight==7.2,"jump height is restored")
    cfg.Noclip=true; move.StepNoclip()
    check(not head.CanCollide and not torso.CanCollide and not root.CanCollide,"noclip disables body collisions")
    State.Fling={Active=true}; move.StepNoclip()
    check(head.CanCollide and torso.CanCollide and not leg.CanCollide,"noclip pauses for fling and restores only original collisions")
    State.Fling=nil; move.StepNoclip(); cfg.Noclip=false; move.StepNoclip()
    check(head.CanCollide and root.CanCollide and not leg.CanCollide,"switching noclip off restores collisions")
    cfg.InfiniteJump=true; move.JumpRequested()
    check(#states==0,"infinite jump leaves ground jumps to the game")
    hum.FloorMaterial="Air"; move.JumpRequested(); move.JumpRequested()
    check(#states==1,"infinite jump fires once per press in mid-air")
    now+=.3; move.JumpRequested()
    check(#states==2,"infinite jump repeats after the hold delay")
    cfg.Fly=true; move.Step()
    check(#created==2 and created[1].Parent==root and hum.PlatformStand,"fly attaches movers and stands the humanoid")
    keys.Space=true; move.Step()
    check(created[1].Velocity.Y==50 and created[1].Velocity.X==0 and not move.Status:find("stopped"),"fly climbs at fly speed while Space is held")
    keys.Space=nil; move.Vertical=-1; move.Step()
    check(created[1].Velocity.Y==-50,"fly sinks while the mobile Down button is held")
    move.Vertical=0; hum.Jump=true; move.Step()
    check(created[1].Velocity.Y==50,"holding the jump button rises while flying")
    hum.Jump=false; move.Vertical=1
    now+=1; move.JumpRequested()
    check(#states==2,"infinite jump stays off while flying")
    cfg.SpeedBoost,cfg.Noclip=true,true; move.Step(); move.StepNoclip()
    State.StopMovement()
    check(created[1].Destroyed and created[2].Destroyed and not hum.PlatformStand and move.Vertical==0,
        "stopping movement removes fly movers and releases the Up/Down hold")
    check(not (cfg.SpeedBoost or cfg.JumpBoost or cfg.InfiniteJump or cfg.Noclip or cfg.Fly) and hum.WalkSpeed==16 and head.CanCollide,
        "stopping movement turns every assist off and restores the character")
end
print(string.format("%d release assertions passed",passed))
