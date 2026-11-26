local count=0
local function check(value,message)
    assert(value,message)
    count+=1
    print("PASS: "..message)
end
local function vec(x) return setmetatable({X=x,Y=0,Z=0},{
    __sub=function(a,b) return vec(a.X-b.X) end})
end
local function typeof(v) return type(v)=="table" and v.Kind or type(v) end
local workspace={}
local char={Parent=workspace}
local player={Character={Parent=workspace}}
local State={ServerBlockers={}}
local Enum={RaycastFilterType={Exclude="Exclude"}}
local RaycastParams={new=function() return {} end}
local CollectionService={
    GetTagged=function() return {} end,
    GetInstanceAddedSignal=function() return {} end,
    GetInstanceRemovedSignal=function() return {} end
}
local function connect() end
local function segmentHitsBox() return false end
local function part(parent,transparent,collidable)
    local v={Kind="Instance",Parent=parent,Transparency=transparent,CanQuery=true,CanCollide=collidable}
    function v:IsA(name) return name=="BasePart" end
    function v:IsDescendantOf(container)
        local p=self.Parent
        while p do if p==container then return true end; p=p.Parent end
        return false
    end
    return v
end
local invisibleRoot=part(char,1,true)
local torso=part(char,0,true)
local wall=part(workspace,0,true)
local tool={Parent=char}
local handle=part(tool,0,true)
local scene={invisibleRoot,torso}
function workspace:Raycast(_,_,params)
    for _,candidate in ipairs(scene) do
        local ignored=false
        for _,node in ipairs(params.FilterDescendantsInstances) do
            if candidate==node or candidate:IsDescendantOf(node) then
                ignored=true;break
            end
        end
        if not ignored then return {Instance=candidate} end
    end
    return nil
end
-- INSERT_TRANSPARENT_COVER
check(clearPath(vec(0),vec(10),char),
    "fully transparent queryable root is skipped to find a real opaque torso")
scene={invisibleRoot,wall,torso}
check(not clearPath(vec(0),vec(10),char),
    "transparent collidable root cannot hide an opaque wall behind it")
scene={torso}
check(clearPath(vec(0),vec(10),char),
    "ordinary visible torso is still a valid gun hit")
scene={handle,torso}
check(not clearPath(vec(0),vec(10),char),
    "a target's weapon handle remains an obstruction, not a body hit")
scene={invisibleRoot}
check(clearPath(vec(0),vec(10),char),
    "transparent target root alone cannot be mistaken for an opaque wall")
print(count.." transparent cover assertions passed")
