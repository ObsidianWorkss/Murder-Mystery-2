-- MM2 standalone coin farm. No UI; starts immediately. End or MM2AutoFarm.Stop() stops it.
-- MM2FarmFormat:2
-- Ground paths by default; the separate loader selects experimental prone underground tweens.
-- Server acceptance, awards and crate results are not guaranteed.
local createFarm = function(C)
    local farm = {Running=true,Status="Waiting for a round",Attempts=0,ServerEvents=0,Removed=0,Resets=0}
    local target,phase,character,deadline,contactUntil,resetAt
    local skipped,full = {},{}
    local resetRequested,serverFull=false,false
    local held=false
    local function release()
        target,phase=nil,nil
        if held then C.Release(); held=false end
    end
    function farm.Stop(reason)
        farm.Running=false
        release()
        farm.Status=reason or "Stopped"
    end
    function farm.NewRound()
        release()
        skipped,full={},{}
        resetRequested,serverFull,resetAt=false,false,nil
        farm.Status="Waiting for round coins"
    end
    function farm.SetBag(kind,isFull)
        -- A delayed GUI refresh must not undo an authoritative full-bag event.
        if kind~=nil and not full[kind] then full[kind]=isFull==true end
    end
    function farm.Collected(kind,amount,capacity)
        farm.ServerEvents+=1
        if kind~=nil and type(amount)=="number" and type(capacity)=="number" and capacity>0 then
            full[kind]=amount>=capacity
            if amount>=capacity then serverFull=true end
        end
    end
    local function available(coin,now)
        if coin.Currency and full[coin.Currency] then return false end
        if not coin.Currency then
            local any,all=false,true
            for _,isFull in pairs(full) do any=true; if not isFull then all=false end end
            if any and all then return false end
        end
        return not skipped[coin.Part] or skipped[coin.Part]<=now
    end
    function farm.Step(dt)
        if not farm.Running then return end
        local now=C.Clock()
        local char=C.Character()
        if char~=character then release(); character=char end
        local blocked=C.Blocked()
        if not char or blocked then
            release(); farm.Status=blocked or "Waiting for a living character"; return
        end
        local any,all=false,true
        for _,isFull in pairs(full) do any=true; if not isFull then all=false end end
        if any and all then
            release()
            farm.Status="Bag full; waiting for the next round"
            if C.ResetWhenFull and serverFull and not resetRequested and C.CanReset() then
                resetAt=resetAt or now+1
                farm.Status="Bag full; reset pending"
                if now>=resetAt then
                    resetRequested=true
                    farm.Resets+=1
                    C.Reset()
                    farm.Status="Bag full; reset requested once"
                end
            end
            return
        end
        resetAt=nil
        if target and (not C.Valid(target) or not C.InMap(target)) then
            if not C.Valid(target) then farm.Removed+=1 end
            C.CancelPath()
            target,phase=nil,nil
        end
        if target and (not available(target,now) or now>deadline) then
            C.CancelPath()
            skipped[target.Part]=now+C.RetrySeconds
            target,phase=nil,nil
        end
        if not target then
            local best,distance
            local position=C.Position()
            for _,coin in ipairs(C.Coins()) do
                if available(coin,now) and C.Valid(coin) and C.InMap(coin) then
                    local d=(coin.Part.Position-position).Magnitude
                    if not distance or d<distance then best,distance=coin,d end
                end
            end
            if not best then
                release(); farm.Status="Waiting for coins or a bag with space"; return
            end
            if not held then C.Acquire(best); held=true end
            target=best
            deadline=now+math.max(15,distance/12*3+8)
            phase=C.MovementName=="Underground" and "Tween" or "Walk"
        end
        local coinPosition=target.Part.Position
        if coinPosition.Y<C.VoidY+20 then
            skipped[target.Part]=now+C.RetrySeconds; release(); farm.Status="Skipped a coin near the void"; return
        end
        if phase=="Walk" or phase=="Tween" then
            farm.Status=phase=="Tween" and "Tweening below the floor in a prone pose" or "Walking a normal path to a coin"
            local result=C.Move(target,dt)
            if result=="Blocked" then
                skipped[target.Part]=now+C.RetrySeconds
                C.CancelPath(); target,phase=nil,nil
            elseif result=="Arrived" then
                phase="Contact"; contactUntil=now+C.ContactSeconds
                farm.Attempts+=1
            end
        elseif phase=="Contact" then
            farm.Status="Waiting for coin collection"
            if now>=contactUntil then
                C.CancelPath()
                skipped[target.Part]=now+C.RetrySeconds
                target,phase=nil,nil
            end
        end
    end
    function farm.Snapshot()
        return {Running=farm.Running,Status=farm.Status,Attempts=farm.Attempts,
            ServerEvents=farm.ServerEvents,Removed=farm.Removed,Resets=farm.Resets,Phase=phase,
            Movement=C.MovementName or "Ground"}
    end
    return farm
end

local createUndergroundRoute=function(C)
    local route={}
    local target,points,index,tween,touching
    function route.Cancel()
        if tween then C.CancelTween(tween); tween=nil end
        C.EndTouch()
        target,points,index,touching=nil,nil,nil,nil
    end
    function route.Step(coin)
        local position=coin.Part.Position
        if target~=coin.Part then
            route.Cancel()
            if position.Y-C.Depth<C.VoidY+20 then return "Blocked" end
            target=coin.Part
            local root=C.Position()
            points={C.Vector(root.X,position.Y-C.Depth,root.Z),
                C.Vector(position.X,position.Y-C.Depth,position.Z),C.Pickup(coin)}
            index=1
        end
        if tween then
            local state=C.TweenState(tween)
            if state=="Completed" then tween=nil; index+=1
            elseif state=="Cancelled" then route.Cancel(); return "Blocked"
            else return "Moving" end
        end
        local point=points[index]
        if point then
            if (point-C.Position()).Magnitude<=.1 then index+=1
            else tween=C.StartTween(point,C.Speed); return "Moving" end
        end
        if index<=#points then return "Moving" end
        if not touching then touching=true; C.BeginTouch(coin) end
        return "Arrived"
    end
    function route.Snapshot()
        return {Mode="Underground",Phase=points and ({"Sink","Slide","Pickup","Contact"})[index] or "Idle",Tweening=tween~=nil}
    end
    return route
end

local createCrateBuyer=function(C)
    local buyer={Running=true,Status="Waiting for earned coins",Opened=0,Spent=0}
    local start=C.Balance()
    local busy,awaitingDebit,nextAt=false,nil,0
    local function amount(n) return type(n)=="number" and n==n and n>=0 and n<1e12 end
    if not amount(start) then buyer.Running=false; buyer.Status="Coin balance unavailable" end
    function buyer.Stop() buyer.Running=false end
    function buyer.Step()
        if not buyer.Running or busy or C.Clock()<nextAt or not C.CanOpen() then return end
        local balance=C.Balance()
        if not amount(balance) then buyer.Status="Waiting for coin balance"; return end
        if awaitingDebit then
            if balance>awaitingDebit then buyer.Status="Waiting for purchase debit"; return end
            awaitingDebit=nil
        end
        local box,price=C.Offer()
        if not box or not amount(price) or price<=0 then buyer.Status="No verified coin crate available"; return end
        if balance<start+price then buyer.Status="Waiting for earned coins"; return end
        busy=true
        awaitingDebit=balance-price
        buyer.Status="Opening "..box
        C.Purchase(box,function(ok,reward,isGodly)
            busy=false; nextAt=C.Clock()+10
            if not ok then
                -- A timeout/failure may still have charged currency. Never retry it blindly.
                buyer.Running=false; buyer.Status="Purchase result unavailable; stopped"; return
            end
            buyer.Opened+=1; buyer.Spent+=price; buyer.LastReward=reward
            buyer.Status=isGodly and "Godly received; stopped" or "Crate opened; waiting for debit"
            if isGodly then buyer.Running=false; C.OnGodly(reward) end
        end)
    end
    function buyer.Snapshot()
        return {Running=buyer.Running,Status=buyer.Status,Opened=buyer.Opened,Spent=buyer.Spent,
            LastReward=buyer.LastReward,Pending=busy,StartingCoins=start}
    end
    return buyer
end

-- Runtime adapter. The controller above is also exercised by the local regression suite.
local env=getgenv()
local launch=env.MM2AutoFarmLaunch
env.MM2AutoFarmLaunch=nil
if game.PlaceId~=142823291 then warn("MM2 coin farm: run this in Murder Mystery 2."); return end
local previous=env.MM2AutoFarm
if previous and type(previous.Stop)=="function" then previous.Stop("Replaced by a new copy") end
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local RS=game:GetService("ReplicatedStorage")
local Pathfinding=game:GetService("PathfindingService")
local TweenService=game:GetService("TweenService")
local player=Players.LocalPlayer
local config={ContactSeconds=.6,RetrySeconds=15,ResetWhenFull=true,AutoOpenCrates=true,Crate="MysteryBox2"}
config.Movement=type(launch)=="table" and launch.Movement=="Underground" and "Underground" or "Ground"
config.Depth=4
config.TweenSpeed=16
local connections,containers,coins={},{},{}
local bounds=setmetatable({},{__mode="k"})
local session,farm,buyer,undergroundRoute,touch
local pathRevision=0
local nextScan=0
local roundEnded=false
local function connect(signal,callback)
    local connection=signal:Connect(callback); table.insert(connections,connection); return connection
end
local function living()
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if char and char:IsDescendantOf(workspace) and hum and hum.Health>0 and root and not root.Anchored then return char,hum,root end
end
local function finite(p)
    return p.X==p.X and p.Y==p.Y and p.Z==p.Z and math.abs(p.X)<1e7 and math.abs(p.Y)<1e7 and math.abs(p.Z)<1e7
end
local function endTouch()
    local active=touch; touch=nil
    if active and type(firetouchinterest)=="function" then pcall(firetouchinterest,active.Root,active.Part,1) end
    if session and session.Hold then session.Hold.VectorVelocity=Vector3.zero; session.ContactPulse=nil end
end
local function cancelPath()
    pathRevision+=1
    if undergroundRoute then undergroundRoute.Cancel() end
    if not session then return end
    if session.PathHook then session.PathHook:Disconnect(); session.PathHook=nil end
    session.Goal,session.GoalPart,session.Waypoints,session.Computing,session.PathError=nil,nil,nil,false,nil
    session.NeedsReplan=nil; session.Direction=Vector3.zero
    if session.Humanoid.Parent and session.Root.Parent==session.Character then
        session.Humanoid:MoveTo(session.Root.Position)
    end
end
local function restore()
    cancelPath()
    local old=session
    session=nil
    if not old or not old.Underground then return end
    if old.NoclipHook then old.NoclipHook:Disconnect() end
    if old.Hold then old.Hold:Destroy() end
    if old.Pose then old.Pose:Destroy() end
    if old.Attachment then old.Attachment:Destroy() end
    local assist=env.MM2Assist
    local controlled=assist and assist.Running and (
        assist.Invis and (assist.Invis.Active or assist.Invis.Busy)
        or assist.ExperimentalInvis and (assist.ExperimentalInvis.Active or assist.ExperimentalInvis.Busy)
        or assist.Fling and assist.Fling.Active or assist.FlingQueue and assist.FlingQueue.Active)
    local sameMap=false
    if old.Map and old.Map:IsDescendantOf(workspace) and old.Root.Parent==old.Character then
        local ok,frame,size=pcall(old.Map.GetBoundingBox,old.Map)
        if ok then
            local p=frame:PointToObjectSpace(old.Root.Position)
            sameMap=math.abs(p.X)<=size.X/2+20 and math.abs(p.Z)<=size.Z/2+20 and math.abs(p.Y)<=size.Y/2+40
        end
    end
    if not controlled and player.Character==old.Character and old.Humanoid.Health>0
        and old.Root.Parent==old.Character and sameMap then
        local ignore={old.Character}
        for container in pairs(containers) do table.insert(ignore,container) end
        for _,p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(ignore,p.Character) end end
        local parameters=RaycastParams.new()
        parameters.FilterType=Enum.RaycastFilterType.Exclude; parameters.FilterDescendantsInstances=ignore
        parameters.RespectCanCollide=true
        local p=old.Root.Position
        local hit=workspace:Raycast(p+Vector3.new(0,config.Depth+8,0),Vector3.new(0,-config.Depth-24,0),parameters)
        old.Root.CFrame=hit and CFrame.new(hit.Position+Vector3.new(0,old.StandingHeight,0))*old.Upright or old.Origin
        old.Root.AssemblyLinearVelocity=Vector3.zero; old.Root.AssemblyAngularVelocity=Vector3.zero
    end
    for part,value in pairs(old.Collisions) do if part.Parent and part.CanCollide==false then part.CanCollide=value end end
    if old.Humanoid.Parent and not controlled then
        if old.Humanoid.AutoRotate==false then old.Humanoid.AutoRotate=old.AutoRotate end
        if old.Humanoid.PlatformStand and old.Humanoid.WalkSpeed>0 then old.Humanoid.PlatformStand=old.PlatformStand end
    end
end
local function eligibleContainer(instance)
    if instance.Name~="CoinContainer" or not (instance:IsA("Model") or instance:IsA("Folder")) then return false end
    local parent=instance.Parent
    while parent and parent~=workspace do
        if parent.Name=="Lobby" or parent.Name=="RegularLobby" or parent:FindFirstChildOfClass("Humanoid") then return false end
        parent=parent.Parent
    end
    return parent==workspace
end
local function scan()
    coins={}
    for container in pairs(containers) do
        if not eligibleContainer(container) then containers[container]=nil
        else
            local map=container.Parent
            if map and map:IsA("Folder") then map=map.Parent end
            if map and map:IsA("Model") then
                for _,part in ipairs(container:GetChildren()) do
                    if part:IsA("BasePart") and part.Name=="Coin_Server" then
                        local visual=part:FindFirstChild("CoinVisual")
                        table.insert(coins,{Part=part,Visual=visual,Map=map,Container=container,
                            Currency=part:GetAttribute("CoinID") or visual and visual:GetAttribute("CoinID")})
                    end
                end
            end
        end
    end
end
local function valid(coin)
    local part=coin.Part
    if part.Parent~=coin.Container or not part:IsDescendantOf(workspace) or not finite(part.Position) or not part.CanTouch then return false end
    for _,instance in ipairs({part,coin.Visual}) do
        if instance:GetAttribute("Collected") or instance:GetAttribute("Delete") or instance:GetAttribute("RoundEnd") then return false end
    end
    return true
end
local function inMap(coin)
    local _,_,root=living()
    if not root or not coin.Map:IsDescendantOf(workspace) then return false end
    local geometry=coin.Map:FindFirstChild("Base") or coin.Map:FindFirstChild("Map") or coin.Map
    if not (geometry:IsA("Model") or geometry:IsA("BasePart")) then geometry=coin.Map end
    local cached=bounds[geometry]
    if not cached or os.clock()-cached.At>2 then
        local ok,frame,size=pcall(function()
            if geometry:IsA("BasePart") then return geometry.CFrame,geometry.Size end
            return geometry:GetBoundingBox()
        end)
        if not ok or not finite(size) or size.Magnitude<1 then return false end
        cached={At=os.clock(),Frame=frame,Size=size}; bounds[geometry]=cached
    end
    local localPoint=cached.Frame:PointToObjectSpace(root.Position)
    return math.abs(localPoint.X)<=cached.Size.X/2+20 and math.abs(localPoint.Z)<=cached.Size.Z/2+20
        and math.abs(localPoint.Y)<=cached.Size.Y/2+40
end
local function blocked()
    if roundEnded then return "Waiting for the next round" end
    local char,hum=living()
    if char and (hum.WalkSpeed<=0 or char:GetAttribute("Frozen")==true) then return "Waiting while frozen" end
    if hum and (hum.PlatformStand and not (session and session.Underground) or hum.Sit) then return "Waiting for character control" end
    local assist=env.MM2Assist
    if assist and assist.Running then
        if assist.Invis and (assist.Invis.Active or assist.Invis.Busy)
            or assist.ExperimentalInvis and (assist.ExperimentalInvis.Active or assist.ExperimentalInvis.Busy)
            or assist.Fling and assist.Fling.Active or assist.FlingQueue and assist.FlingQueue.Active
            or assist.Movement and assist.Config and assist.Config.Fly
            or assist.Config and (assist.Config.SpeedBoost or assist.Config.Noclip)
            or assist.PlayerActions and assist.PlayerActions.Enabled then return "Paused for another movement action" end
    end
end
local function acquire(coin)
    local char,hum,root=living()
    assert(char,"Character changed before walking")
    session={Character=char,Humanoid=hum,Root=root}
    if config.Movement=="Underground" then
        session.Underground=true; session.Map=coin.Map; session.Origin=root.CFrame; session.Collisions={}
        session.AutoRotate=hum.AutoRotate; session.PlatformStand=hum.PlatformStand
        local _,yaw=root.CFrame:ToOrientation()
        session.Upright=CFrame.Angles(0,yaw,0)
        session.Flat=session.Upright*CFrame.Angles(math.pi/2,0,0)
        session.StandingHeight=hum.HipHeight+root.Size.Y/2+(hum.RigType==Enum.HumanoidRigType.R6 and 2 or 0)
        local attachment=Instance.new("Attachment")
        session.Attachment=attachment; attachment.Name="MM2FarmTweenAttachment"; attachment.Parent=root
        local hold=Instance.new("LinearVelocity")
        session.Hold=hold; hold.Attachment0=attachment; hold.RelativeTo=Enum.ActuatorRelativeTo.World
        hold.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector; hold.ForceLimitsEnabled=false
        hold.VectorVelocity=Vector3.zero; hold.Parent=root
        local pose=Instance.new("AlignOrientation")
        session.Pose=pose; pose.Attachment0=attachment; pose.Mode=Enum.OrientationAlignmentMode.OneAttachment
        pose.CFrame=session.Flat; pose.RigidityEnabled=true; pose.Parent=root
        hum.PlatformStand=true; hum.AutoRotate=false
        local current=session
        local function track(part)
            if session==current and part:IsA("BasePart") and not part:FindFirstAncestorOfClass("Tool") then
                if current.Collisions[part]==nil then current.Collisions[part]=part.CanCollide end
                part.CanCollide=false
            end
        end
        for _,part in ipairs(char:GetDescendants()) do track(part) end
        session.NoclipHook=char.DescendantAdded:Connect(track)
    end
end
local function readBagGUI()
    local gui=player:FindFirstChild("PlayerGui")
    local main=gui and gui:FindFirstChild("MainGUI")
    local gameGui=main and main:FindFirstChild("Game")
    local bags=gameGui and gameGui:FindFirstChild("CoinBags")
    local container=bags and bags:FindFirstChild("Container")
    for _,bag in ipairs(container and container:GetChildren() or {}) do
        local full=bag:FindFirstChild("FullBagIcon")
        if bag:IsA("Frame") and bag.Visible and full and full:IsA("GuiObject") then farm.SetBag(bag.Name,full.Visible) end
    end
end
local function walkTo(coin)
    local current=session
    assert(current and current.Character==player.Character and current.Root.Parent==current.Character,"Character changed during walking")
    local goal=coin.Part.Position
    local root=current.Root
    local delta=goal-root.Position
    local horizontal=Vector3.new(delta.X,0,delta.Z)
    if horizontal.Magnitude<=1.2 and math.abs(delta.Y)<=5 then
        current.Direction=Vector3.zero
        return "Arrived"
    end
    if current.GoalPart~=coin.Part or current.Goal and (current.Goal-goal).Magnitude>3 then
        cancelPath()
        current.GoalPart=coin.Part; current.Goal=goal
    end
    if current.PathError or current.NeedsReplan then return "Blocked" end
    if not current.Waypoints then
        current.Direction=Vector3.zero
        if current.Computing then
            return os.clock()-current.ComputeAt>4 and "Blocked" or "Moving"
        end
        current.Computing=true; current.ComputeAt=os.clock()
        local revision=pathRevision
        local origin=root.Position
        task.spawn(function()
            local ok,path,waypoints=pcall(function()
                local p=Pathfinding:CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true,AgentCanClimb=true})
                p:ComputeAsync(origin,goal)
                if p.Status~=Enum.PathStatus.Success then error("No traversable path") end
                return p,p:GetWaypoints()
            end)
            if session~=current or revision~=pathRevision then return end
            current.Computing=false
            if not ok or #waypoints==0 then current.PathError=true; return end
            current.Waypoints=waypoints; current.Index=1
            current.ProgressAt=os.clock(); current.ProgressPosition=root.Position
            current.PathHook=path.Blocked:Connect(function(index)
                if index>=current.Index then current.NeedsReplan=true end
            end)
        end)
        return "Moving"
    end
    if (root.Position-current.ProgressPosition).Magnitude>.5 then
        current.ProgressPosition=root.Position; current.ProgressAt=os.clock()
    elseif os.clock()-current.ProgressAt>3 then return "Blocked" end
    local waypoints=current.Waypoints
    local waypoint=waypoints[current.Index]
    while waypoint do
        local d=waypoint.Position-root.Position
        if Vector3.new(d.X,0,d.Z).Magnitude>1.5 or math.abs(d.Y)>6 then break end
        current.Index+=1; waypoint=waypoints[current.Index]
    end
    local destination=waypoint and waypoint.Position or goal
    local d=destination-root.Position
    local direction=Vector3.new(d.X,0,d.Z)
    current.Direction=direction.Magnitude>.05 and direction.Unit or Vector3.zero
    if waypoint and waypoint.Action==Enum.PathWaypointAction.Jump and current.JumpedAt~=current.Index then
        current.JumpedAt=current.Index; current.Humanoid.Jump=true
    end
    return "Moving"
end
if config.Movement=="Underground" then
    undergroundRoute=createUndergroundRoute({Depth=config.Depth,Speed=config.TweenSpeed,VoidY=workspace.FallenPartsDestroyHeight,
        Position=function() return session.Root.Position end,Vector=Vector3.new,
        Pickup=function(coin)
            -- Place the flat root just under the pickup, with a small overlap for contact.
            local offset=coin.Part.Size.Y/2+session.Root.Size.Z/2-.2
            return coin.Part.Position-Vector3.new(0,math.max(.15,offset),0)
        end,
        StartTween=function(point,speed)
            local root=session.Root
            local duration=math.max(.12,(point-root.Position).Magnitude/speed)
            local tween=TweenService:Create(root,TweenInfo.new(duration,Enum.EasingStyle.Linear),
                {CFrame=CFrame.new(point)*session.Flat})
            tween:Play()
            return tween
        end,
        CancelTween=function(tween) tween:Cancel(); tween:Destroy() end,
        TweenState=function(tween)
            local name=tween.PlaybackState.Name
            if name=="Completed" then tween:Destroy() end
            return name
        end,
        BeginTouch=function(coin)
            endTouch()
            if type(firetouchinterest)=="function" then
                touch={Root=session.Root,Part=coin.Part}
                pcall(firetouchinterest,touch.Root,touch.Part,0)
            else
                -- CFrame changes alone do not guarantee native touch events.
                -- A short physical upward nudge supplements the actual overlap.
                session.ContactPulse=os.clock()+.15
                session.Hold.VectorVelocity=Vector3.new(0,.4,0)
            end
        end,EndTouch=endTouch})
end
farm=createFarm({Clock=os.clock,Character=function() return living() end,Blocked=blocked,
    ContactSeconds=config.ContactSeconds,RetrySeconds=config.RetrySeconds,
    VoidY=workspace.FallenPartsDestroyHeight,Valid=valid,InMap=inMap,
    Coins=function() return coins end,Position=function() local _,_,root=living(); return root.Position end,
    Acquire=acquire,Release=restore,Move=undergroundRoute and undergroundRoute.Step or walkTo,CancelPath=cancelPath,
    MovementName=config.Movement,
    ResetWhenFull=config.ResetWhenFull,
    CanReset=function()
        for _,coin in ipairs(coins) do if inMap(coin) then return true end end
        return false
    end,
    Reset=function()
        local _,hum=living()
        if hum then hum.Health=0 end -- Explicit full-bag option; one request per round.
    end})
local stop=farm.Stop
function farm.Stop(reason)
    if buyer then buyer.Stop() end
    stop(reason)
    restore()
    RunService:UnbindFromRenderStep("MM2AutoFarmWalk")
    for _,connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
end
function farm.GetCrateSnapshot()
    return buyer and buyer.Snapshot() or {Running=false,Status="Crate service unavailable"}
end
function farm.GetMovementSnapshot()
    return undergroundRoute and undergroundRoute.Snapshot() or {Mode="Ground",Phase=session and "Walking" or "Idle"}
end
env.MM2AutoFarm=farm
connect(workspace.DescendantAdded,function(instance)
    if instance.Name=="CoinContainer" and eligibleContainer(instance) then containers[instance]=true; nextScan=0 end
end)
for _,instance in ipairs(workspace:GetDescendants()) do
    if instance.Name=="CoinContainer" and eligibleContainer(instance) then containers[instance]=true end
end
local remotes=RS:FindFirstChild("Remotes")
local gameplay=remotes and remotes:FindFirstChild("Gameplay")
local function remote(name,callback)
    local event=gameplay and gameplay:FindFirstChild(name)
    if event and event:IsA("RemoteEvent") then connect(event.OnClientEvent,callback) end
end
remote("CoinCollected",farm.Collected)
remote("CoinsStarted",function() roundEnded=false; farm.NewRound(); nextScan=0 end)
remote("RoundStart",function() roundEnded=false; farm.NewRound(); nextScan=0 end)
remote("RoundEndFade",function() roundEnded=true; farm.NewRound() end)
connect(player.CharacterRemoving,restore)
connect(UIS.InputBegan,function(input,processed)
    if not processed and not UIS:GetFocusedTextBox() and input.KeyCode==Enum.KeyCode.End then farm.Stop("Stopped with End") end
end)
RunService:BindToRenderStep("MM2AutoFarmWalk",Enum.RenderPriority.Character.Value+1,function()
    if session and not session.Underground and session.Direction and session.Character==player.Character and session.Humanoid.Health>0 then
        session.Humanoid:Move(session.Direction,false)
    end
end)
connect(RunService.PreSimulation,function()
    if not session or not session.Underground then return end
    local ok,message=pcall(function()
        for part in pairs(session.Collisions) do if part.Parent then part.CanCollide=false end end
        session.Root.AssemblyAngularVelocity=Vector3.zero
        if session.ContactPulse and os.clock()>=session.ContactPulse then
            session.ContactPulse=nil; session.Hold.VectorVelocity=Vector3.zero
        end
    end)
    if not ok then farm.Stop("Underground movement error"); warn("MM2 coin farm: "..tostring(message)) end
end)
connect(RunService.Heartbeat,function(dt)
    if not farm.Running then return end
    local ok,message=pcall(function()
        if os.clock()>=nextScan then scan(); readBagGUI(); nextScan=os.clock()+1 end
        farm.Step(math.clamp(dt,1/240,.1))
        if buyer then buyer.Step() end
    end)
    if not ok then farm.Stop("Stopped after an error"); warn("MM2 coin farm: "..tostring(message)) end
end)

if config.AutoOpenCrates then
    -- Uses the native shop's ordinary one-crate Coins request, never a key/Gems/Robux purchase.
    local ok,profile,catalog,shop=pcall(function()
        local data=require(RS.Modules.ProfileData)
        local sync=require(RS.Database.Sync)
        local remoteFolder=RS.Remotes:FindFirstChild("Shop")
        local remoteFunction=remoteFolder and remoteFolder:FindFirstChild("OpenCrate")
        assert(remoteFunction and remoteFunction:IsA("RemoteFunction"),"Shop unavailable")
        return data,sync,remoteFunction
    end)
    if ok then
        buyer=createCrateBuyer({Clock=os.clock,
            Balance=function() return profile.Materials and profile.Materials.Owned and profile.Materials.Owned.Coins end,
            CanOpen=function()
                if not farm.Running or session or blocked() and not roundEnded then return false end
                for _,coin in ipairs(coins) do if inMap(coin) then return false end end
                return living()~=nil
            end,
            Offer=function()
                local box=catalog.MysteryBox and catalog.MysteryBox[config.Crate]
                local offer=catalog.NewShop and catalog.NewShop[config.Crate]
                if box and (type(box.Godly)=="string" or type(box.GodlyTable)=="table" and #box.GodlyTable>0)
                    and offer and offer.Type=="MysteryBox" and offer.Price then
                    return config.Crate,offer.Price.Coins
                end
            end,
            Purchase=function(box,done)
                task.spawn(function()
                    local success,reward=pcall(shop.InvokeServer,shop,box,"MysteryBox","Coins")
                    local godly=false
                    if success and type(reward)=="string" then
                        local info=catalog.MysteryBox[box]
                        godly=reward==info.Godly or info.GodlyTable and table.find(info.GodlyTable,reward)~=nil
                            or info.ChromaTable and table.find(info.ChromaTable,reward)~=nil
                        done(true,reward,godly==true)
                    else done(false) end
                end)
            end,
            OnGodly=function() farm.Stop("Godly received; farming stopped") end})
    end
end
