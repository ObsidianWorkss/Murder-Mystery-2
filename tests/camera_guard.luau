local passed=0
local function check(ok,message) assert(ok,message); passed+=1; print("PASS: "..message) end
local now=100
local os={clock=function() return now end}
local Enum={
    CameraType={Custom="Custom"},CameraMode={LockFirstPerson="FirstPerson"},
    MouseBehavior={Default="Default",LockCenter="LockCenter",LockCurrentPosition="LockCurrentPosition"},
    RotationType={CameraRelative="CameraRelative",MovementRelative="MovementRelative"},
}
local hum={Health=100}
local char={}
function char:FindFirstChildOfClass(name) return name=="Humanoid" and hum or nil end
local player={Character=char,CameraMode="Classic"}
local workspace={CurrentCamera={CameraType="Custom",CameraSubject=hum}}
local UIS={MouseEnabled=true,MouseBehavior="LockCurrentPosition"}
local GuiService={MenuIsOpen=false}
local vr={VREnabled=false}
local module={Parent=true}
local settings={RotationType="MovementRelative"}
local held,rotating,togglePan=false,false,false
local cameraToggle=true
local cameras={activeCameraController={enabled=true,inMouseLockedMode=false,inFirstPerson=false,isCameraToggle=true}}
local input={
    getTogglePan=function() return togglePan end,
    getHoldPan=function() return held end,
    getRotationActivated=function() return rotating end,
}
local overrides=0
local utils={
    setMouseBehaviorOverride=function(value) overrides+=1; UIS.MouseBehavior=value end,
    restoreMouseBehavior=function() end,
    setRotationTypeOverride=function(value) settings.RotationType=value end,
    restoreRotationType=function() end,
}
local State={Running=true}
local guard={Status="Waiting",Corrections=0}
local function touchInput() return false end
-- INSERT_CAMERA_GUARD
held=true
check(not State.CheckCameraLock() and UIS.MouseBehavior=="LockCurrentPosition"
    and guard.Corrections==0 and overrides==0,
    "native camera-toggle hold-pan retains its intentional cursor lock")
held=false
check(State.CheckCameraLock() and UIS.MouseBehavior=="Default" and guard.Corrections==1,
    "a stale cursor lock with no active native camera input is released")
UIS.MouseBehavior="LockCurrentPosition"
now+=.01
check(not State.CheckCameraLock() and guard.Corrections==1 and UIS.MouseBehavior=="LockCurrentPosition",
    "camera guard does not fight a repeating native lock on every frame")
now+=.05
check(State.CheckCameraLock() and guard.Corrections==2 and UIS.MouseBehavior=="Default",
    "camera guard retries a persistent stale lock after 50 ms")
UIS.MouseBehavior="LockCurrentPosition"
rotating=true
check(not State.CheckCameraLock() and UIS.MouseBehavior=="LockCurrentPosition",
    "actively rotating the native camera retains the held cursor")
rotating=false
togglePan=true
check(not State.CheckCameraLock() and UIS.MouseBehavior=="LockCurrentPosition",
    "native camera-toggle pan lock remains untouched")
togglePan=false
cameras.activeCameraController.inMouseLockedMode=true
check(not State.CheckCameraLock() and UIS.MouseBehavior=="LockCurrentPosition",
    "selected native Shift Lock remains untouched")
cameras.activeCameraController.inMouseLockedMode=false
UIS.MouseBehavior="LockCenter"
settings.RotationType="CameraRelative"
now+=.06
check(State.CheckCameraLock() and settings.RotationType=="MovementRelative",
    "stale native rotation mode is restored when no camera lock was selected")
print(passed.." camera guard assertions passed")
