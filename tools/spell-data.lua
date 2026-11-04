-- Writes Data/<Client>.lua: the school of every spell a class can cast with a cast bar (one with a
-- cast time, or a channel), by spell ID, per client. No call returns a spell's school; WoW: Forever
-- gives addons no combat log either. Other spells (an NPC's, a mind-controlled one's) are left to
-- the combat log, the description and the player's own choice.
--
-- A class spell: an ability on a skill line of category Class, a specialization's or a talent's
-- spell, or on Classic Era a Season of Discovery rune's spell (named as an "Engrave <slot> - <rune>"
-- ability, IDs from 398000 up). tools/spell-fixes.lua adds the ones no table names.
--
-- The table lists the spells per class (from SpellClassOptions' class family, else the skill line's
-- ClassMask), by name, each with its name as a comment, so it can be read through.
--
-- Reads the newest build of each client in ../.spelldata (tools/fetch-spelldata.sh gets them).
-- Run from the repository root after a patch:
--
--   lua tools/spell-data.lua

local lfs = require("lfs")

local SPELLDATA = "../.spelldata/"
local CLIENTS = {
    {
        product = "wow_classic_era",
        file = "Data/ClassicEra.lua",
        name = "Classic Era",
        project = "WOW_PROJECT_CLASSIC",
    },
    {
        product = "wow_anniversary",
        file = "Data/BurningCrusade.lua",
        name = "Burning Crusade Classic Anniversary",
        project = "WOW_PROJECT_BURNING_CRUSADE_CLASSIC",
    },
    {
        product = "wow_classic_titan",
        file = "Data/Wrath.lua",
        name = "Wrath Classic",
        project = "WOW_PROJECT_WRATH_CLASSIC",
    },
    {
        product = "wow_classic",
        file = "Data/Mists.lua",
        name = "Mists of Pandaria Classic",
        project = "WOW_PROJECT_MISTS_CLASSIC",
    },
    { product = "wow", file = "Data/Retail.lua", name = "Retail", project = "WOW_PROJECT_MAINLINE" },
    { product = "wowf", file = "Data/Forever.lua", name = "WoW: Forever", project = "WOW_PROJECT_CAMELOT" },
}
-- SpellCastTimes ID 1 is "0 ms": an instant spell, no cast bar.
local INSTANT = 1
-- Attributes_1: SPELL_ATTR1_IS_CHANNELLED and SPELL_ATTR1_IS_SELF_CHANNELLED.
local CHANNELED = { 0x4, 0x40 }
local FIRST_RUNE_SPELL = 398000
-- The SkillLineCategory IDs the script reads.
local categories = { class = 7, secondary = 9, profession = 11 }
-- The SkillLine IDs of category Class that belong to no class.
local skillLines =
    { internal = 769, mounts = 777, companions = 778, engraving = 2851, adventurer = 2816, traveler = 2929 }

-- Those lines, left out of the class lines. Engraving's casts only put a rune on (the rune's own
-- spells are found by name, below); a class mount (Summon Felsteed, Summon Charger) is on its
-- class's line too.
local NOT_A_CLASS = {
    [skillLines.internal] = true,
    [skillLines.mounts] = true,
    [skillLines.companions] = true,
    [skillLines.engraving] = true,
    [skillLines.adventurer] = true,
    [skillLines.traveler] = true,
}
-- The categories of a profession's lines: secondary skills (Cooking, Fishing) and professions.
local PROFESSION_CATEGORIES = { [categories.secondary] = true, [categories.profession] = true }
-- The classes in the game's order, each with its bit in a ClassMask and its family in
-- SpellClassOptions (SpellClassSet). A spell of none goes under OTHER.
local CLASSES = {
    { name = "Warrior", mask = 1, family = 4 },
    { name = "Paladin", mask = 2, family = 10 },
    { name = "Hunter", mask = 4, family = 9 },
    { name = "Rogue", mask = 8, family = 8 },
    { name = "Priest", mask = 16, family = 6 },
    { name = "Death Knight", mask = 32, family = 15 },
    { name = "Shaman", mask = 64, family = 11 },
    { name = "Mage", mask = 128, family = 3 },
    { name = "Warlock", mask = 256, family = 5 },
    { name = "Monk", mask = 512, family = 53 },
    { name = "Druid", mask = 1024, family = 7 },
    { name = "Demon Hunter", mask = 2048, family = 107 },
    { name = "Evoker", mask = 4096, family = 224 },
}
local OTHER = #CLASSES + 1
---@type table<number, number>, table<number, number>
local classByMask, classByFamily = {}, {}
for index, class in ipairs(CLASSES) do
    classByMask[class.mask], classByFamily[class.family] = index, index
end
-- The other tables that teach class spells, with their spell ID columns.
local TAUGHT_BY = {
    SpecializationSpells = { "SpellID" },
    Talent = { "SpellID", "SpellRank_0", "SpellRank_1", "SpellRank_2", "SpellRank_3", "SpellRank_4" },
    TraitDefinition = { "SpellID" },
}

---The newest build folder of a product: versions compared number by number.
---@param dir string
---@return string
local function newestBuild(dir)
    local best, bestKey
    for name in lfs.dir(dir) do
        if name:match("^%d+%.%d+%.%d+%.%d+$") then
            local key = name:gsub("%d+", function(n)
                return ("%06d"):format(tonumber(n))
            end)
            if not bestKey or key > bestKey then
                best, bestKey = name, key
            end
        end
    end
    return assert(best, "no build in " .. dir)
end

---Whether bit is set in value (Lua 5.1 has no bit operators).
---@param value number
---@param bit number
---@return boolean
local function has(value, bit)
    return math.floor(value / bit) % 2 == 1
end

---The fields of a CSV line: quoted ones (which may hold commas) unquoted, numbers as numbers.
---@param line string
---@return (string|number)[]
local function split(line)
    local fields = {}
    local pos = 1
    line = line:gsub("\r$", "")
    while pos <= #line + 1 do
        local value, after
        if line:sub(pos, pos) == '"' then
            local close = pos
            repeat
                close = assert(line:find('"', close + 1, true), "unclosed quote")
                local doubled = line:sub(close + 1, close + 1) == '"'
                if doubled then close = close + 1 end
            until not doubled
            value, after = line:sub(pos + 1, close - 1):gsub('""', '"'), close + 1
        else
            after = line:find(",", pos, true) or #line + 1
            value = line:sub(pos, after - 1)
        end
        fields[#fields + 1] = tonumber(value) or value
        pos = after + 1
    end
    return fields
end

---Each row of a table as {column name = value}.
---@param path string
---@return fun(): table<string, string|number>?
local function rows(path)
    local file = assert(io.open(path, "rb"))
    local header = split(file:read("*l"))
    return function()
        local line = file:read("*l")
        if not line then
            file:close()
            return nil
        end
        -- A quoted field can hold line breaks (a talent's description): an odd number of quotes
        -- means the record goes on on the next line.
        while select(2, line:gsub('"', "")) % 2 == 1 do
            line = line .. "\n" .. assert(file:read("*l"), "unclosed quote at the end of " .. path)
        end
        local row = {}
        for index, value in ipairs(split(line)) do
            row[header[index]] = value
        end
        return row
    end
end

---The school of each class spell with a cast bar, from one build, and every spell's name.
---@param dir string the build's folder
---@param fixes table<number, true|number> the product's own fixes (tools/spell-fixes.lua)
---@return table<number, number> schools
---@return table<number, string> names
local function readSchools(dir, fixes)
    ---@type table<number, string>
    local names = {}
    for row in rows(dir .. "/SpellName.csv") do
        names[row.ID] = tostring(row.Name_lang)
    end

    -- A class's skill line (category Class: "Death Knight", "Frost", "Pet - Ghoul"). Only its
    -- abilities count: the ClassMask alone also marks mounts, bandages and the like on the newer
    -- clients, and leaves many class spells at 0 there.
    ---@type table<number, boolean>, table<number, boolean>
    local classLines, professionLines = {}, {}
    for row in rows(dir .. "/SkillLine.csv") do
        if row.CategoryID == categories.class and not NOT_A_CLASS[row.ID] then classLines[row.ID] = true end
        if PROFESSION_CATEGORIES[row.CategoryID] then professionLines[row.ID] = true end
    end
    -- A profession's recipes come in through retail's talent trees too; they are left out.
    ---@type table<number, boolean>, table<string, boolean>, table<number, boolean>
    local classSpells, runes, recipes = {}, {}, {}
    for row in rows(dir .. "/SkillLineAbility.csv") do
        local rune = row.ClassMask > 0 and (names[row.Spell] or ""):match("^Engrave [^-]+ %- (.+)$")
        if rune then runes[rune] = true end
        if classLines[row.SkillLine] then classSpells[row.Spell] = true end
        if professionLines[row.SkillLine] then recipes[row.Spell] = true end
    end
    for id, name in pairs(names) do
        if id >= FIRST_RUNE_SPELL and runes[name] then classSpells[id] = true end
    end
    -- Spells taught by a specialization, a talent (each rank its own spell) or a retail talent tree;
    -- each table only where the client has it.
    for table, columns in pairs(TAUGHT_BY) do
        if lfs.attributes(dir .. "/" .. table .. ".csv") then
            for row in rows(dir .. "/" .. table .. ".csv") do
                for _, column in ipairs(columns) do
                    local spell = row[column]
                    if type(spell) == "number" and spell > 0 then classSpells[spell] = true end
                end
            end
        end
    end
    for id in pairs(fixes) do
        classSpells[id] = true
    end

    ---@type table<number, number>
    local schools = {}
    for row in rows(dir .. "/SpellMisc.csv") do
        local attributes = row.Attributes_1
        local channeled = has(attributes, CHANNELED[1]) or has(attributes, CHANNELED[2])
        -- A spell can have a row per difficulty; the base one (DifficultyID 0) wins.
        if
            classSpells[row.SpellID]
            and not recipes[row.SpellID]
            and row.SchoolMask > 0
            and (row.CastingTimeIndex ~= INSTANT or channeled)
            and row.DifficultyID == 0
        then
            schools[row.SpellID] = row.SchoolMask
        end
    end
    for id, fix in pairs(fixes) do
        if type(fix) == "number" then schools[id] = fix end
        -- A fix that did not make it: a wrong ID, or a spell without a cast bar.
        if not schools[id] then print(("  fix %d (%s): no cast bar in this build"):format(id, names[id] or "?")) end
    end
    return schools, names
end

---The class of each spell, as an index into CLASSES (OTHER for none): its family in
---SpellClassOptions, else the class of a skill line ability's ClassMask, else of the line it is on
---(the newer clients leave the ClassMask of many abilities at 0, but not all of a line's).
---@param dir string the build's folder
---@return table<number, number>
local function readClasses(dir)
    ---@type table<number, number>, table<number, number>, table<number, number>
    local byFamily, byMask, lineClass = {}, {}, {}
    for row in rows(dir .. "/SpellClassOptions.csv") do
        byFamily[row.SpellID] = classByFamily[row.SpellClassSet]
    end
    ---@type {spell: number, line: number}[]
    local unmarked = {}
    for row in rows(dir .. "/SkillLineAbility.csv") do
        local class = classByMask[row.ClassMask]
        if class then
            byMask[row.Spell], lineClass[row.SkillLine] = class, class
        else
            unmarked[#unmarked + 1] = { spell = row.Spell, line = row.SkillLine }
        end
    end
    for _, row in ipairs(unmarked) do
        byMask[row.spell] = byMask[row.spell] or lineClass[row.line]
    end
    return setmetatable({}, {
        __index = function(_, id)
            return byFamily[id] or byMask[id] or OTHER
        end,
    })
end

-- The fixes per product.
---@type table<string, table<number, true|number>>
local FIXES = dofile("tools/spell-fixes.lua")

for _, client in ipairs(CLIENTS) do
    local build = newestBuild(SPELLDATA .. client.product)
    local dir = SPELLDATA .. client.product .. "/" .. build
    local schools, names = readSchools(dir, FIXES[client.product] or {})
    local classOf = readClasses(dir)
    -- Per class in the game's order, then by name (a spell's ranks together), then by ID.
    ---@type number[]
    local ids = {}
    for id in pairs(schools) do
        ids[#ids + 1] = id
    end
    table.sort(ids, function(a, b)
        if classOf[a] ~= classOf[b] then return classOf[a] < classOf[b] end
        local nameA, nameB = names[a] or "", names[b] or ""
        if nameA ~= nameB then return nameA < nameB end
        return a < b
    end)

    local out = assert(io.open(client.file, "wb"))
    out:write("-- Generated by tools/spell-data.lua from ", client.name, " ", build, " (wago.tools). Do not edit.\n")
    out:write("-- The school mask of each class spell with a cast bar, by spell ID; loaded on ", client.name)
    out:write(" only.\n")
    out:write("if WOW_PROJECT_ID ~= ", client.project, " then return end\n")
    out:write("local _, ns = ... ---@type string, SchoolCastbarNamespace\n")
    out:write("-- stylua: ignore\n")
    out:write("ns.data = {\n")
    local section
    for _, id in ipairs(ids) do
        if classOf[id] ~= section then
            section = classOf[id]
            out:write("-- ", CLASSES[section] and CLASSES[section].name or "Other", "\n")
        end
        out:write("[", id, "]=", schools[id], ", -- ", names[id] or "?", "\n")
    end
    out:write("}\n")
    out:close()
    print(("%s: %d spells from %s %s"):format(client.file, #ids, client.name, build))
end
