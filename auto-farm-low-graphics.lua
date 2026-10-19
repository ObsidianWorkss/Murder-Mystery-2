-- No UI. Experimental underground currency farm with optional 3D-off / 20 FPS controls.
-- Run only inside MM2. This does not launch additional clients or guarantee collection.
if game.PlaceId~=142823291 then warn("MM2 farm: run this in Murder Mystery 2.");return end
local source=game:HttpGet("https://raw.githubusercontent.com/ObsidianWorkss/Murder-Mystery-2/refs/heads/main/auto-farm.lua?farm=20261020.1")
if not source:find("-- MM2FarmRevision:20261020.1",1,true) then error("MM2 low-graphics farm: stale core download; retry the latest loader.") end
local chunk,message=loadstring(source,"MM2AutoFarmLowGraphics")
if not chunk then error("MM2 low-graphics farm compilation failed: "..tostring(message)) end
local env=getgenv()
env.MM2AutoFarmLaunch={Movement="Underground",LowGraphics=true}
local ok,result=pcall(chunk)
env.MM2AutoFarmLaunch=nil
if not ok then
    local farm=env.MM2AutoFarm
    if farm and type(farm.Stop)=="function" then pcall(farm.Stop,"Low-graphics startup failed") end
    error("MM2 low-graphics farm failed: "..tostring(result))
end
