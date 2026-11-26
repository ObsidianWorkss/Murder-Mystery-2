local passed=0
local function check(value,message) assert(value,message); passed+=1; print("PASS: "..message) end
local backpack={}
local humanoid={Health=100,WalkSpeed=16}
local character={EquippedTool=nil}
function character:FindFirstChildOfClass(name)
    if name=="Humanoid" then return humanoid end
    if name=="Tool" then return self.EquippedTool end
end
local equips=0
function humanoid:EquipTool(tool)
    equips+=1
    tool.Parent=character
    character.EquippedTool=tool
end
local player={Character=character}
function player:FindFirstChild(name) return name=="Backpack" and backpack or nil end
local State={Running=true,Config={Aim=true,MagicBullet=true,SpeedBoost=false,WalkSpeed=24},WeaponHandlers={},
    CanUseCombatWeapon=function() return true end}
local scheduled={}
local task={delay=function(_,callback) table.insert(scheduled,callback) end}
local function owned(item) return item.Parent==character or item.Parent==backpack end
local function stopTracks() end
local function loadTracks() end
local function recordConnect(record,signal,callback)
    signal.Callback=callback
    table.insert(record.Connections,{Disconnect=function() signal.Callback=nil end})
end
local function touchInput() return false end
local function sendGun() end
local function clickKnife() end
local function ready() return true end
local function reportStabContact() end
local function makeTool(kind,equipped,visible)
    local item={Name=kind,Parent=equipped and character or backpack,Enabled=true,
        Activated={},Equipped={},Unequipped={}}
    function item:IsA(name) return name=="Tool" end
    function item:GetAttribute(name) return name=="EquippedPerk" and "Haste" or nil end
    local original={Name=kind.."Client",Parent=item,Enabled=true}
    function original:IsA(name) return name=="LocalScript" end
    function original:Clone()
        local copy={Name=self.Name,Enabled=self.Enabled,Parent=nil}
        function copy:FindFirstChild() return nil end
        function copy:Destroy() self.Parent=nil; self.Destroyed=true end
        return copy
    end
    function original:Destroy() self.Parent=nil; self.Destroyed=true end
    local cantShoot=kind=="Gun" and {Enabled=visible,Parent=item} or nil
    if cantShoot then
        function cantShoot:IsA(name) return name=="LayerCollector" end
    end
    function item:FindFirstChild(name)
        if name==original.Name and original.Parent==self then return original end
        if name=="CantShoot" and cantShoot and cantShoot.Parent==self then return cantShoot end
        return nil
    end
    return item,cantShoot
end
-- INSERT_RESTORE
-- INSERT_TAKEOVER
do
    local item,cantShoot=makeTool("Gun",false,true)
    takeOver(item)
    check(State.WeaponHandlers[item]~=nil and cantShoot.Enabled==false,
        "gun takeover hides the native shooting hint")
    restoreHandler(item)
    check(cantShoot.Enabled==true,"restoring gun returns the original visible shooting hint")
end
do
    local item,cantShoot=makeTool("Gun",false,false)
    takeOver(item); restoreHandler(item)
    check(cantShoot.Enabled==false,"restoring gun preserves an originally hidden shooting hint")
end
do
    local knife=makeTool("Knife",true)
    humanoid.WalkSpeed=0
    takeOver(knife)
    check(humanoid.WalkSpeed==0,"equipping knife does not unfreeze a zero-speed character")
    knife.Unequipped.Callback()
    check(humanoid.WalkSpeed==0,"unequipping knife does not unfreeze a zero-speed character")
    restoreHandler(knife)
end
do
    local knife=makeTool("Knife",true)
    State.Config.SpeedBoost=true
    humanoid.WalkSpeed=24
    takeOver(knife)
    check(humanoid.WalkSpeed==24,"equipping knife does not override active movement speed boost")
    knife.Unequipped.Callback()
    check(humanoid.WalkSpeed==24,"unequipping knife does not override active movement speed boost")
    restoreHandler(knife)
end
do
    local knife=makeTool("Knife",true)
    State.Config.SpeedBoost=false
    humanoid.WalkSpeed=16
    takeOver(knife)
    check(humanoid.WalkSpeed==18,"ordinary Haste knife speed remains unchanged")
    knife.Unequipped.Callback()
    check(humanoid.WalkSpeed==16,"ordinary knife unequip restores normal speed")
    restoreHandler(knife)
end
do
    local knife=makeTool("Knife",true)
    local before=#scheduled
    takeOver(knife); restoreHandler(knife)
    check(#scheduled==before+1,"restoring an equipped weapon schedules native re-equip")
    character.EquippedTool={Name="OtherTool"}
    local previous=equips
    scheduled[#scheduled]()
    check(equips==previous,"delayed restore does not steal a newly equipped different tool")
    character.EquippedTool=nil
end
do
    local knife=makeTool("Knife",true)
    takeOver(knife); restoreHandler(knife)
    local previous=equips
    character.EquippedTool=nil
    scheduled[#scheduled]()
    check(equips==previous+1 and knife.Parent==character,
        "delayed restore still returns the original equipped weapon when no new tool was selected")
    character.EquippedTool=nil
end
print(passed.." weapon lifecycle assertions passed")
