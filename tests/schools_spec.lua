-- Where a spell's school comes from: the player's own choice, the client's spell table, the combat
-- log (Classic Era), the spell's description.

local FIREBALL, FROSTFIRE = 133, 401502
-- Spell IDs the tables do not have: an NPC's spells, say.
local NPC_BOLT, NPC_FLAME, NPC_SHADOW = 999001, 999002, 999003

local function colors(client)
    return client.E.db.schoolCastbar.colors
end

local function rgba(color)
    return { color.r, color.g, color.b, 1 }
end

describe("the client's spell table", function()
    it("gives the school by spell ID on WoW: Forever, whatever the spell's name", function()
        local client = NewClient({ client = "forever" })
        assert.same({ 20, "data" }, { client.ns.Schools.Of(FROSTFIRE, "Bolt de givrefeu") })
    end)

    it("gives it on Classic Era too, from Classic Era's own table", function()
        local client = NewClient()
        assert.same({ 4, "data" }, { client.ns.Schools.Of(FIREBALL, "Fireball") })
        -- Season of Discovery's rune spells are in it.
        assert.equal(20, client.ns.Schools.Of(FROSTFIRE, "Frostfire Bolt"))
    end)

    it("gives it on Burning Crusade Classic, from that client's table", function()
        local client = NewClient({ client = "tbc" })
        -- Fireball's last rank, which only Burning Crusade has.
        assert.same({ 4, "data" }, { client.ns.Schools.Of(27070, "Fireball") })
        assert.is_nil(client.ns.Schools.Of(FROSTFIRE, "Frostfire Bolt"))
    end)

    it("is there on every client, Fireball in each", function()
        for _, kind in ipairs({ "era", "tbc", "wrath", "mists", "retail", "forever" }) do
            local client = NewClient({ client = kind })
            assert.same({ 4, "data" }, { client.ns.Schools.Of(FIREBALL, "Fireball") }, kind)
        end
    end)

    it("works with the client's own school masks missing (Enum.Damageclass)", function()
        local client = NewClient({ client = "wrath" })
        assert.equal(16, client.ns.Schools.masks.frost)
    end)

    it("works on a client without issecretvalue, which hides nothing", function()
        local client = NewClient({ client = "wrath" })
        local bar = client:Cast("player", "Fireball", FIREBALL)
        assert.same({ 4, "data" }, { client.ns.Schools.Of(FIREBALL, "Fireball") })
        assert.equal(1, bar.fill.color[4])
    end)

    it("is not listened to on retail either", function()
        local client = NewClient({ client = "retail" })
        assert.is_nil(client.events.COMBAT_LOG_EVENT_UNFILTERED)
    end)

    it("listens to the combat log on Burning Crusade Classic too", function()
        local client = NewClient({ client = "tbc" })
        client:CombatLog("SPELL_CAST_START", "Dark Bolt", 32)
        assert.equal(32, client.ns.Schools.Of(nil, "Dark Bolt"))
    end)

    it("is skipped for a spell ID the client hides", function()
        local client = NewClient({ client = "forever" })
        assert.is_nil(client.ns.Schools.Of(SECRET, "Fireball"))
    end)
end)

describe("the combat log", function()
    it("is not listened to on WoW: Forever, where addons cannot read it", function()
        local client = NewClient({ client = "forever" })
        assert.is_nil(client.events.COMBAT_LOG_EVENT_UNFILTERED)
    end)

    it("teaches a spell's school by name on Classic Era, for a spell the table lacks", function()
        local client = NewClient()
        client:CombatLog("SPELL_CAST_START", "Dark Bolt", 32)
        -- Classic Era's combat log gives no spell ID; every rank shares the name.
        assert.same({ 32, "combatlog" }, { client.ns.Schools.Of(NPC_BOLT, "Dark Bolt") })
    end)

    it("teaches from a channel's or an instant's start too", function()
        local client = NewClient()
        client:CombatLog("SPELL_CAST_SUCCESS", "Arcane Storm", 64)
        assert.equal(64, client.ns.Schools.Of(nil, "Arcane Storm"))
    end)

    it("comes second to the table", function()
        local client = NewClient()
        client:CombatLog("SPELL_CAST_START", "Fireball", 20)
        assert.same({ 4, "data" }, { client.ns.Schools.Of(FIREBALL, "Fireball") })
    end)

    it("is ignored for other lines", function()
        local client = NewClient()
        client:CombatLog("SPELL_DAMAGE", "Dark Bolt", 32)
        assert.is_nil(client.ns.Schools.Of(nil, "Dark Bolt"))
    end)

    it("is remembered for the next session", function()
        local client = NewClient()
        client:CombatLog("SPELL_CAST_START", "Dark Bolt", 32)
        local later = NewClient({ saved = _G[TOC_SAVED] })
        assert.equal(32, later.ns.Schools.Of(nil, "Dark Bolt"))
    end)

    it("colours the cast already on the bar once it names its school", function()
        local client = NewClient()
        local bar = client:Cast("target", "Frostfire Blast", NPC_FLAME)
        assert.equal(0, #client:Segments(bar))
        client:CombatLog("SPELL_CAST_START", "Frostfire Blast", 20)
        assert.equal(1, #client:Segments(bar))
    end)

    it("leaves a bar alone that casts something else", function()
        local client = NewClient()
        local bar = client:Cast("target", "Other Bolt", NPC_SHADOW)
        client:CombatLog("SPELL_CAST_START", "Dark Bolt", 32)
        assert.same({ ELVUI_COLOR[1], ELVUI_COLOR[2], ELVUI_COLOR[3], 1 }, bar.fill.color)
    end)

    it("leaves a hidden bar alone", function()
        local client = NewClient()
        local bar = client:Cast("target", "Dark Bolt", NPC_BOLT)
        bar:Hide()
        bar.fill.color = nil
        client:CombatLog("SPELL_CAST_START", "Dark Bolt", 32)
        assert.is_nil(bar.fill.color)
    end)
end)

describe("the spell's description", function()
    it("names the school where nothing else does", function()
        local client =
            NewClient({ descriptions = { [NPC_BOLT] = "Hurls a fiery ball that causes 14 to 22 Fire damage." } })
        assert.same({ 4, "tooltip" }, { client.ns.Schools.Of(NPC_BOLT, "Flame Bolt") })
    end)

    it("reads a named mix as its schools, not its parts", function()
        local client = NewClient({ descriptions = { [NPC_FLAME] = "Deals 100 Frostfire damage." } })
        assert.equal(20, client.ns.Schools.Of(NPC_FLAME, "Frostfire Blast"))
    end)

    it("takes the first school it names as damage", function()
        local client = NewClient({ descriptions = { [NPC_BOLT] = "Deals Fire damage, then Shadow damage over time." } })
        assert.equal(4, client.ns.Schools.Of(NPC_BOLT, "Twin Bolt"))
    end)

    it("skips a school named for something else than damage", function()
        local client = NewClient({ descriptions = { [NPC_BOLT] = "Lowers Fire resistance, then deals Frost damage." } })
        assert.equal(16, client.ns.Schools.Of(NPC_BOLT, "Chill"))
    end)

    it("reads damage in any capitals", function()
        local client = NewClient({ descriptions = { [NPC_BOLT] = "Arcane Damage to all nearby enemies." } })
        assert.equal(64, client.ns.Schools.Of(NPC_BOLT, "Arcane Burst"))
    end)

    it("takes a school's name only as a whole word", function()
        local client =
            NewClient({ descriptions = { [NPC_BOLT] = "Lights a Bonfire damage zone, then deals Nature damage." } })
        assert.equal(8, client.ns.Schools.Of(NPC_BOLT, "Campfire"))
    end)

    it("takes damage only as a whole word", function()
        local client = NewClient({ descriptions = { [NPC_BOLT] = "Fire damageless, then Shadow damage." } })
        assert.equal(32, client.ns.Schools.Of(NPC_BOLT, "Odd"))
    end)

    it("allows any space between the school and damage, a line break too", function()
        local client = NewClient({ descriptions = { [NPC_BOLT] = "Deals 100 Frost\ndamage." } })
        assert.equal(16, client.ns.Schools.Of(NPC_BOLT, "Chill"))
    end)

    it("knows a whole word in a script Lua has no letters for", function()
        -- Russian: "урона от огня" puts the school last; the name stands alone, so it is found anywhere.
        local client = NewClient({
            locale = "ruRU",
            descriptions = { [NPC_BOLT] = "Наносит 100 ед. урона от огня." },
        })
        assert.equal(4, client.ns.Schools.Of(NPC_BOLT, "Огненный шар"))
        -- A name inside a word, not at its start, does not count.
        local inside =
            NewClient({ locale = "ruRU", descriptions = { [NPC_BOLT] = "Призывает стражаогня." } })
        assert.is_nil(inside.ns.Schools.Of(NPC_BOLT, "Страж"))
    end)

    it("reads the school in any capitals too", function()
        local client = NewClient({ descriptions = { [NPC_BOLT] = "Deals 100 frostfire damage." } })
        assert.equal(20, client.ns.Schools.Of(NPC_BOLT, "Frost Flame"))
    end)

    it("reads a school after damage in a language that puts it there, in any capitals", function()
        -- French: "dégâts de feu", the school after the word for damage.
        local client =
            NewClient({ locale = "frFR", descriptions = { [NPC_BOLT] = "Inflige 100 points de dégâts de feu." } })
        assert.equal(4, client.ns.Schools.Of(NPC_BOLT, "Boule de feu"))
    end)

    it("takes a school with physical in it for a spell's name, not a school", function()
        -- Flamestrike (Physical + Fire) is a spell as well as a school's name.
        local client =
            NewClient({ descriptions = { [NPC_BOLT] = "Calls down a Flamestrike damage zone, dealing Fire damage." } })
        assert.equal(4, client.ns.Schools.Of(NPC_BOLT, "Pillar"))
    end)

    it("knows all schools together (127) by its name", function()
        local client = NewClient({ descriptions = { [NPC_BOLT] = "Deals Chromatic damage." } })
        assert.equal(127, client.ns.Schools.Of(NPC_BOLT, "Prism"))
    end)

    it("finds the school anywhere in a language that joins it to damage", function()
        -- German: "Frostschaden", one word.
        local client = NewClient({ locale = "deDE", descriptions = { [NPC_BOLT] = "Verursacht 100 Frostschaden." } })
        assert.equal(16, client.ns.Schools.Of(NPC_BOLT, "Frostblitz"))
    end)

    it("does not search that loosely in English", function()
        local client = NewClient({ descriptions = { [NPC_BOLT] = "Grants Frost resistance." } })
        assert.is_nil(client.ns.Schools.Of(NPC_BOLT, "Ward"))
    end)

    it("names none when it has no school's name", function()
        local client = NewClient({ descriptions = { [NPC_BOLT] = "Heals a friendly target." } })
        assert.is_nil(client.ns.Schools.Of(NPC_BOLT, "Mend"))
    end)

    it("is not read with the option off", function()
        local client = NewClient({ descriptions = { [NPC_BOLT] = "Causes Fire damage." } })
        client.E.db.schoolCastbar.tooltip = false
        assert.is_nil(client.ns.Schools.Of(NPC_BOLT, "Flame Bolt"))
    end)

    it("comes second to the combat log", function()
        local client = NewClient({ descriptions = { [NPC_BOLT] = "Causes Fire damage." } })
        client:CombatLog("SPELL_CAST_START", "Flame Bolt", 20)
        assert.same({ 20, "combatlog" }, { client.ns.Schools.Of(NPC_BOLT, "Flame Bolt") })
    end)

    it("colours the bar once the client has the text, if it had none yet", function()
        local client = NewClient({ client = "forever" })
        local bar = client:Cast("target", "Shadow Bolt", NPC_SHADOW)
        client.descriptions[NPC_SHADOW] = "Sends a shadowy bolt at the enemy, causing Shadow damage."
        client:Fire("SPELL_TEXT_UPDATE", NPC_SHADOW)
        assert.same(rgba(colors(client).shadow), bar.fill.color)
    end)

    it("is read once per spell", function()
        local client = NewClient({ descriptions = { [NPC_BOLT] = "Causes Fire damage." } })
        client.ns.Schools.Of(NPC_BOLT, "Flame Bolt")
        client.descriptions[NPC_BOLT] = "Causes Frost damage."
        assert.equal(4, client.ns.Schools.Of(NPC_BOLT, "Flame Bolt"))
    end)
end)

describe("the player's own choice", function()
    it("comes before everything else", function()
        local client = NewClient({ client = "forever" })
        client.ns.Schools.overrides["Frostfire Bolt"] = 16
        assert.same({ 16, "override" }, { client.ns.Schools.Of(FROSTFIRE, "Frostfire Bolt") })
    end)

    it("is kept for the next session", function()
        local client = NewClient()
        client.ns.Schools.overrides.Fireball = 2
        local later = NewClient({ saved = _G[TOC_SAVED] })
        assert.equal(2, later.ns.Schools.Of(FIREBALL, "Fireball"))
    end)
end)

describe("a school mask", function()
    it("splits into its schools in the order of their bits", function()
        local client = NewClient()
        local out = {}
        assert.equal(3, client.ns.Schools.Split(4 + 32 + 64, out))
        assert.same({ "fire", "shadow", "arcane" }, out)
    end)

    it("reuses the list it fills, cutting off what an earlier mask left", function()
        local client = NewClient()
        local out = {}
        client.ns.Schools.Split(127, out)
        assert.equal(1, client.ns.Schools.Split(2, out))
        assert.same({ "holy" }, out)
    end)
end)
