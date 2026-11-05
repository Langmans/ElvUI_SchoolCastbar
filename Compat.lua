-- ns.C: the modern spellbook API under the plugin's own name, so the Spells tab reads one API on
-- every client. Each function is the client's own where it has one (retail, WoW: Forever), else the
-- classic way: Classic Era's C_SpellBook has no skill lines, so its spell tabs stand in
-- (GetSpellTabInfo, GetSpellBookItemInfo). Looked up on each call, never written into the game's
-- shared C_ tables: another addon must not take the plugin's stand-ins for the client's.

local _, ns = ... ---@type string, SchoolCastbarNamespace

---@class SchoolCastbarCompat
local C = { SpellBook = {} }
ns.C = C

-- The kinds of spellbook item and the player's own spellbook, as the client's enums have them
-- (Classic Era has neither enum).
C.SpellBookItemType = Enum and Enum.SpellBookItemType or { Spell = 1 }
C.SpellBookSpellBank = Enum and Enum.SpellBookSpellBank or { Player = 0 }

---Whether the client hides a value (secret values: WoW: Forever and retail in combat). Such a value
---may not be tested or compared, only passed on. A client without the check hides nothing.
---@param _ string|number|boolean|table|nil
---@return boolean
local function NeverSecret(_)
    return false
end
C.IsSecret = issecretvalue or NeverSecret

---The client's C_SpellBook function `name`, nil without it.
---@param name string
---@return function?
local function SpellBook(name)
    return C_SpellBook and C_SpellBook[name]
end

---How many skill lines (classic: spell tabs) the spellbook has.
---@return number
function C.SpellBook.GetNumSpellBookSkillLines()
    local own = SpellBook("GetNumSpellBookSkillLines") --[[@as (fun(): number)?]]
    if own then return own() end
    ---@diagnostic disable-next-line: wrong-flavor-api
    return GetNumSpellTabs()
end

---A skill line's (classic: spell tab's) first slot less one, and its number of slots.
---@param line number
---@return SchoolCastbarSkillLine?
function C.SpellBook.GetSpellBookSkillLineInfo(line)
    local own = SpellBook("GetSpellBookSkillLineInfo") --[[@as (fun(line: number): SchoolCastbarSkillLine?)?]]
    if own then return own(line) end
    ---@diagnostic disable-next-line: wrong-flavor-api
    local name, _, offset, count = GetSpellTabInfo(line)
    if not name then return nil end
    return { itemIndexOffset = offset, numSpellBookItems = count }
end

---What sits in a slot of the player's spellbook: its kind and, for a spell, its spell ID.
---@param slot number
---@return SchoolCastbarBookItem?
function C.SpellBook.GetSpellBookItemInfo(slot)
    local own = SpellBook("GetSpellBookItemInfo") --[[@as (fun(slot: number, bank: number): SchoolCastbarBookItem?)?]]
    if own then return own(slot, C.SpellBookSpellBank.Player) end
    ---@diagnostic disable-next-line: wrong-flavor-api
    local kind, id = GetSpellBookItemInfo(slot, BOOKTYPE_SPELL)
    if kind ~= "SPELL" then return nil end
    return { itemType = C.SpellBookItemType.Spell, spellID = id }
end
