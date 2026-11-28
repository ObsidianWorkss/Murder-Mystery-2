-- Extracted from the actual main.lua role and phase policy.
-- INSERT_STYLE_POLICY

local passed=0
local function check(label, actual, expected)
    assert(actual==expected, ("%s: expected %s, got %s"):format(label,tostring(expected),tostring(actual)))
    passed+=1
end

check("Murderer jukes Sheriff",styleOpponentRole("Murderer","Sheriff"),true)
check("Murderer jukes Hero",styleOpponentRole("Murderer","Hero"),true)
check("Murderer ignores other Murderer",styleOpponentRole("Murderer","Murderer"),false)
check("Murderer ignores innocent",styleOpponentRole("Murderer","Innocent"),false)
check("Sheriff jukes Murderer",styleOpponentRole("Sheriff","Murderer"),true)
check("Hero jukes Murderer",styleOpponentRole("Hero","Murderer"),true)
check("Innocent jukes Murderer",styleOpponentRole("Innocent","Murderer"),true)
check("Innocent ignores Sheriff",styleOpponentRole("Innocent","Sheriff"),false)
check("Unknown role cannot juke",styleOpponentRole("Unknown","Murderer"),false)
check("Event role cannot juke Classic threat",styleOpponentRole("Zombie","Sheriff"),false)
check("Unknown opponent not targeted",styleOpponentRole("Sheriff","Unknown"),false)

check("Juke starts with feint",styleJukePhase(0),-1)
check("Feint holds until phase boundary",styleJukePhase(0.119),-1)
check("Juke commits to other direction",styleJukePhase(0.12),1)
check("Juke remains active before end",styleJukePhase(0.479),1)
check("Juke ends on time",styleJukePhase(0.48),nil)
check("Juke stays ended",styleJukePhase(10),nil)

local tolerance=1e-7
local function angle(label,actual,expected)
    assert(math.abs(actual-expected)<tolerance,label)
    passed+=1
end
angle("Spin starts at zero",styleSpinAngle(0),0)
angle("Spin rotates 90 degrees",styleSpinAngle(0.15),math.pi/2)
angle("Spin rotates 180 degrees",styleSpinAngle(0.30),math.pi)
angle("Spin rotates full 360 degrees",styleSpinAngle(0.60),math.pi*2)
angle("Spin stays capped",styleSpinAngle(30),math.pi*2)
angle("Spin clamps negative elapsed",styleSpinAngle(-1),0)
angle("Adaptive spin ends at its selected duration",styleSpinAngle(0.42,0.42),math.pi*2)
angle("Adaptive spin midpoint",styleSpinAngle(0.21,0.42),math.pi)
angle("Adaptive spin clamps after completion",styleSpinAngle(0.7,0.42),math.pi*2)

check("Measured planar speed uses horizontal axes",stylePlanarSpeed({X=3,Y=500,Z=4}),5)
check("Missing measured velocity safely falls back",stylePlanarSpeed(nil),0)
check("Invalid measured velocity safely falls back",stylePlanarSpeed({X=0/0,Z=8}),0)
check("Telemetry spike is ignored",stylePlanarSpeed({X=180,Z=5}),0)
check("Fast style factor",styleSpeedFactor("Fast"),0.82)
check("Smooth style factor",styleSpeedFactor("Smooth"),1.18)
check("Adaptive style factor",styleSpeedFactor("Adaptive"),1)
check("Unknown style factor uses adaptive",styleSpeedFactor("not-a-setting"),1)

local function less(label,a,b)
    assert(a<b,label..": expected "..tostring(a).." < "..tostring(b))
    passed+=1
end
local function within(label,value,min,max)
    assert(value>=min and value<=max,label..": "..tostring(value).." is out of bounds")
    passed+=1
end

local slowJuke=styleJukeDuration(12,10,2,"Adaptive")
local fastJuke=styleJukeDuration(12,38,13,"Adaptive")
less("Fast incoming threat shortens juke",fastJuke,slowJuke)
less("Fast profile shortens juke",styleJukeDuration(12,10,2,"Fast"),slowJuke)
less("Smooth profile lengthens juke",slowJuke,styleJukeDuration(12,10,2,"Smooth"))
within("Juke minimum is bounded",styleJukeDuration(0,100,100,"Fast"),0.32,0.68)
within("Juke maximum is bounded",styleJukeDuration(30,0,0,"Smooth"),0.32,0.68)
local slowSpin=styleSpinDuration(0,0,"Adaptive")
less("Fast opponent shortens spin",styleSpinDuration(16,35,"Adaptive"),slowSpin)
less("Fast profile shortens spin",styleSpinDuration(0,0,"Fast"),slowSpin)
less("Smooth profile lengthens spin",slowSpin,styleSpinDuration(0,0,"Smooth"))
within("Minimum spin duration bounded",styleSpinDuration(40,100,"Fast"),0.34,0.84)
within("Maximum spin duration bounded",styleSpinDuration(0,0,"Smooth"),0.34,0.84)

-- Timing is adaptive, but the juke runtime no longer modifies WalkSpeed.
within("Stationary character still has bounded juke timing",
    styleJukeDuration(0,12,4,"Fast"),0.32,0.68)
within("Slow-moving character has bounded juke timing",
    styleJukeDuration(6,12,4,"Adaptive"),0.32,0.68)
within("Sprinting character has bounded juke timing",
    styleJukeDuration(34,12,4,"Adaptive"),0.32,0.68)
less("Fast changes timing only, not movement speed",
    styleJukeDuration(16,20,5,"Fast"),styleJukeDuration(16,20,5,"Adaptive"))
less("Smooth has more deliberate timing",
    styleJukeDuration(16,20,5,"Adaptive"),styleJukeDuration(16,20,5,"Smooth"))
less("Faster opponents reduce auto juke cooldown",
    styleAutoCooldown("Juke",45,"Adaptive"),styleAutoCooldown("Juke",5,"Adaptive"))
less("Faster opponents reduce auto trickshot cooldown",
    styleAutoCooldown("Trickshot",45,"Adaptive"),styleAutoCooldown("Trickshot",5,"Adaptive"))
less("Fast mode reduces juke cooldown",
    styleAutoCooldown("Juke",15,"Fast"),styleAutoCooldown("Juke",15,"Adaptive"))
less("Adaptive juke cooldown shorter than smooth",
    styleAutoCooldown("Juke",15,"Adaptive"),styleAutoCooldown("Juke",15,"Smooth"))
within("Juke cooldown always bounded",styleAutoCooldown("Juke",200,"Fast"),2.1,4.2)
within("Spin cooldown always bounded",styleAutoCooldown("Trickshot",200,"Fast"),9.5,16.5)

check("Single safe direction uses quick cut",styleJukePattern(9,6,28,2,false,true),"Quick cut")
check("Close fast approach uses brake cut",styleJukePattern(6,10,15,1,true,true),"Brake cut")
check("Aggressive approach can use jump cut",styleJukePattern(12,11,18,3,true,true),"Jump cut")
check("Fast enemy can prompt double fake",styleJukePattern(12,1,30,2,true,true),"Double fake")
check("Fourth pattern rotates brake cut",styleJukePattern(12,1,12,4,true,false),"Brake cut")
check("Fifth pattern rotates jump cut",styleJukePattern(12,1,12,5,true,true),"Jump cut")
check("Default safe feint",styleJukePattern(12,1,12,1,true,true),"Fake cut")
check("Fast target induces zigzag",styleJukePattern(12,2,28,7,true,true,1),"Zigzag")
check("Crowded route induces wide arc",styleJukePattern(12,2,12,3,true,true,3),"Wide arc")
check("Ninth juke rotates to wide arc",styleJukePattern(12,2,12,9,true,false,1),"Wide arc")
check("Eighth juke rotates to sprint cut",styleJukePattern(12,2,12,8,true,false,1),"Sprint cut")
check("Sixth juke rotates reverse bait",styleJukePattern(12,2,12,6,true,false,1),"Reverse bait")
check("Unsafe feint still uses direct cut in crowd",styleJukePattern(12,10,28,9,false,true,3),"Quick cut")

check("Zigzag opens with false cut",styleJukePhase(0.05,"Zigzag",0.5),-1)
check("Zigzag briefly reverses",styleJukePhase(0.12,"Zigzag",0.5),1)
check("Zigzag second fake",styleJukePhase(0.22,"Zigzag",0.5),-1)
check("Zigzag escapes at end",styleJukePhase(0.40,"Zigzag",0.5),1)
check("Zigzag ends precisely",styleJukePhase(0.5,"Zigzag",0.5),nil)
check("Reverse bait begins opposite",styleJukePhase(0.05,"Reverse bait",0.5),-1)
check("Reverse bait pauses",styleJukePhase(0.13,"Reverse bait",0.5),0)
check("Reverse bait commits",styleJukePhase(0.2,"Reverse bait",0.5),1)
check("Sprint cut starts immediately",styleJukePhase(0,"Sprint cut",0.5),1)
check("Wide arc starts immediately",styleJukePhase(0,"Wide arc",0.5),1)

less("Close threat outranks distant fast target",
    styleThreatPriority(35,35),styleThreatPriority(7,0))
less("Approaching target outranks similarly distant stationary target",
    styleThreatPriority(14,0),styleThreatPriority(14,12))
check("Out-of-range threat gets no priority",styleThreatPriority(65,30),-math.huge)
check("Invalid negative range gets no priority",styleThreatPriority(-2,15),-math.huge)

local oneOpponent={{X=3.5,Z=0}}
less("Safe negative side has lower danger score",
    styleLaneRisk(0,0,-1,0,oneOpponent),styleLaneRisk(0,0,1,0,oneOpponent))
less("Crowded flank is penalized relative to clear flank",
    styleLaneRisk(0,0,-1,0,{{X=3.5,Z=0},{X=8,Z=0}}),
    styleLaneRisk(0,0,1,0,{{X=3.5,Z=0},{X=8,Z=0}}))
check("Empty room has zero lane risk",styleLaneRisk(0,0,1,0,{}),0)
less("More clearance beats equally risky shorter escape",
    styleSpaceScore(3,0.05,"Side",false),styleSpaceScore(6,0.05,"Side",false))
less("Riskier flank loses to equally open safer flank",
    styleSpaceScore(6,0.24,"Side",false),styleSpaceScore(6,0.06,"Side",false))
less("Diagonal route incurs small cost when the corridor is otherwise identical",
    styleSpaceScore(6,0.1,"Diagonal",false),styleSpaceScore(6,0.1,"Side",false))
less("Retreat route is a last choice when straight sides are open",
    styleSpaceScore(6,0.1,"Retreat",false),styleSpaceScore(6,0.1,"Diagonal",false))
less("Alternating preference breaks an exact route tie",
    styleSpaceScore(6,0.1,"Side",false),styleSpaceScore(6,0.1,"Side",true))
less("Safe route matching the player's travel direction wins a tie",
    styleSpaceScore(6,0.1,"Side",false,-1),styleSpaceScore(6,0.1,"Side",false,1))
less("Player momentum does not override a much shorter escape route",
    styleSpaceScore(3,0.1,"Side",false,1),styleSpaceScore(6,0.1,"Side",false,-1))

check("Wide clear lanes are open",styleSpaceClass("Side",7,7,7.5),"Open")
check("One-sided clearance identifies corner",styleSpaceClass("Side",7,1.5,7.5),"Corner")
check("Limited sideways route identifies narrow corridor",styleSpaceClass("Side",4,4,7.5),"Narrow")
check("Diagonal exit identifies a corner escape",styleSpaceClass("Diagonal",6,0,7.5),"Corner")
check("Backward exit identifies retreat",styleSpaceClass("Retreat",5,0,7.5),"Retreat")
check("Open space preserves multi-feint repertoire",
    styleJukePattern(12,2,12,1,true,true,1,"Open"),"Fake cut")
check("Narrow corridor uses direct tight cut",
    styleJukePattern(12,2,12,1,true,true,1,"Narrow"),"Tight cut")
check("Corner uses a single escape direction",
    styleJukePattern(12,2,12,7,true,true,1,"Corner"),"Corner escape")
check("Retreat avoids feints back toward opponent",
    styleJukePattern(12,2,12,2,true,true,1,"Retreat"),"Retreat step")
check("Tight cut has no reverse fake",styleJukePhase(0,"Tight cut",0.25),1)
check("Corner escape has no reverse fake",styleJukePhase(0.1,"Corner escape",0.25),1)
check("Retreat step finishes at its duration",styleJukePhase(0.25,"Retreat step",0.25),nil)

within("Long free lane preserves a normal juke duration",
    styleSpaceDuration(0.4,7.5,16),0.38,0.4)
within("Short free lane reduces juke time",
    styleSpaceDuration(0.5,3,16),0.13,0.2)
check("Wall too close forbids a juke",styleSpaceDuration(0.5,1.9,16),nil)
check("Frozen movement forbids a juke",styleSpaceDuration(0.5,6,0),nil)
check("Very fast movement with little clearance skips the juke",
    styleSpaceDuration(0.5,2.3,40),nil)
check("Auto spin allowed in a rising jump with a targeted gun",
    styleCanAutoSpin(0,true,28,"Gun",45,0.48),true)
check("Auto spin allowed with targeted knife in the air",
    styleCanAutoSpin(0,true,30,"Knife",90,0.41),true)
check("Auto spin does not initiate random jumps from the ground",
    styleCanAutoSpin(0,false,30,"Gun",25,0.55),false)
check("Auto spin blocked by nearby opposing player",
    styleCanAutoSpin(1,true,35,"Gun",0,0.55),false)
check("Auto spin blocked in descending flight",
    styleCanAutoSpin(0,true,-12,"Knife",0,0.50),false)
check("Auto spin blocked late in ascent",
    styleCanAutoSpin(0,true,9.9,"Gun",0,0.55),false)
check("Auto spin blocked if landing is too close",
    styleCanAutoSpin(0,true,35,"Gun",0,0.379),false)
check("Auto spin permitted exactly at minimum runway",
    styleCanAutoSpin(0,true,35,"Gun",0,0.38),true)
check("Auto spin blocked if opponent is away from the crosshair",
    styleCanAutoSpin(0,true,35,"Gun",136,0.55),false)
check("Auto spin permitted at crosshair threshold",
    styleCanAutoSpin(0,true,35,"Gun",135,0.55),true)
check("Auto spin blocked while unarmed",
    styleCanAutoSpin(0,true,35,"None",0,0.55),false)
within("Estimated remaining flight time respects rising vertical speed",
    styleRemainingAirTime(40,200,1),0.42,0.43)
check("Descending player with no clearance has no remaining airborne window",
    styleRemainingAirTime(-15,200,0),0)
check("Zero-gravity world blocks the automatic spin safety estimate",
    styleRemainingAirTime(40,0,1),0)

check("Quick cut commits immediately",styleJukePhase(0,"Quick cut",0.5),1)
check("Jump cut commits immediately",styleJukePhase(0,"Jump cut",0.5),1)
check("Brake cut begins stationary",styleJukePhase(0.05,"Brake cut",0.5),0)
check("Brake cut commits after a pause",styleJukePhase(0.15,"Brake cut",0.5),1)
check("Double fake first feint",styleJukePhase(0.02,"Double fake",0.5),-1)
check("Double fake first cut",styleJukePhase(0.08,"Double fake",0.5),1)
check("Double fake second feint",styleJukePhase(0.17,"Double fake",0.5),-1)
check("Double fake final cut",styleJukePhase(0.24,"Double fake",0.5),1)
check("Double fake stops at exact duration",styleJukePhase(0.5,"Double fake",0.5),nil)

check("Auto juke close murderer threat",
    styleAutoAction("Sheriff","Murderer",8,0,"Gun",false,true,true),"Juke")
check("Auto juke approaching sheriff",
    styleAutoAction("Murderer","Sheriff",14,3,"Knife",false,true,true),"Juke")
check("Auto juke stationary distant target rejected",
    styleAutoAction("Sheriff","Murderer",14,0,"Gun",false,true,false),nil)
check("Auto juke receding distant target rejected",
    styleAutoAction("Sheriff","Murderer",16,-7,"Gun",false,true,false),nil)
check("Auto juke beyond range rejected",
    styleAutoAction("Sheriff","Murderer",18,30,"Gun",false,true,false),nil)
check("Auto juke too close to choose direction",
    styleAutoAction("Sheriff","Murderer",1,30,"Gun",false,true,false),nil)
check("Auto juke disabled",
    styleAutoAction("Sheriff","Murderer",8,6,"Gun",false,false,false),nil)
check("No auto action against innocent",
    styleAutoAction("Murderer","Innocent",8,12,"Knife",true,true,true),nil)
check("No auto action in unknown role",
    styleAutoAction("Unknown","Murderer",7,12,"Gun",true,true,true),nil)
check("Auto spin sheriff with clear gun target",
    styleAutoAction("Sheriff","Murderer",27,0,"Gun",true,true,true),"Trickshot")
check("Auto spin murderer with knife versus sheriff",
    styleAutoAction("Murderer","Sheriff",30,0,"Knife",true,true,true),nil)
check("Murderer does not auto spin into armed Hero fire",
    styleAutoAction("Murderer","Hero",38,0,"Knife",true,true,true),nil)
check("Murderer can still defensively juke a close armed sheriff",
    styleAutoAction("Murderer","Sheriff",9,6,"Knife",true,true,true),"Juke")
check("Gun fight allows a sheriff's automatic airborne trickshot",
    styleAutoAction("Sheriff","Murderer",30,0,"Gun",true,true,true),"Trickshot")
check("Constrained 3.8-stud lane cannot take over steering versus gun",
    styleGunSafeEscape(3.8,7.5),false)
check("Broad 6-stud supported lane still permits a defensive juke",
    styleGunSafeEscape(6,7.5),true)
check("Short escape is rejected even if desired distance is short",
    styleGunSafeEscape(3.8,4),false)
check("Invalid desired clearance fails safely",
    styleGunSafeEscape(5,0),false)
check("Auto spin hero with gun versus murderer",
    styleAutoAction("Hero","Murderer",25,0,"Gun",true,false,true),"Trickshot")
check("Auto spin ignores obstructed target",
    styleAutoAction("Sheriff","Murderer",27,0,"Gun",false,false,true),nil)
check("Auto spin requires weapon equipped",
    styleAutoAction("Sheriff","Murderer",27,0,"None",true,false,true),nil)
check("Auto spin respects equipped role",
    styleAutoAction("Sheriff","Murderer",27,0,"Knife",true,false,true),nil)
check("Auto spin disabled",
    styleAutoAction("Sheriff","Murderer",27,0,"Gun",true,false,false),nil)
check("Auto spin not too close",
    styleAutoAction("Sheriff","Murderer",17.99,0,"Gun",true,false,true),nil)
check("Auto spin not too far",
    styleAutoAction("Sheriff","Murderer",48.01,0,"Gun",true,false,true),nil)
check("Auto juke preferred over auto spin when imminent",
    styleAutoAction("Sheriff","Murderer",8,5,"Gun",true,true,true),"Juke")

print(("%d style move assertions passed"):format(passed))
