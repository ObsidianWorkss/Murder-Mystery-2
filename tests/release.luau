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
    check(report.Settings.Aim and not report.Settings.KillAura and not report.Settings.Triggerbot,"support settings are explicit booleans")
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
do
    -- X-ray: a fake workspace tree; nothing here touches a real game.
    local now=0
    local function node(class,name,parent,props)
        local n={ClassName=class,Name=name,Parent=parent,Children={}}
        for key,value in pairs(props or {}) do n[key]=value end
        function n:IsA(kind) return self.ClassName==kind or (kind=="BasePart" and (self.ClassName=="Part" or self.ClassName=="MeshPart")) end
        function n:FindFirstChildOfClass(kind) for _,child in ipairs(self.Children) do if child.ClassName==kind then return child end end return nil end
        if parent then table.insert(parent.Children,n) end
        return n
    end
    local function part(name,parent,props)
        local p=node("Part",name,parent,props)
        p.Transparency=p.Transparency or 0
        p.LocalTransparencyModifier=p.LocalTransparencyModifier or 0
        return p
    end
    local world=node("Workspace","Workspace",nil)
    function world:GetDescendants()
        local list={}
        local function walk(n) for _,child in ipairs(n.Children) do table.insert(list,child); walk(child) end end
        walk(self)
        return list
    end
    local map=node("Model","Bank",world)
    local wall,floor=part("Wall",map),part("Floor",map)
    local tinted=part("Window",map,{LocalTransparencyModifier=.2})
    local hidden=part("Barrier",map,{Transparency=1})
    local hero=node("Model","Player1",world); node("Humanoid","Humanoid",hero)
    local body=part("Torso",hero)
    local tool=node("Tool","Knife",hero); local blade=part("Handle",tool)
    local gun=part("GunDrop",world)
    local coins=node("Model","CoinContainer",map); local coin=part("Coin_Server",coins)
    local ours=node("Folder","MM2AssistVisuals",world); local marker=part("Marker",ours)
    local State={Running=true,Config={XRay=false,XRayAmount=60}}
    local connections={}
    local C={State=State,Workspace=world,Clock=function() return now end,Batch=3,
        RunService={Heartbeat="Heartbeat"},Connect=function(signal,callback) connections[signal]=callback end}
    world.DescendantAdded="DescendantAdded"
    -- INSERT_XRAY
    installXRay(C)
    local xray=State.XRay
    check(connections.Heartbeat and connections.DescendantAdded,"x-ray hooks frames and new parts")
    xray.Step()
    check(wall.LocalTransparencyModifier==0 and not xray.Active,"x-ray stays off until switched on")
    State.Config.XRay=true
    xray.Step()
    check(xray.Active and xray.Count()<4,"x-ray spreads a big map across frames")
    for _=1,10 do xray.Step() end
    check(wall.LocalTransparencyModifier==.6 and floor.LocalTransparencyModifier==.6 and tinted.LocalTransparencyModifier==.6,
        "x-ray makes map parts see-through")
    check(hidden.LocalTransparencyModifier==0 and body.LocalTransparencyModifier==0 and blade.LocalTransparencyModifier==0,
        "invisible parts, players and tools stay as they are")
    check(gun.LocalTransparencyModifier==0 and coin.LocalTransparencyModifier==0 and marker.LocalTransparencyModifier==0,
        "the dropped gun, coins and the script's own objects stay solid")
    check(xray.Count()==3,"x-ray tracks only the map parts it changed")
    State.Config.XRayAmount=80; xray.Step()
    check(wall.LocalTransparencyModifier==.6,"strength changes wait for the update interval")
    now+=.3; xray.Step()
    check(wall.LocalTransparencyModifier==.8 and floor.LocalTransparencyModifier==.8,"strength changes reach every tracked part")
    local door=part("Door",map); connections.DescendantAdded(door); xray.Step()
    check(door.LocalTransparencyModifier==.8,"parts that load later become see-through")
    floor.LocalTransparencyModifier=.35
    State.Config.XRay=false; xray.Step()
    check(wall.LocalTransparencyModifier==0 and door.LocalTransparencyModifier==0 and tinted.LocalTransparencyModifier==.2,
        "switching x-ray off restores each part's original value")
    check(floor.LocalTransparencyModifier==.35 and not xray.Active and xray.Count()==0,"x-ray leaves values the game changed")
    State.Config.XRay=true
    for _=1,10 do xray.Step() end
    State.StopXRay()
    check(wall.LocalTransparencyModifier==0 and tinted.LocalTransparencyModifier==.2,"unload restores the map")
end
do
    -- Animation packs: the shipped table covers every movement slot of every pack.
    local State={Config={AnimationPack="Ninja"}}
    -- INSERT_PACKS
    local slots={"idle","walk","run","jump","fall","climb","swim","swimidle"}
    check(#packNames==17 and packNames[1]=="Astronaut" and packNames[17]=="Zombie","seventeen packs are listed in order")
    local complete,owners,shared=true,{},0
    for _,name in ipairs(packNames) do
        local pack=animationPacks[name]
        if #pack.idle~=3 then complete=false end
        for _,slot in ipairs(slots) do
            local ids=pack[slot]
            if type(ids)~="table" or #ids==0 then complete=false end
            for _,id in ipairs(ids or {}) do
                if type(id)~="number" or id<1 or id%1~=0 then complete=false end
                if owners[id] and owners[id]~=name then shared+=1 end
                owners[id]=name
            end
        end
    end
    check(complete,"every pack has three idles and all eight movement slots")
    check(shared==0,"no animation ID is shared between packs")
    local mage=animationPacks.Mage
    check(mage.idle[1]==707742142 and mage.idle[2]==707855907 and mage.idle[3]==885508740 and mage.walk[1]==707897309
        and mage.run[1]==707861613 and mage.jump[1]==707853694 and mage.fall[1]==707829716 and mage.climb[1]==707826056
        and mage.swim[1]==707876443 and mage.swimidle[1]==707894699,"the Mage pack keeps its original IDs")
    check(animationPacks.Levitation.idle[1]==616006778 and animationPacks.Ninja.run[1]==656118852,"popular packs carry their catalog IDs")
    check(State.Config.AnimationPack=="Ninja","a valid saved pack is kept")
    State.Config.AnimationPack="Missing"
    -- INSERT_PACKS
    check(State.Config.AnimationPack=="Mage","an unknown saved pack falls back to Mage")
end
do
    local function vec(x,y,z)
        return setmetatable({X=x,Y=y,Z=z,Magnitude=math.sqrt(x*x+y*y+z*z)},{
            __sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
        })
    end
    local now=0
    local ownRoot={Position=vec(0,0,0)}
    local char={hum={Health=100}}
    function char:FindFirstChildOfClass(c) return c=="Humanoid" and self.hum or nil end
    function char:FindFirstChild(n) if n=="HumanoidRootPart" then return ownRoot end return nil end
    local me={Name="Me",UserId=1,Character=char}
    local killerRoot={Position=vec(0,0,3)}
    local killerChar={hum={Health=100}}
    function killerChar:FindFirstChildOfClass(c) return c=="Humanoid" and self.hum or nil end
    function killerChar:FindFirstChild(n) if n=="HumanoidRootPart" then return killerRoot end return nil end
    local killer={Name="Killer",UserId=2,Character=killerChar}
    local innoRoot={Position=vec(0,0,3)}
    local innocentChar={hum={Health=100}}
    function innocentChar:FindFirstChildOfClass(c) return c=="Humanoid" and self.hum or nil end
    function innocentChar:FindFirstChild(n) if n=="HumanoidRootPart" then return innoRoot end return nil end
    local innocent={Name="Inno",UserId=3,Character=innocentChar}
    local roles={[me]="Sheriff",[killer]="Murderer",[innocent]="Innocent"}
    local excluded={[killer]=false}
    local alivePlayers={[me]=true,[killer]=true,[innocent]=true}
    local gunTool={Name="Gun",Enabled=true,Parent=char}
    local knifeTool={Name="Knife",Enabled=true,Parent=char}
    local currentWeapon=gunTool
    local sentGunShots={}
    local sentKnifeStabs={}
    local aimTarget=nil
    local pathClear=true

    local State={Running=true,Config={Triggerbot=false,KnifeTriggerbot=false,Aim=false,MagicBullet=false},
        WeaponHandlers={[gunTool]={Kind="Gun",Item=gunTool},[knifeTool]={Kind="Knife",Item=knifeTool,Charging=false,LastStab=-math.huge}},
        IsPlayerExcluded=function(p) return excluded[p]==true end,
        SetMagicBullet=function(v) State.Config.MagicBullet=v end,
        GetKillAuraRange=function() return 6.5 end}
    local connections={}
    local C={State=State,Player=me,Players={GetPlayers=function() return {me,killer,innocent} end},
        Clock=function() return now end,Connect=function(s,cb) connections[s]=cb end,
        RunService={Heartbeat="Heartbeat"},
        RoleFor=function(p) return roles[p] end,
        IsAlive=function(p) return alivePlayers[p]==true end,
        EquippedWeapon=function() return currentWeapon,currentWeapon and currentWeapon.Name end,
        SendGun=function(record,target) table.insert(sentGunShots,target); return true end,
        StabKnife=function(record,target,part) table.insert(sentKnifeStabs,target); return true end,
        GetTarget=function() return aimTarget,aimTarget and aimTarget.Character,aimTarget and aimTarget.Character:FindFirstChild("HumanoidRootPart") end,
        ClearPath=function() return pathClear end,
        GetKillAuraRange=function() return 6.5 end,
        InputBlocked=function() return false end}
    -- INSERT_TRIGGERBOT
    installTriggerbot(C)
    local bot=State.Triggerbot
    check(connections.Heartbeat and not State.Config.Triggerbot and not State.Config.KnifeTriggerbot and bot.Status=="Off","triggerbot hooks heartbeat and starts off")
    bot.Step()
    check(#sentGunShots==0 and not bot.Active,"triggerbot stays off until enabled")
    State.SetTriggerbot(true)
    check(State.Config.Triggerbot and State.Config.KnifeTriggerbot and State.Config.Aim and State.Config.MagicBullet,"enabling triggerbot turns on aim and gun aim")
    bot.Step()
    check(bot.Status=="Ready  ·  aim at murderer" and #sentGunShots==0,"triggerbot waits for aim target")
    aimTarget=innocent
    bot.Step()
    check(bot.Status=="Aiming at innocent" and #sentGunShots==0,"triggerbot ignores innocent players")
    aimTarget=killer; excluded[killer]=true
    bot.Step()
    check(bot.Status=="Target protected" and #sentGunShots==0,"triggerbot skips protected murderer")
    excluded[killer]=false
    bot.Step()
    check(#sentGunShots==1 and sentGunShots[1]==killer and bot.Shots==1 and bot.Status=="Fired  ·  @Killer","triggerbot fires at murderer")
    bot.Step()
    check(#sentGunShots==1,"triggerbot enforces cooldown between shots")
    currentWeapon=nil
    now+=1
    bot.Step()
    check(bot.Status=="Waiting for weapon","triggerbot reports missing gun")
    currentWeapon=knifeTool
    roles[me]="Murderer"
    roles[killer]="Sheriff"
    aimTarget=killer
    now+=1
    bot.Step()
    check(#sentKnifeStabs==1 and sentKnifeStabs[1]==killer and bot.Status=="Swung  ·  @Killer","triggerbot swings knife at player in reach while murderer")
    bot.Step()
    check(#sentKnifeStabs==1,"triggerbot enforces knife swing cooldown")
    now+=1
    killerRoot.Position=vec(0,0,20)
    bot.Step()
    check(bot.Status=="Target out of reach" and #sentKnifeStabs==1,"triggerbot does not swing at players out of reach")
    killerRoot.Position=vec(0,0,3)
    pathClear=false
    bot.Step()
    check(bot.Status=="Target obstructed" and #sentKnifeStabs==1,"triggerbot does not swing at obstructed targets")
    pathClear=true
    State.StopTriggerbot()
    check(not State.Config.Triggerbot and not State.Config.KnifeTriggerbot and bot.Status=="Off","stopping triggerbot clears knife triggerbot")
    State.SetKnifeTriggerbot(true)
    check(State.Config.KnifeTriggerbot and bot.Enabled,"setting knife triggerbot enables it")
    State.StopTriggerbot()
end
do
    -- Keybinds: fake input objects and setters; nothing here touches a real game.
    local Enum={UserInputType={Keyboard="Keyboard",MouseButton1="MouseButton1"}}
    local focused,mode=nil,"PC"
    local UIS={InputBegan="InputBegan",GetFocusedTextBox=function() return focused end}
    local toasts,tones,refreshed,synced={},{},0,0
    local cfg={Aim=true,MagicBullet=true,Triggerbot=false,KillAura=false,ESP=true,XRay=false,Fly=false,Noclip=false,SpeedBoost=false,
        JumpBoost=false,InfiniteJump=false,Invisibility=false,MageAnimations=true,
        Keybinds={Fly="Q",Noclip="W",InfiniteJump="Q",ESP="H"}}
    local State={Running=true,Config=cfg,MobileUI={MenuOpen=false,Refresh=function() refreshed+=1 end,
        Toast=function(text,tone) table.insert(toasts,text); table.insert(tones,tone) end}}
    function State.SetMagicBullet(enabled) cfg.MagicBullet=enabled end
    function State.SetTriggerbot(enabled) cfg.Triggerbot=enabled; return true end
    function State.SetKillAura(enabled) if enabled then return false,"Waiting until you are murderer" end cfg.KillAura=false; return true end
    function State.SetInvisibility(enabled) cfg.Invisibility=enabled end
    function State.SetMageAnimations(enabled) cfg.MageAnimations=enabled end
    function State.RevealRolesInChat() return false,"Available during a round" end
    function State.TeleportToArea() return false,"Wait for your living character" end
    function State.FixCamera() error("camera module missing") end
    local connections={}
    local C={State=State,UIS=UIS,Connect=function(signal,callback) connections[signal]=callback end,
        SyncWeapons=function() synced+=1 end,RefreshAim=function() end,UpdateVisuals=function() end,
        InputMode=function() return mode end}
    -- INSERT_KEYBINDS
    installKeybinds(C)
    local keys=State.Keybinds
    local function press(name,processed) return keys.Press({UserInputType="Keyboard",KeyCode={Name=name}},processed) end
    check(connections.InputBegan==keys.Press,"keybinds listen to keyboard input")
    check(cfg.Keybinds.Fly=="Q" and cfg.Keybinds.ESP=="H","saved keybinds are kept")
    check(cfg.Keybinds.Noclip=="None","a saved reserved key is dropped")
    check(cfg.Keybinds.InfiniteJump=="None" and cfg.Keybinds.XRay=="X","a saved duplicate key stays with the earlier action")
    check(cfg.Keybinds.Aim=="F6" and cfg.Keybinds.KillAura=="K" and cfg.Keybinds.RevealRoles=="None","missing keybinds use their defaults")
    check(press("Q")=="Fly on" and cfg.Fly and toasts[#toasts]=="Fly on" and tones[#tones]=="on" and refreshed==1,"a keybind toggles its feature and confirms it")
    check(press("Q")=="Fly off" and not cfg.Fly and tones[#tones]=="off","pressing again switches it off")
    check(press("F6")=="Aim assist off" and not cfg.Aim and synced==1,"aim assist keeps its F6 default")
    check(cfg.Keybinds.Triggerbot=="T","triggerbot defaults to T")
    check(press("T")=="Triggerbot on" and cfg.Triggerbot and toasts[#toasts]=="Triggerbot on","keybind toggles triggerbot")
    check(press("T")=="Triggerbot off" and not cfg.Triggerbot,"pressing again switches triggerbot off")
    check(press("Q",true)==nil and not cfg.Fly,"keys the game already handled are ignored")
    focused={}
    check(press("Q")==nil,"keys are ignored while typing")
    focused=nil; State.MobileUI.MenuOpen=true
    check(press("Q")==nil,"keys are ignored while the menu is open")
    State.MobileUI.MenuOpen=false; mode="Mobile"
    check(press("Q")==nil,"keybinds are PC only")
    mode="PC"
    check(keys.Press({UserInputType="MouseButton1",KeyCode={Name="Unknown"}})==nil,"mouse clicks never trigger keybinds")
    local ok,message=State.SetKeybind("Noclip","W")
    check(not ok and message=="W is reserved","movement keys cannot be bound")
    ok,message=State.SetKeybind("Noclip","MouseLeftButton")
    check(not ok and cfg.Keybinds.Noclip=="None","mouse buttons cannot be bound")
    ok,message=State.SetKeybind("Noclip","Q")
    check(ok and message=="Q moved from Fly to Noclip" and cfg.Keybinds.Fly=="None" and cfg.Keybinds.Noclip=="Q",
        "binding a used key moves it to the new action")
    ok,message=State.SetKeybind("Noclip","Backspace")
    check(ok and message=="Noclip unbound" and cfg.Keybinds.Noclip=="None","Backspace clears a keybind")
    check(press("K")=="Waiting until you are murderer" and not cfg.KillAura,"a refused action shows why")
    State.SetKeybind("RevealRoles","R")
    check(press("R")=="Available during a round" and tones[#tones]=="info","reveal roles reports its result")
    check(press("F10"):find("Repair camera failed",1,true)==1 and tones[#tones]=="warn","an action error is reported instead of breaking input")
    State.ResetKeybinds()
    check(cfg.Keybinds.Fly=="F" and cfg.Keybinds.Noclip=="N" and cfg.Keybinds.RevealRoles=="None","reset restores default keys")
end
print(string.format("%d release assertions passed",passed))
