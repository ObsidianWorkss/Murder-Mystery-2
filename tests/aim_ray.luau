-- Tests against the production gun sampling and reliable-part policy.
local State = {}
local rayDistance
local hitAt
local workspace = {
    Raycast = function(_, origin, direction)
        rayDistance = direction.Magnitude
        if hitAt and rayDistance >= hitAt then return {Position = origin + direction.Unit * hitAt} end
        return nil
    end,
}
local meta = {}
local function vec(x, y, z)
    return setmetatable({X = x, Y = y, Z = z}, meta)
end
meta.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
meta.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
meta.__mul = function(a, b)
    if type(a) == "number" then a, b = b, a end
    return vec(a.X * b, a.Y * b, a.Z * b)
end
meta.__index = function(a, key)
    if key == "Magnitude" then return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z) end
    if key == "Unit" then
        local length = math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
        return vec(a.X / length, a.Y / length, a.Z / length)
    end
end

-- INSERT_RELIABLE_PART
-- INSERT_SAMPLE_RAY

local passed = 0
local function check(label, condition)
    assert(condition, label)
    passed += 1
end

local safe = State.GunReliablePartNames({
    "UpperTorso", "Torso", "LowerTorso", "Head", "HumanoidRootPart",
    "RightUpperArm", "LeftLowerLeg", "RightHand", "LeftFoot",
})
check("reliable gun points retain torso, head and optional visible root", #safe == 5)
check("reliable gun points keep torso first", safe[1] == "UpperTorso" and safe[2] == "Torso")
check("reliable gun points reject limb-only candidates",
    #State.GunReliablePartNames({"LeftFoot", "RightUpperArm", "LeftLowerLeg"}) == 0)

local origin, target = vec(0, 0, 0), vec(0, 0, 10)
hitAt = 9.9
check("body before the sampled point remains valid", sampleRayHitsBody(origin, target, {}) == true)
hitAt = 10.12
check("body just after the sampled point allows tiny tolerance", sampleRayHitsBody(origin, target, {}) == true)
hitAt = 10.3
check("body beyond the chosen point is not a false-positive aim hit",
    sampleRayHitsBody(origin, target, {}) == false)
check("ray validation does not scan 8 studs behind the target", rayDistance < 10.2)
hitAt = nil
check("unobstructed ray with no body hit is rejected", sampleRayHitsBody(origin, target, {}) == false)
check("zero-length aim ray is rejected", sampleRayHitsBody(origin, origin, {}) == false)

print(("%d aim ray assertions passed"):format(passed))
