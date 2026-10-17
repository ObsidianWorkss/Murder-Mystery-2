local passed=0
local function check(ok,message) assert(ok,message); passed+=1; print("PASS: "..message) end
-- INSERT_EQUIP
local function signal()
    local s={Connections={}}
    function s:Connect(fn)
        local c={Callback=fn}
        function c:Disconnect() self.Disconnected=true end
        table.insert(self.Connections,c); return c
    end
    function s:Fire(...)
        for _,c in ipairs(self.Connections) do if not c.Disconnected then c.Callback(...) end end
    end
    return s
end
local function fixture()
    local f={Now=10,Jobs={},Equips=0,NativeAllowed=true,HasHandle=true,PC=true}
    f.Input,f.Heartbeat,f.ParentChanged,f.Lost,f.Gained=signal(),signal(),signal(),signal(),signal()
    f.Action={Pressed=signal()}; f.Char={}; f.Bag={}; f.Hum={Health=100}
    f.Tool={Name="Knife",Parent=f.Bag,RequiresHandle=true}
    function f.Tool:GetPropertyChangedSignal() return f.ParentChanged end
    function f.Tool:FindFirstChild() return f.HasHandle and {} or nil end
    function f.Move(parent) f.Tool.Parent=parent; f.ParentChanged:Fire() end
    local State={Running=true,Config={WeaponEquipRecovery=true}}
    local C={State=State,Clock=function() return f.Now end,One="One",Keyboard="Keyboard",
        Input=f.Input,Heartbeat=f.Heartbeat,FocusLost=f.Lost,FocusGained=f.Gained,
        IsPC=function() return f.PC end,Blocked=function() return f.Blocked==true end,
        Connect=function(s,fn) return s:Connect(fn) end,Watch=function(s,fn) return s:Connect(fn) end,
        Schedule=function(delay,fn) table.insert(f.Jobs,{At=f.Now+delay,Run=fn}) end,
        Read=function() return {Tool=not f.Missing and not f.Ambiguous and f.Tool or nil,Ambiguous=f.Ambiguous,
            Character=f.Char,Backpack=f.Bag,Humanoid=f.Hum,Action=f.Action,NativeAllowed=f.NativeAllowed} end,
        Equip=function(hum,item)
            if f.EquipError then error("private test error") end
            f.Equips+=1; f.Move(f.Char)
        end}
    installWeaponEquipRecovery(C)
    f.State,f.Report=State,State.WeaponEquipRecovery
    function f.Press(processed,key) f.Input:Fire({KeyCode=key or "One",UserInputType="Keyboard"},processed) end
    function f.Advance(dt)
        f.Now+=dt or .13; f.Heartbeat:Fire()
        local jobs=f.Jobs; f.Jobs={}
        for _,job in ipairs(jobs) do if job.At<=f.Now then job.Run() else table.insert(f.Jobs,job) end end
    end
    f.Heartbeat:Fire()
    return f
end

do
    local f=fixture(); f.Press(false)
    check(f.Equips==0,"observer never equips on the original key callback")
    f.Advance(.1); check(f.Equips==0,"native hotbar gets time before a recovery")
    f.Advance(.03)
    check(f.Equips==1 and f.Report.Recoveries==1 and f.Tool.Parent==f.Char,"unchanged missed native equip gets one guarded recovery")
    f.Advance(1)
    check(f.Equips==1,"one key cannot create a repeat equip loop")
    f=fixture(); f.Tool.Enabled=false; f.Press(false); f.Advance()
    check(f.Equips==1,"disabled firing state does not incorrectly prevent equipping")
end

do
    local f=fixture(); f.Press(false); f.Move(f.Char); f.Action.Pressed:Fire(); f.Advance()
    check(f.Equips==0 and f.Report.Recoveries==0,"native equip after the key callback is never toggled twice")
    f=fixture(); f.Move(f.Char); f.Action.Pressed:Fire(); f.Press(false); f.Advance()
    check(f.Equips==0 and f.Tool.Parent==f.Char,"native equip before the observer is preserved")
    f=fixture(); f.Move(f.Char); f.Heartbeat:Fire(); f.Press(false); f.Move(f.Bag); f.Advance()
    check(f.Equips==0 and f.Tool.Parent==f.Bag,"a normal holster press is not auto-equipped again")
    f=fixture(); f.Move(f.Char); f.Heartbeat:Fire(); f.Move(f.Bag); f.Press(false); f.Advance()
    check(f.Equips==0 and f.Tool.Parent==f.Bag,"native holster before the observer is also preserved")
    f=fixture(); f.Press(false); f.Move(f.Char); f.Press(false); f.Move(f.Bag); f.Advance()
    check(f.Equips==0 and f.Tool.Parent==f.Bag,"rapid equip then holster cancels the pending recovery")
    f=fixture(); f.Press(false); f.Move(f.Char); f.Move(f.Bag); f.Advance()
    check(f.Equips==0,"parenting changes cancel recovery even when the tool returns to backpack")
end

do
    local f=fixture(); f.Press(true); f.Advance()
    check(f.Equips==0 and f.Report.Status:find("consumed",1,true),"consumed input without native hotbar action is respected")
    f=fixture(); f.Press(true); f.Action.Pressed:Fire(); f.Advance()
    check(f.Equips==1 and f.Report.LastNativeSignal,"processed input can recover only when the native slot action was observed")
end

for _,case in ipairs({
    {"menu or chat",function(f) f.Blocked=true end},
    {"disabled native context",function(f) f.NativeAllowed=false end},
    {"multiple weapons",function(f) f.Ambiguous=true end},
    {"no owned weapon",function(f) f.Missing=true end},
    {"touch mode",function(f) f.PC=false end},
}) do
    local f=fixture(); case[2](f); f.Press(false); f.Advance()
    check(f.Equips==0,"recovery respects "..case[1])
end

for _,case in ipairs({
    {"menu opened",function(f) f.Blocked=true end},
    {"context disabled",function(f) f.NativeAllowed=false end},
    {"character replaced",function(f) f.Char={} end},
    {"weapon removed",function(f) f.Missing=true end},
    {"dead humanoid",function(f) f.Hum.Health=0 end},
    {"handle still loading",function(f) f.HasHandle=false end},
    {"focus lost",function(f) f.Lost:Fire() end},
    {"toggle disabled",function(f) f.State.SetWeaponEquipRecovery(false) end},
    {"script unload",function(f) f.State.Running=false; f.State.StopWeaponEquipRecovery() end},
}) do
    local f=fixture(); f.Press(false); case[2](f); f.Advance()
    check(f.Equips==0,"pending recovery cancels after "..case[1])
end

do
    local f=fixture(); f.Press(false,"Two"); f.Advance()
    check(f.Equips==0 and f.Report.Presses==0,"other number keys are untouched")
    f=fixture(); f.EquipError=true; f.Press(false); f.Advance()
    check(f.Report.Failures==1 and f.Report.Recoveries==0,"failed equip is recorded without retrying in a loop")
    local snap=f.State.GetWeaponEquipSnapshot(); snap.Presses=999
    check(f.Report.Presses==1 and snap.LastError==nil,"diagnostic snapshots cannot mutate counters or expose raw errors")
    f=fixture(); f.State.SetWeaponEquipRecovery(false); f.Press(false); f.Advance()
    check(f.Report.Status=="Off" and f.Equips==0,"off remains off")
    f.State.SetWeaponEquipRecovery(true); f.Advance(); f.Press(false); f.Advance()
    check(f.Equips==1,"re-enabling builds a fresh stable snapshot")
end
print(passed.." equip assertions passed")
