-- The bridge to the debug addons, the only file that talks to them. The plugin sends to each one
-- that is installed:
--
-- - OAP Debug (a debug window: log, inspector, metrics, Lua errors; /oapd). The plugin registers
--   with it under its folder (so its Lua errors are filed under it), sends log lines and counts.
-- - _DebugLog (DLAPI: a window of log tabs). The same lines go to the plugin's tab as text; flags
--   before the text colour it (ERR~, WARN~), mark detail (2~) or name a category (tooltip~).
--
-- How much goes is the setting every OAP addon has: errors only, normal, normal + metrics (the
-- default), detailed; it is kept in ElvUI's profile as schoolCastbar.oapDebug.

local addon, ns = ... ---@type string, SchoolCastbarNamespace
local P = ElvUI[4]

local ICON = "Interface\\Icons\\Spell_Fire_FlameBolt"
local ERRORS, NORMAL, METRICS, DETAILED = 1, 2, 3, 4
local LEVELS = { errors = ERRORS, normal = NORMAL, metrics = METRICS, detailed = DETAILED }
-- What a log line of each kind needs, and its flag in _DebugLog.
local NEEDS = { error = ERRORS, warn = NORMAL, info = NORMAL, debug = DETAILED }
local FLAGS = { error = "ERR~", warn = "WARN~", info = "", debug = "2~" }

-- The setting's choices, in the options' order.
ns.debugLevels = { "errors", "normal", "metrics", "detailed" }
P.schoolCastbar.oapDebug = "metrics"

-- The debug addons' tables, found once at login (OptionalDeps loads them first); nil without them.
---@type OAPDebugApi?
local api
---@type DebugLogApi?
local dl

---Finds the debug addons and registers the plugin with OAP Debug.
function ns.ConnectDebug()
    api = rawget(_G, "OAPDebug") --[[@as OAPDebugApi?]]
    dl = rawget(_G, "DLAPI") --[[@as DebugLogApi?]]
    if api then api.Register(addon, { title = addon, folder = addon, icon = ICON }) end
end

---Whether a debug addon is installed.
---@return boolean
function ns.HasDebugAddon()
    return api ~= nil or dl ~= nil
end

---@return number
local function Level()
    return LEVELS[ns.db().oapDebug] or METRICS
end

---A log line: "error", "warn", "info" or "debug"; values fill {1}, {2}, ... A word and a colon
---first ("tooltip: ...") is the line's category in _DebugLog.
---@param kind "error"|"warn"|"info"|"debug"
---@param msg string
---@param ... string|number
function ns.Log(kind, msg, ...)
    if not ns.HasDebugAddon() or Level() < NEEDS[kind] then return end
    if api then api.Log(addon, msg, kind, ...) end
    if not dl then return end
    local values = { ... }
    local text = msg:gsub(
        "{(%d+)}",
        ---@param n string
        ---@return string
        function(n)
            return tostring(values[tonumber(n)])
        end
    )
    local category, rest = text:match("^([%w_]+): (.*)$")
    -- "%s": a % in the line is not read as a format.
    dl.DebugLog(addon, "%s", FLAGS[kind] .. (category and category .. "~" .. rest or text))
end

---Counts something that happens, from Normal + metrics.
---@param name string
function ns.Count(name)
    if api and Level() >= METRICS then api.Count(addon, name) end
end
