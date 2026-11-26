local passed=0
local function check(value,message) assert(value,message); passed+=1; print("PASS: "..message) end
local Enum={
    KeyCode={RightShift="RightShift",F10="F10",End="End",H="H"},
    UserInputState={Begin="Begin",End="End"},
    ContextActionResult={Sink="Sink",Pass="Pass"},
    ContextActionPriority={High={Value=2000}},
}
local function keyCode(name) return Enum.KeyCode[name] end
local toggles,stops=0,0
local window={Toggle=function() toggles+=1 end}
local State={Running=true,Config={Keybinds={Menu="F10",Stop="End"}},
    EmergencyStop=function() stops+=1 end}
local mobile={Destroyed=false,TriggerEmergencyStop=function() stops+=1 end}
local focused,mode=false,"PC"
local UIS={InputBegan={}}
function UIS:GetFocusedTextBox() return focused and {} or nil end
local function getMode() return mode end
local callbacks={}
local function connect(signal,callback) callbacks[signal]=callback end
local actionService={Actions={}}
function actionService:BindActionAtPriority(name,callback,_,priority,...)
    self.Actions[name]={Callback=callback,Keys={...},Priority=priority}
end
function actionService:UnbindAction(name) self.Actions[name]=nil end
local menuAction,emergencyAction="TestMenu","TestStop"
local menuBound,emergencyBound=false,false
-- INSERT_MENU_INPUT
local function hasBind(action,key)
    local binding=actionService.Actions[action]
    for _,boundKey in ipairs(binding and binding.Keys or {}) do
        if boundKey==key then return true end
    end
    return false
end
local function press(action)
    local binding=actionService.Actions[action]
    return binding and binding.Callback(action,Enum.UserInputState.Begin)
end
check(hasBind(menuAction,"RightShift") and hasBind(menuAction,"F10"),
    "saved F10 menu shortcut also binds the permanent Right Shift alias")
check(press(menuAction)=="Sink" and toggles==1,
    "right shift action opens and closes the menu through the native context binding")
focused=true
check(press(menuAction)=="Pass" and toggles==1,"menu shortcut does not interrupt text input")
focused=false
mode="Mobile"
check(press(menuAction)=="Pass" and toggles==1,"menu shortcut does not steal mobile controls")
mode="PC"
State.Config.Keybinds.Menu="RightShift"
mobile.BindMenuKeys()
check(hasBind(menuAction,"RightShift") and #actionService.Actions[menuAction].Keys==1,
    "default Right Shift binds exactly once")
State.Config.Keybinds.Menu="H"
mobile.BindMenuKeys()
check(hasBind(menuAction,"H") and hasBind(menuAction,"RightShift") and not hasBind(menuAction,"F10"),
    "changing the optional menu key keeps Right Shift while replacing the old shortcut")
check(#actionService.Actions[menuAction].Keys==2,"menu action binds exactly two distinct shortcut keys")
check(actionService.Actions[emergencyAction] and hasBind(emergencyAction,"End"),
    "emergency stop remains independently bound to End")
do
    local actionService=nil
    local mobile={Destroyed=false}
    local callbacks={}
    local UIS={InputBegan={}}
    function UIS:GetFocusedTextBox() return focused and {} or nil end
    local function connect(signal,callback) callbacks[signal]=callback end
    local menuBound,emergencyBound=false,false
    local window={Toggle=function() toggles+=1 end}
    State.Config.Keybinds.Menu="F10"
    -- INSERT_MENU_FALLBACK
    local before=toggles
    callbacks[UIS.InputBegan]({KeyCode="RightShift"},true)
    check(toggles==before+1,"fallback Right Shift opens UI even when native camera processed the key")
    callbacks[UIS.InputBegan]({KeyCode="F10"},false)
    check(toggles==before+2,"fallback also accepts the optional saved F10 key")
    callbacks[UIS.InputBegan]({KeyCode="F10"},true)
    check(toggles==before+2,"fallback ignores processed non-Shift shortcuts")
    focused=true
    callbacks[UIS.InputBegan]({KeyCode="RightShift"},false)
    check(toggles==before+2,"fallback Right Shift does not interrupt typing")
    focused=false
end
print(passed.." menu shortcut assertions passed")
