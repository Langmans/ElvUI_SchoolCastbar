-- The Spells tab: a list at the left (AceConfig's tree, as ElvUI's tags and BattleCry's triggers)
-- of every spell the plugin knows by name: the player's own choices, the spellbook's spells with a
-- cast bar, what the combat log named and what was cast this session. Each with its icon; one the
-- player turned off in red. Its page ticks its schools as they are now; a tick makes them the
-- player's own choice, every tick off (or the Off tick) turns the spell off, and a button puts its
-- own schools back. Above the list a filter, and a box to add any spell by name or ID.
--
-- ElvUI's options are a table, built once: the list is built again (and ElvUI told to redraw it)
-- when a spell comes in or a choice changes, while ElvUI's window is open; else when it opens.

local addon, ns = ... ---@type string, SchoolCastbarNamespace
local E = ElvUI[1]
local L = LibStub("AceLocale-3.0"):GetLocale(addon)
local S = ns.Schools

-- A spell's page in the list: its key is the prefix and the spell's name.
local PREFIX = "spell:"
-- The icon of a spell the client has none for: the question mark.
local QUESTION_MARK = 134400
local ICON = "|T%d:16:16|t %s"
local OFF_NAME = "|cffff3333%s|r"

-- The tab, once ElvUI's options are loaded; nil before.
---@type table?
local tab
-- What the filter holds, in lower case.
local filter = ""
-- The spells to list, by name: their spell ID, or false where none is known. Filled anew for each
-- build, reused.
---@type table<string, number|false>
local spells = {}
-- Builds the list again and has ElvUI redraw it (below; the pages call it after a change).
local Rebuild ---@type fun()

---Lists a spell, keeping a spell ID it already has.
---@param name string?
---@param id number|false|nil
local function List(name, id)
    if name and not spells[name] then spells[name] = id or false end
end

---Lists a spellbook spell when it has a cast bar: a cast time, or a channel the data has.
---@param id number?
local function ListSpellbookSpell(id)
    local info = id and C_Spell.GetSpellInfo(id)
    if info and (info.castTime > 0 or (ns.data and ns.data[id])) then List(info.name, id) end
end

---Lists the player's spellbook: by skill line on retail and WoW: Forever (C_SpellBook), by tab on
---the classic clients.
local function ListSpellbook()
    if C_SpellBook then
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
            for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local item = C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
                if item and item.itemType == Enum.SpellBookItemType.Spell then ListSpellbookSpell(item.spellID) end
            end
        end
        return
    end
    -- The classic clients' spellbook, which retail and WoW: Forever left for C_SpellBook (above).
    ---@diagnostic disable-next-line: wrong-flavor-api
    for index = 1, GetNumSpellTabs() do
        ---@diagnostic disable-next-line: wrong-flavor-api
        local _, _, offset, count = GetSpellTabInfo(index)
        for slot = offset + 1, offset + count do
            ---@diagnostic disable-next-line: wrong-flavor-api
            local kind, id = GetSpellBookItemInfo(slot, BOOKTYPE_SPELL)
            if kind == "SPELL" then ListSpellbookSpell(id) end
        end
    end
end

---The schools a spell has now, and where they come from.
---@param name string
---@return number? mask
---@return string? source
local function SchoolsOf(name)
    return S.Of(spells[name] or nil, name)
end

---Whether the player turned a spell off.
---@param name string
---@return boolean
local function IsOff(name)
    return S.overrides[name] == S.OFF
end

---Sets a spell's own choice, colours the bars again and redraws the list (its name may turn red).
---@param name string
---@param mask number?
local function Choose(name, mask)
    S.overrides[name] = mask
    ns.RepaintAll()
    Rebuild()
end

---A spell's page.
---@param name string
---@return table
local function SpellPage(name)
    local args = {
        source = {
            type = "description",
            order = 1,
            ---@return string
            name = function()
                local _, source = SchoolsOf(name)
                local key = IsOff(name) and "off" or source or "none"
                return L.SOURCE:format(L["SOURCE_" .. key]) --[[@as string]]
            end,
        },
        off = { type = "toggle", order = 20, name = L.OFF, desc = L.OFF_DESC },
        remove = {
            type = "execute",
            order = 30,
            width = "double",
            name = L.REMOVE,
            ---@return boolean
            disabled = function()
                return S.overrides[name] == nil
            end,
            func = function()
                Choose(name, nil)
            end,
        },
    }
    for order, school in ipairs(S.order) do
        args[school] = { type = "toggle", order = 10 + order, name = L[school] }
    end
    return {
        type = "group",
        ---@return string
        name = function()
            local id = spells[name]
            local info = C_Spell.GetSpellInfo(id or name)
            local text = IsOff(name) and OFF_NAME:format(name) or name
            return ICON:format(info and info.iconID or QUESTION_MARK, text)
        end,
        ---@return boolean
        hidden = function()
            return filter ~= "" and not name:lower():find(filter, 1, true)
        end,
        ---@param info string[]
        ---@return boolean
        get = function(info)
            local key = info[#info]
            if key == "off" then return IsOff(name) end
            return bit.band(SchoolsOf(name) or 0, S.masks[key] --[[@as number]]) ~= 0
        end,
        ---@param info string[]
        ---@param on boolean
        set = function(info, on)
            local key = info[#info]
            if key == "off" then
                Choose(name, on and S.OFF or nil)
                return
            end
            local mask, school = SchoolsOf(name) or 0, S.masks[key] --[[@as number]]
            if on then
                mask = bit.bor(mask, school)
            elseif bit.band(mask, school) ~= 0 then
                mask = mask - school
            end
            -- Every tick off: the spell is off, as the player's choice.
            Choose(name, mask)
        end,
        args = args,
    }
end

---Builds the list again from what the plugin knows now.
local function Build()
    for name in pairs(spells) do
        spells[name] = nil
    end
    for name in pairs(S.overrides) do
        List(name)
    end
    ListSpellbook()
    for name, id in pairs(ns.seen) do
        List(name, id)
    end
    for name in pairs(S.learned) do
        List(name)
    end
    local args = (tab --[[@as {args: table<string, table>}]]).args
    for key in pairs(args) do
        if key:sub(1, #PREFIX) == PREFIX then args[key] = nil end
    end
    for name in pairs(spells) do
        args[PREFIX .. name] = SpellPage(name)
    end
end

-- The list is behind what the plugin knows: built again when ElvUI's window opens.
local stale = false

Rebuild = function()
    stale = false
    Build()
    E.Libs.AceConfigRegistry:NotifyChange("ElvUI")
end

---Takes in what changed: at once while ElvUI's options window is open, else when it opens next
---(a spell the combat log names in combat should not build the list for a closed window).
function ns.RefreshSpells()
    if not tab then return end
    if E.Libs.AceConfigDialog.OpenFrames.ElvUI then
        Rebuild()
    else
        stale = true
    end
end

---ElvUI's options window opened (E:ToggleOptions): the list takes in what changed while it was shut.
function ns.OptionsOpened()
    if stale then Rebuild() end
end

---The tab, built once ElvUI's options are loaded.
---@return table
function ns.SpellsTab()
    tab = {
        type = "group",
        order = 3,
        name = L.SPELLS,
        childGroups = "tree",
        args = {
            desc = { type = "description", order = 0, name = L.SPELLS_DESC },
            filter = {
                type = "input",
                order = 1,
                name = L.FILTER,
                ---@return string
                get = function()
                    return filter
                end,
                ---@param _ string[]
                ---@param text string
                set = function(_, text)
                    filter = text:lower()
                end,
            },
            add = {
                type = "input",
                order = 2,
                name = L.ADD,
                ---@return string
                get = function()
                    return ""
                end,
                ---@param _ string[]
                ---@param text string a spell name, or a spell ID
                set = function(_, text)
                    local id = tonumber(text)
                    local info = C_Spell.GetSpellInfo(id or text)
                    local name = info and info.name or text
                    ns.seen[name] = info and info.spellID or false
                    Rebuild()
                    E.Libs.AceConfigDialog:SelectGroup("ElvUI", addon, "spells", PREFIX .. name)
                end,
            },
        },
    }
    Build()
    return tab
end
