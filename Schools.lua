-- A spell's school, as the client's school mask (one bit per school). The game has no call for it,
-- so it comes from, first to last:
--
-- - the player's own choice (the Spells tab), by spell name;
-- - the client's spell table (Data\), by spell ID: the class spells with a cast bar;
-- - the combat log, by spell name: on Classic Era each cast names its school there, and what it
--   names is kept (WoW: Forever gives addons no combat log);
-- - the spell's description: the first school it deals damage in ("Fire damage"), read once per
--   spell.

local _, ns = ... ---@type string, SchoolCastbarNamespace

---@class SchoolCastbarSchools
local S = {}
ns.Schools = S

-- The client's school masks (Enum.Damageclass), with their values for a client that lacks the enum.
local Damageclass = Enum and Enum.Damageclass
    or {
        MaskPhysical = 1,
        MaskHoly = 2,
        MaskFire = 4,
        MaskNature = 8,
        MaskFrost = 16,
        MaskShadow = 32,
        MaskArcane = 64,
    }

-- The schools by name, each its bit in the mask; and in the order of their bits.
---@type table<string, number>
S.masks = {
    physical = Damageclass.MaskPhysical,
    holy = Damageclass.MaskHoly,
    fire = Damageclass.MaskFire,
    nature = Damageclass.MaskNature,
    frost = Damageclass.MaskFrost,
    shadow = Damageclass.MaskShadow,
    arcane = Damageclass.MaskArcane,
}
---@type string[]
S.order = { "physical", "holy", "fire", "nature", "frost", "shadow", "arcane" }

-- Where a school came from, as Of returns it.
S.sources = { override = "override", data = "data", combatlog = "combatlog", tooltip = "tooltip" }

-- Kept between sessions (SavedVariables): the player's choices and what the combat log named, by
-- spell name. Set up by Load.
---@type table<string, number>
S.overrides = {}
---@type table<string, number>
S.learned = {}

-- Read from descriptions this session, by spell ID: the mask, or false for none.
---@type table<number, number|false>
local described = {}

-- All schools at once: the one combination with Physical in it that counts as a school's name.
local ALL_SCHOOLS = 127

-- Where a word starts and ends, as Lua patterns (frontiers). A letter is %w or any byte of a UTF-8
-- character (128-255): Lua's %w knows only A to Z, so Cyrillic and the like would never start one.
local WORD_START = "%f[%w\128-\255]"
local WORD_END = "%f[^%w\128-\255]"

---A text as a pattern that matches it literally.
---@param text string
---@return string
local function Literal(text)
    return (text:gsub("%p", "%%%0"))
end

---The client's school names with their masks, in lower case and as patterns, longest first, so
---where two start at the same place the longer one wins. Combinations with Physical in them are
---left out, but for all schools at once: their names (Flamestrike, Spellstrike) are spells' names
---too. Built once, on first use.
---@type {name: string, mask: number}[]?
local schoolNames

---@return {name: string, mask: number}[]
local function SchoolNames()
    if schoolNames then return schoolNames end
    schoolNames = {}
    for mask = 1, ALL_SCHOOLS do
        local name = C_Spell.GetSchoolString(mask)
        local physical = mask ~= S.masks.physical and bit.band(mask, S.masks.physical) ~= 0
        -- A combination without a name of its own comes back as a list ("Fire, Frost").
        if name and name ~= "" and not name:find("[,%s]") and (not physical or mask == ALL_SCHOOLS) then
            schoolNames[#schoolNames + 1] = { name = Literal(name:lower()), mask = mask }
        end
    end
    ---@param a {name: string}
    ---@param b {name: string}
    ---@return boolean
    local function longerFirst(a, b)
        return #a.name > #b.name
    end
    table.sort(schoolNames, longerFirst)
    return schoolNames
end

---The school whose name comes first in a text, at the start of a word, and with damage given: as
---"<school> <damage>", the two whole words with any space between. Both in lower case, as a
---description may write them in any capitals; nil for none.
---@param text string in lower case
---@param damage string? the client's word for damage, in lower case, as a pattern
---@return number?
local function FirstSchool(text, damage)
    local tail = damage and ("%s+" .. damage .. WORD_END) or ""
    local bestAt, bestMask
    for _, entry in ipairs(SchoolNames()) do
        local at = text:find(WORD_START .. entry.name .. tail)
        if at and (not bestAt or at < bestAt) then
            bestAt, bestMask = at, entry.mask
        end
    end
    return bestMask
end

---The school a description deals damage in: the first "<school> damage" in it, in the client's
---words (DAMAGE). Languages that join the two into one word ("Frostschaden") or put the school
---after damage ("dégâts de feu") are read for the first school's name at a word's start instead.
---@param text string
---@return number?
local function FromText(text)
    text = text:lower()
    local mask = FirstSchool(text, Literal((DAMAGE or "Damage"):lower()))
    if mask then return mask end
    local locale = GetLocale()
    if locale ~= "enUS" and locale ~= "enGB" then return FirstSchool(text) end
    return nil
end

---The school its description names, read once; nil while the client has no text for it yet. A
---school found goes to the debug addons: the spell is missing from the spell data.
---@param id number
---@param name string?
---@return number?
local function Described(id, name)
    local known = described[id]
    if known ~= nil then return known or nil end
    local text = C_Spell.GetSpellDescription(id)
    if not text or issecretvalue(text) or text == "" then return nil end
    local mask = FromText(text)
    described[id] = mask or false
    if mask then
        local spell = name or "?"
        ns.Log(
            "info",
            "tooltip: {1} ({2}) is not in the spell data; its description says {3}",
            spell,
            id,
            C_Spell.GetSchoolString(mask) or mask
        )
        ns.Log("debug", "tooltip: {1}'s description: {2}", spell, text)
        ns.Count("tooltip")
    end
    return mask
end

---A spell's school mask and where it came from; nil when nothing knows it.
---@param id number|nil the spell ID; a hidden one (issecretvalue) is skipped
---@param name string|nil the spell's name; a hidden one is skipped
---@return number? mask
---@return string? source one of S.sources
function S.Of(id, name)
    if issecretvalue(id) then id = nil end
    if issecretvalue(name) then name = nil end
    ---@type number?
    local mask = name and S.overrides[name] or nil
    if mask then return mask, S.sources.override end
    mask = id and ns.data and ns.data[id] or nil
    if mask then return mask, S.sources.data end
    mask = name and S.learned[name] or nil
    if mask then return mask, S.sources.combatlog end
    mask = id and ns.db().tooltip and Described(id, name) or nil
    if mask then return mask, S.sources.tooltip end
    return nil
end

---Keeps the school the combat log gave a spell. Whether that changed what is known.
---@param name string
---@param mask number
---@return boolean
function S.Learn(name, mask)
    if not mask or mask == 0 or S.learned[name] == mask then return false end
    S.learned[name] = mask
    return true
end

---Fills out with a mask's school names in the order of their bits; returns how many. out is the
---caller's own list, reused: entries past the count are cleared.
---@param mask number
---@param out string[]
---@return number
function S.Split(mask, out)
    local count = 0
    for _, school in ipairs(S.order) do
        if bit.band(mask, S.masks[school]) ~= 0 then
            count = count + 1
            out[count] = school
        end
    end
    for i = count + 1, #out do
        out[i] = nil
    end
    return count
end

---Connects the saved tables, made on the first session.
function S.Load()
    ElvUI_SchoolCastbarDB = ElvUI_SchoolCastbarDB or {}
    local saved = ElvUI_SchoolCastbarDB
    saved.overrides = saved.overrides or {}
    saved.learned = saved.learned or {}
    S.overrides, S.learned = saved.overrides, saved.learned
end
