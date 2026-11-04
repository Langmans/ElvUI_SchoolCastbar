-- The plugin's page in ElvUI's options, among the plugins in its side bar, in three tabs:
-- - General: the bars it colours, the gradient, reading the description;
-- - Colours: a colour per school, and the defaults back;
-- - Spells: a spell's schools of the player's own choice, for one the plugin gets wrong or does not
--   know. The list holds the spells cast this session and those with a choice; a name or a spell ID
--   picks any other. The ticks start from the schools the spell has now.

local addon, ns = ... ---@type string, SchoolCastbarNamespace
local E, P = ElvUI[1], ElvUI[4]
local L = LibStub("AceLocale-3.0"):GetLocale(addon)
local S = ns.Schools

-- The plugin's name in the side bar, in the Fire colour.
local TITLE = "|cffff8000%s|r"

-- The spell picked on the Spells tab, by name.
---@type string?
local picked

---The schools the picked spell has now, and where they come from.
---@return number? mask
---@return string? source
local function PickedSchools()
    return S.Of(ns.seen[picked] or nil, picked)
end

---A tick on the General tab.
---@param order number
---@param key string the locale key of its name; its description, if any, is key .. "_DESC"
---@return table
local function Toggle(order, key)
    return { type = "toggle", order = order, name = L[key], desc = rawget(L, key .. "_DESC") }
end

---@return table
local function GeneralTab()
    local db = ns.db
    local args = {
        units = { type = "header", order = 0, name = L.UNITS },
        settings = { type = "header", order = 10, name = "" },
        gradient = Toggle(11, "GRADIENT"),
        tooltip = Toggle(12, "TOOLTIP"),
    }
    for order, unit in ipairs(ns.unitOrder) do
        args[unit] = Toggle(order, unit)
    end
    return {
        type = "group",
        order = 1,
        name = L.GENERAL,
        ---@param info string[]
        ---@return boolean
        get = function(info)
            local key = info[#info]
            if ns.units[key] then return db().units[key] end
            return db()[key] --[[@as boolean]]
        end,
        ---@param info string[]
        ---@param value boolean
        set = function(info, value)
            local key = info[#info]
            if ns.units[key] then
                db().units[key] = value
            else
                db()[key] = value
            end
            ns.RepaintAll()
        end,
        args = args,
    }
end

---@return table
local function ColorsTab()
    local args = {
        reset = {
            type = "execute",
            order = 100,
            name = L.RESET,
            func = function()
                for school, color in pairs(P.schoolCastbar.colors) do
                    local own = ns.db().colors[school]
                    own.r, own.g, own.b = color.r, color.g, color.b
                end
                ns.RepaintAll()
            end,
        },
    }
    for order, school in ipairs(S.order) do
        args[school] = { type = "color", order = order, name = L[school] }
    end
    return {
        type = "group",
        order = 2,
        name = L.COLORS,
        ---@param info string[]
        ---@return number, number, number
        get = function(info)
            local c = ns.db().colors[info[#info]]
            return c.r, c.g, c.b
        end,
        ---@param info string[]
        ---@param r number
        ---@param g number
        ---@param b number
        set = function(info, r, g, b)
            local c = ns.db().colors[info[#info]]
            c.r, c.g, c.b = r, g, b
            ns.RepaintAll()
        end,
        args = args,
    }
end

---@return boolean
local function NothingPicked()
    return picked == nil
end

---@return table
local function SpellsTab()
    local args = {
        desc = { type = "description", order = 0, name = L.SPELLS_DESC },
        add = {
            type = "input",
            order = 1,
            name = L.ADD,
            get = function()
                return ""
            end,
            ---@param _ string[]
            ---@param text string a spell name, or a spell ID
            set = function(_, text)
                local id = tonumber(text)
                local name = id and C_Spell.GetSpellName(id) or text
                if id and name then ns.seen[name] = id end
                picked = name
            end,
        },
        spell = {
            type = "select",
            order = 2,
            name = L.SPELL,
            desc = L.SPELL_DESC,
            values = function()
                local values = {}
                for name in pairs(ns.seen) do
                    values[name] = name
                end
                for name in pairs(S.overrides) do
                    values[name] = name
                end
                return values
            end,
            get = function()
                return picked
            end,
            ---@param _ string[]
            ---@param name string
            set = function(_, name)
                picked = name
            end,
        },
        source = {
            type = "description",
            order = 3,
            ---@return string
            name = function()
                if not picked then return "" end
                local _, source = PickedSchools()
                return L.SOURCE:format(L["SOURCE_" .. (source or "none")]) --[[@as string]]
            end,
        },
        remove = {
            type = "execute",
            order = 20,
            name = L.REMOVE,
            disabled = function()
                return not (picked and S.overrides[picked])
            end,
            func = function()
                S.overrides[picked] = nil
                ns.RepaintAll()
            end,
        },
    }
    for order, school in ipairs(S.order) do
        args[school] = { type = "toggle", order = 10 + order, name = L[school], hidden = NothingPicked }
    end
    return {
        type = "group",
        order = 3,
        name = L.SPELLS,
        ---@param info string[]
        ---@return boolean
        get = function(info)
            local mask = PickedSchools() or 0
            return bit.band(mask, S.masks[info[#info]] --[[@as number]]) ~= 0
        end,
        ---@param info string[]
        ---@param on boolean
        set = function(info, on)
            local mask, school = PickedSchools() or 0, S.masks[info[#info]] --[[@as number]]
            if on then
                mask = bit.bor(mask, school)
            elseif bit.band(mask, school) ~= 0 then
                mask = mask - school
            end
            S.overrides[picked] = mask > 0 and mask or nil
            ns.RepaintAll()
        end,
        args = args,
    }
end

---LibElvUIPlugin calls this once ElvUI's options are loaded.
function ns.InsertOptions()
    if not E.Options then return end
    E.Options.args[addon] = {
        type = "group",
        name = TITLE:format(L.OPTIONS),
        childGroups = "tab",
        args = {
            desc = { type = "description", order = 0, name = L.OPTIONS_DESC },
            general = GeneralTab(),
            colors = ColorsTab(),
            spells = SpellsTab(),
        },
    }
end
