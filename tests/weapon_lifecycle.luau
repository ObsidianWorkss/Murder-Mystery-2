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
local playerGui={Name="PlayerGui"}
function playerGui:FindFirstChild(name)
    return self.CantShoot and self.CantShoot.Name==name and
        self.CantShoot.Parent==self and self.CantShoot or nil
end
local player={Character=character}
function player:FindFirstChild(name) return name=="Backpack" and backpack or nil end
function player:FindFirstChildOfClass(name)
    return name=="PlayerGui" and playerGui or nil
end
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
local function makeTool(kind,equipped,visible,uiWhere)
    local item={Name=kind,Parent=equipped and character or backpack,Enabled=true,
        Activated={},Equipped={},Unequipped={}}
    function item:IsA(name) return name=="Tool" end
    function item:GetAttribute(name) return name=="EquippedPerk" and "Haste" or nil end
    local original={Name=kind.."Client",Parent=item,Enabled=true}
    local cantShoot,slash
    function original:IsA(name) return name=="LocalScript" end
    function original:FindFirstChild(name)
        if name=="Slash" then
            return self.Slash and self.Slash.Parent==self and self.Slash or nil
        end
        return self.CantShoot and self.CantShoot.Name==name and
            self.CantShoot.Parent==self and self.CantShoot or nil
    end
    function original:Clone()
        local copy={Name=self.Name,Enabled=self.Enabled,Parent=nil}
        function copy:FindFirstChild(name)
            local found
            if name=="CantShoot" then found=self.CantShoot or cantShoot
            elseif name=="Slash" then found=self.Slash or slash end
            return found and found.Parent==self and found or nil
        end
        function copy:Destroy() self.Parent=nil; self.Destroyed=true end
        if self.CantShoot and self.CantShoot.Parent==self and
            self.CantShoot.Archivable~=false then
            local cg={Name="CantShoot",Parent=copy,Enabled=self.CantShoot.Enabled}
            function cg:IsA(name) return name=="LayerCollector" end
            copy.CantShoot=cg
        end
        if self.Slash and self.Slash.Parent==self and
            self.Slash.Archivable~=false then
            local sa={Name="Slash",Parent=copy,Archivable=true}
            function sa:IsA(name) return name=="Animation" end
            copy.Slash=sa
        end
        return copy
    end
    function original:Destroy() self.Parent=nil; self.Destroyed=true end
    local origin=uiWhere=="client" and original or
        uiWhere=="playerGui" and playerGui or item
    cantShoot=kind=="Gun" and uiWhere~="missing" and
        {Name="CantShoot",Enabled=visible,Parent=origin,
            Archivable=uiWhere~="clientUnarchivable"} or nil
    if cantShoot then
        function cantShoot:IsA(name) return name=="LayerCollector" end
        if origin==original then original.CantShoot=cantShoot end
        if origin==playerGui then playerGui.CantShoot=cantShoot end
    end
    if kind=="Knife" and uiWhere~="knifeMissing" then
        local slashOwner=uiWhere=="knifeTool" and item or original
        slash={Name="Slash",Parent=slashOwner,
            Archivable=uiWhere~="knifeNonArchivable"}
        function slash:IsA(name) return name=="Animation" end
        if slashOwner==original then original.Slash=slash end
    end
    function item:FindFirstChild(name)
        if name==original.Name and original.Parent==self then return original end
        if name=="CantShoot" and cantShoot and cantShoot.Parent==self then return cantShoot end
        if name=="Slash" and slash and slash.Parent==self then return slash end
        return nil
    end
    return item,cantShoot
end
-- INSERT_STAGE_GUN_UI
-- INSERT_RESTORE
-- INSERT_TAKEOVER
do
    local item,cantShoot=makeTool("Gun",false,true)
    takeOver(item)
    check(State.WeaponHandlers[item]~=nil and cantShoot.Enabled==false,
        "gun takeover hides the native shooting hint")
    check(State.WeaponHandlers[item].Backup:FindFirstChild("CantShoot")==cantShoot,
        "gun takeover stages native UI beneath the backed-up GunClient")
    restoreHandler(item)
    check(cantShoot.Enabled==true,"restoring gun returns the original visible shooting hint")
end
do
    local item,cantShoot=makeTool("Gun",false,false)
    takeOver(item); restoreHandler(item)
    check(cantShoot.Enabled==false,"restoring gun preserves an originally hidden shooting hint")
end
do
    local item,cantShoot=makeTool("Gun",false,true,"playerGui")
    takeOver(item)
    local record=State.WeaponHandlers[item]
    check(record and record.Backup:FindFirstChild("CantShoot")==cantShoot,
        "GUI previously moved into PlayerGui is staged under saved GunClient")
    restoreHandler(item)
    check(cantShoot.Parent==record.Backup and cantShoot.Enabled,
        "restored GunClient has the missing UI before its native script starts")
end
do
    local item=makeTool("Gun",false,true,"client")
    takeOver(item)
    local record=State.WeaponHandlers[item]
    check(record and record.Backup:FindFirstChild("CantShoot")~=nil,
        "normal native GunClient UI is preserved by its clone")
    restoreHandler(item)
end
do
    local item,cantShoot=makeTool("Gun",false,true,"clientUnarchivable")
    -- simulate Roblox cloning the LocalScript without a non-Archivable child
    cantShoot.Parent=item:FindFirstChild("GunClient")
    local original=item:FindFirstChild("GunClient")
    original.CantShoot=cantShoot
    takeOver(item)
    local record=State.WeaponHandlers[item]
    check(record and record.Backup:FindFirstChild("CantShoot")==cantShoot,
        "non-Archivable native UI is moved out before original script destruction")
    restoreHandler(item)
    check(cantShoot.Parent==record.Backup and cantShoot.Enabled,
        "non-Archivable native UI survives its original script being replaced")
end
do
    local item=makeTool("Gun",false,true,"missing")
    local original=item:FindFirstChild("GunClient")
    takeOver(item)
    check(State.WeaponHandlers[item]==nil and original.Parent==item
        and original.Enabled==true and not original.Destroyed,
        "missing GunClient UI leaves native gun alone instead of recreating a broken script")
end
do
    local knife=makeTool("Knife",false,nil,"knifeTool")
    takeOver(knife)
    local record=State.WeaponHandlers[knife]
    check(record and record.Backup:FindFirstChild("Slash")~=nil,
        "knife Slash animation staged from tool before original is destroyed")
    restoreHandler(knife)
    check(record.Backup:FindFirstChild("Slash")~=nil,
        "restored native KnifeClient contains Slash before being re-enabled")
end
do
    local knife=makeTool("Knife",false,nil,"knifeNonArchivable")
    takeOver(knife)
    local record=State.WeaponHandlers[knife]
    check(record and record.Backup:FindFirstChild("Slash")~=nil,
        "non-Archivable Slash animation survives script replacement")
    restoreHandler(knife)
end
do
    local knife=makeTool("Knife",false,nil,"knifeMissing")
    local original=knife:FindFirstChild("KnifeClient")
    takeOver(knife)
    check(State.WeaponHandlers[knife]==nil and original.Parent==knife
        and original.Enabled and not original.Destroyed,
        "missing Slash leaves the original KnifeClient running untouched")
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
