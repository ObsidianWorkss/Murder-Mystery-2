local passed=0
local function check(value,message) assert(value,message);passed+=1 end
local vectorMeta={}
local function vector(x,y,z)
    return setmetatable({X=x,Y=y,Z=z,Magnitude=math.sqrt(x*x+y*y+z*z)},vectorMeta)
end
vectorMeta.__sub=function(a,b) return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vectorMeta.__add=function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
-- INSERT_FARM
local function fixture()
    local f={Now=0,Character={},Position=vector(0,10,0),Coins={},Moves={},Acquires=0,Releases=0,Cancels=0,Resets=0,InRound=true}
    f.C={Clock=function() return f.Now end,Character=function() return f.Character end,
        Blocked=function() return f.Blocked end,VoidY=-500,ContactSeconds=.6,RetrySeconds=15,ResetWhenFull=true,
        Coins=function() return f.Coins end,Position=function() return f.Position end,
        Valid=function(c) return not c.Invalid end,InMap=function(c) return not c.Outside end,
        Acquire=function() f.Acquires+=1 end,Release=function() f.Releases+=1 end,
        Move=function(c) table.insert(f.Moves,c);return f.Result or "Moving" end,
        CancelPath=function() f.Cancels+=1 end,CanReset=function() return f.InRound end,Reset=function() f.Resets+=1 end}
    f.Farm=createFarm(f.C)
    function f.Add(x,y,z,currency)
        local coin={Part={Position=vector(x,y,z)},Currency=currency};table.insert(f.Coins,coin);return coin
    end
    function f.Step(seconds) f.Now+=seconds or .1;f.Farm.Step(.1) end
    return f
end
do
    local f=fixture();f.Step()
    check(f.Farm.Running and #f.Moves==0 and f.Acquires==0,"empty round stays idle without acquiring control")
    local far=f.Add(50,10,0,"Candy");local near=f.Add(5,10,0,"Candy");f.Step()
    check(f.Moves[1]==near and f.Farm.Snapshot().Phase=="Walk","selects nearest eligible coin through the walking adapter")
    check(f.Farm.Attempts==0 and f.Farm.ServerEvents==0,"walking is not reported as pickup or server collection")
    f.Result="Arrived";f.Step()
    check(f.Farm.Attempts==1 and f.Farm.Snapshot().Phase=="Contact","physical arrival starts a bounded collection wait")
    f.Step(1)
    check(f.Cancels==1 and f.Farm.Snapshot().Phase==nil,"collection wait ends before a new route")
    f.Result="Moving";f.Step()
    check(f.Moves[#f.Moves]==far and f.Acquires==1,"unchanged pickup is temporarily skipped and the session is reused")
end
do
    local f=fixture();local c=f.Add(5,10,0,"Candy");f.Step();c.Invalid=true;f.Step()
    check(f.Releases==1 and f.Farm.Removed==1 and f.Cancels==1,"removed target cancels its route and releases control")
    f=fixture();c=f.Add(5,10,0,"Candy");c.Outside=true;f.Step()
    check(#f.Moves==0,"lobby or another map never starts walking toward round coins")
    c.Outside=false;f.Step();c.Outside=true;f.Step()
    check(f.Releases==1,"map departure releases the walking session")
    f=fixture();f.Add(5,10,0,"Candy");f.Step();f.Character={};f.Step()
    check(f.Releases==1 and f.Acquires==2,"replacement character cannot reuse the old session")
    f.Character=nil;f.Step()
    check(f.Releases==2,"death releases character control")
end
do
    local f=fixture();f.Add(5,10,0,"Candy");f.Farm.SetBag("Candy",true);f.Step()
    check(f.Acquires==0 and f.Resets==0,"full bag pauses movement and allows server bookkeeping before reset")
    f.Farm.SetBag("Candy",false);f.Farm.Collected("Candy",40,40);f.Step();f.Step(1.1)
    check(f.Resets==1 and f.Farm.Resets==1,"stale GUI cannot undo full state and reset is requested once")
    f.Step(20);f.Character={};f.Step(20)
    check(f.Resets==1,"repeated frames and respawn cannot reset again in the same round")
    f.Farm.NewRound();f.Step()
    check(f.Acquires==1,"new round clears old full-bag state")
    f.Farm.Collected("Candy",40,40);f.Step();f.Step(1.1)
    check(f.Farm.ServerEvents==2 and f.Resets==2,"a new round permits one reset after a new server full event")
    f=fixture();f.Farm.Collected("Candy",40,40);f.InRound=false;f.Step(5);f.Step(5)
    check(f.Resets==0,"full-bag reset is refused in the lobby")
    f=fixture();f.C.ResetWhenFull=false;f.Farm.Collected("Candy",40,40);f.Step();f.Step(5)
    check(f.Resets==0,"reset option can be disabled")
    f=fixture();f.Add(5,10,0,"Candy");local coin=f.Add(8,10,0,"Coin")
    f.Farm.SetBag("Candy",true);f.Farm.SetBag("Coin",false);f.Step()
    check(f.Moves[1]==coin and f.Resets==0,"partial capacity farms the other currency without resetting")
    f.Farm.Collected(nil,nil,nil)
    check(f.Farm.ServerEvents==1,"malformed optional bag fields do not fail the listener")
end
do
    local f=fixture();f.Add(5,10,0,"Candy");f.Blocked="Paused while invisible";f.Step()
    check(f.Acquires==0 and f.Farm.Status==f.Blocked,"conflicting movement prevents control acquisition")
    f.Blocked=nil;f.Step();f.Blocked="Frozen";f.Step()
    check(f.Releases==1,"freezing releases movement rather than overriding the game")
    f=fixture();f.Add(5,-490,0,"Candy");f.Step()
    check(f.Releases==1 and #f.Moves==0,"void coins are rejected without a movement request")
    f=fixture();f.Add(5,10,0,"Candy");f.Step();f.Step(40)
    check(f.Releases==1 and f.Farm.Snapshot().Phase==nil,"stuck walking times out instead of looping forever")
    f.Step(16)
    check(f.Acquires==2,"timed-out target becomes eligible after a retry delay")
    f=fixture();local bad=f.Add(5,10,0,"Candy");local good=f.Add(8,10,0,"Candy")
    f.Result="Blocked";f.Step();f.Result="Moving";f.Step()
    check(f.Cancels==1 and f.Moves[#f.Moves]==good,"unreachable coin is skipped instead of flying through its obstacle")
end
do
    local f=fixture();f.Add(5,10,0,"Candy");f.Step();f.Farm.Stop("End")
    check(not f.Farm.Running and f.Releases==1 and f.Farm.Status=="End","stop cancels walking and retains its reason")
    local moves=#f.Moves;f.Step(30);f.Farm.Stop()
    check(#f.Moves==moves and f.Releases==1,"stopped farm cannot resume or release twice")
    f=fixture();f.Add(5,10,0,"Candy");f.Step();f.Farm.NewRound()
    check(f.Releases==1 and f.Farm.Running and f.Farm.Snapshot().Phase==nil,"new round cancels old route and stays armed")
    local snapshot=f.Farm.Snapshot();snapshot.Attempts=99
    check(f.Farm.Attempts==0,"diagnostic snapshots cannot change controller state")
end
local function tweenFixture()
    local f={Position=vector(0,10,0),Starts={},Cancelled=0,Begins=0,Ends=0}
    f.C={Depth=4,Speed=16,VoidY=-500,Vector=vector,
        Position=function() return f.Position end,
        Pickup=function(c) return vector(c.Part.Position.X,c.Part.Position.Y-.8,c.Part.Position.Z) end,
        StartTween=function(point,speed)
            local t={Position=point,State="Playing",Speed=speed};table.insert(f.Starts,t);return t
        end,
        CancelTween=function(t) f.Cancelled+=1;t.State="Cancelled" end,TweenState=function(t) return t.State end,
        BeginTouch=function() f.Begins+=1 end,EndTouch=function() f.Ends+=1 end}
    f.Route=createUndergroundRoute(f.C)
    function f.Coin(x,y,z) return {Part={Position=vector(x,y,z)}} end
    function f.Complete()
        local t=f.Starts[#f.Starts];t.State="Completed";f.Position=t.Position
    end
    return f
end
do
    local f=tweenFixture();local coin=f.Coin(20,10,0)
    check(f.Route.Step(coin)=="Moving" and f.Starts[1].Position.Y==6 and f.Starts[1].Position.X==0,"underground route sinks at the current horizontal position before crossing the map")
    f.Route.Step(coin)
    check(#f.Starts==1 and f.Route.Snapshot().Tweening,"in-progress tween is reused instead of restarted on every tick")
    f.Complete();f.Route.Step(coin)
    check(f.Starts[2].Position.X==20 and f.Starts[2].Position.Y==6 and f.Starts[2].Speed==16,"slide tween stays below the pickup plane at its configured speed")
    f.Complete();f.Route.Step(coin)
    check(f.Starts[3].Position.Y==9.2 and f.Begins==0,"last tween approaches the contact point from below before beginning a touch")
    f.Complete()
    check(f.Route.Step(coin)=="Arrived" and f.Begins==1,"completed pickup tween begins a single contact attempt")
    f.Route.Step(coin)
    check(f.Begins==1,"holding the same pickup does not spam touch starts")
    f.Route.Cancel()
    check(f.Route.Snapshot().Phase=="Idle" and not f.Route.Snapshot().Tweening and f.Ends>=1,"cancel ends contact and clears all routing state")
    f.Route.Step(f.Coin(30,10,0))
    check(f.Starts[#f.Starts].Position.Y==6,"successive pickups reuse a fixed floor offset instead of sinking cumulatively")
end
do
    local f=tweenFixture();local a=f.Coin(20,10,0);f.Route.Step(a)
    local b=f.Coin(40,12,0);f.Route.Step(b)
    check(f.Cancelled==1 and #f.Starts==2 and f.Starts[2].Position.Y==8,"target replacement cancels the old tween before starting a new route")
    f.Route.Cancel();f.Route.Cancel()
    check(f.Cancelled==2,"repeated cancel does not cancel an already-cleared tween twice")
    f=tweenFixture();local coin=f.Coin(20,10,0);f.Route.Step(coin);f.Starts[1].State="Cancelled"
    check(f.Route.Step(coin)=="Blocked" and f.Route.Snapshot().Phase=="Idle","externally cancelled tween is reported as blocked rather than resumed")
    f=tweenFixture()
    check(f.Route.Step(f.Coin(0,-480,0))=="Blocked" and #f.Starts==0,"underground offset is checked against the void before creating a tween")
    f=tweenFixture();f.Position=vector(0,6,0);coin=f.Coin(20,10,0);f.Route.Step(coin);f.Route.Step(coin)
    check(#f.Starts==1 and f.Starts[1].Position.X==20,"already-submerged character skips an unnecessary sink tween")
    f=fixture();f.C.MovementName="Underground";f.Add(5,10,0,"Candy");f.Step()
    check(f.Farm.Snapshot().Phase=="Tween" and f.Farm.Snapshot().Movement=="Underground","shared controller reports underground movement without invoking ground-specific phases")
end
do
    local f=tweenFixture();local coin=f.Coin(20,10,0);f.Route.Step(coin)
    f.Starts[1].State="Completed" -- A server correction can leave the live position elsewhere.
    check(f.Route.Step(coin)=="Blocked" and #f.Starts==1 and f.Begins==0,"a completed playback with no actual arrival cannot advance or report contact")
    f=tweenFixture();coin=f.Coin(20,10,0);f.Route.Step(coin)
    f.Complete();f.Route.Step(coin);f.Complete();f.Route.Step(coin);f.Complete();f.Route.Step(coin)
    f.Position=vector(60,10,0)
    check(f.Route.Step(coin)=="Blocked" and f.Begins==1,"displacement during contact cancels the old target instead of maintaining a remote touch")
end
do
    local position=vector(50,-4,30)
    check(chooseRecoveryPoint(position,nil,3,16,vector)==position,"missing floor preserves current position instead of teleporting back to the origin")
    check(chooseRecoveryPoint(position,vector(0,0,0),3,16,vector)==position,"distant recovery point cannot relocate the character across the map")
    local nextPosition=chooseRecoveryPoint(position,vector(50,0,30),3,16,vector)
    check(nextPosition.X==50 and nextPosition.Y==3 and nextPosition.Z==30,"nearby recovery remains directly above the character on the detected floor")
end
local function shopFixture(start)
    local f={Balance=start,Now=0,Price=1000,CanOpen=true,Requests=0,Godlies=0}
    f.C={Clock=function() return f.Now end,Balance=function() return f.Balance end,
        CanOpen=function() return f.CanOpen end,Offer=function() return "MysteryBox2",f.Price,nil,1,false,f.Currency or "Coins" end,
        Purchase=function(box,currency,done) f.Requests+=1;f.Box=box;f.PurchasedCurrency=currency;f.Done=done end,
        OnGodly=function() f.Godlies+=1 end}
    f.Buyer=createCrateBuyer(f.C)
    return f
end
do
    local f=shopFixture(500);f.Buyer.Step()
    check(f.Requests==0,"balance below a crate price waits")
    f.Balance=999;f.Buyer.Step()
    check(f.Requests==0,"partial crate balance does not purchase")
    f.Balance=1000;f.Buyer.Step()
    check(f.Requests==1 and f.Box=="MysteryBox2","available balance permits exactly one selected crate")
    f.Now=100;f.Buyer.Step()
    check(f.Requests==1,"pending unbox is single-flight even after a long delay")
    f.Done(true,"CommonKnife",false);f.Buyer.Step()
    check(f.Buyer.Opened==1 and f.Buyer.Spent==1000,"only a successful native result increments opened and spent counts")
    f.Now=120;f.Buyer.Step()
    check(f.Requests==1,"stale balance after success cannot purchase a second crate before the debit appears")
    f.Balance=0;f.Buyer.Step()
    check(f.Requests==1,"observed debit does not buy an unaffordable second crate")
    f.Balance=1000;f.Buyer.Step()
    check(f.Requests==2,"additional balance allows another ordinary roll")
    f.Done(true,"Lightbringer",true)
    check(f.Godlies==1 and not f.Buyer.Running,"verified godly result stops further rolls")
end
do
    local f=shopFixture(0);f.Balance=1000;f.CanOpen=false;f.Buyer.Step()
    check(f.Requests==0,"purchases wait while the native round or movement is active")
    f.CanOpen=true;f.Price=nil;f.Buyer.Step()
    check(f.Requests==0,"missing verified price never falls back to keys or another currency")
    f.Price=0;f.Buyer.Step()
    check(f.Requests==0,"invalid zero price is refused")
    f.Price=1000;f.Buyer.Step();f.Done(false);f.Now=100;f.Buyer.Step()
    check(not f.Buyer.Running and f.Requests==1 and f.Buyer.Spent==0,"ambiguous or rejected purchase stops instead of retrying a possible charge")
    f=shopFixture(nil);f.Buyer.Step()
    check(f.Buyer.Running and f.Requests==0,"missing initial balance waits for profile replication")
    f.Balance=1000;f.Buyer.Step()
    check(f.Requests==1,"late balance replication can resume purchasing")
    f=shopFixture(0);f.Balance=1000;f.Buyer.Stop();f.Buyer.Step()
    check(f.Requests==0,"stopped buyer cannot dispatch")
end
do
    local f=tweenFixture();f.C.Speed=48;f.C.ApproachSpeed=12
    local coin=f.Coin(30,10,0);f.Route.Step(coin)
    check(f.Starts[1].Speed==12,"fast mode keeps sink speed separate from travel speed")
    f.Complete();f.Route.Step(coin)
    check(f.Starts[2].Speed==48,"fast mode uses the configured faster speed on the underground travel leg")
    f.Complete();f.Route.Step(coin)
    check(f.Starts[3].Speed==12,"fast mode slows down for pickup instead of overshooting the contact stage")
end
do
    local catalog={MysteryBox={A={Godly="Alpha"},B={GodlyTable={"Beta","Gamma"},ChromaTable={"ChromaBeta"}},Retired={Godly="Old"}},
        NewShop={A={Type="MysteryBox",Price={Coins=1000}},B={Type="MysteryBox",Price={Coins=1000}}}}
    local box,price,_,missing=chooseCrateOffer(catalog,{}, {},"A")
    check(box=="B" and price==1000 and missing==2,"equal-price smart selection prefers more listed unowned targets without assuming their odds")
    box=chooseCrateOffer(catalog,{Beta=1,Gamma=1},{},"B")
    check(box=="A","owned godlies redirect the next crate choice to another listed target")
    box=chooseCrateOffer(catalog,{Alpha=1,Beta=1},{Gamma=true},"A")
    check(box=="B","received overlay accounts for inventory replication delay before choosing remaining chromas")
    local again,_,reason,remaining=chooseCrateOffer(catalog,{Alpha=1,Beta=1,Gamma=1,ChromaBeta=1},{},"A")
    check(again=="A" and reason==nil and remaining==0,"fully owned catalog continues rolling without a collection limit")
    catalog.NewShop.A.Price.Coins=500
    box,price=chooseCrateOffer(catalog,{}, {},"B")
    check(box=="A" and price==500,"lower coin price takes priority over a more expensive crate's target count")
    catalog.NewShop.A.Price={Gems=100};catalog.NewShop.B.Price={Key=1}
    box=chooseCrateOffer(catalog,{}, {},"A")
    check(box==nil,"smart selection never falls back to Gems or keys and safely ignores a missing shop record")
    box=chooseCrateOffer(catalog,nil,{},"A")
    check(box==nil,"unavailable inventory disables smart selection instead of guessing ownership")
    catalog.NewShop.A.Price={Coins=1000};catalog.NewShop.B.Price={Coins=1000};catalog.MysteryBox.B.GodlyTable={"Beta"}
    box=chooseCrateOffer(catalog,{}, {},"A")
    check(box=="A","preferred crate breaks an otherwise equal tie deterministically")
    local f=shopFixture(0);f.C.StopOnGodly=false;f.Balance=1000;f.Buyer.Step();f.Done(true,"Alpha",true)
    check(f.Buyer.Running and f.Godlies==1 and f.Buyer.Snapshot().Godlies==1,"collection mode records a godly without stopping the buyer")
    f.Balance=0;f.Now=11;f.Buyer.Step();f.Balance=1000;f.Buyer.Step()
    check(f.Requests==2,"collection mode still waits for debit and new earnings before another roll")
end
do
    local f=fixture();f.C.Safe=function(c) return not c.Dangerous end
    local near=f.Add(2,10,0,"Candy");near.Dangerous=true;local safe=f.Add(12,10,0,"Candy");f.Step()
    check(f.Moves[1]==safe,"armed-player avoidance rejects a dangerous nearest coin in favor of a safe one")
    near.Dangerous=false;safe.Dangerous=true;f.Step()
    check(f.Moves[#f.Moves]==near and f.Farm.DangerSkips==1,"a newly threatened pickup is abandoned and contact is cancelled")
    f=fixture();f.C.MovementName="Underground";f.C.Safe=function(c) return not c.Dangerous end
    local c=f.Add(2,10,0,"Candy");f.Step();c.Dangerous=true;f.Step()
    check(f.Releases==0 and f.Farm.Status:find("Holding underground",1,true),"no safe target holds an existing underground session instead of surfacing beside armed players")
    c.Dangerous=false;f.Step()
    check(f.Acquires==1 and f.Farm.Snapshot().Phase=="Tween","safe target return resumes without acquiring a competing movement session")
    f.Farm.Stop()
    check(f.Releases==1,"stop still releases a danger-paused underground session")
end
do
    check(isRoleThreat("Classic","Murderer","Sheriff",false) and isRoleThreat("Classic","Murderer","Hero",false),"murderer avoids the sheriff and hero roles")
    check(isRoleThreat("Classic","Sheriff","Murderer",false) and isRoleThreat("Classic","Innocent","Murderer",false),"sheriff and innocent avoid the murderer")
    check(not isRoleThreat("Classic","Murderer","Innocent",false) and not isRoleThreat("Classic","Sheriff","Innocent",false),"known harmless classic roles are not treated as role opponents")
    check(isRoleThreat("Infection","Zombie","Survivor",false) and isRoleThreat("Infection","Survivor","Zombie",false),"infection threat policy follows both sides of conversion")
    check(not isRoleThreat("Infection","Zombie","Zombie",true),"known infection teammates do not trigger opponent hiding")
    check(isRoleThreat("FreezeTag","Runner","Freezer",false) and not isRoleThreat("FreezeTag","Freezer","Runner",false),"freeze-tag threat policy follows actual attack-capable roles")
    check(isRoleThreat("Unknown","Unknown","Unknown",true) and not isRoleThreat("Unknown","Unknown","Unknown",false),"unsupported mode falls back conservatively to visible weapons")
    local f=tweenFixture();local c=f.Coin(20,10,0);f.Route.Step(c);f.Complete();f.Route.Step(c);f.Complete();f.Route.Step(c);f.Complete();f.Route.Step(c)
    f.Route.Hide()
    check(f.Route.Snapshot().Phase=="Hide" and f.Starts[#f.Starts].Position.Y==6,"hiding descends to the saved travel plane rather than surfacing")
    f.Complete();check(f.Route.Hide()=="Hidden" and f.Begins==1,"completed hiding creates no pickup contact")
    local count=#f.Starts;f.Route.Hide()
    check(#f.Starts==count,"repeated hiding does not create a new tween or sink cumulatively")
    f.Route.Step(c)
    check(f.Route.Snapshot().Phase~="Hide","a safe target resumes the ordinary underground route after hiding")
    f=fixture();f.C.MovementName="Underground";f.C.DangerNear=function() return f.Threat end;f.C.Hide=function() f.Hidden=true end
    f.Add(5,10,0,"Candy");f.Step();f.Threat=true;f.Step()
    check(f.Hidden and f.Releases==0 and f.Farm.DangerSkips==1,"nearby role opponent cancels a pickup and hides without releasing character control")
end
do
    local f=fixture();local c=f.Add(2,10,0,"Candy");f.Result="Arrived";f.C.MaxPickupRetries=2
    f.C.RetryPickup=function(_,variant) f.Variant=variant;return true end
    f.Step();f.Step(1)
    check(f.Farm.Retries==1 and f.Variant==2 and f.Farm.Snapshot().Phase=="Walk","unacknowledged contact schedules a second bounded contact position")
    f.Step();f.Step(1);f.Step();f.Step(1)
    check(f.Farm.Retries==2 and f.Farm.Unconfirmed==1 and f.Farm.PickupEvents==0,"three failed contacts remain unconfirmed instead of counted as collections")
    f=fixture();c=f.Add(2,10,0,"Candy");f.Result="Arrived";f.Farm.SetBag("Candy",false,5);f.Step();f.Farm.Collected("Candy",6,40);f.Step()
    check(f.Farm.PickupEvents==1 and f.Farm.Retries==0 and f.Farm.Snapshot().Phase==nil,"matching nearby bag increase ends contact without needless retry")
    f=fixture();f.Add(2,10,0,"Candy");f.Result="Arrived";f.Step();f.Farm.Collected("Coin",1,40)
    check(f.Farm.PickupEvents==0,"unrelated currency event cannot acknowledge the current pickup")
    f.Farm.SetBag("Candy",false,5);f.Farm.Collected("Candy",5,40)
    check(f.Farm.PickupEvents==0,"unchanged server bag amount is not treated as a new collection")
    f.Position=vector(100,10,0);f.Farm.Collected("Candy",6,40)
    check(f.Farm.PickupEvents==0,"distant bag update is not attributed to the selected coin")
    local t=tweenFixture();local coin=t.Coin(10,10,0)
    t.C.Pickup=function(x,variant) return vector(x.Part.Position.X,(variant or 1)==3 and 10.1 or 9.9,x.Part.Position.Z) end
    check(t.Route.Retry(coin,3),"alternate contact can prepare a bounded new approach")
    t.Route.Step(coin);t.Complete();t.Route.Step(coin);t.Complete();t.Route.Step(coin)
    check(t.Starts[#t.Starts].Position.Y==10.1,"retry uses the selected alternate pickup geometry")
end
local function reconnectFixture(supported)
    local f={Queued=0,Rejoins=0,Prepared=0,Cleaned=0,Now=0,Jobs={},MaxJobs=0}
    f.State=createReconnect({Supported=supported,Schedule=function(delay,callback)
            table.insert(f.Jobs,{At=f.Now+delay,Callback=callback});f.MaxJobs=math.max(f.MaxJobs,#f.Jobs)
        end,
        Queue=function() f.Queued+=1;if f.FailQueue then error("queue failed") end end,
        Prepare=function() f.Prepared+=1;if f.FailPrepare then error("cleanup failed") end end,
        Cleanup=function() f.Cleaned+=1 end,
        Rejoin=function() f.Rejoins+=1;if f.FailTeleport then error("connection lost") end end})
    function f.Advance(seconds)
        local target=f.Now+seconds
        while true do
            table.sort(f.Jobs,function(a,b) return a.At<b.At end)
            if not f.Jobs[1] or f.Jobs[1].At>target then break end
            local job=table.remove(f.Jobs,1);f.Now=job.At;job.Callback()
        end
        f.Now=target
    end
    return f
end
do
    local f=reconnectFixture(true)
    check(f.State.Error("Disconnected: connection lost") and not f.State.Error("Disconnected again"),"duplicate disconnect notifications schedule only one attempt")
    f.Advance(5)
    check(f.Queued==1 and f.Prepared==1 and f.Rejoins==1 and f.State.Attempts==1,"resume code is queued before the first rejoin request")
    check(not f.State.Error("Invalid position: kicked") and f.State.InFlight,"in-flight teleport cannot be duplicated by another notification")
    f.State.Failed("Network error");f.Advance(10)
    check(f.Rejoins==2 and f.Queued==1 and f.Prepared==1,"failed teleport retries without accumulating queued scripts or cleanup calls")
    f.Advance(20)
    check(f.Rejoins==2 and f.State.InFlight,"stale watchdog from an earlier attempt cannot cancel a later request")
    f.Advance(10)
    check(f.State.Pending and f.State.Snapshot().RetryIn==20,"missing teleport completion schedules another attempt with increasing delay")
    f=reconnectFixture(true);f.State.Error("Disconnected");f.State.Stop();f.Advance(1000)
    check(f.Rejoins==0 and f.Queued==0 and f.Cleaned==1,"manual stop cancels a pending reconnect before queueing and cleans hooks")
    f.State.Stop()
    check(f.Cleaned==1 and not f.State.Snapshot().Running,"repeated stop cannot clean hooks twice")
    f=reconnectFixture(false)
    check(not f.State.Error("Disconnected") and not f.State.Snapshot().ResumeSupported,"missing executor capabilities never claim automatic resume")
    f=reconnectFixture(true)
    check(not f.State.Error("Unrelated shop error") and f.State.Running,"unrelated errors do not schedule reconnects")
    check(not f.State.Error("You are banned or restricted") and not f.State.Running,"access refusal stops automatic retries")
    f=reconnectFixture(true);f.FailQueue=true;f.State.Error("Disconnected");f.Advance(5)
    check(f.Rejoins==0 and f.Prepared==0 and f.State.Pending,"failed resume queue prevents a blind teleport and schedules a later queue retry")
    f.FailQueue=false;f.Advance(10)
    check(f.Rejoins==1 and f.Queued==2,"queue recovery can proceed without an attempt limit")
    f=reconnectFixture(true);f.State.Error("Disconnected");f.Advance(5);f.State.Failed("Access denied")
    f.Advance(1000)
    check(f.Rejoins==1 and not f.State.Running,"access refusal in a teleport failure cancels watchdogs and retries")
    f=reconnectFixture(true);f.FailTeleport=true;f.State.Error("Connection lost");f.Advance(24*60*60)
    check(f.State.Attempts>700 and f.State.Pending and f.State.Running and f.State.Snapshot().Unlimited,"a simulated full day of failures never exhausts a reconnect budget")
    check(f.Queued==1 and f.Prepared==1 and f.MaxJobs<=2 and f.State.Snapshot().RetryIn==120,"long retry chains keep fixed resource use and a two-minute maximum delay")
    f.State.Stop();local attempts=f.State.Attempts;f.Advance(86400)
    check(f.State.Attempts==attempts,"stopped day-long retry chain never restarts")
    f=reconnectFixture(true);f.State.Error("Idle timeout prevention")
    check(f.State.CancelPending() and not f.State.Pending,"returning input can cancel an idle-prevention rejoin")
    f.Advance(100)
    check(f.Rejoins==0 and f.State.Error("Disconnected"),"cancelled idle timer is stale while later real disconnects still work")
    f=reconnectFixture(true);f.FailPrepare=true;f.State.Error("Disconnected");f.Advance(1000)
    check(f.Rejoins==0 and not f.State.Running,"failed movement cleanup prevents a teleport with competing controllers")
end

do
    local base={MysteryBox={Regular={Godly="R"},Old={Godly="Old"}},Item={},
        NewShop={Regular={Type="MysteryBox",Price={Coins=1000}},Old={Type="MysteryBox",Price={Candies2025=800}}}}
    local events={Halloween2026={Status="Started",Priority="Main",EventStartInfo={CurrencyName="Candies2026",KeyName="HalloweenKey2026",
        Items={MysteryBox={Halloween2026Box={Godly="Embersickle"}},Item={Embersickle={Rarity="Godly"}}},
        ShopData={Halloween2026Box={Type="MysteryBox",Price={Candies2026=600,HalloweenKey2026=1}}}}}}
    local c=discoverCrateCatalog(base,events)
    local box,price,_,missing,_,currency=chooseCrateOffer(c,{}, {},"Regular")
    check(c.Event=="Halloween2026" and currency=="Candies2026" and box=="Halloween2026Box" and price==600 and missing==1,"current replicated event shop supplies the Candy ID, crate and price")
    check(c.NewShop.Regular==nil and c.NewShop.Old==nil and base.NewShop.Halloween2026Box==nil,"event discovery isolates its offers without mutating the game catalog or falling back to Coins/old Candy")
    check(c.Item.Embersickle.Rarity=="Godly","event reward metadata is available for godly recognition")
    box=chooseCrateOffer(c,{Embersickle=1},{},"Regular")
    check(box=="Halloween2026Box","owned event godly does not cap further Candy rolls")
    events.Halloween2026.EventStartInfo.ShopData.Halloween2026Box.Price.Candies2026=nil
    c=discoverCrateCatalog(base,events);box=chooseCrateOffer(c,{}, {},"Regular")
    check(box==nil,"a key-only event crate never falls back to a key or a regular Coin crate")
    events.Halloween2026.Status="Ended";c=discoverCrateCatalog(base,events)
    box,price,_,_,_,currency=chooseCrateOffer(c,{}, {},"Regular")
    check(c.Currency=="Coins" and box=="Regular" and currency=="Coins","ended event returns to verified regular collectible-currency offers")
    check(discoverCrateCatalog(base,nil)==nil,"failed event discovery cannot guess a currency")
    events.Halloween2026.Status="Started";events.Halloween2026.EventStartInfo.CurrencyName="Gems"
    check(discoverCrateCatalog(base,events)==nil,"premium main-event currency never enables a Coin or premium fallback")
    for _,id in ipairs({"Gems","Robux","HalloweenKey2026","Key","","Bad\nCurrency"}) do
        check(not collectibleCurrency(id),"disallowed currency refused: "..id)
    end
    check(collectibleCurrency("Candies2027") and collectibleCurrency("BeachBalls2027"),"future event collectible IDs are discovered rather than hardcoded")
    local f=shopFixture(1800);f.Currency="Candies2026";f.Price=600;f.C.StopOnGodly=false;f.Buyer.Step()
    check(f.Requests==1 and f.PurchasedCurrency=="Candies2026","existing Candy balance is usable immediately with no reserved starting balance")
    f.Done(true,"Embersickle",true);f.Done(true,"Embersickle",true)
    check(f.Buyer.Opened==1 and f.Godlies==1,"duplicate or late completion callbacks cannot count or apply a purchase twice")
    f.Balance=1200;f.Now=11;f.Buyer.Step();f.Done(true,"Common",false)
    f.Balance=600;f.Now=22;f.Buyer.Step();f.Done(true,"Common",false)
    f.Balance=0;f.Now=33;f.Buyer.Step()
    local snap=f.Buyer.Snapshot()
    check(f.Requests==3 and snap.SpentByCurrency.Candies2026==1800 and snap.SelectedCurrency=="Candies2026","successive rolls exhaust the available Candy without overspending or stopping after a godly")
    snap.SpentByCurrency.Candies2026=99
    check(f.Buyer.Snapshot().SpentByCurrency.Candies2026==1800,"snapshot currency totals cannot mutate the buyer")
    f=shopFixture(1000);f.Buyer.Step();f.Done(true,"Common",false);f.Now=11
    f.Currency="Candies2026";f.Price=600;f.Balance=600;f.Buyer.Step()
    check(f.Requests==1,"changing event currency still waits for the previous currency's debit")
    f.Balance=0;f.Buyer.Step();f.Balance=600;f.Buyer.Step()
    check(f.Requests==2 and f.PurchasedCurrency=="Candies2026","verified old debit allows a subsequent new-currency purchase")
    f=shopFixture(1000);f.Currency="Robux";f.Buyer.Step()
    check(f.Requests==0,"buyer refuses a premium currency even if its offer adapter mislabels it")
    f=shopFixture(600);f.Price=600;f.Currency="Candies2026";f.C.StopOnGodly=false
    for i=1,10000 do
        f.Balance=600;f.Now=i*11;f.Buyer.Step();f.Done(true,i%100==0 and "Embersickle" or "Common",i%100==0)
        f.Balance=0;f.Now+=10;f.Buyer.Step()
    end
    check(f.Requests==10000 and f.Buyer.Running and f.Godlies==100,"over thirty simulated hours of Candy rolls have no time, count, spending or godly cap")
    check(f.Buyer.Snapshot().SpentByCurrency.Candies2026==6000000,"long-run spending matches the exact authorized currency total")
end

do
    local source=createResumeSource("Underground",true,"token-1")
    check(type(loadstring(source))=="function","generated reconnect bootstrap compiles")
    local context={};setmetatable(context,{__index=getfenv()})
    local env,waits,fetches,disconnected={},0,0,0
    context.getgenv=function() return env end
    context.Enum={KeyCode={End="End"}}
    local input={InputBegan={Connect=function() return {Disconnect=function() disconnected+=1 end} end}}
    context.game={PlaceId=142823291,IsLoaded=function() return true end,GetService=function() return input end,HttpGet=function()
        fetches+=1
        if fetches==1 then error("network unavailable") end
        if fetches==2 then return "-- stale version" end
        return '-- MM2FarmRevision:20261019.4\ngetgenv().Loaded=getgenv().MM2AutoFarmLaunch'
    end}
    context.task={wait=function() waits+=1 end}
    context.loadstring=function(code) local chunk=loadstring(code);if chunk then setfenv(chunk,context) end;return chunk end
    local chunk=loadstring(source);setfenv(chunk,context);chunk()
    check(fetches==3 and waits==2 and env.Loaded.Movement=="Underground" and env.Loaded.PurchasesPaused,"bootstrap retries unavailable/stale downloads and preserves movement and paused purchases")
    check(disconnected==1 and env.MM2AutoFarmLaunch==nil,"bootstrap removes its input hook and one-use launch state")
    chunk()
    check(fetches==3,"duplicate executor-queued bootstraps with the same token do not run twice")
    env={};fetches=0
    context.game.HttpGet=function() fetches+=1;error("offline") end
    context.task.wait=function() env.MM2AutoFarm.Stop() end
    chunk=loadstring(createResumeSource("Ground",false,"token-2"));setfenv(chunk,context);chunk()
    check(fetches==1 and not env.MM2AutoFarm.Running,"public Stop cancels an offline bootstrap download loop")
end
print(passed.." auto-farm assertions passed")
