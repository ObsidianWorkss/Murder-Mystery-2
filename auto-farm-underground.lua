-- Experimental prone/noclip tween loader. No UI. End stops the farm.
-- Underground movement may be rejected with Invalid position; this is not an anti-cheat bypass.
if game.PlaceId~=142823291 then warn("MM2 coin farm: run this in Murder Mystery 2."); return end
local source=game:HttpGet("https://raw.githubusercontent.com/ObsidianWorkss/Murder-Mystery-2/refs/heads/main/auto-farm.lua?farm=20261020.1")
if not source:find("-- MM2FarmFormat:2",1,true) then error("MM2 underground farm: downloaded an older core; retry after the update reaches the download server.") end
if not source:find("-- MM2FarmRevision:20261020.1",1,true) then error("MM2 underground farm: stale core download; retry the latest loader.") end
local chunk,message=loadstring(source,"MM2AutoFarmUnderground")
if not chunk then error("MM2 underground farm compilation failed: "..tostring(message)) end
local env=getgenv()
env.MM2AutoFarmLaunch={Movement="Underground"}
local ok,result=pcall(chunk)
env.MM2AutoFarmLaunch=nil
if not ok then error("MM2 underground farm failed: "..tostring(result)) end
