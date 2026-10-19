-- MM2 standalone currency farm. No UI; starts immediately. End or MM2AutoFarm.Stop() stops it.
-- MM2FarmFormat:2
-- MM2FarmRevision:20261020.1
-- Ground paths by default; the separate loader selects experimental prone underground tweens.
-- Server acceptance, awards and crate results are not guaranteed.
local createFarm = function(C)
    local farm = {Running=true,Status="Waiting for a round",Attempts=0,ServerEvents=0,Removed=0,Resets=0,
        DangerSkips=0,PickupEvents=0,Retries=0,Unconfirmed=0}
    local target,phase,character,deadline,contactUntil,resetAt
    local skipped,full,bagCounts = {},{},{}
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
        skipped,full,bagCounts={},{},{}
        resetRequested,serverFull,resetAt=false,false,nil
        farm.Status="Waiting for round coins"
    end
    function farm.SetBag(kind,isFull,amount)
        -- A delayed GUI refresh must not undo an authoritative full-bag event.
        if kind~=nil and not full[kind] then full[kind]=isFull==true end
        if kind~=nil and bagCounts[kind]==nil and type(amount)=="number" then bagCounts[kind]=amount end
    end
    function farm.Collected(kind,amount,capacity)
        farm.ServerEvents+=1
        if kind~=nil and type(amount)=="number" and type(capacity)=="number" and capacity>0 then
            local previous=bagCounts[kind]
            bagCounts[kind]=amount
            full[kind]=amount>=capacity
            if amount>=capacity then serverFull=true end
            if target and not target.Acknowledged and (not target.Currency or target.Currency==kind)
                and amount>(previous or 0) and C.Character() then
                local ok,position=pcall(C.Position)
                if ok and (position-target.Part.Position).Magnitude<=6 then
                    target.Acknowledged=true;farm.PickupEvents+=1
                end
            end
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
        if held and C.MovementName=="Underground" and C.DangerNear and C.DangerNear() then
            if target then C.CancelPath();farm.DangerSkips+=1;target,phase=nil,nil end
            if C.Hide then C.Hide() end
            farm.Status="Hiding below the floor from a nearby role opponent";return
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
        if target and target.Acknowledged then
            C.CancelPath();skipped[target.Part]=now+C.RetrySeconds;target,phase=nil,nil
        end
        if target and C.Safe and not C.Safe(target) then
            C.CancelPath(); farm.DangerSkips+=1; target,phase=nil,nil
        end
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
            local best,distance,unsafe
            local position=C.Position()
            for _,coin in ipairs(C.Coins()) do
                if available(coin,now) and C.Valid(coin) and C.InMap(coin) then
                    if C.Safe and not C.Safe(coin) then unsafe=true
                    else
                        local d=(coin.Part.Position-position).Magnitude
                        if not distance or d<distance then best,distance=coin,d end
                    end
                end
            end
            if not best then
                if unsafe and held and C.MovementName=="Underground" then
                    if C.Hide then C.Hide() else C.CancelPath() end
                    farm.Status="Holding underground; opponents near available coins";return
                end
                release(); farm.Status="Waiting for coins or a bag with space"; return
            end
            if not held then C.Acquire(best); held=true end
            target=best
            target.RetryCount=0;target.Acknowledged=false
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
                if C.RetryPickup and target.RetryCount<(C.MaxPickupRetries or 0) then
                    target.RetryCount+=1;farm.Retries+=1
                    if C.RetryPickup(target,target.RetryCount+1) then
                        phase=C.MovementName=="Underground" and "Tween" or "Walk"
                        deadline=now+8
                    else
                        farm.Unconfirmed+=1;C.CancelPath();skipped[target.Part]=now+C.RetrySeconds;target,phase=nil,nil
                    end
                else
                    farm.Unconfirmed+=1;C.CancelPath();skipped[target.Part]=now+C.RetrySeconds;target,phase=nil,nil
                end
            end
        end
    end
    function farm.Snapshot()
        return {Running=farm.Running,Status=farm.Status,Attempts=farm.Attempts,
            ServerEvents=farm.ServerEvents,Removed=farm.Removed,Resets=farm.Resets,Phase=phase,
            Movement=C.MovementName or "Ground",DangerSkips=farm.DangerSkips,
            PickupEvents=farm.PickupEvents,Retries=farm.Retries,Unconfirmed=farm.Unconfirmed}
    end
    return farm
end

local isRoleThreat=function(mode,own,other,armed)
    local threats={
        Classic={Murderer={Sheriff=true,Hero=true},Sheriff={Murderer=true},Hero={Murderer=true},Innocent={Murderer=true}},
        Infection={Zombie={Survivor=true},Survivor={Zombie=true}},
        FreezeTag={Runner={Freezer=true},Freezer={}},
    }
    local roles=threats[mode]
    if roles and roles[own] and roles[other] then return roles[own][other]==true end
    return armed==true or other=="Murderer" or other=="Sheriff" or other=="Hero" or other=="Zombie" or other=="Freezer"
end

local createUndergroundRoute=function(C)
    local route={}
    local target,points,index,tween,touching,underY,hiding
    function route.Cancel()
        if tween then C.CancelTween(tween); tween=nil end
        C.EndTouch()
        target,points,index,touching,hiding=nil,nil,nil,nil,nil
    end
    function route.Step(coin)
        local position=coin.Part.Position
        if hiding then route.Cancel() end
        if target~=coin.Part then
            route.Cancel()
            if position.Y-C.Depth<C.VoidY+20 then return "Blocked" end
            target=coin.Part
            underY=position.Y-C.Depth
            local root=C.Position()
            points={C.Vector(root.X,position.Y-C.Depth,root.Z),
                C.Vector(position.X,position.Y-C.Depth,position.Z),C.Pickup(coin)}
            index=1
        end
        if tween then
            local state=C.TweenState(tween)
            if state=="Completed" then
                -- Playback completion alone is not proof the live root reached its goal.
                if (C.Position()-points[index]).Magnitude>1 then route.Cancel(); return "Blocked" end
                if C.FinishTween then C.FinishTween(tween) end
                tween=nil; index+=1
            elseif state=="Cancelled" then route.Cancel(); return "Blocked"
            else return "Moving" end
        end
        local point=points[index]
        if point then
            if (point-C.Position()).Magnitude<=.1 then index+=1
            else tween=C.StartTween(point,index==2 and C.Speed or C.ApproachSpeed or C.Speed); return "Moving" end
        end
        if index<=#points then return "Moving" end
        if (C.Position()-points[#points]).Magnitude>1.5 then route.Cancel(); return "Blocked" end
        if not touching then touching=true; C.BeginTouch(coin) end
        return "Arrived"
    end
    function route.Hide()
        if not underY then return "Blocked" end
        if not hiding then
            route.Cancel();hiding=true
            local p=C.Position();points={C.Vector(p.X,underY,p.Z)};index=1
        end
        if tween then
            local state=C.TweenState(tween)
            if state=="Completed" then
                local arrived=(C.Position()-points[1]).Magnitude<=1
                if C.FinishTween then C.FinishTween(tween) end
                tween=nil
                if not arrived then route.Cancel();return "Blocked" end
            elseif state=="Cancelled" then route.Cancel();return "Blocked"
            else return "Moving" end
        end
        if (C.Position()-points[1]).Magnitude>.1 then
            tween=C.StartTween(points[1],C.ApproachSpeed or C.Speed);return "Moving"
        end
        return "Hidden"
    end
    function route.Retry(coin,variant)
        route.Cancel()
        local p=coin.Part.Position
        if p.Y-C.Depth<C.VoidY+20 then return false end
        target=coin.Part;underY=p.Y-C.Depth
        local root=C.Position()
        points={C.Vector(root.X,underY,root.Z),C.Vector(p.X,underY,p.Z),C.Pickup(coin,variant)}
        index=1;return true
    end
    function route.Snapshot()
        return {Mode="Underground",Phase=hiding and "Hide" or points and ({"Sink","Slide","Pickup","Contact"})[index] or "Idle",Tweening=tween~=nil}
    end
    return route
end

local chooseRecoveryPoint=function(position,floor,height,limit,vector)
    if not floor then return position end
    local candidate=floor+vector(0,height,0)
    return (candidate-position).Magnitude<=limit and candidate or position
end

local validAmount=function(n)
    return type(n)=="number" and n==n and n>=0 and n<1e12
end

-- Only earned collectible currency is eligible. Keys/premium currencies are never fallbacks.
local collectibleCurrency=function(id)
    if type(id)~="string" then return false end
    local lower=id:lower()
    if lower:find("key",1,true) or lower:find("gem",1,true) or lower:find("robux",1,true) then return false end
    return id~="" and #id<=80 and id:match("^[%w_%-]+$")~=nil
end

local discoverCrateCatalog=function(base,events)
    if type(events)~="table" then return nil,"Event shop discovery unavailable" end
    local catalog={NewShop={},MysteryBox={},Item={}}
    for _,kind in ipairs({"NewShop","MysteryBox","Item"}) do
        for id,value in pairs(base[kind] or {}) do catalog[kind][id]=value end
    end
    local active={}
    for id,event in pairs(events) do
        if type(event)=="table" and event.Status=="Started" and type(event.EventStartInfo)=="table" then
            table.insert(active,{Id=tostring(id),Event=event})
        end
    end
    table.sort(active,function(a,b)
        local am,bm=a.Event.Priority=="Main",b.Event.Priority=="Main"
        if am~=bm then return am end
        return a.Id<b.Id
    end)
    local currency,eventId
    for _,row in ipairs(active) do
        local info=row.Event.EventStartInfo
        for _,kind in ipairs({"MysteryBox","Item"}) do
            for id,value in pairs(type(info.Items)=="table" and info.Items[kind] or {}) do catalog[kind][id]=value end
        end
        for id,value in pairs(info.ShopData or {}) do catalog.NewShop[id]=value end
        -- CurrencyName is the server's actual event currency ID, not the pickup bag name.
        if row.Event.Priority=="Main" and info.CurrencyName~=nil and not collectibleCurrency(info.CurrencyName) then
            return nil,"Main event collectible currency unavailable"
        end
        if not currency and collectibleCurrency(info.CurrencyName) then currency=info.CurrencyName;eventId=row.Id end
    end
    catalog.Currency=currency or "Coins";catalog.Event=eventId
    if currency then
        -- A live event never falls back to spending a different currency or a stale event offer.
        local offers={}
        for _,row in ipairs(active) do
            if row.Id==eventId then
                for id,offer in pairs(row.Event.EventStartInfo.ShopData or {}) do offers[id]=offer end
            end
        end
        catalog.NewShop=offers
    end
    return catalog
end

local chooseCrateOffer=function(catalog,owned,received,preferred,currency)
    currency=currency or catalog.Currency or "Coins"
    if not collectibleCurrency(currency) then return nil,nil,"No collectible currency selected" end
    if type(owned)~="table" then return nil,nil,"Inventory unavailable" end
    local function has(id)
        local n=owned[id]
        return received[id]==true or n==true or type(n)=="number" and n>0
    end
    local function targets(box,chroma)
        local ids,seen={},{}
        local function add(id) if type(id)=="string" and id~="" and not seen[id] then seen[id]=true;table.insert(ids,id) end end
        if chroma then for _,id in ipairs(type(box.ChromaTable)=="table" and box.ChromaTable or {}) do add(id) end
        else
            add(box.Godly)
            for _,id in ipairs(type(box.GodlyTable)=="table" and box.GodlyTable or {}) do add(id) end
        end
        local missing=0
        for _,id in ipairs(ids) do if not has(id) then missing+=1 end end
        return missing
    end
    local fallback
    for _,chroma in ipairs({false,true}) do
        local best
        for id,box in pairs(catalog.MysteryBox or {}) do
            local offer=catalog.NewShop and catalog.NewShop[id]
            local price=type(offer)=="table" and type(offer.Price)=="table" and offer.Price[currency]
            if type(id)=="string" and type(box)=="table" and offer and offer.Type=="MysteryBox"
                and type(price)=="number" and price==price and price>0 and price<1e12 then
                local missing=targets(box,chroma)
                if not chroma and (type(box.Godly)=="string" or type(box.GodlyTable)=="table" and #box.GodlyTable>0)
                    and (not fallback or price<fallback.Price or price==fallback.Price and (id==preferred or fallback.Id~=preferred and id<fallback.Id)) then
                    fallback={Id=id,Price=price}
                end
                if missing>0 and (not best or price<best.Price
                    or price==best.Price and (missing>best.Missing
                    or missing==best.Missing and (id==preferred and best.Id~=preferred or best.Id~=preferred and id<best.Id))) then
                    best={Id=id,Price=price,Missing=missing,Chroma=chroma}
                end
            end
        end
        if best then return best.Id,best.Price,nil,best.Missing,best.Chroma,currency end
    end
    if fallback then return fallback.Id,fallback.Price,nil,0,false,currency end
    return nil,nil,"No verified crate for "..currency
end

local createReconnect=function(C)
    local state={Attempts=0,Status="Ready",Pending=false,Running=true,InFlight=false}
    local revision,queued,prepared=0,false,false
    if not C.Supported then state.Status="Executor resume/error notification unavailable" end
    local function refused(message)
        if type(message)~="string" then return false end
        local text=message:lower()
        return text:find("banned",1,true) or text:find("restricted",1,true) or text:find("not authorized",1,true)
            or text:find("access denied",1,true) or text:find("permission",1,true)
    end
    function state.Stop(reason)
        if not state.Running then return end
        state.Running=false;state.Pending=false;state.InFlight=false;revision+=1
        state.Status=reason or "Stopped"
        if C.Cleanup then C.Cleanup() end
    end
    function state.CancelPending()
        if not state.Pending then return false end
        revision+=1;state.Pending=false;state.RetryIn=nil;state.Status="Ready"
        return true
    end
    local schedule
    function state.Failed(message)
        if not state.Running or not state.InFlight then return end
        state.InFlight=false;revision+=1
        if refused(message) then state.Stop("Access refusal; no automatic retry");return end
        schedule("Teleport failed")
    end
    schedule=function(reason)
        if not state.Running or state.Pending or state.InFlight or not C.Supported then return false end
        revision+=1;local ticket=revision
        local delay=math.min(120,5*2^math.min(state.Attempts,5))
        state.Pending=true;state.RetryIn=delay;state.Status=(reason or "Disconnected").."; rejoin pending"
        C.Schedule(delay,function()
            if not state.Running or not state.Pending or ticket~=revision then return end
            state.Pending=false;state.RetryIn=nil;state.Attempts+=1
            if not queued then
                local ok,result=pcall(C.Queue)
                if not ok or result==false then schedule("Resume queue failed");return end
                queued=true
            end
            if not prepared then
                local ok=pcall(C.Prepare)
                if not ok then state.Stop("Could not stop movement before rejoin");return end
                prepared=true
            end
            state.InFlight=true;state.Status="Rejoin requested"
            local ok,result=pcall(C.Rejoin)
            if not ok or result==false then state.Failed(ok and "Teleport rejected" or tostring(result));return end
            C.Schedule(30,function()
                if state.Running and state.InFlight and ticket==revision then state.Failed("Teleport did not complete") end
            end)
        end)
        return true
    end
    function state.Error(message)
        if not state.Running or not C.Supported or type(message)~="string" then return false end
        if refused(message) then state.Stop("Access refusal; no automatic retry");return false end
        local text=message:lower()
        if not (text:find("disconnect",1,true) or text:find("kicked",1,true) or text:find("invalid position",1,true)
            or text:find("connection lost",1,true) or text:find("lost connection",1,true)
            or text:find("idle",1,true)) then return false end
        return schedule()
    end
    function state.Snapshot()
        return {Attempts=state.Attempts,Status=state.Status,Running=state.Running,Pending=state.Pending,
            InFlight=state.InFlight,RetryIn=state.RetryIn,ResumeSupported=C.Supported==true,Unlimited=true}
    end
    return state
end

local createCrateBuyer=function(C)
    local buyer={Running=true,Status="Waiting for a collectible-currency crate",Opened=0,Spent=0}
    local spent={}
    local busy,awaitingDebit,nextAt=false,nil,0
    function buyer.Stop() buyer.Running=false end
    function buyer.Step()
        if not buyer.Running or busy or C.Clock()<nextAt or not C.CanOpen() then return end
        if awaitingDebit then
            local balance=C.Balance(awaitingDebit.Currency)
            if not validAmount(balance) or balance>awaitingDebit.Balance then buyer.Status="Waiting for purchase debit"; return end
            awaitingDebit=nil
        end
        local box,price,reason,missing,_,currency=C.Offer()
        if not box or not validAmount(price) or price<=0 or not collectibleCurrency(currency) then
            buyer.Status=reason or "No verified collectible-currency crate available";return
        end
        buyer.SelectedCrate=box;buyer.SelectedPrice=price;buyer.SelectedCurrency=currency;buyer.MissingTargets=missing
        local balance=C.Balance(currency)
        if not validAmount(balance) then buyer.Status="Waiting for "..currency.." balance";return end
        if balance<price then buyer.Status="Waiting for "..currency;return end
        busy=true
        awaitingDebit={Currency=currency,Balance=balance-price}
        buyer.Status="Opening "..box
        local completed=false
        C.Purchase(box,currency,function(ok,reward,isGodly)
            if completed then return end
            completed=true
            busy=false; nextAt=C.Clock()+10
            if not ok then
                -- A timeout/failure may still have charged currency. Never retry it blindly.
                buyer.Running=false; buyer.Status="Purchase result unavailable; stopped"; return
            end
            buyer.Opened+=1; buyer.Spent+=price; buyer.LastReward=reward
            spent[currency]=(spent[currency] or 0)+price
            buyer.Status=isGodly and "Godly received; updating target selection" or "Crate opened; waiting for debit"
            if isGodly then
                buyer.Godlies=(buyer.Godlies or 0)+1
                if C.StopOnGodly~=false then buyer.Running=false; buyer.Status="Godly received; stopped" end
                C.OnGodly(reward)
            end
        end)
    end
    function buyer.Snapshot()
        local currencies=table.clone(spent)
        return {Running=buyer.Running,Status=buyer.Status,Opened=buyer.Opened,Spent=buyer.Spent,
            LastReward=buyer.LastReward,Pending=busy,SpentByCurrency=currencies,SelectedCrate=buyer.SelectedCrate,SelectedCurrency=buyer.SelectedCurrency,
            SelectedPrice=buyer.SelectedPrice,MissingTargets=buyer.MissingTargets,Godlies=buyer.Godlies or 0}
    end
    return buyer
end

local createLowGraphics=function(C)
    local state={Enabled=C.Enabled==true,Disabled3D=false,OriginalKnown=false,Status="Normal graphics",FPSStatus="Unchanged"}
    local renderingOwned,fpsOwned=false,false
    local originalRendering,originalFPS=true,nil
    local function readRendering()
        if type(C.ReadRendering)~="function" then return nil end
        local ok,value=pcall(C.ReadRendering)
        if ok and type(value)=="boolean" then return value end
    end
    if state.Enabled then
        local before=readRendering()
        state.OriginalKnown=before~=nil
        if before~=nil then originalRendering=before end
        if before==false then state.Disabled3D=true;state.Status="3D rendering was already disabled"
        elseif type(C.WriteRendering)=="function" then
            local ok,result=pcall(C.WriteRendering,false)
            if ok and result~=false then
                renderingOwned=true;state.Disabled3D=true;state.Status="3D rendering disabled"
                if readRendering()==true then state.Disabled3D=false;state.Status="Rendering change not confirmed" end
            else state.Status="3D rendering control unavailable" end
        else state.Status="3D rendering control unavailable" end
        if type(C.GetFPS)=="function" and type(C.SetFPS)=="function" then
            local ok,value=pcall(C.GetFPS)
            if ok and validAmount(value) then
                originalFPS=value
                if value==0 or value>20 then
                    local changed,result=pcall(C.SetFPS,20)
                    if changed and result~=false then fpsOwned=true;state.FPSCap=20;state.FPSStatus="20 FPS requested"
                    else state.FPSStatus="FPS setter unavailable" end
                else state.FPSCap=value;state.FPSStatus="Existing low FPS cap retained" end
            else state.FPSStatus="Previous FPS cap unavailable; unchanged" end
        else state.FPSStatus="Paired FPS APIs unavailable; unchanged" end
    end
    function state.Restore()
        if renderingOwned then
            local ok,result=pcall(C.WriteRendering,originalRendering)
            if ok and result~=false then
                renderingOwned=false;state.Disabled3D=originalRendering==false
            end
        end
        if fpsOwned then
            local ok,current=pcall(C.GetFPS)
            if ok and current~=20 then fpsOwned=false -- A later user/executor change takes precedence.
            else
                local restored,result=pcall(C.SetFPS,originalFPS)
                if restored and result~=false then fpsOwned=false;state.FPSCap=originalFPS end
            end
        end
        state.RestorePending=renderingOwned or fpsOwned
        state.Status=state.RestorePending and "Graphics restoration incomplete; call Restore again" or "Graphics changes released"
        return not state.RestorePending
    end
    function state.Snapshot()
        return {Enabled=state.Enabled,Disabled3D=state.Disabled3D,OriginalKnown=state.OriginalKnown,
            Status=state.Status,FPSCap=state.FPSCap,FPSStatus=state.FPSStatus,RestorePending=state.RestorePending==true}
    end
    return state
end

local createResumeSource=function(movement,paused,token,lowGraphics)
    assert(movement=="Ground" or movement=="Underground","Invalid movement")
    return string.format([[
if game.PlaceId~=142823291 then return end
local env=getgenv()
local token=%q
if env.MM2AutoFarmResumeToken==token then return end
env.MM2AutoFarmResumeToken=token
local resume={Running=true,Status="Downloading farm after reconnect"}
local hook
function resume.Stop() resume.Running=false;if hook then hook:Disconnect();hook=nil end end
function resume.Snapshot() return {Running=resume.Running,Status=resume.Status} end
env.MM2AutoFarm=resume
local input=game:GetService("UserInputService")
hook=input.InputBegan:Connect(function(key,processed)
    if not processed and not input:GetFocusedTextBox() and key.KeyCode==Enum.KeyCode.End then resume.Stop() end
end)
while resume.Running and not game:IsLoaded() do task.wait(1) end
local delay=5
while resume.Running do
    local ok,source=pcall(game.HttpGet,game,"https://raw.githubusercontent.com/ObsidianWorkss/Murder-Mystery-2/refs/heads/main/auto-farm.lua?farm=20261020.1")
    if not resume.Running then return end
    if ok and type(source)=="string" and source:find("-- MM2FarmRevision:20261020.1",1,true) then
        local chunk=loadstring(source,"MM2AutoFarmResume")
        if chunk then
            resume.Stop()
            env.MM2AutoFarmLaunch={Movement=%q,PurchasesPaused=%s,LowGraphics=%s}
            local loaded,why=pcall(chunk)
            env.MM2AutoFarmLaunch=nil
            if not loaded then warn("MM2 farm resume failed: "..tostring(why)) end
            return
        end
    end
    resume.Status="Farm download unavailable; retrying"
    task.wait(delay);delay=math.min(120,delay*2)
end
]],token,movement,tostring(paused==true),tostring(lowGraphics==true))
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
local roundClient
pcall(function()
    local modules=RS:FindFirstChild("Modules")
    local current=modules and modules:FindFirstChild("CurrentRoundClient")
    if current then roundClient=require(current) end
end)
local config={ContactSeconds=.9,RetrySeconds=15,MaxPickupRetries=2,ResetWhenFull=true,AutoOpenCrates=true,AutoRejoin=true,RejoinBeforeIdle=true,
    Crate="MysteryBox2",SmartCrates=true,StopOnGodly=false,AvoidOpponents=true,DangerRadius=24}
config.Movement=type(launch)=="table" and launch.Movement=="Underground" and "Underground" or "Ground"
config.LowGraphics=type(launch)=="table" and launch.LowGraphics==true
config.Depth=4
config.TweenSpeed=48
config.ApproachSpeed=12
local connections,containers,coins={},{},{}
local reconnectConnections={}
local shopState={Pending=false,NextRefresh=0,Status="Waiting for event discovery"}
local bounds=setmetatable({},{__mode="k"})
local session,farm,buyer,undergroundRoute,touch,reconnect,graphics
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
        -- Never turn a missing/distant floor query into a cross-map teleport to the session origin.
        local destination=chooseRecoveryPoint(p,hit and hit.Position,old.StandingHeight,config.Depth+12,Vector3.new)
        old.Root.CFrame=CFrame.new(destination)*old.Upright
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
                for _,part in ipairs(container:GetDescendants()) do
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
    if not part:IsDescendantOf(coin.Container) or not part:IsDescendantOf(workspace) or not finite(part.Position) or not part.CanTouch then return false end
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
            or assist.Config and (assist.Config.Noclip or assist.Config.SpeedBoost and config.Movement=="Ground")
            or assist.PlayerActions and assist.PlayerActions.Enabled then return "Paused for another movement action" end
    end
end
local threatRoots,nextThreatScan={},0
local function opponentNear(position)
    if not config.AvoidOpponents then return false end
    if os.clock()>=nextThreatScan then
        nextThreatScan=os.clock()+.2; threatRoots={}
        local assist=env.MM2Assist
        local context=assist and assist.Running and assist.GameContext
        local mode=context and context.Mode() or workspace:GetAttribute("GameMode") or "Unknown"
        local function roleFor(p)
            if context then local ok,value=pcall(context.Role,p);if ok then return value end end
            local char=p.Character
            if mode=="Infection" and char and char:GetAttribute("Zombie")==true then return "Zombie" end
            local rows=roundClient and roundClient.PlayerData
            local row=type(rows)=="table" and (rows[p.Name] or rows[tostring(p.UserId)] or rows[p.UserId])
            if type(row)=="table" and type(row.Role)=="string" then return row.Role end
            local pack=p==player and p:FindFirstChild("Backpack")
            local knife=char and char:FindFirstChild("Knife") or pack and pack:FindFirstChild("Knife")
            local gun=char and char:FindFirstChild("Gun") or pack and pack:FindFirstChild("Gun")
            if mode=="Classic" then return knife and "Murderer" or gun and "Sheriff" or "Unknown" end
            if mode=="Infection" and gun then return "Survivor" end
            if mode=="FreezeTag" and (gun or knife) then return "Freezer" end
            return "Unknown"
        end
        local ownRole=roleFor(player)
        for _,other in ipairs(Players:GetPlayers()) do
            if other~=player then
                local char=other.Character
                local root=char and char:FindFirstChild("HumanoidRootPart")
                local hum=char and char:FindFirstChildOfClass("Humanoid")
                if root and hum and hum.Health>0 then
                    local role=roleFor(other)
                    local armed=char:FindFirstChild("Knife")~=nil or char:FindFirstChild("Gun")~=nil
                    local threat=isRoleThreat(mode,ownRole,role,armed)
                    if context and context.Target and role~="Unknown" and ownRole~="Unknown" then
                        local ok,value=pcall(function() return context.Target(other,player,"Knife") or context.Target(other,player,"Gun") end)
                        if ok then threat=value end
                    end
                    if threat then
                        table.insert(threatRoots,root)
                    end
                end
            end
        end
    end
    for _,root in ipairs(threatRoots) do
        if root.Parent and (root.Position-position).Magnitude<config.DangerRadius then return true end
    end
    return false
end
local function acquire(coin)
    local char,hum,root=living()
    assert(char,"Character changed before walking")
    session={Character=char,Humanoid=hum,Root=root}
    if config.Movement=="Underground" then
        session.Underground=true; session.Map=coin.Map; session.Collisions={}
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
        if bag:IsA("Frame") and bag.Visible and full and full:IsA("GuiObject") then
            local frame=bag:FindFirstChild("CurrencyFrame")
            local icon=frame and frame:FindFirstChild("Icon")
            local count=icon and icon:FindFirstChild("Coins")
            local amount=count and (count:IsA("TextLabel") or count:IsA("TextButton")) and tonumber(count.Text:match("%d+"))
            farm.SetBag(bag.Name,full.Visible,amount)
        end
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
    undergroundRoute=createUndergroundRoute({Depth=config.Depth,Speed=config.TweenSpeed,ApproachSpeed=config.ApproachSpeed,
        VoidY=workspace.FallenPartsDestroyHeight,
        Position=function() return session.Root.Position end,Vector=Vector3.new,
        Pickup=function(coin,variant)
            if variant==2 then return coin.Part.Position-Vector3.new(0,.1,0) end
            if variant==3 then return coin.Part.Position+Vector3.new(.25,.1,0) end
            -- Place the flat root just under the pickup, with a small overlap for contact.
            local offset=coin.Part.Size.Y/2+session.Root.Size.Z/2-.2
            return coin.Part.Position-Vector3.new(0,math.max(.15,offset),0)
        end,
        StartTween=function(point,speed)
            local root=session.Root
            local duration=math.max(.12,(point-root.Position).Magnitude/speed)
            -- Let the tween own rotation during travel; re-enable the pose hold at rest.
            session.Pose.Enabled=false
            local tween=TweenService:Create(root,TweenInfo.new(duration,Enum.EasingStyle.Linear),
                {CFrame=CFrame.new(point)*session.Flat})
            tween:Play()
            return tween
        end,
        CancelTween=function(tween)
            tween:Cancel(); tween:Destroy()
            if session and session.Pose then session.Pose.Enabled=true end
        end,
        FinishTween=function(tween) tween:Destroy() end,
        TweenState=function(tween)
            local name=tween.PlaybackState.Name
            if name=="Completed" then
                if session and session.Pose then session.Pose.Enabled=true end
            end
            return name
        end,
        BeginTouch=function(coin)
            endTouch()
            local began=false
            if type(firetouchinterest)=="function" then
                touch={Root=session.Root,Part=coin.Part}
                began=pcall(firetouchinterest,touch.Root,touch.Part,0)
            end
            if not began then
                -- CFrame changes alone do not guarantee native touch events.
                -- A short physical upward nudge supplements the actual overlap.
                session.ContactPulse=os.clock()+.15
                session.Hold.VectorVelocity=Vector3.new(0,.4,0)
            end
        end,EndTouch=endTouch})
end
farm=createFarm({Clock=os.clock,Character=function() return living() end,Blocked=blocked,
    ContactSeconds=config.ContactSeconds,RetrySeconds=config.RetrySeconds,
    MaxPickupRetries=config.MaxPickupRetries,RetryPickup=undergroundRoute and undergroundRoute.Retry,
    VoidY=workspace.FallenPartsDestroyHeight,Valid=valid,InMap=inMap,
    Safe=function(coin) return not opponentNear(coin.Part.Position) end,
    DangerNear=function() local _,_,root=living();return root and opponentNear(root.Position) or false end,
    Hide=undergroundRoute and undergroundRoute.Hide,
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
function farm.Stop(reason,keepReconnect)
    if reconnect and not keepReconnect then reconnect.Stop() end
    if buyer then buyer.Stop() end
    if graphics then graphics.Restore() end
    stop(reason)
    restore()
    RunService:UnbindFromRenderStep("MM2AutoFarmWalk")
    for _,connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
end
function farm.GetCrateSnapshot()
    local snapshot=buyer and buyer.Snapshot() or {Running=false,Status="Crate service unavailable"}
    snapshot.Discovery=shopState.Status
    snapshot.Event=shopState.Catalog and shopState.Catalog.Event
    snapshot.Currency=shopState.Catalog and shopState.Catalog.Currency
    return snapshot
end
function farm.GetMovementSnapshot()
    return undergroundRoute and undergroundRoute.Snapshot() or {Mode="Ground",Phase=session and "Walking" or "Idle"}
end
function farm.GetGraphicsSnapshot()
    return graphics and graphics.Snapshot() or {Enabled=false,Status="Normal graphics"}
end
function farm.RestoreGraphics()
    if graphics then return graphics.Restore() end
    return true
end
function farm.GetReconnectSnapshot()
    return reconnect and reconnect.Snapshot() or {ResumeSupported=false,Status="Not initialized"}
end
function farm.GetThreatSnapshot()
    return {Mode=workspace:GetAttribute("GameMode"),Avoid=config.AvoidOpponents,Radius=config.DangerRadius,Threats=#threatRoots}
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
    -- Native one-crate request, using only the verified active collectible currency.
    local ok,profile,baseCatalog,shop,eventSource=pcall(function()
        local data=require(RS.Modules.ProfileData)
        local sync=require(RS.Database.Sync)
        local remoteFolder=RS.Remotes:FindFirstChild("Shop")
        local remoteFunction=remoteFolder and remoteFolder:FindFirstChild("OpenCrate")
        assert(remoteFunction and remoteFunction:IsA("RemoteFunction"),"Shop unavailable")
        local eventRemote=RS.Remotes.Events:FindFirstChild("GetEvents")
        assert(eventRemote and eventRemote:IsA("RemoteFunction"),"Event discovery unavailable")
        return data,sync,remoteFunction,eventRemote
    end)
    if ok then
        local received={}
        local function refreshShop()
            if not farm.Running or shopState.Pending or os.clock()<shopState.NextRefresh then return end
            shopState.Pending=true;shopState.NextRefresh=os.clock()+60
            task.spawn(function()
                local success,events=pcall(eventSource.InvokeServer,eventSource)
                if not farm.Running then return end
                shopState.Pending=false
                if not success then shopState.Status="Event discovery failed; waiting to retry";return end
                local catalog,reason=discoverCrateCatalog(baseCatalog,events)
                if not catalog then shopState.Status=reason;return end
                shopState.Catalog=catalog;shopState.UpdatedAt=os.clock();shopState.Status="Current shop verified"
            end)
        end
        refreshShop()
        connect(RunService.Heartbeat,refreshShop)
        buyer=createCrateBuyer({Clock=os.clock,
            Balance=function(currency)
                local owned=profile.Materials and profile.Materials.Owned
                return owned and owned[currency]
            end,
            CanOpen=function()
                if not farm.Running or session or blocked() and not roundEnded then return false end
                for _,coin in ipairs(coins) do if inMap(coin) then return false end end
                return living()~=nil
            end,
            Offer=function()
                local catalog=shopState.Catalog
                if not catalog or os.clock()-(shopState.UpdatedAt or 0)>180 then
                    return nil,nil,"Waiting for current event shop data"
                end
                if config.SmartCrates then
                    return chooseCrateOffer(catalog,profile.Weapons and profile.Weapons.Owned,received,config.Crate,catalog.Currency)
                end
                local box=catalog.MysteryBox and catalog.MysteryBox[config.Crate]
                local offer=catalog.NewShop and catalog.NewShop[config.Crate]
                if box and (type(box.Godly)=="string" or type(box.GodlyTable)=="table" and #box.GodlyTable>0)
                    and offer and offer.Type=="MysteryBox" and offer.Price then
                    return config.Crate,offer.Price[catalog.Currency],nil,nil,false,catalog.Currency
                end
            end,
            Purchase=function(box,currency,done)
                local catalog=shopState.Catalog
                local offer=catalog and catalog.NewShop[box]
                if not catalog or catalog.Currency~=currency or not offer or not offer.Price
                    or offer.Price[currency]~=buyer.SelectedPrice then done(false);return end
                task.spawn(function()
                    if not farm.Running or not buyer.Running then done(false);return end
                    local success,reward=pcall(shop.InvokeServer,shop,box,"MysteryBox",currency)
                    local godly=false
                    if success and type(reward)=="string" and reward~="" then
                        local info=catalog.MysteryBox and catalog.MysteryBox[box] or {}
                        godly=reward==info.Godly or info.GodlyTable and table.find(info.GodlyTable,reward)~=nil
                            or info.ChromaTable and table.find(info.ChromaTable,reward)~=nil
                            or catalog.Item[reward] and (catalog.Item[reward].Rarity=="Godly" or catalog.Item[reward].Rarity=="Ancient")
                        done(true,reward,godly==true)
                    else done(false) end
                end)
                task.delay(60,function() done(false) end)
            end,
            StopOnGodly=config.StopOnGodly,
            OnGodly=function(reward)
                received[reward]=true
                if config.StopOnGodly then farm.Stop("Godly received; farming stopped") end
            end})
        if type(launch)=="table" and launch.PurchasesPaused then
            buyer.Stop();buyer.Status="Purchases paused after an unresolved result before reconnect"
        end
    else shopState.Status="Native shop unavailable"
    end
end

if config.AutoRejoin then
    local queue=queue_on_teleport or queueonteleport or type(syn)=="table" and syn.queue_on_teleport
    local ok,notification=pcall(function() return game:GetService("GuiService").ErrorMessageChanged end)
    local resumeToken=game:GetService("HttpService"):GenerateGUID(false)
    reconnect=createReconnect({Supported=type(queue)=="function" and ok and typeof(notification)=="RBXScriptSignal",
        Schedule=task.delay,
        Queue=function()
            local info=buyer and buyer.Snapshot()
            return queue(createResumeSource(config.Movement,info and (not info.Running or info.Pending),resumeToken,config.LowGraphics))
        end,
        Prepare=function() farm.Stop("Automatic reconnect in progress",true) end,
        Cleanup=function()
            for _,connection in ipairs(reconnectConnections) do connection:Disconnect() end
            table.clear(reconnectConnections)
        end,
        Rejoin=function()
            local service=game:GetService("TeleportService")
            service:Teleport(142823291,player)
        end})
    if ok and typeof(notification)=="RBXScriptSignal" then
        table.insert(reconnectConnections,notification:Connect(function(message) reconnect.Error(message) end))
    end
    table.insert(reconnectConnections,game:GetService("TeleportService").TeleportInitFailed:Connect(function(p,result,message)
        if p==player then reconnect.Failed(tostring(result).." "..tostring(message)) end
    end))
    -- Farm's ordinary input hook is disconnected while retrying, so retain an independent stop hook.
    table.insert(reconnectConnections,UIS.InputBegan:Connect(function(input,processed)
        if not processed and not UIS:GetFocusedTextBox() and input.KeyCode==Enum.KeyCode.End then farm.Stop("Stopped with End") end
    end))
    if config.RejoinBeforeIdle then
        local idlePending,idleQueued=false,false
        connect(player.Idled,function(seconds) if seconds>=900 then idlePending=true end end)
        connect(UIS.InputBegan,function()
            idlePending=false
            if idleQueued then reconnect.CancelPending();idleQueued=false end
        end)
        connect(RunService.Heartbeat,function()
            if not farm.Running or not idlePending or idleQueued or session then return end
            local info=buyer and buyer.Snapshot()
            if info and info.Pending then return end
            for _,coin in ipairs(coins) do if inMap(coin) then return end end
            -- Rejoin while still connected, preferably between rounds, before the engine's idle kick.
            idleQueued=reconnect.Error("Idle timeout prevention")
        end)
    end
end

-- Optional local rendering changes only. Movement, bags and buying keep their existing timing.
graphics=createLowGraphics({Enabled=config.LowGraphics and farm.Running,
    ReadRendering=function() return RunService:Is3dRenderingEnabled() end,
    WriteRendering=function(enabled) RunService:Set3dRenderingEnabled(enabled) end,
    GetFPS=type(getfpscap)=="function" and getfpscap or nil,
    SetFPS=type(setfpscap)=="function" and setfpscap or nil})
