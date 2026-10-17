-- MM2 Universal: latest-main loader with actionable startup errors.
-- The complete bundled script remains available as main.lua.
if type(loadstring) ~= "function" then
    error("MM2: this environment does not provide loadstring.", 0)
end
local url = "https://raw.githubusercontent.com/ObsidianWorkss/Murder-Mystery-2/refs/heads/main/main.lua"
local fetched, source = pcall(function() return game:HttpGet(url) end)
if not fetched then error("MM2: download failed. Check your connection and HTTP support, then retry.", 0) end
if type(source) ~= "string" or not source:find("local createLibrary = function", 1, true) then
    error("MM2: the download is not the expected script. Retry later or use main.lua from the repository.", 0)
end
local chunk, message = loadstring(source, "@MM2Universal")
if not chunk then error("MM2: script compilation failed: " .. tostring(message), 0) end
local started, result = pcall(chunk)
if not started then error("MM2: startup failed: " .. tostring(result), 0) end
return result
