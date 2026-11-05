-- The plugin's ElvUI module: it takes over nothing, but paints after ElvUI on the cast bars of the
-- player, the target, the focus, the pet, the bosses, the arena opponents and the party (Paint.lua).
--
-- ElvUI sets its cast callbacks (PostCastStart and the rest) on each bar when it builds the frame,
-- so the plugin wraps them on the bar itself: at login on every frame oUF spawned so far (the party
-- buttons have no fixed names), and through UF.Configure_Castbar, which ElvUI runs for each frame
-- on every settings change, on a frame built later (the focus frame turned on, say).
-- On the classic clients the combat log names each cast's school (Schools.lua); a spell whose text
-- the client loads late (SPELL_TEXT_UPDATE) is read again.

local addon, ns = ... ---@type string, SchoolCastbarNamespace
local E, P = ElvUI[1], ElvUI[4]
local UF = E:GetModule("UnitFrames")
local S = ns.Schools

-- The bars the plugin paints: ElvUI's unitframeType of their frame, in the options' order.
-- ElvUI's raid frames have no cast bar.
ns.units = {
    player = "player",
    target = "target",
    focus = "focus",
    pet = "pet",
    boss = "boss",
    arena = "arena",
    party = "party",
}
ns.unitOrder = { "player", "target", "focus", "pet", "boss", "arena", "party" }

-- The spells cast this session, for the Spells tab: name to spell ID (false when hidden).
---@type table<string, number|false>
ns.seen = {}

P.schoolCastbar = {
    -- The party's bars only when asked: five more bars in colour can be a lot.
    units = { player = true, target = true, focus = true, pet = true, boss = true, arena = true, party = false },
    gradient = true,
    tooltip = true,
    -- Picked to tell apart on a dark bar: Fire orange, Frost icy blue, Shadow purple and so on.
    colors = {
        physical = { r = 0.78, g = 0.61, b = 0.43 },
        holy = { r = 1, g = 0.9, b = 0.5 },
        fire = { r = 1, g = 0.5, b = 0 },
        nature = { r = 0.3, g = 0.85, b = 0.3 },
        frost = { r = 0.4, g = 0.8, b = 1 },
        shadow = { r = 0.6, g = 0.4, b = 0.9 },
        arcane = { r = 1, g = 0.5, b = 1 },
    },
}

-- Returns the line's fields: time, subevent, ..., spell ID, spell name, school mask (the 14th).
local GetCombatLogInfo = C_CombatLog and C_CombatLog.GetCurrentEventInfo --[[@as (fun(): number, string, boolean, string, string, number, number, string, string, number, number, number, string, number)?]]
-- The combat log lines that start a cast: a cast time's, and a channel's (or an instant's).
local CAST_STARTS = { SPELL_CAST_START = true, SPELL_CAST_SUCCESS = true }

local M = E:NewModule(addon, "AceHook-3.0", "AceEvent-3.0")

---The plugin's settings in the current ElvUI profile.
---@return SchoolCastbarSettings
function ns.db()
    return E.db.schoolCastbar
end

-- The bars wrapped so far, to repaint them.
---@type SchoolCastbarBar[]
local bars = {}

---Paints again each shown bar, or only those whose field key holds value. A field the client hides
---(ns.C.IsSecret) may not be compared, and never matches.
---@param key "spellName"|"spellID"|nil
---@param value string|number|nil
local function Repaint(key, value)
    for _, bar in ipairs(bars) do
        local field = key and bar[key]
        if bar:IsShown() and (not key or (not ns.C.IsSecret(field) and field == value)) then ns.Paint(bar, true) end
    end
end

---Paints every shown bar again, after a settings change.
function ns.RepaintAll()
    Repaint()
end

---Wraps a cast callback on a bar: ElvUI's first, then the plugin's.
---@param bar SchoolCastbarBar
---@param key "PostCastStart"|"PostCastInterruptible"|"PostCastFail"|"PostCastInterrupted"
---@param after fun(bar: SchoolCastbarBar, again: boolean?)
local function Wrap(bar, key, after)
    local own = bar[key]
    ---@param self SchoolCastbarBar
    ---@param unit string
    local function wrapped(self, unit)
        own(self, unit)
        after(self)
    end
    bar[key] = wrapped
end

---Takes a frame's cast bar on, once, if it is one of the plugin's units.
---@param _ table the module
---@param frame SchoolCastbarFrame
function M:Attach(_, frame)
    local bar = frame.Castbar
    if not bar or not ns.units[frame.unitframeType] or bar.schoolWrapped then return end
    bar.schoolWrapped = true
    Wrap(bar, "PostCastStart", ns.Paint)
    Wrap(bar, "PostCastInterruptible", ns.Paint)
    Wrap(bar, "PostCastFail", ns.Clear)
    Wrap(bar, "PostCastInterrupted", ns.Clear)
    bars[#bars + 1] = bar
end

---A combat log line: a cast's school, learned by spell name.
function M:COMBAT_LOG_EVENT_UNFILTERED()
    if not GetCombatLogInfo then return end
    local _, subevent, _, _, _, _, _, _, _, _, _, _, name, school = GetCombatLogInfo()
    if CAST_STARTS[subevent] and S.Learn(name, school) then
        Repaint("spellName", name)
        ns.RefreshSpells()
    end
end

---The spellbook changed: the Spells tab's list takes it in.
function M:SPELLS_CHANGED()
    ns.RefreshSpells()
end

---ElvUI's options window opened.
function M:OptionsToggled()
    ns.OptionsOpened()
end

---The client has a spell's text now: a bar casting it may learn its school from it.
---@param _ string the event
---@param id number
function M:SPELL_TEXT_UPDATE(_, id)
    Repaint("spellID", id)
end

function M:Initialize()
    S.Load()
    ns.ConnectDebug()
    LibStub("LibElvUIPlugin-1.0"):RegisterPlugin(addon, ns.InsertOptions)
    self:SecureHook(UF, "Configure_Castbar", "Attach")
    self:SecureHook(E, "ToggleOptions", "OptionsToggled")
    for _, frame in ipairs(E.oUF.objects) do
        self:Attach(UF, frame)
    end
    -- Retail and WoW: Forever give addons no combat log.
    if GetCombatLogInfo and not E.Modern then self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end
    self:RegisterEvent("SPELL_TEXT_UPDATE")
    self:RegisterEvent("SPELLS_CHANGED")
end

E:RegisterModule(M:GetName())
