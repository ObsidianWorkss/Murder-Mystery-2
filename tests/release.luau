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
    State.KillAll={Active=true,Targets={"PrivatePlayer"}}
    report=State.GetSupportSnapshot()
    check(report.Settings.KillAll==true and report.KillAll==nil,"support reports Kill all activity without leaking its target queue")
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
    State.ReleaseFly()
    check(created[1].Destroyed and created[2].Destroyed and not hum.PlatformStand,"teleports and invisibility can release fly's hold")
    move.Step()
    check(#created==4 and created[3].Parent==root and hum.PlatformStand,"fly resumes on the next frame")
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
    -- Keybinds: fake input objects and setters; nothing here touches a real game.
    local Enum={UserInputType={Keyboard="Keyboard",MouseButton1="MouseButton1"}}
    local focused,mode=nil,"PC"
    local UIS={InputBegan="InputBegan",GetFocusedTextBox=function() return focused end}
    local toasts,tones,refreshed,synced={},{},0,0
    local cfg={Aim=true,MagicBullet=true,KillAura=false,ESP=true,XRay=false,Fly=false,Noclip=false,SpeedBoost=false,
        JumpBoost=false,InfiniteJump=false,Invisibility=false,MageAnimations=true,
        Keybinds={Fly="Q",Noclip="W",InfiniteJump="Q",ESP="H"}}
    local State={Running=true,Config=cfg,MobileUI={MenuOpen=false,Refresh=function() refreshed+=1 end,
        Toast=function(text,tone) table.insert(toasts,text); table.insert(tones,tone) end}}
    function State.SetMagicBullet(enabled) cfg.MagicBullet=enabled end
    function State.SetTriggerbot(enabled) cfg.Triggerbot=enabled end
    function State.SetKnifeTriggerbot(enabled) cfg.KnifeTriggerbot=enabled end
    function State.StartKillAll() return false,"Kill all requires a living murderer" end
    function State.StopKillAll() return true,"Kill all stopped" end
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
    check(press("K")=="Waiting until you are murderer" and not cfg.KillAura and tones[#tones]=="warn","a refused action shows why as a warning")
    local setInvisibility=State.SetInvisibility
    function State.SetInvisibility() cfg.Invisibility=false; return false,"A living, unseated character with its original root is required" end
    check(press("F8")=="A living, unseated character with its original root is required" and tones[#tones]=="warn",
        "refused invisibility shows its reason instead of off")
    State.SetInvisibility=setInvisibility
    State.SetKeybind("RevealRoles","R")
    check(press("R")=="Available during a round" and tones[#tones]=="warn","a refused reveal shows why as a warning")
    check(press("F10"):find("Repair camera failed",1,true)==1 and tones[#tones]=="warn","an action error is reported instead of breaking input")
    check(cfg.Keybinds.Menu=="RightShift" and cfg.Keybinds.Stop=="End","menu and stop keys default to Right Shift and End")
    ok,message=State.SetKeybind("Menu","Backspace")
    check(not ok and message=="Open / close menu needs a key" and cfg.Keybinds.Menu=="RightShift","the menu key can never be cleared")
    ok,message=State.SetKeybind("Fly","End")
    check(not ok and message=="End is used by Emergency stop","the stop key cannot be taken by another action")
    ok,message=State.SetKeybind("Menu","H")
    check(ok and message=="H moved from Player ESP to Open / close menu" and cfg.Keybinds.ESP=="None","the menu key can move to a new key")
    check(press("H")==nil,"menu and stop keys are left to the menu's own binding")
    local options={}
    State.MobileUI.SetOption=function(key,enabled)
        table.insert(options,key.."="..tostring(enabled))
        if key=="AutoPickup" then return false,"Your executor lacks firetouchinterest" end
        cfg[key]=enabled
        return enabled
    end
    local everything={"StabSweep","GunESP","Toasts","AutoKnifeDodge","InvisibleKnife","TacticalGuide",
        "FlingMurderer","FlingAll","StopFling","RepairCharacter","Unload"}
    local listed=0
    for _,id in ipairs(everything) do if cfg.Keybinds[id]=="None" then listed+=1 end end
    check(listed==#everything,"every menu toggle and action has an unbound keybind")
    State.SetKeybind("StabSweep","U")
    check(press("U")=="Stab sweep on" and options[#options]=="StabSweep=true" and tones[#tones]=="on",
        "a toggle key goes through the same path as its menu toggle")
    State.SetKeybind("AutoPickup","Y")
    check(press("Y")=="Your executor lacks firetouchinterest" and tones[#tones]=="warn","a toggle key shows its menu toggle's refusal")
    check(cfg.Keybinds.Triggerbot=="None" and cfg.Keybinds.KnifeTriggerbot=="None","both trigger keys start unbound")
    local universal
    for _,action in ipairs(keys.Actions) do if action.Id=="UniversalTriggerbot" then universal=action end end
    check(cfg.Keybinds.UniversalTriggerbot=="T" and universal and universal.Group=="Combat",
        "universal triggerbot defaults to T and appears in Combat keys")
    check(press("T")=="Universal triggerbot on" and cfg.Triggerbot and cfg.KnifeTriggerbot and not cfg.Aim,
        "universal T enables gun and knife modes without changing master aim")
    check(press("T")=="Universal triggerbot off" and not cfg.Triggerbot and not cfg.KnifeTriggerbot,
        "universal T disables both trigger modes")
    cfg.Triggerbot=true
    check(press("T")=="Universal triggerbot off" and not cfg.Triggerbot and not cfg.KnifeTriggerbot,
        "universal T stops both modes when only one was enabled")
    State.SetKeybind("Triggerbot","T")
    check(press("T")=="Gun triggerbot on" and options[#options]=="Triggerbot=true" and not cfg.Aim,
        "gun trigger key uses its menu setter without enabling master aim")
    State.SetKeybind("KnifeTriggerbot","B")
    check(press("B")=="Knife triggerbot on" and options[#options]=="KnifeTriggerbot=true",
        "knife trigger key uses its independent menu setter")
    check(cfg.Keybinds.KillAll=="None" and cfg.Keybinds.StopKillAll=="None","Kill all and its stop action are rebindable and start unbound")
    State.SetKeybind("KillAll","P")
    check(press("P")=="Kill all requires a living murderer" and tones[#tones]=="warn","Kill all key reports a role refusal")
    State.SetKeybind("StopKillAll","L")
    check(press("L")=="Kill all stopped","Stop Kill all key runs the stop action")
    State.MobileUI.SetOption=nil
    State.ResetKeybinds()
    check(cfg.Keybinds.Fly=="F" and cfg.Keybinds.Noclip=="N" and cfg.Keybinds.RevealRoles=="None" and cfg.Keybinds.Menu=="RightShift"
        and cfg.Keybinds.UniversalTriggerbot=="T",
        "reset restores default keys")
end
do
    -- X-ray robustness: Terrain and a part that refuses writes must never break switching off or unloading.
    local function node(class,name,parent,props)
        local n={ClassName=class,Name=name,Parent=parent,Children={}}
        for key,value in pairs(props or {}) do n[key]=value end
        function n:IsA(kind) return self.ClassName==kind or (kind=="BasePart" and (self.ClassName=="Part" or self.ClassName=="Terrain")) end
        function n:FindFirstChildOfClass() return nil end
        if parent then table.insert(parent.Children,n) end
        return n
    end
    local world=node("Workspace","Workspace",nil)
    function world:GetDescendants()
        local list={}
        local function walk(n) for _,child in ipairs(n.Children) do table.insert(list,child); walk(child) end end
        walk(self)
        return list
    end
    world.DescendantAdded="DescendantAdded"
    local writes=0
    local function locked(class,name)
        local part=setmetatable({ClassName=class,Name=name,Parent=world,Children={},Transparency=0},{
            __index=function(_,key) if key=="LocalTransparencyModifier" then return 0 end return nil end,
            __newindex=function(t,key,value)
                if key=="LocalTransparencyModifier" then writes+=1; error("Unable to assign property") end
                rawset(t,key,value)
            end})
        function part:IsA(kind) return kind=="BasePart" or kind==class end
        table.insert(world.Children,part)
        return part
    end
    local terrain=locked("Terrain","Terrain")
    local stubborn=locked("Part","LockedWall")
    local wall=node("Part","Wall",world,{Transparency=0,LocalTransparencyModifier=0})
    local State={Running=true,Config={XRay=true,XRayAmount=60}}
    local C={State=State,Workspace=world,Clock=function() return 0 end,RunService={Heartbeat="Heartbeat"},Connect=function() end}
    -- INSERT_XRAY
    installXRay(C)
    local stepped=pcall(State.XRay.Step)
    check(stepped and wall.LocalTransparencyModifier==.6,"x-ray keeps working when a part refuses the change")
    check(writes==1 and State.XRay.Count()==1,"Terrain is skipped and a refusing part is not tracked")
    State.Config.XRay=false
    local stopped=pcall(State.XRay.Step)
    check(stopped and wall.LocalTransparencyModifier==0 and not State.XRay.Active,"x-ray switches off cleanly after a refused part")
    State.Config.XRay=true; State.XRay.Step()
    check(pcall(State.StopXRay) and wall.LocalTransparencyModifier==0,"unload restores the map after a refused part")
end
do
    -- Two copies of X-ray on one map (what a duplicate script instance does): turning X-ray off must clear it.
    local function node(class,name,parent)
        local n={ClassName=class,Name=name,Parent=parent,Children={},Transparency=0,LocalTransparencyModifier=0,Attributes={}}
        function n:IsA(kind) return self.ClassName==kind or (kind=="BasePart" and self.ClassName=="Part") end
        function n:FindFirstChildOfClass() return nil end
        function n:GetAttribute(key) return self.Attributes[key] end
        function n:SetAttribute(key,value) self.Attributes[key]=value end
        if parent then table.insert(parent.Children,n) end
        return n
    end
    local world=node("Workspace","Workspace",nil)
    function world:GetDescendants()
        local list={}
        local function walk(n) for _,child in ipairs(n.Children) do table.insert(list,child); walk(child) end end
        walk(self)
        return list
    end
    world.DescendantAdded="DescendantAdded"
    local map=node("Model","Lobby",world)
    local wall,rock=node("Part","Wall",map),node("Part","Rock",map)
    local function copy()
        local State={Running=true,Config={XRay=true,XRayAmount=60}}
        local C={State=State,Workspace=world,Clock=function() return 0 end,RunService={Heartbeat="Heartbeat"},Connect=function() end}
        -- INSERT_XRAY
        installXRay(C)
        return State
    end
    local first=copy(); first.XRay.Step()
    local second=copy(); second.XRay.Step()
    check(wall.LocalTransparencyModifier==.6 and wall.Attributes.MM2XRayBefore==0,"a second copy keeps the true original value")
    second.Config.XRay=false; second.XRay.Step()
    check(wall.LocalTransparencyModifier==0 and rock.LocalTransparencyModifier==0 and wall.Attributes.MM2XRayBefore==nil,
        "switching X-ray off clears the map even while another copy has it on")
    first.Config.XRay=false; first.XRay.Step()
    check(wall.LocalTransparencyModifier==0 and rock.LocalTransparencyModifier==0,"the other copy switching off keeps the map clear")
    local crashed=copy(); crashed.XRay.Step()
    check(rock.LocalTransparencyModifier==.6,"a copy that stops without cleanup leaves the map see-through")
    copy()
    check(rock.LocalTransparencyModifier==0 and wall.LocalTransparencyModifier==0 and rock.Attributes.MM2XRayBefore==nil,
        "the next copy to start restores what a crashed copy left")
end
do
    -- Saved settings: a file on the executor, loaded at start, written only when something changed.
    local encoded={}
    local function serialize(value)
        if type(value)~="table" then return type(value)=="string" and string.format("%q",value) or tostring(value) end
        local keys={}
        for k in pairs(value) do table.insert(keys,tostring(k)) end
        table.sort(keys)
        local parts={}
        for _,k in ipairs(keys) do table.insert(parts,k.."="..serialize(value[k] == nil and value[tonumber(k)] or value[k])) end
        return "{"..table.concat(parts,",").."}"
    end
    local function clone(value)
        if type(value)~="table" then return value end
        local out={}
        for k,v in pairs(value) do out[k]=clone(v) end
        return out
    end
    local Http={}
    function Http:JSONEncode(value) local text=serialize(value); encoded[text]=clone(value); return text end
    function Http:JSONDecode(text) if encoded[text]==nil then error("Can't parse JSON") end return clone(encoded[text]) end
    local files,writes,failWrites={},0,false
    local function fs(overrides)
        local C={Http=Http,ReadFile=function(p) return files[p] end,IsFile=function(p) return files[p]~=nil end,
            WriteFile=function(p,t) if failWrites then error("disk full") end files[p]=t; writes+=1 end,
            MakeFolder=function() end,IsFolder=function() return true end}
        for k,v in pairs(overrides or {}) do C[k]=v end
        return C
    end
    local function defaults()
        return {Aim=true,Fly=false,WalkSpeed=24,Ping=0.04,MenuTheme="Midnight",Keybinds=false,ExcludedPlayers={},AnimationPack="Mage",
            KillAllMode="Burst",TargetPriority="Nearest",PerformancePreset="Balanced",MapVoteRepeat=false,AutoKnifeDodge=true}
    end
    local function start(overrides)
        local State={Config=defaults()}
        local C=fs(overrides); C.State=State
        -- INSERT_SETTINGS
        installSettings(C)
        return State
    end
    local path="MM2Universal/settings.json"
    local first=start()
    check(first.Settings.Loaded==0 and first.Config.WalkSpeed==24,"first start without a file uses defaults")
    check(first.SaveSettings() and writes==1 and files[path]~=nil,"settings are written to the executor folder")
    first.SaveSettings()
    check(writes==1,"nothing is written when nothing changed")
    first.Config.WalkSpeed,first.Config.Fly,first.Config.MenuTheme,first.Config.Ping=40,true,"Light",0.2
    first.Config.Keybinds={Menu="F4",Fly="G"}
    first.Config.KillAllMode,first.Config.TargetPriority,first.Config.PerformancePreset="Aimed throws","Sheriff first","Low effects"
    first.Config.MapVoteRepeat=true
    first.Config.AutoKnifeDodge=false
    first.Config.ExcludedPlayers["123"]={UserId=123,Name="friend",DisplayName="friend"}
    first.SaveSettings()
    check(writes==2,"a change is written once")
    local second=start()
    check(second.Config.WalkSpeed==40 and second.Config.Fly==true and second.Config.MenuTheme=="Light",
        "the next start loads saved sliders, switches and the menu theme")
    check(type(second.Config.Keybinds)=="table" and second.Config.Keybinds.Menu=="F4" and second.Config.Keybinds.Fly=="G",
        "saved keybinds load")
    check(second.Config.ExcludedPlayers["123"] and second.Config.ExcludedPlayers["123"].Name=="friend","protected players load")
    check(second.Config.Ping==0.04,"ping is measured each session, never loaded")
    check(second.Config.MapVoteRepeat==false,"map vote respawns never resume from saved settings")
    check(second.Config.AutoKnifeDodge,"auto dodge starts enabled instead of persisting a session off setting")
    files[path]=Http:JSONEncode({Version=1,Config={MapVoteRepeat=true,AutoRevealGun=true,AutoKnifeDodge=false}})
    local session=start()
    check(not session.Config.MapVoteRepeat and session.Config.AutoRevealGun==nil,"older files cannot arm map vote respawns or restore auto-reveal")
    check(session.Config.AutoKnifeDodge,"old saved false cannot disable the new default-on dodge session")
    check(second.Config.KillAllMode=="Aimed throws" and second.Config.TargetPriority=="Sheriff first" and second.Config.PerformancePreset=="Low effects",
        "mode, priority and performance preset survive saved-settings reload")
    check(second.DefaultConfig.WalkSpeed==24 and second.DefaultConfig.ExcludedPlayers["123"]==nil,"defaults are kept apart from saved values")
    files[path]=Http:JSONEncode({Version=1,Config={WalkSpeed="fast",Aim=false,Removed=true}})
    local third=start()
    check(third.Config.WalkSpeed==24 and third.Config.Aim==false and third.Config.Removed==nil,
        "wrong kinds of values and unknown settings are ignored")
    files[path]="{broken"
    local fourth=start()
    check(fourth.Config.WalkSpeed==24 and fourth.Settings.Status=="Saved settings were unreadable; defaults used",
        "an unreadable file falls back to defaults and says so")
    local noFiles=start({WriteFile=false,ReadFile=false})
    local saved,status=noFiles.SaveSettings()
    check(saved==false and noFiles.Settings.CanSave==false and status=="This executor cannot save files",
        "an executor without file access runs without saving")
    failWrites=true
    fourth.Config.Fly=true
    local ok,reason=fourth.SaveSettings()
    check(ok==false and reason:find("disk full",1,true)~=nil,"a failed write is reported")
    failWrites=false
    check(fourth.SaveSettings() and fourth.Settings.Status=="Saved automatically","the next write succeeds and clears the error")
    -- Reset: switches go through the menu path, numbers and keybinds go back, protected players stay.
    local switched,applied,synced={},nil,false
    second.MobileUI={SetOption=function(key,value) switched[key]=value; second.Config[key]=value end,
        ApplyTheme=function(name) applied=name; second.Config.MenuTheme=name end,SyncSliders=function() synced=true end}
    function second.ResetKeybinds() second.Config.Keybinds={Menu="RightShift"} end
    local before=writes
    check(second.ResetSettings(),"reset settings runs")
    check(switched.Fly==false and second.Config.Fly==false and second.Config.WalkSpeed==24,"reset turns switches off through the menu and moves sliders back")
    check(applied=="Midnight" and synced and second.Config.Keybinds.Menu=="RightShift","reset restores the theme, slider positions and keybinds")
    check(second.Config.ExcludedPlayers["123"]~=nil,"reset keeps protected players")
    check(second.Config.KillAllMode=="Burst" and second.Config.TargetPriority=="Nearest" and second.Config.PerformancePreset=="Balanced",
        "reset restores mode, priority and performance defaults")
    check(writes==before+1,"reset is saved right away")
end
do
    -- Anti-fling on fake characters: spinners lose collision with you, and a launch you did not make is undone.
    local now=0
    local vectorMeta={}
    local function vector(x,y,z) return setmetatable({X=x,Y=y,Z=z,Magnitude=math.sqrt(x*x+y*y+z*z)},vectorMeta) end
    local Vector3={new=vector,zero=vector(0,0,0)}
    local workspace={Gravity=196.2}
    local function part(collide) return {CanCollide=collide,Parent=true,IsA=function(_,class) return class=="BasePart" end} end
    local function body(name)
        local root=part(true); root.AssemblyLinearVelocity,root.AssemblyAngularVelocity=vector(0,0,0),vector(0,0,0)
        local parts={root,part(true),part(true),part(false)}
        local hum={Health=100,WalkSpeed=16,JumpPower=50,JumpHeight=7.2,UseJumpPower=true}
        local char={}
        function char:FindFirstChild(n) return n=="HumanoidRootPart" and root or nil end
        function char:FindFirstChildOfClass(class) return class=="Humanoid" and hum or nil end
        function char:GetDescendants() return parts end
        return {Name=name,Character=char},root,parts,hum
    end
    local me,myRoot,_,myHum=body("me")
    local friend,friendRoot,friendParts=body("friend")
    local spinner,spinnerRoot,spinnerParts=body("spinner")
    local toasts={}
    local State={Running=true,Config={AntiFling=true,Fly=false,FlySpeed=50},
        MobileUI={Toast=function(text) table.insert(toasts,text) end}}
    local connections={}
    local C={State=State,Player=me,Players={GetPlayers=function() return {me,friend,spinner} end},Clock=function() return now end,
        RunService={Stepped="Stepped",Heartbeat="Heartbeat"},Connect=function(signal,callback) connections[signal]=callback end}
    -- INSERT_ANTIFLING
    installAntiFling(C)
    local guard=State.AntiFling
    local function frame(dt) now+=dt or 1/60; guard.StepShield(); guard.StepSelf() end
    check(connections.Stepped==guard.StepShield and connections.Heartbeat==guard.StepSelf,"anti-fling runs before and after physics")
    friendRoot.AssemblyLinearVelocity,friendRoot.AssemblyAngularVelocity=vector(16,0,0),vector(0,25,0)
    frame()
    check(friendParts[1].CanCollide and friendParts[2].CanCollide and guard.Shielded==0,"players moving and turning normally stay solid")
    spinnerRoot.AssemblyAngularVelocity=vector(0,300,0)
    frame()
    check(not spinnerParts[1].CanCollide and not spinnerParts[2].CanCollide and guard.Shielded==1,"a spinning player passes through you")
    check(friendParts[1].CanCollide,"other players stay solid while one is shielded")
    spinnerRoot.AssemblyAngularVelocity=vector(0,0,0)
    frame(2)
    check(not spinnerParts[1].CanCollide,"the shield holds for a few seconds after the spin stops")
    frame(1.5)
    check(spinnerParts[1].CanCollide and spinnerParts[2].CanCollide and not spinnerParts[4].CanCollide and guard.Shielded==0,
        "collisions come back afterwards and parts that never collided stay that way")
    spinnerRoot.AssemblyLinearVelocity=vector(0,900,0)
    frame()
    check(not spinnerParts[1].CanCollide,"a player launched at fling speed is shielded too")
    spinnerRoot.AssemblyLinearVelocity=vector(0,0,0)
    -- Your own movement: walking, boosted speed, jumping, flying and long falls are never undone.
    local start={"start"}
    myRoot.CFrame=start
    local function move(x,y,z) myRoot.AssemblyLinearVelocity=vector(x,y,z); frame() end
    myRoot.AssemblyAngularVelocity=vector(0,25,0)
    move(16,0,0); myRoot.AssemblyAngularVelocity=vector(0,0,0); myHum.WalkSpeed=60; move(60,0,0); myHum.JumpPower=150; move(0,150,0)
    State.Config.Fly,State.Config.FlySpeed=true,120; move(120,0,0); move(0,120,0)
    State.Config.Fly=false
    for y=0,-700,-4 do move(0,y,0) end
    check(guard.Stopped==0 and myRoot.AssemblyLinearVelocity.Y==-700,"walking, turning, speed boost, jumping, flying and falling are left alone")
    move(0,0,0)
    local safe={"safe"}
    myRoot.CFrame=safe; frame()
    myRoot.CFrame={"flung"}; move(900,40,0)
    check(guard.Stopped==1 and myRoot.CFrame==safe and myRoot.AssemblyLinearVelocity.Magnitude==0,"a sideways launch is undone and you are put back")
    check(#toasts==1 and toasts[1]=="Fling blocked","a toast says a fling was blocked")
    myRoot.AssemblyAngularVelocity=vector(200,0,0); myRoot.CFrame={"tilted"}; frame()
    check(guard.Stopped==2 and myRoot.CFrame==safe and myRoot.AssemblyAngularVelocity.Magnitude==0,"being spun is undone")
    check(#toasts==1,"toasts are limited to one every few seconds")
    move(0,-5,0); myRoot.CFrame={"slammed"}; move(0,-1100,0)
    check(guard.Stopped==3 and myRoot.CFrame==safe,"a slam into the floor is undone")
    check(guard.Status:find("3 flings stopped",1,true)~=nil,"the status counts stopped flings")
    -- Your own fling and invisibility move you on purpose: anti-fling stands aside, then waits a moment.
    State.Fling={Active=true}
    spinnerRoot.AssemblyAngularVelocity=vector(0,300,0)
    myRoot.CFrame={"flinging"}; move(0,0,1100)
    check(guard.Stopped==3 and spinnerParts[1].CanCollide and guard.Status=="Paused while you fling",
        "your own fling is never undone and can still hit players")
    State.Fling.Active=false; spinnerRoot.AssemblyAngularVelocity=vector(0,0,0)
    move(0,0,0); move(0,0,1100)
    check(guard.Stopped==3,"anti-fling waits briefly after your fling ends")
    now+=1; move(0,0,0); myRoot.CFrame={"late"}; move(0,0,1100)
    check(guard.Stopped==4,"anti-fling resumes after the wait")
    State.Invis={Active=true}; move(0,0,0); move(0,0,1100)
    check(guard.Stopped==4 and guard.Status=="Paused while invisible","invisibility moves you without interference")
    State.Invis=nil
    -- Off and unload restore every collision it changed.
    now+=1; spinnerRoot.AssemblyAngularVelocity=vector(0,300,0); frame()
    check(not spinnerParts[1].CanCollide,"shield active before switching off")
    State.Config.AntiFling=false; frame()
    check(spinnerParts[1].CanCollide and spinnerParts[2].CanCollide and guard.Status=="Off","switching off restores collisions")
    move(0,0,0); move(900,0,0)
    check(guard.Stopped==4,"switched off, nothing is undone")
    State.Config.AntiFling=true; frame()
    check(not spinnerParts[1].CanCollide,"switching back on shields again")
    State.StopAntiFling()
    check(spinnerParts[1].CanCollide and spinnerParts[2].CanCollide,"unload restores collisions")
    spinnerRoot.AssemblyAngularVelocity=nil; frame()
    check(State.Config.AntiFling==false and guard.Status:find("Anti-fling stopped",1,true)==1,"an error switches anti-fling off and says why")
end
do
    local defaults={CleanVisuals=true,CompactHUD=true,StableBodyESP=false,AimMarker=true,ThreatWarning=true,TacticalGuide=true,LearnedSheriffGuide=true}
    local State={Config={PerformancePreset="Balanced",Aim=true,Triggerbot=true,TacticalGuide=false},DefaultConfig=defaults,PreviewCache={}}
    local redraws,guide=0,nil
    State.SetTacticalGuide=function(value) guide=value end
    local C={State=State,UpdateVisuals=function() redraws+=1 end}
    -- INSERT_PERFORMANCE
    installPerformancePreset(C)
    check(State.Config.TacticalGuide==false and redraws==0,"balanced startup preserves custom visual settings")
    check(State.GetBackgroundInterval(.2)==.2,"balanced keeps the normal background cadence")
    check(State.SetPerformancePreset("Low effects") and not State.Config.AimMarker and not State.Config.ThreatWarning
        and not State.Config.TacticalGuide and guide==false,"low effects suppresses extra visuals and guidance")
    check(State.Config.Aim and State.Config.Triggerbot,"performance preset preserves combat switches")
    check(State.GetBackgroundInterval(.2)==.4 and State.GetBackgroundInterval(.3)==.6,"low effects slows background visual and dashboard updates")
    check(State.PreviewCache==nil and redraws==1,"preset changes invalidate visual previews and refresh rendered effects")
    State.SetPerformancePreset("Balanced")
    check(State.Config.AimMarker and State.Config.TacticalGuide and guide==true,"balanced restores visual defaults")
    check(not State.SetPerformancePreset("Unknown") and State.Config.PerformancePreset=="Balanced","invalid performance preset is refused")
    State.Config.PerformancePreset="Low effects"; State.Config.AimMarker=true
    installPerformancePreset(C)
    check(not State.Config.AimMarker and not State.Config.TacticalGuide,"saved low-effects preset is reapplied on startup")
end
do
    local starts,retries,closes=0,0,0
    local accepted=false
    local State={StartKillAll=function() starts+=1; return accepted,"Start result" end,
        RetryKillAll=function() retries+=1; return accepted,"Retry result" end}
    local window={Close=function() closes+=1 end}
    local mobile={Toast=function() end}
    local function suppressInput() end
    -- INSERT_RUN_KILLALL
    local ok,message=mobile.RunKillAll(true)
    check(not ok and message=="Retry result" and retries==1 and starts==0 and closes==0,
        "refused retry never falls back to attacking everyone or closes the menu")
    ok,message=mobile.RunKillAll(false)
    check(not ok and message=="Start result" and starts==1 and closes==0,"refused start preserves its message and menu")
    accepted=true; ok,message=mobile.RunKillAll(false)
    check(ok and message=="Start result" and starts==2 and closes==1,"successful start closes the menu exactly once")
    ok,message=mobile.RunKillAll(true)
    check(ok and message=="Retry result" and retries==2 and starts==2 and closes==2,"successful retry closes menu without starting a full queue")
end
print(string.format("%d release assertions passed",passed))
