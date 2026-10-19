local passed=0
local function check(value,message) assert(value,message);passed+=1 end
local vectorMeta={}
local function vector(x,y,z)
    return setmetatable({X=x,Y=y,Z=z,Magnitude=math.sqrt(x*x+y*y+z*z)},vectorMeta)
end
vectorMeta.__sub=function(a,b) return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
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
local function shopFixture(start)
    local f={Balance=start,Now=0,Price=1000,CanOpen=true,Requests=0,Godlies=0}
    f.Buyer=createCrateBuyer({Clock=function() return f.Now end,Balance=function() return f.Balance end,
        CanOpen=function() return f.CanOpen end,Offer=function() return "MysteryBox2",f.Price end,
        Purchase=function(box,done) f.Requests+=1;f.Box=box;f.Done=done end,
        OnGodly=function() f.Godlies+=1 end})
    return f
end
do
    local f=shopFixture(500);f.Buyer.Step()
    check(f.Requests==0,"starting balance is reserved instead of spent on crates")
    f.Balance=1499;f.Buyer.Step()
    check(f.Requests==0,"new earnings below a complete crate price do not purchase")
    f.Balance=1500;f.Buyer.Step()
    check(f.Requests==1 and f.Box=="MysteryBox2","sufficient new coin balance permits exactly one selected crate")
    f.Now=100;f.Buyer.Step()
    check(f.Requests==1,"pending unbox is single-flight even after a long delay")
    f.Done(true,"CommonKnife",false);f.Buyer.Step()
    check(f.Buyer.Opened==1 and f.Buyer.Spent==1000,"only a successful native result increments opened and spent counts")
    f.Now=120;f.Buyer.Step()
    check(f.Requests==1,"stale balance after success cannot purchase a second crate before the debit appears")
    f.Balance=500;f.Buyer.Step()
    check(f.Requests==1,"observed debit still preserves the original balance")
    f.Balance=1500;f.Buyer.Step()
    check(f.Requests==2,"additional session earnings allow another ordinary roll")
    f.Done(true,"Lightbringer",true)
    check(f.Godlies==1 and not f.Buyer.Running,"verified godly result stops further rolls")
end
do
    local f=shopFixture(0);f.Balance=1000;f.CanOpen=false;f.Buyer.Step()
    check(f.Requests==0,"purchases wait while the native round or movement is active")
    f.CanOpen=true;f.Price=nil;f.Buyer.Step()
    check(f.Requests==0,"missing verified Coins price never falls back to keys or another currency")
    f.Price=0;f.Buyer.Step()
    check(f.Requests==0,"invalid zero price is refused")
    f.Price=1000;f.Buyer.Step();f.Done(false);f.Now=100;f.Buyer.Step()
    check(not f.Buyer.Running and f.Requests==1 and f.Buyer.Spent==0,"ambiguous or rejected purchase stops instead of retrying a possible charge")
    f=shopFixture(nil);f.Buyer.Step()
    check(not f.Buyer.Running and f.Requests==0,"missing initial balance disables purchasing")
    f=shopFixture(0);f.Balance=1000;f.Buyer.Stop();f.Buyer.Step()
    check(f.Requests==0,"stopped buyer cannot dispatch")
end
print(passed.." auto-farm assertions passed")
