local passed=0
local function check(ok,message) assert(ok,message); passed+=1 end
local mt={}
local function vector(x,y,z) return setmetatable({X=x,Y=y,Z=z},mt) end
mt.__add=function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
mt.__sub=function(a,b) return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
mt.__div=function(a,b) return vector(a.X/b,a.Y/b,a.Z/b) end
mt.__index=function(a,key) if key=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end end
local Vector3={new=vector}
local function node(name,class,parent)
    local n={Name=name,ClassName=class,Parent=parent,Children={},Attributes={}}
    if parent then table.insert(parent.Children,n) end
    function n:IsA(kind) return self.ClassName==kind end
    function n:FindFirstChild(name) for _,c in ipairs(self.Children) do if c.Name==name then return c end end end
    function n:FindFirstChildOfClass(kind) for _,c in ipairs(self.Children) do if c:IsA(kind) then return c end end end
    function n:GetChildren() return self.Children end
    function n:GetAttribute(key) return self.Attributes[key] end
    function n:IsDescendantOf(root)
        local p=self.Parent; while p do if p==root then return true end; p=p.Parent end; return false
    end
    function n:GetBoundingBox()
        if self.FailBounds then error("streaming unavailable") end
        self.BoundsCalls=(self.BoundsCalls or 0)+1
        local center=self.Center or vector(0,0,0)
        return {PointToObjectSpace=function(_,p) return p-center end},self.Size or vector(100,40,100)
    end
    return n
end
-- INSERT_CONTEXT
local function fixture(mode)
    local f={Now=0}
    local world=node("Workspace","Workspace"); world.Attributes.GameMode=mode or "Classic"
    local map=node("MapOne","Model",world)
    node("Spawns","Model",map); local base=node("Base","Model",map)
    local lobby=node("Lobby","Model",world); node("Spawns","Model",lobby); local lobbyBase=node("Base","Model",lobby)
    lobbyBase.Center=vector(1000,0,0)
    local own={Name="Own",UserId=1,Tools={}}; local enemy={Name="Other",UserId=2,Tools={}}
    for _,p in ipairs({own,enemy}) do
        p.Character=node(p.Name,"Model",world)
        node("Humanoid","Humanoid",p.Character).Health=100
        node("HumanoidRootPart","BasePart",p.Character).Position=vector(0,0,0)
    end
    local round={PlayerData={Own={Role="Sheriff"},Other={Role="Murderer"}}}
    local ctx=createGameContext({World=world,Round=round,Player=own,Clock=function() return f.Now end,ToolFor=function(p,kind) return p.Tools[kind] end})
    f.World,f.Map,f.Base,f.Lobby,f.Own,f.Other,f.Round,f.Context=world,map,base,lobby,own,enemy,round,ctx
    function f.Roles(a,b) round.PlayerData.Own={Role=a};round.PlayerData.Other={Role=b} end
    function f.Refresh() f.Now+=3.1 end
    return f,ctx
end
do
    local f,c=fixture()
    check(c.Contains(vector(0,0,0)) and c.Alive(f.Own),"classic Base map is active")
    check(not c.Contains(vector(1000,0,0)),"lobby rejected even when it contains a Base")
    check(#c.Maps()==1 and c.Maps()[1]==f.Map,"only round map is returned")
    for _=1,100 do c.Alive(f.Own) end
    check(f.Base.BoundsCalls==1,"hot-path role and alive checks reuse cached geometry")
    check(c.Target(f.Own,f.Other,"Gun") and not c.Target(f.Own,f.Own,"Gun"),"classic gun only selects another eligible player")
    f.Roles("Sheriff","Innocent")
    check(not c.Target(f.Own,f.Other,"Gun"),"classic gun cannot target innocent players")
    f.Roles("Murderer","Innocent")
    check(c.Target(f.Own,f.Other,"Knife") and c.CanThrow(f.Own),"classic murderer retains knife assistance and throws")
    f.Roles("Murderer","Murderer")
    check(not c.Target(f.Own,f.Other,"Knife"),"same attacking role is excluded")
    f.Roles("Innocent","Murderer");f.Own.Tools.Gun={}
    check(c.Role(f.Own)=="Sheriff" and c.Target(f.Own,f.Other,"Gun"),"classic gun pickup still identifies the hero with stale innocent metadata")
    f.Own.Tools.Gun=nil;f.Own.Tools.Knife={}
    check(c.Role(f.Own)=="Murderer","classic knife fallback retained")
end
do
    local f,c=fixture(); f.Base.Name="Map";f.Refresh()
    check(c.Contains(vector(0,0,0)),"Map geometry works without Base, matching observed Spaceship hierarchy")
    f.Map.Name="SeasonalArena";f.Base.Name="Geometry";f.Refresh()
    check(c.Contains(vector(0,0,0)),"Spawns-only model does not require a specific geometry child")
    f.Map:FindFirstChild("Spawns").Name="SpawnPoints";f.Refresh()
    check(c.InRound(f.Other),"SpawnPoints layout supported")
    local container=node("RoundContainer","Folder",f.World)
    f.Map.Parent=container;f.World.Children={f.Lobby,f.Own.Character,f.Other.Character,container};container.Children={f.Map};f.Refresh()
    check(c.Maps()[1]==f.Map and c.Alive(f.Other),"nested round map is discovered")
    f.Map.Parent=nil
    check(not c.Contains(vector(0,0,0)),"removed map stops qualifying before the scan interval")
    f.Refresh(); check(#c.Maps()==0,"removed map cache is pruned")
end
do
    local f,c=fixture()
    f.Base.FailBounds=true
    check(not c.Alive(f.Own),"unreadable map geometry refuses round qualification")
    f.Base.FailBounds=false;f.Refresh()
    check(c.Alive(f.Own),"streamed geometry recovers")
    f.Base.Size=vector(0,0,0);f.Refresh()
    check(not c.Contains(vector(0,0,0)),"empty streamed map cannot create a usable box")
    check(not c.Contains(vector(0/0,0,0)) and not c.Contains(vector(math.huge,0,0)),"nonfinite points rejected")
end
for _,case in ipairs({
    {"Infection","Survivor","Zombie","Gun",true},
    {"Infection","Survivor","Survivor","Gun",false},
    {"Infection","Zombie","Survivor","Knife",true},
    {"Infection","Zombie","Zombie","Knife",false},
    {"Infection","Zombie","Survivor","Gun",false},
    {"Infection","Survivor","Zombie","Knife",false},
    {"FreezeTag","Freezer","Runner","Gun",true},
    {"FreezeTag","Freezer","Runner","Knife",true},
    {"FreezeTag","Freezer","Freezer","Gun",false},
    {"FreezeTag","Freezer","Freezer","Knife",false},
    {"FreezeTag","Runner","Freezer","Gun",false},
    {"FreezeTag","Runner","Freezer","Knife",false},
}) do
    local f,c=fixture(case[1]); f.Roles(case[2],case[3])
    check(c.Target(f.Own,f.Other,case[4])==case[5],table.concat({case[1],case[2],case[3],case[4]}," / "))
end
do
    local f,c=fixture("Infection");f.Roles("Survivor","Survivor")
    f.Other.Character.Attributes.Zombie=true
    check(c.Role(f.Other)=="Zombie" and c.Target(f.Own,f.Other,"Gun"),"replicated conversion overrides previous Survivor role")
    f.Own.Character.Attributes.Zombie=true
    check(not c.Target(f.Own,f.Other,"Gun") and not c.Target(f.Own,f.Other,"Knife"),"conversion immediately rejects the new teammate")
    f.Other.Character.Attributes.Zombie=false
    check(c.Target(f.Own,f.Other,"Knife"),"converted local zombie selects survivors")
    check(not c.CanThrow(f.Own),"zombie throws remain blocked like native KnifeClient")
    f.Roles("Zombie","Survivor");f.Own.Tools.Knife={}
    check(c.Role(f.Own)=="Zombie","holding knife does not relabel an event role")
    f.Round.PlayerData.Own=nil;f.Own.Character.Attributes.Zombie=false;f.Own.Tools.Gun={}
    check(c.Role(f.Own)=="Survivor","missing Infection row can use observed owned gun fallback")
end
do
    local f,c=fixture("FreezeTag");f.Roles("Freezer","Runner")
    f.Round.PlayerData.Other.Frozen=true
    check(c.Alive(f.Other) and c.Frozen(f.Other) and not c.Target(f.Own,f.Other,"Gun"),"frozen runner stays visible but is not a new attack target")
    f.Round.PlayerData.Other.Frozen=false;f.Other.Character.Attributes.Frozen=true
    check(not c.Target(f.Own,f.Other,"Knife"),"replicated frozen state also cancels targeting")
    f.Own.Character.Attributes.Frozen=true
    check(not c.CanUse(f.Own,"Gun"),"frozen local player cannot automate a weapon")
    f.Own.Character.Attributes.Frozen=false
    check(c.CanThrow(f.Own),"freezer may use a normally supported owned knife throw")
end
do
    local f,c=fixture()
    f.Round.PlayerData.Other.Dead=true
    check(not c.Alive(f.Other) and not c.Target(f.Own,f.Other,"Gun"),"round death metadata rejects a healthy-looking corpse")
    f.Round.PlayerData.Other={Killed=true,Role="Murderer"}
    check(not c.Alive(f.Other),"Killed metadata respected")
    f.Round.PlayerData.Other=nil
    check(c.Alive(f.Other),"living in-map character can render while role data arrives")
    check(c.Role(f.Other)=="Unknown" and not c.Target(f.Own,f.Other,"Gun"),"missing role cannot make an unknown player a gun target")
    f.Other.Character:FindFirstChild("HumanoidRootPart").Position=vector(1000,0,0)
    check(not c.Alive(f.Other),"healthy lobby character does not become a combat target")
    f.Other.Character:FindFirstChild("HumanoidRootPart").Position=vector(0,0,0)
    f.Other.Character:FindFirstChildOfClass("Humanoid").Health=0
    check(not c.Alive(f.Other),"native death respected without a row")
end
do
    local f,c=fixture("Infection");f.Roles("Survivor","Zombie")
    check(c.Target(f.Own,f.Other,"Gun"),"setup infection target")
    check(c.ResolveRole("Murderer")=="Zombie" and c.ResolveRole("Sheriff")=="Survivor","role action groups resolve infection teams")
    check(c.ResolveRole("Opponent")=="Zombie","survivor opponent group is zombies")
    f.World.Attributes.GameMode="FreezeTag";f.Roles("Runner","Freezer")
    check(not c.CanUse(f.Own,"Gun") and not c.Target(f.Own,f.Other,"Gun"),"mode change immediately invalidates old gun policy")
    check(c.Threat(f.Own,f.Other),"runner threat is a freezer")
    check(c.ResolveRole("Murderer")=="Freezer" and c.ResolveRole("Sheriff")=="Runner","role action groups resolve freeze teams")
    f.World.Attributes.GameMode="OtherMode";f.Roles("private-text","Murderer")
    check(not c.CanUse(f.Own,"Gun") and not c.Target(f.Own,f.Other,"Knife"),"unknown mode cannot inherit classic attack rules")
    check(c.ResolveRole("Opponent")==nil,"unknown modes do not inherit role-action targets")
    local snapshot=c.Snapshot()
    check(snapshot.Mode=="Unknown" and snapshot.Role=="Unknown" and not snapshot.Supported and not snapshot.Token and not snapshot.Players,"diagnostics are bounded and omit arbitrary names/role text")
    f.World.Attributes.GameMode="Classic";f.Roles("Hero","Murderer")
    snapshot=c.Snapshot()
    check(snapshot.Supported and snapshot.Role=="Hero" and snapshot.Maps==1 and snapshot.PlayerRows==2,"supported diagnostics expose mode and aggregate readiness")
    snapshot.Mode="changed";check(c.Mode()=="Classic","snapshot cannot mutate runtime")
    f.Round.PlayerData={[1]={Role="Sheriff"},["2"]={Role="Murderer"}}
    check(c.Role(f.Own)=="Sheriff" and c.Role(f.Other)=="Murderer","numeric and string user ID row keys supported")
    f.Round.PlayerData=false
    check(c.Role(f.Own)=="Unknown","malformed role table handled without errors")
end
local Color3={fromRGB=function(r,g,b) return {r,g,b} end}
-- INSERT_COLORS
local function roleFor(p) return p.Role end
-- INSERT_VISUAL_ROLE
for _,role in ipairs({"Zombie","Survivor","Freezer","Runner","Murderer","Sheriff","Hero","Innocent"}) do
    check(visualRoleFor({Role=role})==role and colors[role]~=nil,"ESP retains role and color: "..role)
end
check(visualRoleFor({Role="unrecognized"})=="Unknown","unknown ESP stays neutral")
-- INSERT_TACTICAL
do
    local policy=createTacticalPolicy()
    local own={Active=true,Mode="Infection",Role="Zombie",Position=vector(0,0,0),Players={},Destinations={}}
    local ally={Id=1,Name="ally",Role="Zombie",Position=vector(2,0,0),Enemy=false}
    local enemy={Id=2,Name="enemy",Role="Survivor",Position=vector(20,0,0),Enemy=true,Visible=true}
    own.Players={ally,enemy}
    local decision=policy.Decide(own)
    check(decision.Target==enemy and decision.Goal==enemy.Position,"event guidance approaches an opponent and skips a closer ally")
    enemy.Position=vector(4,0,0);decision=policy.Decide(own)
    check(decision.Goal==nil and decision.Instruction:find("Stab",1,true),"nearby zombie guidance does not suggest throwing")
    own.Role="Survivor";own.Weapon="Gun";own.Enabled=true;enemy.Role="Zombie";enemy.Position=vector(20,0,0)
    decision=policy.Decide(own)
    check(decision.Target==enemy and decision.Instruction:find("aim",1,true),"survivor guidance uses visible zombie target")
    own.Mode="FreezeTag";own.Role="Runner";enemy.Role="Freezer";enemy.Enemy=false;enemy.Threat=true
    own.Destinations={{Name="clear",Position=vector(-40,0,0)}}
    decision=policy.Decide(own)
    check(decision.Kind=="Retreat" and decision.DestinationName=="clear","runner guidance chooses a destination farther from the freezer")
    own.Frozen=true
    check(policy.Decide(own).Instruction:find("Frozen",1,true),"frozen runner guidance waits for a teammate")
    own.Frozen=false;own.Mode="unsupported"
    check(policy.Decide(own).Goal==nil,"unknown-mode guidance cannot plan a classic route")
end
-- INSERT_LEARNED_POLICY
do
    local marker={Instruction="event rule"}
    local state={Config={LearnedSheriffGuide=true}}
    local model={Metadata={},Infer=function() error("event must not invoke Classic actor") end}
    local policy=createLearnedPolicy({State=state,Model=model,BasePolicy={Decide=function() return marker end,RouteAllowed=function() return true end}})
    check(policy.Decide({Active=true,Mode="Infection",Role="Sheriff"})==marker
        and state.LearnedSheriff.Reason=="Event mode uses rule guidance","event modes use rule guidance without invoking the Classic trained actor")
end
print(string.format("%d game-mode assertions passed",passed))
