local passed=0
local function check(value,message)
    assert(value,message)
    passed+=1
end
-- INSERT_PHONE
for _,closed in ipairs({false,true}) do
    local av={StartClosed=closed}
    local opened=0
    local aw={UIElements={Main={Visible=true}},Closed=false,CanDropdown=true}
    function aw:Open() opened+=1 end
    -- INSERT_WINDOW_START
    check(opened==(closed and 0 or 1),"closed phone startup never queues the library's automatic Open")
    if closed then check(aw.Closed and not aw.UIElements.Main.Visible and not aw.CanDropdown,"closed startup matches the menu's hidden state") end
end
local cfg={MobileShortcuts=true,MobileShowStatus=false,MobileStartClosed=true,
    Invisibility=false,SpeedBoost=false,KillAura=false,Triggerbot=false,KnifeTriggerbot=false,AutoKnifeDodge=true}
local state={Running=true,Config=cfg,KillAll={Active=false}}
local typing=false
local calls,toasts={},{}
local ui={Mode="Mobile",MenuOpen=false,Destroyed=false}
function ui.Toast(text,tone) table.insert(toasts,{Text=text,Tone=tone}) end
function ui.SetOption(id,value)
    table.insert(calls,{Id=id,Value=value})
    cfg[id]=value
    return value
end
local stops,starts,killStops=0,0,0
function ui.TriggerEmergencyStop() stops+=1; cfg.AutoKnifeDodge=false; return true end
function ui.RunKillAll(retry)
    check(retry==false,"phone starts the existing action, not a retry")
    starts+=1
    state.KillAll.Active=true
    return true,"started"
end
function state.StopKillAll() killStops+=1; state.KillAll.Active=false; return true end
local controls=createPhoneControls({State=state,UI=ui,Typing=function() return typing end})
check(controls.Visible() and controls.StartClosed(),"shortcuts and closed-menu startup are phone defaults")
check(not controls.ShowStatus(),"phone instructions are hidden by default")
check(not cfg.Invisibility and not cfg.SpeedBoost and not cfg.Triggerbot and not cfg.KillAura,
    "constructing phone shortcuts does not enable automation")
check(#calls==0 and starts==0,"constructing the dock sends no actions")
local primary,more={},{}
for _,entry in ipairs(controls.Items) do table.insert(entry.More and more or primary,entry.Id) end
check(table.concat(primary,",")=="Invisibility,SpeedBoost,UniversalTriggerbot,KillAura","requested shortcuts occupy the main dock")
check(table.concat(more,",")=="Fly,Noclip,AutoKnifeDodge,KillAll","extra actions stay under More")
check(controls.Press("SpeedBoost") and cfg.SpeedBoost and calls[#calls].Id=="SpeedBoost","speed uses the menu setter")
check(toasts[#toasts].Text=="Speed on" and toasts[#toasts].Tone=="on","on state is announced")
check(controls.Press("SpeedBoost") and not cfg.SpeedBoost and toasts[#toasts].Tone=="off","second tap turns speed off")
check(controls.Press("Invisibility") and cfg.Invisibility,"invisibility calls its feature setter")
check(controls.Press("KillAura") and cfg.KillAura and calls[#calls].Id=="KillAura","aura calls its feature setter")
check(controls.Press("UniversalTriggerbot") and cfg.Triggerbot and cfg.KnifeTriggerbot,"one phone button enables both triggerbots")
check(controls.Press("UniversalTriggerbot") and not cfg.Triggerbot and not cfg.KnifeTriggerbot,"second tap disables both triggerbots")
cfg.KnifeTriggerbot=true
check(controls.Press("UniversalTriggerbot") and not cfg.Triggerbot and not cfg.KnifeTriggerbot,"mixed trigger state turns both off")
local original=ui.SetOption
function ui.SetOption(id,value)
    if id=="Invisibility" then return false,"A living character is required" end
    return original(id,value)
end
local accepted,_,reason=controls.Press("Invisibility")
check(not accepted and reason=="A living character is required","feature refusal is preserved")
check(toasts[#toasts].Tone=="warn" and toasts[#toasts].Text==reason,"refused actions display the real reason")
function ui.SetOption(id,value) error("setter failed") end
accepted=controls.Press("Invisibility")
check(not accepted and not controls.Busy.Invisibility and toasts[#toasts].Tone=="warn","errors release the button and show a failure")
ui.SetOption=original
controls.Busy.Invisibility=true
local before=#calls
check(not controls.Press("Invisibility") and #calls==before,"busy buttons cannot queue duplicate actions")
check(controls.Press("Stop") and stops==1,"Stop remains available while another action is busy")
controls.Busy.Invisibility=nil
check(controls.Press("KillAll") and starts==1 and state.KillAll.Active,"Kill all dispatches only on a deliberate tap")
check(controls.Press("KillAll") and killStops==1 and not state.KillAll.Active,"active Kill all can be stopped from the same button")
function ui.RunKillAll() return false,"Kill all requires a living murderer" end
accepted,_,reason=controls.Press("KillAll")
check(not accepted and reason=="Kill all requires a living murderer" and starts==1,"refused Kill all never falls back to another attack")
for _,block in ipairs({"Menu","Typing","PC","Destroyed","Unloaded"}) do
    ui.MenuOpen=block=="Menu"; typing=block=="Typing"; ui.Mode=block=="PC" and "PC" or "Mobile"
    ui.Destroyed=block=="Destroyed"; state.Running=block~="Unloaded"
    local count=#calls
    check(not controls.Press("SpeedBoost") and #calls==count,block.." prevents shortcut activation")
    check(not controls.Press("Stop") and stops==1,block.." prevents stale Stop callbacks")
    if block~="Typing" then check(not controls.Visible(),block.." hides the dock") end
end
ui.MenuOpen=false; typing=false; ui.Mode="PC"; ui.Destroyed=false; state.Running=true
check(controls.ShowStatus() and not controls.StartClosed(),"desktop HUD and startup stay unchanged")
ui.Mode="Mobile"; cfg.MobileShowStatus=true
check(controls.ShowStatus(),"phone instructions can be explicitly enabled")
cfg.MobileShortcuts=false; cfg.MobileStartClosed=false
check(not controls.Visible() and not controls.StartClosed(),"phone preferences can be disabled")
check(not controls.Press("Unknown"),"unknown actions are ignored")
local function overlaps(a,b)
    return a.X<b.X+b.W and b.X<a.X+a.W and a.Y<b.Y+b.H and b.Y<a.Y+a.H
end
for _,screen in ipairs({{320,568},{390,844},{430,932},{568,284},{667,339},{844,354},{1024,732}}) do
    local w,h=table.unpack(screen)
    local layout=controls.Layout(w,h)
    for _,id in ipairs({"Dock","More","Weapon","Icon","Fly"}) do
        local r=layout[id]
        check(r.X>=6 and r.Y>=6 and r.X+r.W<=w-6 and r.Y+r.H<=h-6,id.." stays on screen after orientation changes")
        check(r.Y+r.H<=h-130,id.." defaults above the native bottom controls")
    end
    check(not overlaps(layout.Dock,layout.More),"More opens beside the main dock")
    check(not overlaps(layout.Dock,layout.Weapon),"weapon buttons do not overlap shortcuts")
    check(not overlaps(layout.Fly,layout.Weapon) and not overlaps(layout.Fly,layout.Icon),"fly, menu and weapon buttons remain separate")
    check(layout.Menu.W<=w-16 and layout.Menu.H<=h-16,"full menu fits portrait and landscape")
end
print(string.format("%d phone-control assertions passed",passed))
