local passed=0
local function check(ok,message) assert(ok,message); passed+=1; print("PASS: "..message) end
local now=100
local os={clock=function() return now end}
local good={Kind="Knife"}
local bad={Kind="Knife"}
local State={WeaponHandlers={[good]=good,[bad]=bad},Stats={}}
local goodChecks,badChecks=0,0
local fail=true
local function scanStabContacts(record)
    if record==bad then
        badChecks+=1
        if fail then error("transient simulated collision query failure") end
    else
        goodChecks+=1
    end
end
-- INSERT_SAFE_WEAPON_SWEEPS
scanWeaponContacts()
check(goodChecks==1 and badChecks==1 and State.Stats.StabSweepErrors==1,
    "one broken knife scan cannot prevent scanning another weapon")
check(bad.NextBladeScanRetryAt==100.25 and good.NextBladeScanRetryAt==nil,
    "only the failing weapon receives a short retry delay")
for _=1,12 do
    now+=.01
    scanWeaponContacts()
end
check(badChecks==1 and goodChecks==13 and State.Stats.StabSweepErrors==1,
    "repeated collision query failures do not create a per-frame error loop")
fail=false
now=100.26
scanWeaponContacts()
check(badChecks==2 and goodChecks==14 and bad.NextBladeScanRetryAt==nil,
    "the failing knife automatically recovers when its retry window expires")
scanWeaponContacts()
check(badChecks==3 and goodChecks==15 and State.Stats.StabSweepErrors==1,
    "successful blade queries immediately return to normal scanning")
State.WeaponHandlers[bad]=nil
scanWeaponContacts()
check(goodChecks==16 and badChecks==3,"removed weapon is never scanned again")
print(passed.." blade scan assertions passed")
