-- MM2 standalone coin farm. No UI; starts immediately. End or MM2AutoFarm.Stop() stops it.
-- Uses normal paths and character speed. Server awards and crate results are not guaranteed.
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
            if not held then C.Acquire(); held=true end
            target=best
            deadline=now+math.max(15,distance/12*3+8)
            phase="Walk"
        end
        local coinPosition=target.Part.Position
        if coinPosition.Y<C.VoidY+20 then
            skipped[target.Part]=now+C.RetrySeconds; release(); farm.Status="Skipped a coin near the void"; return
        end
        if phase=="Walk" then
            farm.Status="Walking a normal path to a coin"
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
            ServerEvents=farm.ServerEvents,Removed=farm.Removed,Resets=farm.Resets,Phase=phase}
    end
    return farm
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
if game.PlaceId~=142823291 then warn("MM2 coin farm: run this in Murder Mystery 2."); return end
local previous=env.MM2AutoFarm
if previous and type(previous.Stop)=="function" then previous.Stop("Replaced by a new copy") end
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local RS=game:GetService("ReplicatedStorage")
local Pathfinding=game:GetService("PathfindingService")
local player=Players.LocalPlayer
local config={ContactSeconds=.6,RetrySeconds=15,ResetWhenFull=true,AutoOpenCrates=true,Crate="MysteryBox2"}
local connections,containers,coins={},{},{}
local bounds=setmetatable({},{__mode="k"})
local session,farm,buyer
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
local function cancelPath()
    pathRevision+=1
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
    session=nil
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
    if hum and (hum.PlatformStand or hum.Sit) then return "Waiting for character control" end
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
local function acquire()
    local char,hum,root=living()
    assert(char,"Character changed before walking")
    session={Character=char,Humanoid=hum,Root=root}
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
farm=createFarm({Clock=os.clock,Character=function() return living() end,Blocked=blocked,
    ContactSeconds=config.ContactSeconds,RetrySeconds=config.RetrySeconds,
    VoidY=workspace.FallenPartsDestroyHeight,Valid=valid,InMap=inMap,
    Coins=function() return coins end,Position=function() local _,_,root=living(); return root.Position end,
    Acquire=acquire,Release=restore,Move=walkTo,CancelPath=cancelPath,
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
    if session and session.Direction and session.Character==player.Character and session.Humanoid.Health>0 then
        session.Humanoid:Move(session.Direction,false)
    end
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
